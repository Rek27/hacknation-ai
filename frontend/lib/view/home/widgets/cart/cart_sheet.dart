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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
        title: const Text('Cart'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
      body: const CartMobilePanel(),
    );
  }
}
