import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';

/// Renders a text chunk with a word-by-word typing animation that gives the
/// impression the content is being generated in real time.
class TextChunkWidget extends StatefulWidget {
  const TextChunkWidget({
    super.key,
    required this.chunk,
    this.onTypingComplete,
  });

  final TextChunk chunk;
  final VoidCallback? onTypingComplete;

  @override
  State<TextChunkWidget> createState() => _TextChunkWidgetState();
}

class _TextChunkWidgetState extends State<TextChunkWidget> {
  /// Number of words currently visible.
  int _visibleWordCount = 0;
  late List<String> _words;
  bool _isComplete = false;

  /// Incremented when new content arrives; old typing loops abort.
  int _typingGeneration = 0;

  @override
  void initState() {
    super.initState();
    _words = widget.chunk.content.split(RegExp(r'(\s+)'));
    _startTyping();
  }

  @override
  void didUpdateWidget(TextChunkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chunk.content != oldWidget.chunk.content) {
      final List<String> newWords =
          widget.chunk.content.split(RegExp(r'(\s+)'));
      if (newWords.length > _words.length) {
        _words = newWords;
        _typingGeneration++;
        _startTyping();
      }
    }
  }

  Future<void> _startTyping() async {
    final int myGen = _typingGeneration;
    for (int i = _visibleWordCount + 1; i <= _words.length; i++) {
      await Future<void>.delayed(AppConstants.textWordDelay);
      if (!mounted || myGen != _typingGeneration) return;
      setState(() {
        _visibleWordCount = i;
      });
    }
    if (mounted &&
        myGen == _typingGeneration &&
        _visibleWordCount >= _words.length &&
        !_isComplete) {
      setState(() {
        _isComplete = true;
      });
      widget.onTypingComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    // Show only the first _visibleWordCount words, or all if complete.
    final String displayText = _isComplete
        ? widget.chunk.content
        : _words.take(_visibleWordCount).join();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: AppConstants.elevationMd,
            offset: const Offset(0, AppConstants.elevationSm),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: AppConstants.durationMedium,
        alignment: Alignment.topLeft,
        curve: Curves.easeOut,
        child: Text(
          displayText,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
