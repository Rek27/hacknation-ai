import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;

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
    return HealthStatus.fromJson(jsonDecode(res.body));
  }

  Future<List<RagDocument>> listDocuments() async {
    _log('listDocuments()');
    final res = await _client.get('/documents');
    if (res.statusCode != 200) {
      throw HttpException('Documents failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return docs.map(RagDocument.fromJson).toList();
  }

  Future<UploadResponse> uploadDocument(File file) async {
    _log('uploadDocument(file=${file.path})');
    final streamed = await _client.postMultipart('/upload', file, 'file');
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw HttpException('Upload failed: ${res.statusCode}');
    }
    return UploadResponse.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteDocument(String filename) async {
    _log('deleteDocument(filename=$filename)');
    final res = await _client.delete('/documents/$filename');
    if (res.statusCode != 200 && res.statusCode != 404) {
      throw HttpException('Delete failed: ${res.statusCode}');
    }
  }

  /// Stream OutputItemBase from POST /chat (SSE-esque text/event-stream).
  Stream<OutputItemBase> streamChat(ChatRequestBody body) async* {
    _log('streamChat(sessionId=${body.sessionId})');
    final response = await _client.postStreamJson('/chat', body.toJson());
    if (response.statusCode != 200) {
      throw HttpException('Chat failed: ${response.statusCode}');
    }
    _log('streamChat() connected: ${response.statusCode}');

    // Read the byte stream and parse lines starting with "data: "
    final stream = response.stream.transform(utf8.decoder);
    final buffer = StringBuffer();

    await for (final chunk in stream) {
      _log('streamChat() chunk bytes=${chunk.length}');
      buffer.write(chunk);
      var text = buffer.toString();

      final lines = text.split('\n');
      buffer.clear();
      if (!text.endsWith('\n')) {
        // keep last incomplete line in buffer
        buffer.write(lines.removeLast());
      }

      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final data = trimmed.substring(6).trim();
        if (data.isEmpty) continue;
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final item = parseOutputItem(json);
          _log('streamChat() item type=${item.type}');
          yield item;
        } catch (e) {
          _log('streamChat() parse failed: $e; data="$data"');
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Chat service abstraction for the new chunk-based chat feature.
// ---------------------------------------------------------------------------

/// Contract for sending a user message and receiving agent output chunks.
/// Implement with real HTTP when the backend is ready.
abstract class ChatService {
  Future<List<OutputItemBase>> sendMessage(String message);
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
        ];
      case 1:
        return [
          TextChunk(
            type: OutputItemType.text,
            content:
                'Now let\'s look at the equipment you might need '
                'for the event:',
          ),
          TreeChunk(
            treeType: TreeType.equipment,
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
      case 2:
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
