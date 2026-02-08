import 'package:flutter/material.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:provider/provider.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/home_controller.dart';
import 'package:frontend/view/home/widgets/chat/chat_panel.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_panel.dart';
import 'package:frontend/service/agent_api.dart';

/// Desktop/web layout: chat area and cart view in a Row.
class HomeDesktopLayout extends StatelessWidget {
  const HomeDesktopLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = context.watch<HomeController>();

    return Column(
      children: [
        if (controller.errorMessage != null)
          _ErrorBanner(message: controller.errorMessage!),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: ChangeNotifierProvider<ChatController>(
                  create: (_) => ChatController(chatService: MockChatService()),
                  child: const ChatPanel(),
                ),
              ),
              Expanded(
                flex: 5,
                child: ChangeNotifierProvider<CartController>(
                  create: (_) => CartController(),
                  child: CartPanel(),
                ),
              ),
            ],
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
