import 'dart:convert';

/// Health endpoint response: GET /health
class HealthStatus {
  final String status;
  final int activeSessions;

  HealthStatus({
    required this.status,
    required this.activeSessions,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) => HealthStatus(
    status: json['status'] as String,
    activeSessions: json['active_sessions'] as int,
  );
}

/// Document entry from GET /documents
class RagDocument {
  final String filename;
  final int chunks;

  RagDocument({required this.filename, required this.chunks});

  factory RagDocument.fromJson(Map<String, dynamic> json) => RagDocument(
    filename: json['filename'] as String,
    chunks: json['chunks'] as int,
  );
}

/// Response from POST /upload
class UploadResponse {
  final bool success;
  final String filename;
  final int chunksAdded;
  final int totalChunks;

  UploadResponse({
    required this.success,
    required this.filename,
    required this.chunksAdded,
    required this.totalChunks,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) => UploadResponse(
    success: json['success'] as bool,
    filename: json['filename'] as String,
    chunksAdded: json['chunks_added'] as int,
    totalChunks: json['total_chunks'] as int,
  );
}

/// Request body for POST /chat
class ChatRequestBody {
  final String userName;
  final String message;
  final String sessionId;

  ChatRequestBody({
    required this.userName,
    required this.message,
    required this.sessionId,
  });

  Map<String, dynamic> toJson() => {
    'user_name': userName,
    'message': message,
    'session_id': sessionId,
  };

  String toJsonString() => jsonEncode(toJson());
}

/// Request body for POST /submit-tree
class SubmitTreeRequestBody {
  final String sessionId;
  final List<Map<String, dynamic>> peopleTree;
  final List<Map<String, dynamic>> placeTree;

  SubmitTreeRequestBody({
    required this.sessionId,
    required this.peopleTree,
    required this.placeTree,
  });

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'people_tree': peopleTree,
    'place_tree': placeTree,
  };
}

/// Request body for POST /submit-form
class SubmitFormRequestBody {
  final String sessionId;
  final Map<String, dynamic> address;
  final Map<String, dynamic> budget;
  final Map<String, dynamic> date;
  final Map<String, dynamic> duration;
  final Map<String, dynamic> numberOfAttendees;

  SubmitFormRequestBody({
    required this.sessionId,
    required this.address,
    required this.budget,
    required this.date,
    required this.duration,
    required this.numberOfAttendees,
  });

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'address': address,
    'budget': budget,
    'date': date,
    'duration': duration,
    'numberOfAttendees': numberOfAttendees,
  };
}

/// Response from POST /submit-form
class SubmitFormResponse {
  final bool success;
  final String message;
  final String sessionId;
  final List<String> itemsSummary;

  SubmitFormResponse({
    required this.success,
    required this.message,
    required this.sessionId,
    required this.itemsSummary,
  });

  factory SubmitFormResponse.fromJson(Map<String, dynamic> json) =>
      SubmitFormResponse(
        success: json['success'] as bool,
        message: json['message'] as String,
        sessionId: json['session_id'] as String,
        itemsSummary:
            (json['items_summary'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
      );
}

/// Response from POST /start-voice
class StartVoiceResponse {
  final String sessionId;
  final String text;
  final String audioId;
  final String phase;

  StartVoiceResponse({
    required this.sessionId,
    required this.text,
    required this.audioId,
    required this.phase,
  });

  factory StartVoiceResponse.fromJson(Map<String, dynamic> json) =>
      StartVoiceResponse(
        sessionId: json['session_id'] as String,
        text: json['text'] as String,
        audioId: json['audio_id'] as String,
        phase: json['phase'] as String,
      );
}

/// Response from POST /voice-input
class VoiceInputResponse {
  final String text;
  final String audioId;
  final String phase;
  final Map<String, dynamic> data;
  final String transcribedText;
  final bool waitForInput;

  VoiceInputResponse({
    required this.text,
    required this.audioId,
    required this.phase,
    required this.data,
    required this.transcribedText,
    required this.waitForInput,
  });

  factory VoiceInputResponse.fromJson(Map<String, dynamic> json) =>
      VoiceInputResponse(
        text: json['text'] as String,
        audioId: json['audio_id'] as String,
        phase: json['phase'] as String,
        data: json['data'] as Map<String, dynamic>? ?? {},
        transcribedText: json['transcribed_text'] as String? ?? '',
        waitForInput: json['wait_for_input'] as bool? ?? true,
      );
}
