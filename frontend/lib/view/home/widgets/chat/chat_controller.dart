import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart';

import 'package:frontend/model/api_models.dart';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/service/agent_api.dart';

/// Sample prompt shown before the conversation begins.
class SamplePrompt {
  final String display;
  final String hiddenPrompt;

  const SamplePrompt({required this.display, required this.hiddenPrompt});
}

/// Mutable selection / expansion state for a single category node
/// inside a TreeChunk, keyed by its label path (e.g. "People/Catering/Food").
class CategoryNodeState {
  bool isSelected;
  bool isExpanded;

  CategoryNodeState({this.isSelected = false, this.isExpanded = false});
}

/// Controller for the chat feature.
/// Manages messages, tree interactions, form pinning, and agent communication.
class ChatController extends ChangeNotifier {
  final ChatService _chatService;

  ChatController({required ChatService chatService})
    : _chatService = chatService;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _hasStarted = false;
  bool get hasStarted => _hasStarted;

  /// Counter incremented whenever the view should auto-scroll.
  int _scrollTrigger = 0;
  int get scrollTrigger => _scrollTrigger;

  /// IDs of messages whose interactive chunks (Tree / Form) are disabled.
  final Set<String> _disabledMessageIds = {};
  bool isMessageDisabled(String messageId) =>
      _disabledMessageIds.contains(messageId);

  /// Mutable tree state per message.  messageId -> (labelPath -> state)
  final Map<String, Map<String, CategoryNodeState>> _treeStates = {};

  /// The last user message text, kept for retry.
  String? _lastUserText;

  // -- TextFormChunk pinning --------------------------------------------------

  TextFormChunk? _pinnedTextForm;
  TextFormChunk? get pinnedTextForm => _pinnedTextForm;

  String? _pinnedTextFormMessageId;
  String? get pinnedTextFormMessageId => _pinnedTextFormMessageId;

  // ---------------------------------------------------------------------------
  // Sample prompts
  // ---------------------------------------------------------------------------

  static const List<SamplePrompt> samplePrompts = [
    SamplePrompt(
      display: 'Plan a birthday party',
      hiddenPrompt:
          'I want to plan a birthday party for about 50 people. '
          'I need catering, music, and decorations. '
          'Help me find everything I need.',
    ),
    SamplePrompt(
      display: 'Organize a corporate event',
      hiddenPrompt:
          'I need to organize a corporate networking event for 120 attendees. '
          'I need audio equipment, catering, a photographer, and furniture rental. '
          'Help me source everything.',
    ),
    SamplePrompt(
      display: 'Set up an outdoor wedding',
      hiddenPrompt:
          'I\'m setting up an outdoor wedding for 200 guests. '
          'I need tents, lighting, a live band, catering, photography, '
          'and floral decorations. Help me plan it all.',
    ),
    SamplePrompt(
      display: 'Host a small team meetup',
      hiddenPrompt:
          'I want to host a casual team meetup for 15 people in a rented space. '
          'I need snacks, drinks, a projector, and some basic furniture. '
          'Help me get everything organized.',
    ),
  ];

  // ---------------------------------------------------------------------------
  // Public methods
  // ---------------------------------------------------------------------------

  /// Send a sample prompt. The display text becomes the visible user message.
  Future<void> sendSamplePrompt(SamplePrompt prompt) async {
    _hasStarted = true;
    await sendMessage(prompt.hiddenPrompt, displayText: prompt.display);
  }

  /// Send a free-form user message.
  Future<void> sendMessage(String text, {String? displayText}) async {
    if (_isLoading || text.trim().isEmpty) return;

    _hasStarted = true;
    _lastUserText = text;
    _errorMessage = null;

    // Add user message
    _messages.add(ChatMessage.user(displayText ?? text));
    _triggerScroll();
    _isLoading = true;
    notifyListeners();

    try {
      final List<OutputItemBase> chunks = await _chatService.sendMessage(text);
      _handleAgentResponse(chunks);
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      _messages.add(
        ChatMessage.agent([
          ErrorOutput(type: OutputItemType.error, message: _errorMessage!),
        ]),
      );
    } finally {
      _isLoading = false;
      _triggerScroll();
      notifyListeners();
    }
  }

