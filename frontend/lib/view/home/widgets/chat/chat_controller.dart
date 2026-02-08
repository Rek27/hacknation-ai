import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/widgets.dart';

import 'package:frontend/debug_log.dart';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/service/agent_api.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';

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
  final CartController? _cartController;

  ChatController({
    required ChatService chatService,
    CartController? cartController,
  }) : _chatService = chatService,
       _cartController = cartController;

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

  // -- Sequential tree display ------------------------------------------------

  /// Chunks buffered after a tree, waiting for the user to submit before
  /// showing more content. Implements the sequential tree display flow.
  final List<OutputItemBase> _bufferedChunks = [];

  /// True when we have seen a TreeChunk and should buffer subsequent chunks
  /// until the user submits the tree.
  bool _isBufferingAfterTree = false;

  /// Saved tree selections from trees submitted during the current
  /// buffered flow. Sent to the API once the final tree is submitted.
  final Map<TreeType, List<Map<String, dynamic>>> _pendingTreeSelections = {};

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
      display: 'Organize a hackathon',
      hiddenPrompt:
          'I\'m hosting a hackathon for 60 people — figure out what I need '
          '(snacks, badges, adapters, decorations, prizes) and buy it at the best price.',
    ),
    SamplePrompt(
      display: 'Organize a corporate event',
      hiddenPrompt:
          'I need to organize a corporate networking event for 120 attendees. '
          'The event will run for about 3 hours with a mix of presentations and mingling. '
          'I need professional audio equipment (microphones, speakers) for the main stage and background music in the reception area. '
          'Catering: buffet or passed appetizers plus drinks—coffee, water, and perhaps wine/beer for the networking portion. '
          'I need a photographer for candid shots and a few group photos. '
          'Furniture rental: high-top tables, lounge seating, registration desk. '
          'The venue will likely be a conference center or similar. Help me source everything.',
    ),
    SamplePrompt(
      display: 'Set up an outdoor wedding',
      hiddenPrompt:
          'I\'m setting up an outdoor wedding for 200 guests. '
          'Ceremony and reception will both be outdoors, so I need weather backup (tents or marquee) and proper flooring. '
          'Lighting: string lights, uplighting, and adequate illumination for dinner and dancing. '
          'Entertainment: a live band for the reception (ceremony music as well, if possible). '
          'Catering: plated or buffet dinner, cocktail hour, wedding cake, plus bar service. '
          'I need a photographer and videographer for the full day. '
          'Floral decorations: ceremony arch, centerpieces, bouquets, and boutonnieres. '
          'Please help me plan and coordinate all vendors.',
    ),
    SamplePrompt(
      display: 'Host a small team meetup',
      hiddenPrompt:
          'I want to host a casual team meetup for 15 people in a rented space. '
          'Duration: half-day (4–5 hours). Purpose: mix of informal collaboration and team bonding. '
          'I need light snacks and drinks—coffee, tea, water, plus pastries or finger food. '
          'Tech: a projector or large screen for presentations, reliable WiFi, and possibly a whiteboard. '
          'Furniture: flexible seating (chairs, maybe some sofas) and tables for laptops. '
          'The space should allow for both group discussion and smaller breakout conversations. '
          'Help me get everything organized.',
    ),
  ];

  // ---------------------------------------------------------------------------
  // Public methods
  // ---------------------------------------------------------------------------

  /// Send a sample prompt. The full prompt is shown in the chat and sent to the agent.
  Future<void> sendSamplePrompt(SamplePrompt prompt) async {
    _hasStarted = true;
    await sendMessage(prompt.hiddenPrompt);
  }

  /// Send a free-form user message.
  Future<void> sendMessage(String text, {String? displayText}) async {
    if (_isLoading || text.trim().isEmpty) return;

    _hasStarted = true;
    _lastUserText = text;
    _errorMessage = null;
    _bufferedChunks.clear();
    _pendingTreeSelections.clear();
    _isBufferingAfterTree = false;

    // Add user message
    _messages.add(ChatMessage.user(displayText ?? text));
    _triggerScroll();
    _isLoading = true;
    notifyListeners();

    try {
      // #region agent log
      int chunkIndex = 0;
      final streamStartMs = DateTime.now().millisecondsSinceEpoch;
      // #endregion
      await for (final OutputItemBase chunk
          in _chatService.sendMessage(text)) {
        // #region agent log
        debugLog(
          'chat_controller.dart:sendMessage_loop',
          'chunk received',
          <String, dynamic>{
            'chunkIndex': chunkIndex,
            'type': chunk.type.toString(),
            'contentLen': chunk is TextChunk ? chunk.content.length : 0,
            'msSinceStreamStart':
                DateTime.now().millisecondsSinceEpoch - streamStartMs,
          },
          'H1',
        );
        // #endregion
        _handleStreamedChunk(chunk);
        _triggerScroll();
        notifyListeners();
        // Yield to the event loop so the framework can render intermediate
        // frames. Without this, multiple SSE events arriving in a single HTTP
        // chunk would be processed as microtasks and the UI would only update
        // once after all chunks are consumed.
        await Future<void>.delayed(Duration.zero);
        // #region agent log
        debugLog(
          'chat_controller.dart:after_delay',
          'after notifyListeners and delay',
          <String, dynamic>{'chunkIndex': chunkIndex},
          'H5',
        );
        chunkIndex++;
        // #endregion
      }
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

  /// Clears the conversation and resets to the initial state (e.g. for "End call" on mobile).
  void clearConversation() {
    _messages.clear();
    _hasStarted = false;
    _lastUserText = null;
    _errorMessage = null;
    _pinnedTextForm = null;
    _pinnedTextFormMessageId = null;
    _disabledMessageIds.clear();
    _treeStates.clear();
    notifyListeners();
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
  /// [initialSelected] is used when creating a new state; it should come from
  /// the Category's isSelected (parsed from the API JSON).
  CategoryNodeState getNodeState(
    String messageId,
    String labelPath, {
    bool? initialSelected,
  }) {
    final Map<String, CategoryNodeState> map = getTreeState(messageId);
    return map.putIfAbsent(
      labelPath,
      () => CategoryNodeState(
        isSelected: initialSelected ?? false,
        isExpanded: initialSelected ?? false,
      ),
    );
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

  /// Submit tree selections. If buffered chunks remain (more trees to show),
  /// the selections are saved in memory and the next tree is revealed.
  /// Only when the final buffered tree is submitted are all saved selections
  /// sent to the backend via /submit-tree.
  Future<void> submitTree(String messageId) async {
    if (isMessageDisabled(messageId)) return;

    // Disable the submitted tree message
    _disabledMessageIds.add(messageId);

    // Build and save selections for every tree in this message
    final ChatMessage message = _messages.firstWhere(
      (ChatMessage m) => m.id == messageId,
    );
    for (final OutputItemBase chunk in message.chunks) {
      if (chunk is TreeChunk) {
        final List<Map<String, dynamic>> nodes = _buildTreeNodesWithSelections(
          messageId,
          chunk.category.subcategories,
          <String>[chunk.category.label],
        );
        _pendingTreeSelections[chunk.treeType] = nodes;
      }
    }

    // If there are buffered chunks, release the next group without calling API
    if (_bufferedChunks.isNotEmpty) {
      _releaseBufferedChunks();
      _triggerScroll();
      notifyListeners();
      return;
    }

    // No more buffered chunks — final tree, submit all saved selections
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<OutputItemBase> chunks = await _chatService.submitTree(
        peopleTree: _pendingTreeSelections[TreeType.people] ?? const [],
        placeTree: _pendingTreeSelections[TreeType.place] ?? const [],
      );
      _pendingTreeSelections.clear();
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
    _disabledMessageIds.add(formMessage.id);

    // Clear pinned state
    _pinnedTextForm = null;
    _pinnedTextFormMessageId = null;
    // Form response is a new stream; do not buffer chunks from the previous
    // tree flow (otherwise text and cart would never be displayed).
    _bufferedChunks.clear();
    _isBufferingAfterTree = false;
    _triggerScroll();
    _isLoading = true;
    _cartController?.setLoading(true); // Cart may be generated from response
    notifyListeners();

    try {
      // #region agent log
      int formChunkIndex = 0;
      final formStreamStartMs = DateTime.now().millisecondsSinceEpoch;
      // #endregion
      await for (final OutputItemBase chunk
          in _chatService.submitFormStream(submittedForm)) {
        // #region agent log
        debugLog(
          'chat_controller.dart:submitTextForm_loop',
          'form response chunk received',
          <String, dynamic>{
            'chunkIndex': formChunkIndex,
            'type': chunk.type.toString(),
            'contentLen': chunk is TextChunk ? chunk.content.length : 0,
            'msSinceStreamStart':
                DateTime.now().millisecondsSinceEpoch - formStreamStartMs,
          },
          'H1',
        );
        // #endregion
        _handleStreamedChunk(chunk);
        _triggerScroll();
        notifyListeners();
        await Future<void>.delayed(Duration.zero);
        // #region agent log
        debugLog(
          'chat_controller.dart:submitTextForm_after_delay',
          'after notifyListeners and delay',
          <String, dynamic>{'chunkIndex': formChunkIndex},
          'H5',
        );
        formChunkIndex++;
        // #endregion
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      _messages.add(
        ChatMessage.agent([
          ErrorOutput(type: OutputItemType.error, message: _errorMessage!),
        ]),
      );
    } finally {
      _isLoading = false;
      _cartController?.setLoading(false);
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

  /// Process a single chunk as it arrives from the stream. Text chunks are
  /// displayed immediately; tree and subsequent chunks are buffered per flow.
  void _handleStreamedChunk(OutputItemBase chunk) {
    if (_isBufferingAfterTree) {
      _bufferedChunks.add(chunk);
      return;
    }
    if (chunk is TextFormChunk) {
      _pinnedTextForm = chunk;
      _pinnedTextFormMessageId = null;
      return;
    }
    if (chunk is CartChunk) {
      _cartController?.setCartFromChunk(chunk);
      return;
    }
    if (chunk is RetailerOffersChunk) {
      _cartController?.setRetailerOffers(chunk.offers);
      return;
    }
    if (chunk is ItemsChunk) {
      return;
    }
    if (chunk is TreeChunk) {
      _disablePreviousTreeMessages();
      _appendScrollChunk(chunk);
      _isBufferingAfterTree = true;
      return;
    }
    if (chunk is TextChunk) {
      _appendOrMergeTextChunk(chunk);
      return;
    }
    _appendScrollChunk(chunk);
  }

  void _disablePreviousTreeMessages() {
    for (final ChatMessage msg in _messages) {
      if (msg.sender == ChatMessageSender.agent &&
          msg.chunks.any((OutputItemBase c) => c is TreeChunk)) {
        _disabledMessageIds.add(msg.id);
      }
    }
  }

  /// Appends a TextChunk, merging with the last TextChunk in the current
  /// agent message if present for seamless streaming display.
  /// Replaces the ChatMessage object so the widget tree detects the change.
  void _appendOrMergeTextChunk(TextChunk chunk) {
    // #region agent log
    final bool wasEmpty =
        _messages.isEmpty || _messages.last.sender != ChatMessageSender.agent;
    // #endregion
    if (wasEmpty) {
      _messages.add(ChatMessage.agent([chunk]));
      // #region agent log
      debugLog(
        'chat_controller.dart:_appendOrMergeTextChunk',
        'add new agent message',
        <String, dynamic>{
          'messagesLength': _messages.length,
          'lastChunksLength': 1,
        },
        'H3',
      );
      // #endregion
      return;
    }
    final ChatMessage lastMsg = _messages.last;
    final List<OutputItemBase> oldChunks = lastMsg.chunks;
    if (oldChunks.isNotEmpty && oldChunks.last is TextChunk) {
      final TextChunk lastText = oldChunks.last as TextChunk;
      final List<OutputItemBase> newChunks = List<OutputItemBase>.from(
        oldChunks,
      );
      newChunks[newChunks.length - 1] = TextChunk(
        type: OutputItemType.text,
        content: lastText.content + chunk.content,
      );
      _messages[_messages.length - 1] = ChatMessage(
        id: lastMsg.id,
        sender: lastMsg.sender,
        timestamp: lastMsg.timestamp,
        chunks: newChunks,
      );
      // #region agent log
      final TextChunk newLast =
          newChunks[newChunks.length - 1] as TextChunk;
      debugLog(
        'chat_controller.dart:_appendOrMergeTextChunk',
        'merge text chunk',
        <String, dynamic>{
          'messagesLength': _messages.length,
          'lastChunksLength': newChunks.length,
          'lastTextContentLen': newLast.content.length,
        },
        'H3',
      );
      // #endregion
    } else {
      final List<OutputItemBase> newChunks = List<OutputItemBase>.from(
        oldChunks,
      )..add(chunk);
      _messages[_messages.length - 1] = ChatMessage(
        id: lastMsg.id,
        sender: lastMsg.sender,
        timestamp: lastMsg.timestamp,
        chunks: newChunks,
      );
    }
  }

  /// Appends a non-text scroll chunk to the current agent message or creates
  /// a new one.
  void _appendScrollChunk(OutputItemBase chunk) {
    if (_messages.isEmpty || _messages.last.sender != ChatMessageSender.agent) {
      _messages.add(ChatMessage.agent([chunk]));
      return;
    }
    _messages.last.chunks.add(chunk);
  }

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

    // Split chunks at the first tree boundary.
    // Everything up to and including the first tree is displayed immediately.
    // Everything after is buffered until that tree is submitted.
    final List<OutputItemBase> toDisplay = [];
    final List<OutputItemBase> toBuffer = [];
    bool foundTree = false;
    for (final OutputItemBase chunk in chunks) {
      if (foundTree) {
        toBuffer.add(chunk);
      } else {
        toDisplay.add(chunk);
        if (chunk is TreeChunk) {
          foundTree = true;
        }
      }
    }

    // Process displayable chunks: extract TextFormChunks for pinning
    _addChunksToMessages(toDisplay);
    _bufferedChunks.addAll(toBuffer);
  }

  /// Release buffered chunks up to (and including) the next tree.
  /// If no tree is found in the buffer, all remaining chunks are released.
  void _releaseBufferedChunks() {
    if (_bufferedChunks.isEmpty) return;
    final List<OutputItemBase> toDisplay = [];
    final List<OutputItemBase> remaining = [];
    bool foundTree = false;
    for (final OutputItemBase chunk in _bufferedChunks) {
      if (foundTree) {
        remaining.add(chunk);
      } else {
        toDisplay.add(chunk);
        if (chunk is TreeChunk) {
          foundTree = true;
        }
      }
    }
    _bufferedChunks.clear();
    _bufferedChunks.addAll(remaining);
    _addChunksToMessages(toDisplay);
  }

  /// Adds chunks to the message list, extracting TextFormChunks for pinning
  /// and forwarding CartChunk / RetailerOffersChunk to the CartController.
  void _addChunksToMessages(List<OutputItemBase> chunks) {
    final List<OutputItemBase> scrollChunks = [];
    for (final OutputItemBase chunk in chunks) {
      if (chunk is TextFormChunk) {
        _pinnedTextForm = chunk;
        _pinnedTextFormMessageId = null;
      } else if (chunk is CartChunk) {
        // Forward cart data to the CartController.
        _cartController?.setCartFromChunk(chunk);
        // Don't add cart to chat messages — it's rendered in the cart panel.
      } else if (chunk is RetailerOffersChunk) {
        // Forward retailer offers to the CartController.
        _cartController?.setRetailerOffers(chunk.offers);
        // Don't add to chat messages — handled by the cart panel.
      } else if (chunk is ItemsChunk) {
        // Items list is intermediate; skip in chat messages.
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
