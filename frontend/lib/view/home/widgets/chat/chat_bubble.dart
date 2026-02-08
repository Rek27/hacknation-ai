import 'package:flutter/material.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_message.dart';
import 'package:frontend/model/chat_models.dart';
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
    final EdgeInsets bubblePadding = _isUser
        ? const EdgeInsets.only(left: AppConstants.chatBubbleHorizontalPadding)
        : const EdgeInsets.only(
            right: AppConstants.chatBubbleHorizontalPadding,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingSm,
        horizontal: AppConstants.spacingMd,
      ),
      child: Row(
        mainAxisAlignment: _isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isUser) _buildAvatarSlot(colorScheme),
          if (!_isUser) const SizedBox(width: AppConstants.spacingSm),
          Flexible(
            child: Padding(
              padding: bubblePadding,
              child: _buildContent(theme, colorScheme),
            ),
          ),
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
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
    // Agent messages / complex user messages render chunks with stagger
    return _StaggeredChunkList(
      chunks: message.chunks,
      messageId: message.id,
      isDisabled: isDisabled,
    );
  }

  String _formatTimestamp(DateTime dt) {
    final String hour = dt.hour.toString().padLeft(2, '0');
    final String minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Reveals agent message chunks one at a time with entry animations.
/// Text chunks trigger the next reveal when their typing animation completes;
/// non-text chunks trigger after [AppConstants.chunkStaggerDelay].
class _StaggeredChunkList extends StatefulWidget {
  const _StaggeredChunkList({
    required this.chunks,
    required this.messageId,
    required this.isDisabled,
  });

  final List<OutputItemBase> chunks;
  final String messageId;
  final bool isDisabled;

  @override
  State<_StaggeredChunkList> createState() => _StaggeredChunkListState();
}

class _StaggeredChunkListState extends State<_StaggeredChunkList> {
  int _revealedCount = 1;

  @override
  void initState() {
    super.initState();
    _scheduleNextIfNonText();
  }

  /// For non-text chunks, schedule the next reveal after a fixed delay.
  void _scheduleNextIfNonText() {
    if (_revealedCount >= widget.chunks.length) return;
    final OutputItemBase lastRevealed = widget.chunks[_revealedCount - 1];
    if (lastRevealed is! TextChunk) {
      Future<void>.delayed(AppConstants.chunkStaggerDelay).then((_) {
        if (mounted) _revealNext();
      });
    }
  }

  void _revealNext() {
    if (_revealedCount >= widget.chunks.length) return;
    setState(() {
      _revealedCount++;
    });
    _scheduleNextIfNonText();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < _revealedCount; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppConstants.spacingSm),
          _AnimatedChunkEntry(
            key: ValueKey<String>('${widget.messageId}-chunk-$i'),
            child: ChunkRenderer(
              chunk: widget.chunks[i],
              messageId: widget.messageId,
              isDisabled: widget.isDisabled,
              onChunkReady:
                  (i == _revealedCount - 1 && widget.chunks[i] is TextChunk)
                  ? _revealNext
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

/// Plays a fade-in + slide-up animation when first mounted.
class _AnimatedChunkEntry extends StatefulWidget {
  const _AnimatedChunkEntry({super.key, required this.child});

  final Widget child;

  @override
  State<_AnimatedChunkEntry> createState() => _AnimatedChunkEntryState();
}

class _AnimatedChunkEntryState extends State<_AnimatedChunkEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.durationSlow,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
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
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: AppConstants.elevationMd,
            offset: const Offset(0, AppConstants.elevationSm),
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