  /// Retry the last failed message.
  Future<void> retryLastMessage() async {
    if (_lastUserText == null) return;
    // Remove the error message that was appended
    if (_messages.isNotEmpty &&
        _messages.last.sender == ChatMessageSender.agent &&
        _messages.last.chunks.length == 1 &&
        _messages.last.chunks.first is ErrorOutput) {
      _messages.removeLast();
    }
    // Also remove the user message that triggered the error
    if (_messages.isNotEmpty &&
        _messages.last.sender == ChatMessageSender.user) {
      _messages.removeLast();
    }
    notifyListeners();
    await sendMessage(_lastUserText!);
  }

  // ---------------------------------------------------------------------------
  // Tree interactions
  // ---------------------------------------------------------------------------

  /// Get or create the mutable state map for a given message's tree.
  Map<String, CategoryNodeState> getTreeState(String messageId) {
    return _treeStates.putIfAbsent(messageId, () => {});
  }

  /// Build a label path like "People/Catering/Food".
  String buildLabelPath(List<String> ancestors, String label) {
    return [...ancestors, label].join('/');
  }

  /// Get the state for a single node, creating default if absent.
  CategoryNodeState getNodeState(String messageId, String labelPath) {
    final Map<String, CategoryNodeState> map = getTreeState(messageId);
    return map.putIfAbsent(labelPath, () => CategoryNodeState());
  }

  /// Toggle selection of a category node.
  void toggleCategorySelection(String messageId, String labelPath) {
    if (isMessageDisabled(messageId)) return;
    final CategoryNodeState state = getNodeState(messageId, labelPath);
    state.isSelected = !state.isSelected;
    if (state.isSelected) {
      state.isExpanded = true;
    } else {
      // Collapse and clear all descendants
      state.isExpanded = false;
      _clearDescendants(messageId, labelPath);
    }
    notifyListeners();
  }

  /// Toggle expansion of a category node independently.
  void toggleCategoryExpansion(String messageId, String labelPath) {
    if (isMessageDisabled(messageId)) return;
    final CategoryNodeState state = getNodeState(messageId, labelPath);
    state.isExpanded = !state.isExpanded;
    notifyListeners();
  }

