import 'package:flutter/material.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:provider/provider.dart';
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // ── Chat panel (left) ────────────────────────────────────────
        Expanded(
          flex: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surfaceContainerLow,
                  colorScheme.surface,
                ],
              ),
            ),
            child: ChangeNotifierProvider<ChatController>(
              create: (_) {
                final HomeController homeController = controller;
                return ChatController(
                  chatService: RealChatService(
                    homeController.api,
                    homeController.sessionId,
                  ),
                );
              },
              child: const ChatPanel(),
            ),
          ),
        ),
        // ── Divider ──────────────────────────────────────────────────
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: colorScheme.outlineVariant,
        ),
        // ── Cart panel (right) ───────────────────────────────────────
        Expanded(
          flex: 5,
          child: ClipRect(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainerLow,
                    colorScheme.surface,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: ChangeNotifierProvider<CartController>(
                create: (_) => CartController(),
                child: CartPanel(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
