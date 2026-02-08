import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/view/home/widgets/chat/chat_input_bar.dart';
import 'package:frontend/view/home/widgets/chat/chat_message_list.dart';
import 'package:frontend/view/home/widgets/chat/sample_prompts.dart';
import 'package:frontend/view/home/widgets/chat/chunks/text_form_chunk_widget.dart';

/// Top-level chat panel that orchestrates the chat UI.
/// Shows sample prompts before the conversation starts,
/// then switches to the message list with input bar.
class ChatPanel extends StatelessWidget {
  const ChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatController controller = context.watch<ChatController>();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          // Main content: sample prompts or message list
          Expanded(
            child: controller.hasStarted
                ? const ChatMessageList()
                : const SamplePrompts(),
          ),
          // Pinned TextFormChunk (final step)
          if (controller.pinnedTextForm != null)
            _PinnedFormSection(chunk: controller.pinnedTextForm!),
          // Loading indicator
          if (controller.isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
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
