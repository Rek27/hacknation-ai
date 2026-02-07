import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:provider/provider.dart';

class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final CartController controller = Provider.of<CartController>(context);

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Text(
              'Cart',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: Center(child: Text('Your cart items will appear here.')),
          ),
        ],
      ),
    );
  }
}
