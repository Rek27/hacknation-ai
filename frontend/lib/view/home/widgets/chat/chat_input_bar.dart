import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';

/// Text input bar at the bottom of the chat.
/// Handles Enter-to-send (Shift+Enter for newline) and disabled state.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    context.read<ChatController>().sendMessage(text);
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _handleSend();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.watch<ChatController>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isLoading = controller.isLoading;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      color: colorScheme.surface,
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          minLines: 3,
          maxLines: 8,
          enabled: !isLoading,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Type a message...  (Enter to send)',
            filled: true,
            fillColor: colorScheme.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
              vertical: AppConstants.spacingMd,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
