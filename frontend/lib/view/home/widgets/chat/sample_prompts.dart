import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';

/// Centered grid of sample prompt cards shown before the conversation starts.
class SamplePrompts extends StatelessWidget {
  const SamplePrompts({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: AppConstants.iconSizeMd,
              color: colorScheme.primary,
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'How can I help you plan your event?',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Choose a prompt below or type your own message.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingXl),
            Wrap(
              spacing: AppConstants.spacingMd,
              runSpacing: AppConstants.spacingMd,
              alignment: WrapAlignment.center,
              children: ChatController.samplePrompts
                  .map(
                    (SamplePrompt prompt) => _SamplePromptCard(prompt: prompt),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SamplePromptCard extends StatefulWidget {
  const _SamplePromptCard({required this.prompt});

  final SamplePrompt prompt;

  @override
  State<_SamplePromptCard> createState() => _SamplePromptCardState();
}

class _SamplePromptCardState extends State<_SamplePromptCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          context.read<ChatController>().sendSamplePrompt(widget.prompt);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: AppConstants.samplePromptWidth,
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          transform: _isHovered
              ? (Matrix4.identity()..setTranslationRaw(0.0, -2.0, 0.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: _isHovered
                  ? colorScheme.primary.withValues(alpha: 0.4)
                  : colorScheme.outlineVariant,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: AppConstants.iconSizeXs,
                color: colorScheme.primary,
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                widget.prompt.display,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
