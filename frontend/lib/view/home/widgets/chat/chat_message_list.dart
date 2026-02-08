import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/debug_log.dart';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/view/home/widgets/chat/chat_bubble.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/view/home/widgets/chat/thinking_bubble.dart';

/// Scrollable message list with auto-scroll and consecutive sender grouping.
/// [bottomReservedHeight] reserves space at the bottom when the pinned form
/// overlays the list, so the viewport never shrinks and scroll position stays correct.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({super.key, this.bottomReservedHeight = 0.0});

  final double bottomReservedHeight;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _isUserScrolledUp = false;
  int _lastScrollTrigger = -1;
  // #region agent log
  static int _buildCount = 0;
  // #endregion

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double currentScroll = _scrollController.offset;
    // Consider "at bottom" if within 80px of max scroll
    final bool scrolledUp = (maxScroll - currentScroll) > 80.0;
    if (scrolledUp != _isUserScrolledUp) {
      setState(() {
        _isUserScrolledUp = scrolledUp;
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: AppConstants.durationSlow,
      curve: Curves.easeOut,
    );
  }

  void _jumpToBottom({double scrollUpOffset = 0}) {
    if (!_scrollController.hasClients) return;
    final double max = _scrollController.position.maxScrollExtent;
    final double target = (max - scrollUpOffset).clamp(0.0, max);
    _scrollController.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.watch<ChatController>();
    final List<ChatMessage> messages = controller.messages;
    final bool hasPinnedForm = controller.pinnedTextForm != null;
    // #region agent log
    _buildCount++;
    debugLog(
      'chat_message_list.dart:build',
      'ChatMessageList build',
      <String, dynamic>{
        'buildCount': _buildCount,
        'messageCount': messages.length,
        'showThinking': controller.isLoading &&
            !(messages.isNotEmpty &&
                messages.last.sender == ChatMessageSender.agent),
      },
      'H2',
    );
    // #endregion

    // Auto-scroll when the trigger changes. When the pinned form is shown we
    // jump to bottom so the new padding doesn't leave a gap.
    if (controller.scrollTrigger != _lastScrollTrigger) {
      _lastScrollTrigger = controller.scrollTrigger;
      final bool scrollBecauseOfForm = hasPinnedForm;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollBecauseOfForm) {
          _jumpToBottom();
          setState(() => _isUserScrolledUp = false);
        } else if (!_isUserScrolledUp) {
          _scrollToBottom();
        }
      });
    }

    final bool isLoading = controller.isLoading;
    // Hide the thinking bubble once agent content starts streaming in,
    // so the user sees the growing text instead of a loading indicator.
    final bool hasAgentResponse = messages.isNotEmpty &&
        messages.last.sender == ChatMessageSender.agent;
    final bool showThinking = isLoading && !hasAgentResponse;
    final int totalItems = messages.length + (showThinking ? 1 : 0);
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: AppConstants.spacingSm,
            bottom: AppConstants.spacingSm + widget.bottomReservedHeight,
          ),
          itemCount: totalItems,
          itemBuilder: (BuildContext context, int index) {
            // Last item is the thinking bubble when loading
            if (showThinking && index == messages.length) {
              return const ThinkingBubble();
            }
            final ChatMessage message = messages[index];
            final bool showAvatar = _shouldShowAvatar(messages, index);
            final bool isDisabled = controller.isMessageDisabled(message.id);
            return ChatBubble(
              message: message,
              showAvatar: showAvatar,
              isDisabled: isDisabled,
            );
          },
        ),
        // Scroll-to-bottom FAB when user has scrolled up
        if (_isUserScrolledUp && messages.isNotEmpty)
          Positioned(
            bottom: AppConstants.spacingSm,
            right: AppConstants.spacingMd,
            child: _ScrollToBottomButton(
              onPressed: () {
                setState(() {
                  _isUserScrolledUp = false;
                });
                _scrollToBottom();
              },
            ),
          ),
      ],
    );
  }

  /// Show avatar only on the first message of a consecutive same-sender group.
  bool _shouldShowAvatar(List<ChatMessage> messages, int index) {
    if (index == 0) return true;
    return messages[index].sender != messages[index - 1].sender;
  }
}

class _ScrollToBottomButton extends StatefulWidget {
  const _ScrollToBottomButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<_ScrollToBottomButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AppConstants.durationMedium,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isHovered
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: AppConstants.elevationMd,
              offset: const Offset(0, AppConstants.elevationSm),
            ),
          ],
        ),
        child: IconButton(
          onPressed: widget.onPressed,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colorScheme.onSurface,
          ),
          tooltip: 'Scroll to bottom',
        ),
      ),
    );
  }
}
