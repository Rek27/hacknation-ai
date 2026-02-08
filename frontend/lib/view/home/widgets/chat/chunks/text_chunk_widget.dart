import 'package:flutter/material.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';

/// Renders a simple text chunk inside an agent bubble.
class TextChunkWidget extends StatelessWidget {
  const TextChunkWidget({super.key, required this.chunk});

  final TextChunk chunk;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        chunk.content,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
