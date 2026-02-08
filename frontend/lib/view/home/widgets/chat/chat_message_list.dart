import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/view/home/widgets/chat/chat_bubble.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';

/// Scrollable message list with auto-scroll and consecutive sender grouping.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({super.key});

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _isUserScrolledUp = false;
  int _lastScrollTrigger = -1;

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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.watch<ChatController>();
    final List<ChatMessage> messages = controller.messages;

    // Auto-scroll when the trigger changes and user hasn't scrolled up
    if (controller.scrollTrigger != _lastScrollTrigger) {
      _lastScrollTrigger = controller.scrollTrigger;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isUserScrolledUp) {
          _scrollToBottom();
        }
      });
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
          itemCount: messages.length,
          itemBuilder: (BuildContext context, int index) {
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
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isHovered
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
