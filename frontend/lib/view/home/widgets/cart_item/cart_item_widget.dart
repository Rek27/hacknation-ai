import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';

/// Visual representation of a single cart line item with expandable details.
class CartItemWidget extends StatefulWidget {
  const CartItemWidget({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggle,
  });

  final CartItem item;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  State<CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<CartItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final borderColor = _hovered || widget.isExpanded
        ? colorScheme.primary
        : colorScheme.outlineVariant.withValues(alpha: 0.6);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onToggle,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderRow(item: widget.item, isExpanded: widget.isExpanded),
                if (widget.isExpanded) ...[
                  const SizedBox(height: AppConstants.spacingMd),
                  const Divider(height: 1),
                  const SizedBox(height: AppConstants.spacingSm),
                  _ExpandedDetails(item: widget.item),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header section of a cart item: name, price, retailer and meta.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.item, required this.isExpanded});

  final CartItem item;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SquareImagePlaceholder(size: 80),
        const SizedBox(width: AppConstants.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatPrice(item.price),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  _RetailerChip(text: item.retailer),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: AppConstants.iconSizeXs,
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  Text(
                    _formatEstimatedDateFromNow(item.deliveryTime),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: AppConstants.iconSizeXs,
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  Text('Qty: ${item.amount}', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppConstants.spacingMd),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _QuantityBadge(quantity: item.amount),
            const SizedBox(height: AppConstants.spacingSm),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }
}

/// Expanded details section: shipping ETA and line total.
class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({required this.item});
  final CartItem item;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: AppConstants.iconSizeXs,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            'Est. delivery: ${_formatEstimatedDurationLabel(item.deliveryTime)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(width: AppConstants.spacingMd),
          const Icon(Icons.attach_money, size: AppConstants.iconSizeXs),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            'Item total: ${_formatPrice(item.price * item.amount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple square image placeholder used for product thumbnails.
class _SquareImagePlaceholder extends StatelessWidget {
  const _SquareImagePlaceholder({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: Container(
        width: size,
        height: size,
        color: colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.image, size: AppConstants.iconSizeSm),
      ),
    );
  }
}

/// Small chip showing the retailer name.
class _RetailerChip extends StatelessWidget {
  const _RetailerChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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

/// Small badge showing the quantity for this line.
class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge({required this.quantity});
  final int quantity;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: 2,
      ),
      child: Text(
        'x$quantity',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
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

/// Short human label for a duration (e.g. 2d, 5h, 30m).
String _formatEstimatedDurationLabel(Duration d) {
  if (d.inDays >= 1) return '${d.inDays}d';
  if (d.inHours >= 1) return '${d.inHours}h';
  return '${d.inMinutes}m';
}

/// Returns a short date like "Feb 10" computed from now + duration.
String _formatEstimatedDateFromNow(Duration d) {
  final DateTime date = DateTime.now().add(d);
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  return '$month ${date.day}';
}
