import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({required String baseUrl, http.Client? client})
    : baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _client = client ?? http.Client();

  Map<String, String> get _defaultHeaders {
    // ngrok free URLs may serve an interstitial warning page unless this header is set.
    if (baseUrl.contains('ngrok-free.app')) {
      return const {'ngrok-skip-browser-warning': 'true'};
    }
    return const {};
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri; // avoid trailing "?"
    return uri.replace(
      queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  void _log(String message) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[ApiClient] $message');
    }
  }

  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _streamStartTimeout = Duration(seconds: 60);

  Future<http.Response> get(String path, {Map<String, dynamic>? query}) async {
    final uri = _uri(path, query);
    _log('GET $uri');
    try {
      final res = await _client
          .get(uri, headers: _defaultHeaders)
          .timeout(_timeout);
      _log('GET $uri -> ${res.statusCode}');
      return res;
    } catch (e) {
      _log('GET $uri !! $e');
      rethrow;
    }
  }

  Future<http.Response> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path);
    _log('POST $uri (json)');
    try {
      final res = await _client
          .post(
            uri,
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              ..._defaultHeaders,
              ...?headers,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      _log('POST $uri -> ${res.statusCode}');
      return res;
    } catch (e) {
      _log('POST $uri !! $e');
      rethrow;
    }
  }

  Future<http.StreamedResponse> postStreamJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final uri = _uri(path);
    _log('POST $uri (stream json)');
    // Use a regular Request (with Content-Length) instead of StreamedRequest
    // to avoid servers/proxies that mishandle chunked request bodies.
    final request = http.Request('POST', uri);
    request.headers[HttpHeaders.contentTypeHeader] = 'application/json';
    request.headers[HttpHeaders.acceptHeader] = 'text/event-stream';
    request.headers.addAll(_defaultHeaders);
    if (headers != null) request.headers.addAll(headers);
    request.body = jsonEncode(body);
    try {
      final res = await _client.send(request).timeout(_streamStartTimeout);
      _log('POST $uri (stream) -> ${res.statusCode}');
      return res;
    } catch (e) {
      _log('POST $uri (stream) !! $e');
      rethrow;
    }
  }

  Future<http.StreamedResponse> postMultipart(
    String path,
    File file,
    String fieldName,
  ) async {
    final uri = _uri(path);
    _log('POST $uri (multipart file=${file.path})');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_defaultHeaders);
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
    try {
      final res = await request.send().timeout(_timeout);
      _log('POST $uri (multipart) -> ${res.statusCode}');
      return res;
    } catch (e) {
      _log('POST $uri (multipart) !! $e');
      rethrow;
    }
  }

  Future<http.Response> delete(String path) async {
    final uri = _uri(path);
    _log('DELETE $uri');
    try {
      final res = await _client
          .delete(uri, headers: _defaultHeaders)
          .timeout(_timeout);
      _log('DELETE $uri -> ${res.statusCode}');
      return res;
    } catch (e) {
      _log('DELETE $uri !! $e');
      rethrow;
    }
  }
}
