import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

import 'package:frontend/model/api_models.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/service/api_client.dart';

class AgentApi {
  final ApiClient _client;

  AgentApi(this._client);

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[AgentApi] $message');
    }
  }

  Future<HealthStatus> getHealth() async {
    _log('getHealth()');
    final res = await _client.get('/health');
    if (res.statusCode != 200) {
      throw HttpException('Health failed: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[AgentApi] getHealth() response JSON:\n${const JsonEncoder.withIndent('  ').convert(json)}',
      );
    }
    return HealthStatus.fromJson(json);
  }

  /// Stream OutputItemBase from POST /chat (SSE-esque text/event-stream).
  Stream<OutputItemBase> streamChat(ChatRequestBody body) async* {
    _log('streamChat(sessionId=${body.sessionId})');
    yield* _streamSse('/chat', body.toJson(), 'streamChat');
  }

  /// Stream OutputItemBase from POST /submit-tree (SSE text/event-stream).
  Stream<OutputItemBase> streamSubmitTree(SubmitTreeRequestBody body) async* {
    _log('streamSubmitTree(sessionId=${body.sessionId})');
    yield* _streamSse('/submit-tree', body.toJson(), 'streamSubmitTree');
  }

  /// Stream OutputItemBase from POST /submit-form (SSE text/event-stream).
  /// The backend streams text reasoning, retailer_offers, and cart events.
  Stream<OutputItemBase> streamSubmitForm(SubmitFormRequestBody body) async* {
    _log('streamSubmitForm(sessionId=${body.sessionId})');
    yield* _streamSse('/submit-form', body.toJson(), 'streamSubmitForm');
  }

  /// Start a voice session via POST /start-voice
  Future<StartVoiceResponse> startVoice(String sessionId) async {
    _log('startVoice(sessionId=$sessionId)');
    final body = {
      'session_id': sessionId,
      'message': 'Hello, please tell me what you are building today so I can help you with the organization.',
      'user_name': 'User',
    };
    final res = await _client.postJson('/start-voice', body);
    if (res.statusCode != 200) {
      throw HttpException('Start voice failed: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (kDebugMode) {
      // ignore: avoid_print
      print('[AgentApi] startVoice() response JSON:\n${const JsonEncoder.withIndent('  ').convert(json)}');
    }
    return StartVoiceResponse.fromJson(json);
  }

  /// Send voice input via POST /voice-input (multipart/form-data)
  Future<VoiceInputResponse> sendVoiceInput(
    String sessionId,
    File audioFile,
  ) async {
    _log('sendVoiceInput(sessionId=$sessionId, audioFile=${audioFile.path})');
    final uri = Uri.parse('${_client.baseUrl}/voice-input');
    final request = http.MultipartRequest('POST', uri);
    
    // Add headers
    if (_client.baseUrl.contains('ngrok-free.app')) {
      request.headers['ngrok-skip-browser-warning'] = 'true';
    }
    
    // Add fields
    request.fields['session_id'] = sessionId;
    
    // Add audio file with explicit content type
    // Use audio/wav for WAV files (more universally compatible)
    request.files.add(await http.MultipartFile.fromPath(
      'audio',
      audioFile.path,
      contentType: http_parser.MediaType('audio', 'wav'),
    ));
    
    try {
      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);
      
      if (res.statusCode != 200) {
        throw HttpException('Voice input failed: ${res.statusCode}');
      }
      
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (kDebugMode) {
        // ignore: avoid_print
        print('[AgentApi] sendVoiceInput() response JSON:\n${const JsonEncoder.withIndent('  ').convert(json)}');
      }
      
      return VoiceInputResponse.fromJson(json);
    } catch (e) {
      _log('sendVoiceInput() failed: $e');
      rethrow;
    }
  }

  /// Get TTS audio URL for the given audio_id
  String getTtsAudioUrl(String audioId) {
    return '${_client.baseUrl}/tts-audio/$audioId';
  }

  /// Shared SSE stream parser for streaming endpoints.
  Stream<OutputItemBase> _streamSse(
    String path,
    Map<String, dynamic> body,
    String tag,
  ) async* {
    final response = await _client.postStreamJson(path, body);
    if (response.statusCode != 200) {
      throw HttpException('$tag failed: ${response.statusCode}');
    }
    _log('$tag() connected: ${response.statusCode}');

    final stream = response.stream.transform(utf8.decoder);
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      _log('$tag() chunk bytes=${chunk.length}');
      buffer.write(chunk);
      var text = buffer.toString();

      final lines = text.split('\n');
      buffer.clear();
      if (!text.endsWith('\n')) {
        buffer.write(lines.removeLast());
      }

      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final data = trimmed.substring(6).trim();
        if (data.isEmpty) continue;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          if (kDebugMode) {
            // ignore: avoid_print
            print(
              '[AgentApi] $tag() response JSON:\n${const JsonEncoder.withIndent('  ').convert(json)}',
            );
          }
          final item = parseOutputItem(json);
          _log('$tag() item type=${item.type}');
          yield item;
        } catch (e) {
          _log('$tag() parse failed: $e; data="$data"');
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Chat service abstraction for the new chunk-based chat feature.
// ---------------------------------------------------------------------------

/// Contract for chat operations: messaging, tree submission, and form submission.
abstract class ChatService {
  Future<List<OutputItemBase>> sendMessage(String message);
  Future<List<OutputItemBase>> submitTree({
    required List<Map<String, dynamic>> peopleTree,
    required List<Map<String, dynamic>> placeTree,
  });
  Future<List<OutputItemBase>> submitForm(TextFormChunk form);
}

/// Real implementation that delegates to [AgentApi] over HTTP.
class RealChatService implements ChatService {
  final AgentApi _api;
  final String _sessionId;

  RealChatService(this._api, this._sessionId);

  @override
  Future<List<OutputItemBase>> sendMessage(String message) async {
    final ChatRequestBody body = ChatRequestBody(
      userName: 'User',
      message: message,
      sessionId: _sessionId,
    );
    return await _api.streamChat(body).toList();
  }

  @override
  Future<List<OutputItemBase>> submitTree({
    required List<Map<String, dynamic>> peopleTree,
    required List<Map<String, dynamic>> placeTree,
  }) async {
    final SubmitTreeRequestBody body = SubmitTreeRequestBody(
      sessionId: _sessionId,
      peopleTree: peopleTree,
      placeTree: placeTree,
    );
    return await _api.streamSubmitTree(body).toList();
  }

  @override
  Future<List<OutputItemBase>> submitForm(TextFormChunk form) async {
    final SubmitFormRequestBody body = SubmitFormRequestBody(
      sessionId: _sessionId,
      address: form.address.toJson(),
      budget: form.budget.toJson(),
      date: form.date.toJson(),
      duration: form.durationOfEvent.toJson(),
      numberOfAttendees: form.numberOfAttendees.toJson(),
    );
    return await _api.streamSubmitForm(body).toList();
  }
}

/// Mock implementation that returns realistic chunk sequences.
/// Tracks conversation step to simulate a multi-turn event-planning flow.
class MockChatService implements ChatService {
  int _step = 0;

  @override
  Future<List<OutputItemBase>> sendMessage(String message) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final List<OutputItemBase> response = _responseForStep(_step);
    _step++;
    return response;
  }

  @override
  Future<List<OutputItemBase>> submitTree({
    required List<Map<String, dynamic>> peopleTree,
    required List<Map<String, dynamic>> placeTree,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return [
      TextChunk(
        type: OutputItemType.text,
        content:
            'Perfect choices! Now let\'s finalize the event details. '
            'Please fill in the information below so I can find the '
            'best options for you.',
      ),
      TextFormChunk(
        address: TextFieldChunk(label: 'Event Address'),
        budget: TextFieldChunk(label: 'Budget (\$)'),
        date: TextFieldChunk(label: 'Event Date'),
        durationOfEvent: TextFieldChunk(label: 'Duration'),
        numberOfAttendees: TextFieldChunk(label: 'Number of Attendees'),
      ),
    ];
  }

  @override
  Future<List<OutputItemBase>> submitForm(TextFormChunk form) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return [
      TextChunk(
        type: OutputItemType.text,
        content: 'Form submitted successfully. Building your cart...',
      ),
    ];
  }

  /// Returns both trees in a single response so the controller can
  /// buffer the second tree until the user submits the first.
  List<OutputItemBase> _responseForStep(int step) {
    switch (step) {
      case 0:
        return [
          TextChunk(
            type: OutputItemType.text,
            content:
                'Great! Let me help you plan your event. '
                'First, let\'s figure out what kind of people and services '
                'you\'ll need. Please select the categories that apply:',
          ),
          TreeChunk(
            treeType: TreeType.people,
            category: Category(
              emoji: '👥',
              label: 'People',
              isSelected: false,
              subcategories: [
                Category(
                  emoji: '🍳',
                  label: 'Catering',
                  isSelected: false,
                  subcategories: [
                    Category(
                      emoji: '🍕',
                      label: 'Food',
                      isSelected: false,
                      subcategories: [],
                    ),
                    Category(
                      emoji: '🍹',
                      label: 'Drinks',
                      isSelected: false,
                      subcategories: [],
                    ),
                    Category(
                      emoji: '🍰',
                      label: 'Desserts',
                      isSelected: false,
                      subcategories: [],
                    ),
                  ],
                ),
                Category(
                  emoji: '🎵',
                  label: 'Music & Entertainment',
                  isSelected: false,
                  subcategories: [
                    Category(
                      emoji: '🎤',
                      label: 'DJ',
                      isSelected: false,
                      subcategories: [],
                    ),
                    Category(
                      emoji: '🎸',
                      label: 'Live Band',
                      isSelected: false,
                      subcategories: [],
                    ),
                  ],
                ),
                Category(
                  emoji: '📸',
                  label: 'Photography',
                  isSelected: false,
                  subcategories: [
                    Category(
                      emoji: '📷',
                      label: 'Photographer',
                      isSelected: false,
                      subcategories: [],
                    ),
                    Category(
                      emoji: '🎥',
                      label: 'Videographer',
                      isSelected: false,
                      subcategories: [],
                    ),
                  ],
                ),
                Category(
                  emoji: '🛡️',
                  label: 'Security',
                  isSelected: false,
                  subcategories: [],
                ),
              ],
            ),
          ),
          TextChunk(
            type: OutputItemType.text,
            content:
                'Now let\'s look at the equipment you might need '
                'for the event:',
          ),
          TreeChunk(
            treeType: TreeType.place,
            category: Category(
              emoji: '🔧',
              label: 'Equipment',
              isSelected: false,
              subcategories: [
                Category(
                  emoji: '🎪',
                  label: 'Tents & Structures',
                  isSelected: false,
                  subcategories: [
                    Category(
                      emoji: '⛺',
                      label: 'Main Tent',
                      isSelected: false,
                      subcategories: [],
                    ),
                    Category(
                      emoji: '🏕️',
                      label: 'Side Canopies',
                      isSelected: false,
                      subcategories: [],
                    ),
                  ],
                ),
                Category(
                  emoji: '🔊',
                  label: 'Audio & Visual',
                  isSelected: false,
                  subcategories: [
                    Category(
                      emoji: '🎙️',
                      label: 'Speakers',
                      isSelected: false,
                      subcategories: [],
                    ),
                    Category(
                      emoji: '💡',
                      label: 'Lighting',
                      isSelected: false,
                      subcategories: [],
                    ),
                    Category(
                      emoji: '📺',
                      label: 'Screens',
                      isSelected: false,
                      subcategories: [],
                    ),
                  ],
                ),
                Category(
                  emoji: '🪑',
                  label: 'Furniture',
                  isSelected: false,
                  subcategories: [
                    Category(
                      emoji: '🍽️',
                      label: 'Tables',
                      isSelected: false,
                      subcategories: [],
                    ),
                    Category(
                      emoji: '💺',
                      label: 'Chairs',
                      isSelected: false,
                      subcategories: [],
                    ),
                  ],
                ),
                Category(
                  emoji: '🚿',
                  label: 'Sanitary',
                  isSelected: false,
                  subcategories: [],
                ),
              ],
            ),
          ),
        ];
      default:
        return [
          TextChunk(
            type: OutputItemType.text,
            content:
                'Thanks for providing all the details! I\'m now searching '
                'for the best deals and will prepare your cart shortly.',
          ),
        ];
    }
  }
}
