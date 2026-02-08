import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:provider/provider.dart';

/// Visual representation of a single cart line item with expandable details.
class CartItemWidget extends StatefulWidget {
  const CartItemWidget({
    super.key,
    required this.groupIndex,
    required this.item,
    required this.isExpanded,
    required this.onToggle,
  });

  final int groupIndex;
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
                _HeaderRow(
                  groupIndex: widget.groupIndex,
                  item: widget.item,
                  isExpanded: widget.isExpanded,
                ),
                if (widget.isExpanded) ...[
                  const SizedBox(height: AppConstants.spacingMd),
                  const Divider(height: 1),
                  const SizedBox(height: AppConstants.spacingSm),
                  _ExpandedDetails(
                    groupIndex: widget.groupIndex,
                    item: widget.item,
                  ),
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
  const _HeaderRow({
    required this.groupIndex,
    required this.item,
    required this.isExpanded,
  });

  final int groupIndex;
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
              Row(
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Tooltip(
                    message: context.read<CartController>().getDisplayedReason(
                      groupIndex,
                    ),
                    preferBelow: true,
                    child: Icon(
                      Icons.info_outline,
                      size: AppConstants.iconSizeSm,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                  Text('Qty:'),
                  const SizedBox(width: AppConstants.spacingXs),
                  SizedBox(
                    width: 40,
                    child: TextFormField(
                      initialValue: item.amount.toString(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.isEmpty) return;
                        final qty = int.tryParse(value);
                        if (qty == null) return;
                        final key = item.id ?? item.name;
                        context.read<CartController>().updateQuantity(key, qty);
                      },
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingSm,
                          vertical: AppConstants.spacingXs,
                        ),
                        hintText: 'Qty',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppConstants.spacingMd),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: AppConstants.iconSizeSm,
                  ),
                  onPressed: () {
                    final key = item.id ?? item.name;
                    context.read<CartController>().deleteItem(key);
                  },
                  // make it dense
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
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
  const _ExpandedDetails({required this.groupIndex, required this.item});
  final int groupIndex;
  final CartItem item;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<CartController>();
    final group = controller.getGroup(groupIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
        ),
        if (group != null) ...[
          const SizedBox(height: AppConstants.spacingMd),
          _RecommendationsRow(groupIndex: groupIndex, group: group),
        ],
      ],
    );
  }
}

/// Row of 4 recommended options: Main, Cheapest, Best reviewed, Fastest.
class _RecommendationsRow extends StatefulWidget {
  const _RecommendationsRow({required this.groupIndex, required this.group});
  final int groupIndex;
  final RecommendedItem group;

  @override
  State<_RecommendationsRow> createState() => _RecommendationsRowState();
}

class _RecommendationsRowState extends State<_RecommendationsRow> {
  int _hoveredIndex = -1;

  bool _same(CartItem a, CartItem b) => (a.id ?? a.name) == (b.id ?? b.name);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.read<CartController>();
    final group = widget.group;

    final c1 = colorScheme.primary.withValues(alpha: 0.1);
    final c2 = colorScheme.primaryFixed.withValues(alpha: 0.1);
    final c3 = colorScheme.primaryFixedDim.withValues(alpha: 0.15);
    final c4 = colorScheme.onPrimaryFixedVariant.withValues(alpha: 0.15);

    final displayedMain =
        controller.getDisplayedMain(widget.groupIndex) ?? group.main;
    final bool selectCheapest = _same(displayedMain, group.cheapest);
    final bool selectBest = _same(displayedMain, group.bestReviewed);
    final bool selectFastest = _same(displayedMain, group.fastest);
    final bool selectMain = !(selectCheapest || selectBest || selectFastest);

    Widget tile({
      required int index,
      required String label,
      required CartItem item,
      required Color bg,
      required bool selected,
    }) {
      final bool hovered = _hoveredIndex == index;
      final Color borderColor = selected
          ? colorScheme.primary
          : (hovered ? colorScheme.primary : Colors.transparent);
      final double borderWidth = selected ? 2 : 1;
      return Expanded(
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) => setState(() => _hoveredIndex = -1),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              hoverColor: Colors.transparent,
              onTap: () =>
                  controller.selectRecommendation(widget.groupIndex, item),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                padding: const EdgeInsets.all(AppConstants.spacingSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXs),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXs),
                    Row(
                      children: [
                        Text(
                          _formatPrice(item.price),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        _RetailerChip(text: item.retailer),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile(
          index: 0,
          label: 'Main',
          item: group.main,
          bg: c1,
          selected: selectMain,
        ),
        const SizedBox(width: AppConstants.spacingSm),
        tile(
          index: 1,
          label: 'Cheapest',
          item: group.cheapest,
          bg: c2,
          selected: selectCheapest,
        ),
        const SizedBox(width: AppConstants.spacingSm),
        tile(
          index: 2,
          label: 'Best reviewed',
          item: group.bestReviewed,
          bg: c3,
          selected: selectBest,
        ),
        const SizedBox(width: AppConstants.spacingSm),
        tile(
          index: 3,
          label: 'Fastest',
          item: group.fastest,
          bg: c4,
          selected: selectFastest,
        ),
      ],
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
  return '$sign$grouped,$decPart €';
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