  /// Submit all tree selections to the backend via /submit-tree.
  /// Collects every TreeChunk across all messages, applies the user's
  /// selection state, and sends the reconstructed trees to the API.
  Future<void> submitTree(String messageId) async {
    if (isMessageDisabled(messageId)) return;

    // Collect all tree chunks grouped by type, applying selections
    List<Map<String, dynamic>> peopleTree = const [];
    List<Map<String, dynamic>> placeTree = const [];

    for (final ChatMessage msg in _messages) {
      for (final OutputItemBase chunk in msg.chunks) {
        if (chunk is TreeChunk) {
          _disabledMessageIds.add(msg.id);
          final List<Map<String, dynamic>> nodes =
              _buildTreeNodesWithSelections(
                msg.id,
                chunk.category.subcategories,
                <String>[chunk.category.label],
              );
          if (chunk.treeType == TreeType.people) {
            peopleTree = nodes;
          } else if (chunk.treeType == TreeType.place) {
            placeTree = nodes;
          }
        }
      }
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<OutputItemBase> chunks = await _chatService.submitTree(
        peopleTree: peopleTree,
        placeTree: placeTree,
      );
      _handleAgentResponse(chunks);
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      _messages.add(
        ChatMessage.agent([
          ErrorOutput(
            type: OutputItemType.error,
            message: _errorMessage!,
          ),
        ]),
      );
    } finally {
      _isLoading = false;
      _triggerScroll();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // TextFormChunk interactions
  // ---------------------------------------------------------------------------

  /// Submit the pinned text form with edited field values via /submit-form.
  Future<void> submitTextForm(Map<String, String> values) async {
    if (_pinnedTextForm == null) return;

    final TextFormChunk submittedForm = TextFormChunk(
      address: TextFieldChunk(
        label: _pinnedTextForm!.address.label,
        content: values['address'],
      ),
      budget: TextFieldChunk(
        label: _pinnedTextForm!.budget.label,
        content: values['budget'],
      ),
      date: TextFieldChunk(
        label: _pinnedTextForm!.date.label,
        content: values['date'],
      ),
      durationOfEvent: TextFieldChunk(
        label: _pinnedTextForm!.durationOfEvent.label,
        content: values['duration'],
      ),
      numberOfAttendees: TextFieldChunk(
        label: _pinnedTextForm!.numberOfAttendees.label,
        content: values['numberOfAttendees'],
      ),
    );

    // Move the form into chat history as a user message
    final ChatMessage formMessage = ChatMessage(
      id: 'form-${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatMessageSender.user,
      timestamp: DateTime.now(),
      chunks: [submittedForm],
    );
    _messages.add(formMessage);

    // Clear pinned state
    _pinnedTextForm = null;
    _pinnedTextFormMessageId = null;
    _triggerScroll();
    _isLoading = true;
    notifyListeners();

    try {
      final SubmitFormResponse response =
          await _chatService.submitForm(submittedForm);
      _messages.add(
        ChatMessage.agent([
          TextChunk(
            type: OutputItemType.text,
            content: response.message,
          ),
        ]),
      );
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      _messages.add(
        ChatMessage.agent([
          ErrorOutput(
            type: OutputItemType.error,
            message: _errorMessage!,
          ),
        ]),
      );
    } finally {
      _isLoading = false;
      _triggerScroll();
      notifyListeners();
    }
  }

  /// Re-pin a submitted form for editing. Disables the old one.
  void editSubmittedForm(String messageId) {
    _disabledMessageIds.add(messageId);

    // Find the message and extract the TextFormChunk
    final ChatMessage message = _messages.firstWhere(
      (ChatMessage m) => m.id == messageId,
    );
    final TextFormChunk original = message.chunks
        .whereType<TextFormChunk>()
        .first;

    _pinnedTextForm = original;
    _pinnedTextFormMessageId = messageId;
    _triggerScroll();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _handleAgentResponse(List<OutputItemBase> chunks) {
    // Disable previous TreeChunks when a new one arrives
    final bool hasNewTree = chunks.any((OutputItemBase c) => c is TreeChunk);
    if (hasNewTree) {
      for (final ChatMessage msg in _messages) {
        if (msg.sender == ChatMessageSender.agent &&
            msg.chunks.any((OutputItemBase c) => c is TreeChunk)) {
          _disabledMessageIds.add(msg.id);
        }
      }
    }

    // Extract TextFormChunk to pin instead of putting in scroll list
    final List<OutputItemBase> scrollChunks = [];
    for (final OutputItemBase chunk in chunks) {
      if (chunk is TextFormChunk) {
        _pinnedTextForm = chunk;
        _pinnedTextFormMessageId = null; // new, not yet submitted
      } else {
        scrollChunks.add(chunk);
      }
    }

    if (scrollChunks.isNotEmpty) {
      _messages.add(ChatMessage.agent(scrollChunks));
    }
  }

  /// Recursively converts a list of [Category] nodes into backend-compatible
  /// TreeNode maps, applying the user's selection state from [_treeStates].
  List<Map<String, dynamic>> _buildTreeNodesWithSelections(
    String messageId,
    List<Category> categories,
    List<String> ancestors,
  ) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final Category cat in categories) {
      final String path = buildLabelPath(ancestors, cat.label);
      final CategoryNodeState nodeState = getNodeState(messageId, path);
      result.add(<String, dynamic>{
        'emoji': cat.emoji,
        'label': cat.label,
        'selected': nodeState.isSelected,
        'children': _buildTreeNodesWithSelections(
          messageId,
          cat.subcategories,
          <String>[...ancestors, cat.label],
        ),
      });
    }
    return result;
  }

  void _clearDescendants(String messageId, String parentPath) {
    final Map<String, CategoryNodeState> map = getTreeState(messageId);
    final List<String> toRemove = map.keys
        .where(
          (String path) =>
              path.startsWith('$parentPath/') && path != parentPath,
        )
        .toList();
    for (final String path in toRemove) {
      map[path]?.isSelected = false;
      map[path]?.isExpanded = false;
    }
  }

  void _triggerScroll() {
    _scrollTrigger++;
  }
}
