import 'dart:convert';

/// Health endpoint response: GET /health
class HealthStatus {
  final String status;
  final String ragPipeline;
  final int toolsAvailable;
  final int documentsCount;

  HealthStatus({
    required this.status,
    required this.ragPipeline,
    required this.toolsAvailable,
    required this.documentsCount,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) => HealthStatus(
    status: json['status'] as String,
    ragPipeline: json['rag_pipeline'] as String,
    toolsAvailable: json['tools_available'] as int,
    documentsCount: json['documents_count'] as int,
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
  final String pageContext;

  ChatRequestBody({
    required this.userName,
    required this.message,
    required this.sessionId,
    required this.pageContext,
  });

  Map<String, dynamic> toJson() => {
    'user_name': userName,
    'message': message,
    'session_id': sessionId,
    'page_context': pageContext,
  };

  String toJsonString() => jsonEncode(toJson());
}
