import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_utils.dart';
import 'package:frontend/view/home/widgets/cart/cart_shared_widgets.dart';
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
        const CartImagePlaceholder(size: AppConstants.cartImageSize),
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
                    formatPrice(item.price),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  CartRetailerChip(text: item.retailer),
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
                    formatEstimatedDateFromNow(item.deliveryTime),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: AppConstants.iconSizeXs,
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  Text('Qty:', style: theme.textTheme.bodySmall),
                  const SizedBox(width: AppConstants.spacingXs),
                  SizedBox(
                    width: AppConstants.qtyFieldWidth,
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
            color: colorScheme.surfaceContainerHigh,
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
                'Est. delivery: ${formatEstimatedDurationLabel(item.deliveryTime)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: AppConstants.spacingMd),
              const Icon(Icons.attach_money, size: AppConstants.iconSizeXs),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                'Item total: ${formatPrice(item.price * item.amount)}',
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

    final Color tint = colorScheme.primary;
    final c1 = tint.withValues(alpha: 0.08);
    final c2 = tint.withValues(alpha: 0.05);
    final c3 = tint.withValues(alpha: 0.06);
    final c4 = tint.withValues(alpha: 0.04);

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
                          formatPrice(item.price),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingSm),
                        CartRetailerChip(text: item.retailer),
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

