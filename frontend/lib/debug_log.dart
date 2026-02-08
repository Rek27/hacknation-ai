import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

// #region agent log
String? _logPath;

/// Call from main() after getTemporaryDirectory() so the app can write logs.
void setDebugLogPath(String path) {
  _logPath = path;
  if (kDebugMode) {
    // ignore: avoid_print
    print('[DebugLog] writing to $path');
  }
}

String? get debugLogPath => _logPath;

void _writeLine(String line) {
  if (_logPath == null) return;
  try {
    final file = File(_logPath!);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    file.writeAsStringSync('$line\n', mode: FileMode.append);
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DebugLog] write failed: $e');
    }
  }
}

void debugLog(
  String location,
  String message,
  Map<String, dynamic> data,
  String hypothesisId,
) {
  final payload = <String, dynamic>{
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'data': data,
    'hypothesisId': hypothesisId,
  };
  _writeLine(jsonEncode(payload));
}

/// Log backend JSON response (same file as chat instrumentation).
void logBackendJson(String tag, Map<String, dynamic> json) {
  final payload = <String, dynamic>{
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': 'agent_api.dart:_streamSse',
    'message': 'backend_response',
    'data': <String, dynamic>{'tag': tag, 'json': json},
    'hypothesisId': 'backend',
  };
  _writeLine(jsonEncode(payload));
}
// #endregion
