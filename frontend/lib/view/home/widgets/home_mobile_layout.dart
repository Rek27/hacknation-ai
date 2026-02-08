import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/home_controller.dart';
import 'package:frontend/view/home/widgets/chat/chat_panel.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/service/agent_api.dart';

/// Mobile layout: full-width chat (documents are in a drawer provided by the parent Scaffold).
class HomeMobileLayout extends StatelessWidget {
  const HomeMobileLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = context.watch<HomeController>();
    return Column(
      children: [
        if (controller.errorMessage != null)
          _ErrorBanner(message: controller.errorMessage!),
        Expanded(
          child: ChangeNotifierProvider<ChatController>(
            create: (_) => ChatController(chatService: MockChatService()),
            child: const ChatPanel(),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
