import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/selectable_widget.dart';
import 'package:provider/provider.dart';

class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final CartController controller = Provider.of<CartController>(context);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart),
              SizedBox(width: AppConstants.spacingMd),
              Text(
                'Cart',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: controller.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined),
                        SizedBox(height: AppConstants.spacingMd),
                        Text(
                          'No items yet',
                          style: theme.textTheme.titleMedium,
                        ),
                        SizedBox(height: AppConstants.spacingSm),
                        Text(
                          'Tell the agent what you need and it\'ll find the best deals across the web.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacingMd,
                    ),
                    itemCount: 10,
                    separatorBuilder: (context, index) {
                      return SizedBox(height: AppConstants.spacingMd);
                    },
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.all(AppConstants.spacingMd),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                        child: Text('Item $index'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
