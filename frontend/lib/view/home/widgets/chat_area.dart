import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/home_controller.dart';

/// Reusable chat message list and input. Used in both mobile and desktop layouts.
class ChatArea extends StatelessWidget {
  const ChatArea({
    super.key,
    required this.scrollController,
    required this.inputController,
  });

  final ScrollController scrollController;
  final TextEditingController inputController;

  @override
  Widget build(BuildContext context) {
    final HomeController controller = context.watch<HomeController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      children: [
        Expanded(
          child: Container(
            color: colorScheme.surfaceContainerLow,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingSm,
              ),
              itemCount: controller.chatItems.length,
              itemBuilder: (BuildContext context, int index) {
                final item = controller.chatItems[index];
                return _buildChatItem(context, item, theme);
              },
            ),
          ),
        ),
        if (controller.sending)
          LinearProgressIndicator(
            minHeight: 2,
            color: colorScheme.primary,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingSm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: inputController,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Ask me anything...',
                  ),
                  onSubmitted: (_) => _send(context),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              ElevatedButton(
                onPressed: controller.sending ? null : () => _send(context),
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatItem(
    BuildContext context,
    ChatItem item,
    ThemeData theme,
  ) {
    switch (item.type) {
      case ChatItemType.user:
        return _ChatBubble(isUser: true, child: Text(item.text));
      case ChatItemType.assistant:
        return _ChatBubble(isUser: false, child: Text(item.text));
      case ChatItemType.tool:
        return _ChatBubble(
          isUser: false,
          child: _ToolIndicator(item: item),
        );
      case ChatItemType.thinking:
        return _ChatBubble(
          isUser: false,
          child: Text(
            '💭 ${item.text}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.tertiary,
            ),
          ),
        );
      case ChatItemType.error:
        return _ChatBubble(
          isUser: false,
          child: Text(
            '⚠️ ${item.text}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        );
    }
  }

  void _send(BuildContext context) {
    final String text = inputController.text.trim();
    if (text.isEmpty) return;
    inputController.clear();
    context.read<HomeController>().sendMessage(text, 'flutter://home');
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.isUser, required this.child});

  final bool isUser;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color backgroundColor =
        isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final Color foregroundColor =
        isUser ? colorScheme.onPrimary : colorScheme.onSurface;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm,
        ),
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: theme.textTheme.bodyLarge!.copyWith(color: foregroundColor),
          child: child,
        ),
      ),
    );
  }
}

class _ToolIndicator extends StatelessWidget {
  const _ToolIndicator({required this.item});

  final ChatItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    Color color;
    IconData icon;
    switch (item.toolStatus) {
      case 'executing':
        color = colorScheme.primaryContainer;
        icon = Icons.play_arrow;
        break;
      case 'completed':
        color = colorScheme.tertiaryContainer;
        icon = Icons.check;
        break;
      default:
        color = colorScheme.errorContainer;
        icon = Icons.close;
    }
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppConstants.spacingXs),
          Text(
            'Tool ${item.toolStatus}: ${item.toolName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
