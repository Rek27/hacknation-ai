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

    return Row(
      children: [
        Expanded(
          flex: 3,
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
        Expanded(
          flex: 5,
          child: ChangeNotifierProvider<CartController>(
            create: (_) => CartController(),
            child: CartPanel(),
          ),
        ),
      ],
    );
  }
}

