import 'package:flutter/material.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/view/home/widgets/chat/chunk_renderer.dart';

/// A single chat message bubble with alignment, optional avatar, and timestamp.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.showAvatar,
    required this.isDisabled,
  });

  final ChatMessage message;
  final bool showAvatar;
  final bool isDisabled;

  bool get _isUser => message.sender == ChatMessageSender.user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingXs,
        horizontal: AppConstants.spacingMd,
      ),
      child: Row(
        mainAxisAlignment: _isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) _buildAvatarSlot(colorScheme),
          if (!_isUser) const SizedBox(width: AppConstants.spacingSm),
          Flexible(child: _buildContent(theme, colorScheme)),
          if (_isUser) const SizedBox(width: AppConstants.spacingSm),
          if (_isUser) _buildAvatarSlot(colorScheme),
        ],
      ),
    );
  }

  /// Fixed-width slot so bubbles stay aligned even without avatar.
  Widget _buildAvatarSlot(ColorScheme colorScheme) {
    if (!showAvatar) {
      return const SizedBox(width: AppConstants.chatAvatarSize);
    }
    return Container(
      width: AppConstants.chatAvatarSize,
      height: AppConstants.chatAvatarSize,
      decoration: BoxDecoration(
        color: _isUser ? colorScheme.primary : colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          _isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
          size: AppConstants.iconSizeXs,
          color: _isUser
              ? colorScheme.onPrimary
              : colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: _isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppConstants.chatBubbleMaxWidth,
          ),
          child: _buildBubbleBody(theme, colorScheme),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingXs,
          ),
          child: Text(
            _formatTimestamp(message.timestamp),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleBody(ThemeData theme, ColorScheme colorScheme) {
    // For user text-only messages, use a colored bubble
    final bool isSimpleTextUser =
        _isUser &&
        message.chunks.length == 1 &&
        message.chunks.first.type.jsonValue == 'text';
    if (isSimpleTextUser) {
      return _UserTextBubble(message: message);
    }
    // Agent messages / complex user messages render chunks
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: message.chunks
          .map(
            (chunk) => ChunkRenderer(
              chunk: chunk,
              messageId: message.id,
              isDisabled: isDisabled,
            ),
          )
          .toList(),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Colored bubble specifically for user text messages.
class _UserTextBubble extends StatelessWidget {
  const _UserTextBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String text = (message.chunks.first as dynamic).content as String;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}
