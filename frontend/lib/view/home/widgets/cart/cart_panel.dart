import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_widget.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_controller.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:provider/provider.dart';
import 'package:frontend/view/home/widgets/cart/cart_loading_list.dart';
import 'package:frontend/view/home/widgets/cart/cart_error_widget.dart';

/// High-level cart panel with header, items list and fixed checkout bar.
class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final CartController controller = Provider.of<CartController>(context);

    return Stack(
      children: [
        // Main content with standard page padding.
        Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Left: title and count chip
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_cart,
                          size: AppConstants.iconSizeSm,
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        Text(
                          'Smart Cart',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        if (!controller.isLoading)
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusSm,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spacingSm,
                              vertical: AppConstants.spacingXs,
                            ),
                            child: Text(
                              '${controller.itemCount} items',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Right: estimated total
                  if (!controller.isLoading)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Estimated total',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatPrice(controller.totalPrice),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingMd),
              const Divider(height: 1),
              Expanded(
                child: controller.isLoading
                    ? const CartLoadingList()
                    : (controller.errorMessage != null)
                    ? CartErrorWidget(
                        title: 'Something went wrong',
                        subtitle: controller.errorMessage!,
                        onRetry: () => controller.loadDummyData(),
                      )
                    : controller.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_outlined),
                            const SizedBox(height: AppConstants.spacingMd),
                            Text(
                              'No items yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppConstants.spacingSm),
                            Text(
                              'Tell the agent what you need and it\'ll find the best deals across the web.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                          top: AppConstants.spacingMd,
                          bottom: 104, // space for bottom bar height
                        ),
                        itemCount: controller.items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppConstants.spacingMd),
                        itemBuilder: (context, index) {
                          final CartItem item = controller.items[index];
                          final expanded = controller.isExpanded(
                            item.id ?? '$index',
                          );
                          final String id = item.id ?? '$index';
                          return ChangeNotifierProvider<CartItemController>(
                            create: (_) => CartItemController(item: item),
                            child: CartItemWidget(
                              item: item,
                              isExpanded: expanded,
                              onToggle: () => controller.toggleExpanded(id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        // Edge-to-edge fixed bottom confirm bar (outside page padding)
        if (!controller.isLoading && controller.errorMessage == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacingMd,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      width: 1,
                    ),
                  ),
                ),
                child: _CheckoutBar(
                  totalPrice: controller.totalPrice,
                  retailerCount: controller.retailerCount,
                  onCheckout: () {
                    // TODO: hook into controller / flow
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Checkout initiated')),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fixed bottom checkout bar with confirm CTA and helper text.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.totalPrice,
    required this.retailerCount,
    required this.onCheckout,
  });

  final double totalPrice;
  final int retailerCount;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              onPressed: onCheckout,
              icon: const Icon(Icons.bolt),
              label: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacingSm,
                ),
                child: Text(
                  'Checkout All — ${_formatPrice(totalPrice)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'Agent will handle checkout across $retailerCount retailers',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Formats a price in euro style (e.g. €1.234,56).
String _formatPrice(double price) {
  final isNegative = price < 0;
  final abs = price.abs();
  final fixed = abs.toStringAsFixed(2); // 1234.56
  final parts = fixed.split('.');
  String intPart = parts[0];
  final decPart = parts[1];
  final chars = intPart.split('').reversed.toList();
  final buf = StringBuffer();
  for (int i = 0; i < chars.length; i++) {
    buf.write(chars[i]);
    if ((i + 1) % 3 == 0 && i + 1 != chars.length) {
      buf.write('.');
    }
  }
  final grouped = buf.toString().split('').reversed.join();
  final sign = isNegative ? '-' : '';
  return '€$sign$grouped,$decPart';
}
