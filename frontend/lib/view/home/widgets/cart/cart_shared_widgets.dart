import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/cart/cart_utils.dart';

/// Small chip showing a retailer name. Used in cart items and summary cards.
class CartRetailerChip extends StatelessWidget {
  const CartRetailerChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Square image placeholder used for product thumbnails and summary cards.
class CartImagePlaceholder extends StatelessWidget {
  const CartImagePlaceholder({super.key, required this.size, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: Container(
        width: size,
        height: size,
        color: color ?? colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.image, size: AppConstants.iconSizeSm),
      ),
    );
  }
}

/// Empty state shown when the cart has no items.
class CartEmptyState extends StatelessWidget {
  const CartEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
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
    );
  }
}

/// Fixed bottom checkout bar with confirm CTA and helper text.
class CartCheckoutBar extends StatelessWidget {
  const CartCheckoutBar({
    super.key,
    required this.totalPrice,
    required this.retailerCount,
    required this.onCheckout,
  });

  final double totalPrice;
  final int retailerCount;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
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
                  'Checkout All — ${formatPrice(totalPrice)}',
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
