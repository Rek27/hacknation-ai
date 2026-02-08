import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_mobile_panel.dart';

/// Full-screen or large bottom-sheet wrapper for [CartPanel] on mobile.
/// Expects [CartController] to be provided by a parent [ChangeNotifierProvider.value].
/// Includes an AppBar with a close button to pop the route or sheet.
class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: const CartMobilePanel(),
      ),
    );
  }
}
