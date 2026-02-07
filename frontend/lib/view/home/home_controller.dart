import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../model/api_models.dart';
import '../../model/chat_models.dart';
import '../../service/agent_api.dart';

class HomeController extends ChangeNotifier {
  final AgentApi api;
  final String sessionId;

  HomeController({required this.api, required this.sessionId});

  HealthStatus? health;
  List<RagDocument> documents = [];
  bool loadingHealth = false;
  bool loadingDocs = false;
  bool sending = false;
  String? errorMessage;

  // Chat state
  final List<ChatItem> chatItems = []; // internal view model
  String currentAssistantText = '';
  final Map<String, bool> activeTools = {};

  Future<void> loadInitial() async {
    await Future.wait([refreshHealth(), refreshDocuments()]);
  }

  Future<void> refreshHealth() async {
    loadingHealth = true;
    notifyListeners();
    try {
      health = await api.getHealth();
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loadingHealth = false;
      notifyListeners();
    }
  }

  Future<void> refreshDocuments() async {
    loadingDocs = true;
    notifyListeners();
    try {
      documents = await api.listDocuments();
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      loadingDocs = false;
      notifyListeners();
    }
  }

  Future<void> upload(File file) async {
    try {
      await api.uploadDocument(file);
      await Future.wait([refreshDocuments(), refreshHealth()]);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteDoc(String filename) async {
    try {
      await api.deleteDocument(filename);
      await Future.wait([refreshDocuments(), refreshHealth()]);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  void addUserMessage(String text) {
    chatItems.add(ChatItem.user(text));
    notifyListeners();
  }

  Future<void> sendMessage(String message, String pageContext) async {
    if (sending || message.trim().isEmpty) return;

    addUserMessage(message);
    sending = true;
    currentAssistantText = '';
    chatItems.add(ChatItem.assistant('')); // placeholder
    activeTools.clear();
    errorMessage = null;
    notifyListeners();

    final body = ChatRequestBody(
      userName: 'User',
      message: message,
      sessionId: sessionId,
      pageContext: pageContext,
    );

    try {
      await for (final item in api.streamChat(body)) {
        _handleOutputItem(item);
        notifyListeners();
      }
    } catch (e) {
      errorMessage = 'Connection error: $e';
      chatItems.add(ChatItem.error(errorMessage!));
      notifyListeners();
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void _handleOutputItem(OutputItemBase item) {
    if (item is ToolOutput) {
      activeTools[item.name] = true;
      chatItems.add(
        ChatItem.tool(
          name: item.name,
          status: 'executing',
          reason: item.reason,
        ),
      );
    } else if (item is ToolResultOutput) {
      activeTools[item.name] = false;
      chatItems.add(
        ChatItem.tool(
          name: item.name,
          status: item.success ? 'completed' : 'failed',
        ),
      );
    } else if (item is TextChunk) {
      currentAssistantText += item.content;
      _updateLastAssistant(currentAssistantText);
    } else if (item is ThinkingChunk) {
      chatItems.add(ChatItem.thinking(item.content));
    } else if (item is ApiAnswerOutput) {
      // final answer already in text stream
    } else if (item is ErrorOutput) {
      chatItems.add(
        ChatItem.error(
          '${item.message}${item.code != null ? ' (${item.code})' : ''}',
        ),
      );
    }
  }

  void _updateLastAssistant(String text) {
    for (int i = chatItems.length - 1; i >= 0; i--) {
      if (chatItems[i].type == ChatItemType.assistant) {
        chatItems[i] = ChatItem.assistant(text);
        return;
      }
    }
    chatItems.add(ChatItem.assistant(text));
  }
}

/// Simple internal view model for the chat list.
enum ChatItemType { user, assistant, tool, thinking, error }

class ChatItem {
  final ChatItemType type;
  final String text;
  final String? toolName;
  final String? toolStatus;
  final String? toolReason;

  ChatItem._({
    required this.type,
    required this.text,
    this.toolName,
    this.toolStatus,
    this.toolReason,
  });

  factory ChatItem.user(String text) =>
      ChatItem._(type: ChatItemType.user, text: text);

  factory ChatItem.assistant(String text) =>
      ChatItem._(type: ChatItemType.assistant, text: text);

  factory ChatItem.tool({
    required String name,
    required String status,
    String? reason,
  }) =>
      ChatItem._(
        type: ChatItemType.tool,
        text: '',
        toolName: name,
        toolStatus: status,
        toolReason: reason,
      );

  factory ChatItem.thinking(String text) =>
      ChatItem._(type: ChatItemType.thinking, text: text);

  factory ChatItem.error(String text) =>
      ChatItem._(type: ChatItemType.error, text: text);
}
