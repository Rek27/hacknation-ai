/// Mirror of your structured outputs from the backend.

enum OutputItemType {
  tool('tool'),
  toolResult('tool_result'),
  text('text'),
  thinking('thinking'),
  answer('answer'),
  error('error');

  const OutputItemType(this.jsonValue);
  final String jsonValue;

  static OutputItemType fromJson(String value) {
    return OutputItemType.values.firstWhere(
      (OutputItemType e) => e.jsonValue == value,
      orElse: () => OutputItemType.error,
    );
  }
}

abstract class OutputItemBase {
  OutputItemType get type;
}

/// type: "tool"
class ToolOutput implements OutputItemBase {
  @override
  final OutputItemType type;
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
    type: OutputItemType.tool,
    name: json['name'] as String,
    reason: json['reason'] as String?,
    arguments: json['arguments'] as Map<String, dynamic>?,
  );
}

/// type: "tool_result"
class ToolResultOutput implements OutputItemBase {
  @override
  final OutputItemType type;
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
        type: OutputItemType.toolResult,
        name: json['name'] as String,
        result: json['result'] as String,
        success: (json['success'] as bool?) ?? true,
      );
}

/// type: "text"
class TextChunk implements OutputItemBase {
  @override
  final OutputItemType type;
  final String content;

  TextChunk({required this.type, required this.content});

  factory TextChunk.fromJson(Map<String, dynamic> json) => TextChunk(
    type: OutputItemType.text,
    content: json['content'] as String,
  );
}

/// type: "thinking"
class ThinkingChunk implements OutputItemBase {
  @override
  final OutputItemType type;
  final String content;

  ThinkingChunk({required this.type, required this.content});

  factory ThinkingChunk.fromJson(Map<String, dynamic> json) => ThinkingChunk(
    type: OutputItemType.thinking,
    content: json['content'] as String,
  );
}

/// type: "answer"
class ApiAnswerOutput implements OutputItemBase {
  @override
  final OutputItemType type;
  final String content;
  final Map<String, dynamic>? metadata;

  ApiAnswerOutput({required this.type, required this.content, this.metadata});

  factory ApiAnswerOutput.fromJson(Map<String, dynamic> json) =>
      ApiAnswerOutput(
        type: OutputItemType.answer,
        content: json['content'] as String,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

/// type: "error"
class ErrorOutput implements OutputItemBase {
  @override
  final OutputItemType type;
  final String message;
  final String? code;

  ErrorOutput({required this.type, required this.message, this.code});

  factory ErrorOutput.fromJson(Map<String, dynamic> json) => ErrorOutput(
    type: OutputItemType.error,
    message: json['message'] as String,
    code: json['code'] as String?,
  );
}

/// Factory
OutputItemBase parseOutputItem(Map<String, dynamic> json) {
  final rawType = json['type'] as String? ?? '';
  final knownValues = OutputItemType.values.map((OutputItemType e) => e.jsonValue).toSet();
  if (!knownValues.contains(rawType)) {
    return ErrorOutput(
      type: OutputItemType.error,
      message: 'Unknown output type: $rawType',
      code: 'UNKNOWN_TYPE',
    );
  }
  final type = OutputItemType.fromJson(rawType);
  switch (type) {
    case OutputItemType.tool:
      return ToolOutput.fromJson(json);
    case OutputItemType.toolResult:
      return ToolResultOutput.fromJson(json);
    case OutputItemType.text:
      return TextChunk.fromJson(json);
    case OutputItemType.thinking:
      return ThinkingChunk.fromJson(json);
    case OutputItemType.answer:
      return ApiAnswerOutput.fromJson(json);
    case OutputItemType.error:
      return ErrorOutput.fromJson(json);
  }
}
