import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../model/api_models.dart';
import '../model/chat_models.dart';
import 'api_client.dart';

class AgentApi {
  final ApiClient _client;

  AgentApi(this._client);

  Future<HealthStatus> getHealth() async {
    final res = await _client.get('/health');
    if (res.statusCode != 200) {
      throw HttpException('Health failed: ${res.statusCode}');
    }
    return HealthStatus.fromJson(jsonDecode(res.body));
  }

  Future<List<RagDocument>> listDocuments() async {
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
    final streamed = await _client.postMultipart('/upload', file, 'file');
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw HttpException('Upload failed: ${res.statusCode}');
    }
    return UploadResponse.fromJson(jsonDecode(res.body));
  }

  Future<void> deleteDocument(String filename) async {
    final res = await _client.delete('/documents/$filename');
    if (res.statusCode != 200 && res.statusCode != 404) {
      throw HttpException('Delete failed: ${res.statusCode}');
    }
  }

  /// Stream OutputItemBase from POST /chat (SSE-esque text/event-stream).
  Stream<OutputItemBase> streamChat(ChatRequestBody body) async* {
    final response = await _client.postStreamJson('/chat', body.toJson());
    if (response.statusCode != 200) {
      throw HttpException('Chat failed: ${response.statusCode}');
    }

    // Read the byte stream and parse lines starting with "data: "
    final stream = response.stream.transform(utf8.decoder);
    final buffer = StringBuffer();

    await for (final chunk in stream) {
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
          yield parseOutputItem(json);
        } catch (_) {
          // ignore malformed
        }
      }
    }
  }
}
