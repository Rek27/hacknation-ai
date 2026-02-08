import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/home_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_utils.dart';
import 'package:provider/provider.dart';

/// Displays a 5-star rating with optional numeric label.
/// Stars fill proportionally based on [rating] (0.0–5.0).
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.starSize = AppConstants.metaIconSize,
    this.showLabel = true,
  });

  final double rating;
  final double starSize;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color filledColor = categoryAccentColor(context, 'best');
    final Color emptyColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.25,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List<Widget>.generate(AppConstants.starCount, (int index) {
          final double fillLevel = (rating - index).clamp(0.0, 1.0);
          return Padding(
            padding: EdgeInsets.only(
              right: index < AppConstants.starCount - 1
                  ? AppConstants.starSpacing
                  : 0,
            ),
            child: _StarIcon(
              fillLevel: fillLevel,
              size: starSize,
              filledColor: filledColor,
              emptyColor: emptyColor,
            ),
          );
        }),
        if (showLabel) ...[
          const SizedBox(width: AppConstants.spacingXs),
          Text(
            rating.toStringAsFixed(1),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Renders a single star with partial fill support.
/// [fillLevel] ranges from 0.0 (empty) to 1.0 (fully filled).
class _StarIcon extends StatelessWidget {
  const _StarIcon({
    required this.fillLevel,
    required this.size,
    required this.filledColor,
    required this.emptyColor,
  });

  final double fillLevel;
  final double size;
  final Color filledColor;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    if (fillLevel >= 1.0) {
      return Icon(Icons.star_rounded, size: size, color: filledColor);
    }
    if (fillLevel <= 0.0) {
      return Icon(Icons.star_rounded, size: size, color: emptyColor);
    }
    return SizedBox(
      width: size,
      height: size,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            stops: <double>[fillLevel, fillLevel],
            colors: <Color>[filledColor, emptyColor],
          ).createShader(bounds);
        },
        child: Icon(Icons.star_rounded, size: size),
      ),
    );
  }
}

/// Small chip showing a retailer logo + name. Used in cart items and summary cards.
class CartRetailerChip extends StatelessWidget {
  const CartRetailerChip({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String baseUrl = context.read<HomeController>().api.baseUrl;
    final String logoFullUrl = '$baseUrl${retailerLogoUrl(text)}';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs / 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: Image.network(
              logoFullUrl,
              width: 16,
              height: 16,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: AppConstants.spacingXs),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Square image placeholder used for product thumbnails and summary cards.
/// When [imageUrl] (a relative path like "/images/42") is provided the widget
/// loads the image from the backend. Otherwise it shows a grey placeholder icon.
class CartImagePlaceholder extends StatelessWidget {
  const CartImagePlaceholder({
    super.key,
    required this.size,
    this.color,
    this.imageUrl,
  });

  final double size;
  final Color? color;

  /// Relative URL such as "/images/42".  Resolved against the API base URL.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bgColor = color ?? colorScheme.surfaceContainerHighest;

    // Resolve full URL — extract the path portion and prepend the app base URL
    // so images always route through the correct host (e.g. ngrok tunnel).
    String? fullUrl;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final baseUrl = context.read<HomeController>().api.baseUrl;
      String path = imageUrl!;
      // If the backend returned an absolute URL, extract just the path.
      if (path.startsWith('http://') || path.startsWith('https://')) {
        path = Uri.parse(path).path;
      }
      fullUrl = '$baseUrl$path';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Container(
        width: size,
        height: size,
        color: bgColor,
        child: fullUrl != null
            ? Image.network(
                fullUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _PlaceholderIcon(size: size, colorScheme: colorScheme),
              )
            : _PlaceholderIcon(size: size, colorScheme: colorScheme),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon({required this.size, required this.colorScheme});
  final double size;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.image_outlined,
      size: size * 0.4,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
    );
  }
}

/// Empty state shown when the cart has no items.
class CartEmptyState extends StatelessWidget {
  const CartEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppConstants.errorIconSize,
              height: AppConstants.errorIconSize,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: AppConstants.iconSizeSm + 8,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              'No items yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              'Tell the agent what you need and it\'ll find the best deals across the web.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacingSm + 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
              ),
              onPressed: onCheckout,
              icon: const Icon(Icons.bolt),
              label: Text(
                'Checkout All — ${formatPrice(totalPrice)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
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
