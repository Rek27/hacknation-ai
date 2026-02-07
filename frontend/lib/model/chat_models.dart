/// Mirror of your structured outputs from the backend.

abstract class OutputItemBase {
  String get type;
}

/// type: "tool"
class ToolOutput implements OutputItemBase {
  @override
  final String type;
  final String name;
  final String? reason;
  final Map<String, dynamic>? arguments;

  ToolOutput({
    required this.type,
    required this.name,
    this.reason,
    this.arguments,
  });

  factory ToolOutput.fromJson(Map<String, dynamic> json) => ToolOutput(
    type: json['type'] as String,
    name: json['name'] as String,
    reason: json['reason'] as String?,
    arguments: json['arguments'] as Map<String, dynamic>?,
  );
}

/// type: "tool_result"
class ToolResultOutput implements OutputItemBase {
  @override
  final String type;
  final String name;
  final String result;
  final bool success;

  ToolResultOutput({
    required this.type,
    required this.name,
    required this.result,
    required this.success,
  });

  factory ToolResultOutput.fromJson(Map<String, dynamic> json) =>
      ToolResultOutput(
        type: json['type'] as String,
        name: json['name'] as String,
        result: json['result'] as String,
        success: (json['success'] as bool?) ?? true,
      );
}

/// type: "text"
class TextChunk implements OutputItemBase {
  @override
  final String type;
  final String content;

  TextChunk({required this.type, required this.content});

  factory TextChunk.fromJson(Map<String, dynamic> json) => TextChunk(
    type: json['type'] as String,
    content: json['content'] as String,
  );
}

/// type: "thinking"
class ThinkingChunk implements OutputItemBase {
  @override
  final String type;
  final String content;

  ThinkingChunk({required this.type, required this.content});

  factory ThinkingChunk.fromJson(Map<String, dynamic> json) => ThinkingChunk(
    type: json['type'] as String,
    content: json['content'] as String,
  );
}

/// type: "answer"
class ApiAnswerOutput implements OutputItemBase {
  @override
  final String type;
  final String content;
  final Map<String, dynamic>? metadata;

  ApiAnswerOutput({required this.type, required this.content, this.metadata});

  factory ApiAnswerOutput.fromJson(Map<String, dynamic> json) =>
      ApiAnswerOutput(
        type: json['type'] as String,
        content: json['content'] as String,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

/// type: "error"
class ErrorOutput implements OutputItemBase {
  @override
  final String type;
  final String message;
  final String? code;

  ErrorOutput({required this.type, required this.message, this.code});

  factory ErrorOutput.fromJson(Map<String, dynamic> json) => ErrorOutput(
    type: json['type'] as String,
    message: json['message'] as String,
    code: json['code'] as String?,
  );
}

/// Factory
OutputItemBase parseOutputItem(Map<String, dynamic> json) {
  final type = json['type'] as String? ?? '';
  switch (type) {
    case 'tool':
      return ToolOutput.fromJson(json);
    case 'tool_result':
      return ToolResultOutput.fromJson(json);
    case 'text':
      return TextChunk.fromJson(json);
    case 'thinking':
      return ThinkingChunk.fromJson(json);
    case 'answer':
      return ApiAnswerOutput.fromJson(json);
    case 'error':
      return ErrorOutput.fromJson(json);
    default:
      return ErrorOutput(
        type: 'error',
        message: 'Unknown output type: $type',
        code: 'UNKNOWN_TYPE',
      );
  }
}
