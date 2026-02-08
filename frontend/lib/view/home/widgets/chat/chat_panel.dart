import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/config/app_theme.dart';
import 'package:frontend/model/api_models.dart';
import 'package:frontend/view/home/home_controller.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/view/home/widgets/chat/chat_input_bar.dart';
import 'package:frontend/view/home/widgets/chat/chat_message_list.dart';
import 'package:frontend/view/home/widgets/chat/sample_prompts.dart';
import 'package:frontend/view/home/widgets/chat/chunks/text_form_chunk_widget.dart';

/// Top-level chat panel that orchestrates the chat UI.
/// Shows a header bar (title + API/session actions), then sample prompts
/// or message list, pinned form if any, and input bar.
class ChatPanel extends StatelessWidget {
  const ChatPanel({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.watch<ChatController>();
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _ChatHeader(baseUrl: baseUrl),
          // Main content: sample prompts or message list
          Expanded(
            child: controller.hasStarted
                ? const ChatMessageList()
                : const SamplePrompts(),
          ),
          // Pinned TextFormChunk (final step)
          if (controller.pinnedTextForm != null)
            _PinnedFormSection(chunk: controller.pinnedTextForm!),
          // Loading indicator removed – thinking bubble shown in message list
          // Input bar
          const ChatInputBar(),
        ],
      ),
    );
  }
}

/// Wraps the pinned TextFormChunk with a subtle top shadow.
class _PinnedFormSection extends StatelessWidget {
  const _PinnedFormSection({required this.chunk});

  final dynamic chunk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
      child: TextFormChunkWidget(
        chunk: chunk,
        messageId: '',
        isDisabled: false,
        isPinned: true,
      ),
    );
  }
}

/// Header bar at the top of the chat panel (title + API/session actions).
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingMd,
          ),
          child: Row(
            children: [
              Text(
                'AI Agent Chat',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              _ChatHeaderActions(baseUrl: baseUrl),
            ],
          ),
        ),
        Container(height: 1, color: colorScheme.outlineVariant),
      ],
    );
  }
}

class _ChatHeaderActions extends StatelessWidget {
  const _ChatHeaderActions({required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final HomeController controller = context.watch<HomeController>();
    final HealthStatus? health = controller.health;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isHealthy = health?.status == 'healthy';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'API: $baseUrl',
          child: Padding(
            padding: const EdgeInsets.only(right: AppConstants.spacingSm),
            child: Center(
              child: Text(
                'API',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        Icon(
          isHealthy ? Icons.check_circle : Icons.error,
          color: isHealthy ? AppTheme.success : colorScheme.error,
          size: AppConstants.iconSizeXs,
        ),
        const SizedBox(width: AppConstants.spacingSm),
        if (health != null)
          Padding(
            padding: const EdgeInsets.only(right: AppConstants.spacingMd),
            child: Center(
              child: Text(
                'Sessions: ${health.activeSessions}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
