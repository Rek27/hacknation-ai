import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:provider/provider.dart';
import 'package:frontend/view/home/home_controller.dart';
import 'package:frontend/view/home/widgets/chat/chat_panel.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_panel.dart';
import 'package:frontend/service/agent_api.dart';
import 'package:frontend/view/home/widgets/resizable_divider.dart';

/// Desktop/web layout: chat area and cart view in a Row.
/// CartController is shared between the ChatController and CartPanel.
/// The two panels are separated by a draggable divider that lets the
/// user resize each section.
class HomeDesktopLayout extends StatefulWidget {
  const HomeDesktopLayout({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  State<HomeDesktopLayout> createState() => _HomeDesktopLayoutState();
}

class _HomeDesktopLayoutState extends State<HomeDesktopLayout> {
  double _chatWidthFraction = AppConstants.defaultChatWidthFraction;

  void _handleDividerDrag(double delta, double availableWidth) {
    setState(() {
      _chatWidthFraction += delta / availableWidth;
      _chatWidthFraction = _chatWidthFraction.clamp(
        AppConstants.panelMinWidthFraction,
        1.0 - AppConstants.panelMinWidthFraction,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final HomeController controller = context.watch<HomeController>();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // CartController is created as an ancestor so both panels can access it.
    return ChangeNotifierProvider<CartController>(
      create: (_) => CartController(),
      child: Builder(
        builder: (context) {
          final CartController cartController = context.read<CartController>();
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double totalWidth = constraints.maxWidth;
              final double availableWidth =
                  totalWidth - AppConstants.resizeDividerHitWidth;
              final double chatWidth = availableWidth * _chatWidthFraction;
              final double cartWidth =
                  availableWidth * (1.0 - _chatWidthFraction);
              return Row(
                children: [
                  // ── Chat panel (left) ──────────────────────────────────
                  SizedBox(
                    width: chatWidth,
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
                            cartController: cartController,
                          );
                        },
                        child: ChatPanel(baseUrl: widget.baseUrl),
                      ),
                    ),
                  ),
                  // ── Resizable divider ─────────────────────────────────
                  ResizableDivider(
                    onDragUpdate: (double delta) =>
                        _handleDividerDrag(delta, availableWidth),
                  ),
                  // ── Cart panel (right) ─────────────────────────────────
                  SizedBox(
                    width: cartWidth,
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
                        child: CartPanel(),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
