import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) =>
      Uri.parse('$baseUrl$path').replace(
        queryParameters:
            query?.map((k, v) => MapEntry(k, v.toString())) ?? const {},
      );

  Future<http.Response> get(String path, {Map<String, dynamic>? query}) async =>
      _client.get(_uri(path, query));

  Future<http.Response> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async => _client.post(
    _uri(path),
    headers: {HttpHeaders.contentTypeHeader: 'application/json', ...?headers},
    body: jsonEncode(body),
  );

  Future<http.StreamedResponse> postStreamJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final request = http.StreamedRequest('POST', _uri(path));
    request.headers[HttpHeaders.contentTypeHeader] = 'application/json';
    if (headers != null) {
      request.headers.addAll(headers);
    }
    request.sink.add(utf8.encode(jsonEncode(body)));
    await request.sink.close();
    return _client.send(request);
  }

  Future<http.StreamedResponse> postMultipart(
    String path,
    File file,
    String fieldName,
  ) async {
    final uri = _uri(path);
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));
    return request.send();
  }

  Future<http.Response> delete(String path) async => _client.delete(_uri(path));
}
