import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_utils.dart';
import 'package:frontend/view/home/widgets/cart/cart_shared_widgets.dart';
import 'package:provider/provider.dart';

/// Mobile-optimised cart item card with smaller image, wrapping name,
/// and a 2x2 recommendation grid instead of a 4-column row.
class CartItemMobileWidget extends StatelessWidget {
  const CartItemMobileWidget({
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
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color borderColor = isExpanded
        ? colorScheme.primary
        : colorScheme.outlineVariant.withValues(alpha: 0.6);
    return InkWell(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MobileHeaderRow(
                groupIndex: groupIndex,
                item: item,
                isExpanded: isExpanded,
              ),
              if (isExpanded) ...[
                const SizedBox(height: AppConstants.spacingSm),
                const Divider(height: 1),
                const SizedBox(height: AppConstants.spacingSm),
                _MobileExpandedDetails(
                  groupIndex: groupIndex,
                  item: item,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobile header: 56px image, 2-line name, price/retailer, and compact actions.
class _MobileHeaderRow extends StatelessWidget {
  const _MobileHeaderRow({
    required this.groupIndex,
    required this.item,
    required this.isExpanded,
  });

  final int groupIndex;
  final CartItem item;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CartImagePlaceholder(size: 56),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  _MobileActionIcons(
                    item: item,
                    isExpanded: isExpanded,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingXs),
              Row(
                children: [
                  Text(
                    formatPrice(item.price),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  CartRetailerChip(text: item.retailer),
                ],
              ),
              const SizedBox(height: AppConstants.spacingXs),
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
                  const Text('Qty:'),
                  const SizedBox(width: AppConstants.spacingXs),
                  SizedBox(
                    width: 40,
                    child: TextFormField(
                      initialValue: item.amount.toString(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (String value) {
                        if (value.isEmpty) return;
                        final int? qty = int.tryParse(value);
                        if (qty == null) return;
                        final String key = item.id ?? item.name;
                        context.read<CartController>().updateQuantity(key, qty);
                      },
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
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
      ],
    );
  }
}

/// Delete and expand/collapse icons for the mobile item card.
class _MobileActionIcons extends StatelessWidget {
  const _MobileActionIcons({
    required this.item,
    required this.isExpanded,
  });

  final CartItem item;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Remove',
          icon: const Icon(
            Icons.delete_outline,
            size: AppConstants.iconSizeXs,
          ),
          onPressed: () {
            final String key = item.id ?? item.name;
            context.read<CartController>().deleteItem(key);
          },
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        Icon(
          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          size: AppConstants.iconSizeXs,
          color: colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

/// Expanded details for mobile: delivery info and 2x2 recommendations grid.
class _MobileExpandedDetails extends StatelessWidget {
  const _MobileExpandedDetails({
    required this.groupIndex,
    required this.item,
  });

  final int groupIndex;
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final CartController controller = context.watch<CartController>();
    final RecommendedItem? group = controller.getGroup(groupIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
          padding: const EdgeInsets.all(AppConstants.spacingSm),
          child: Wrap(
            spacing: AppConstants.spacingMd,
            runSpacing: AppConstants.spacingXs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
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
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
            ],
          ),
        ),
        if (group != null) ...[
          const SizedBox(height: AppConstants.spacingSm),
          _MobileRecommendationsGrid(groupIndex: groupIndex, group: group),
        ],
      ],
    );
  }
}

/// 2x2 grid of recommendation tiles optimised for mobile screens.
class _MobileRecommendationsGrid extends StatelessWidget {
  const _MobileRecommendationsGrid({
    required this.groupIndex,
    required this.group,
  });

  final int groupIndex;
  final RecommendedItem group;

  bool _same(CartItem a, CartItem b) => (a.id ?? a.name) == (b.id ?? b.name);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final CartController controller = context.read<CartController>();
    final CartItem displayedMain =
        controller.getDisplayedMain(groupIndex) ?? group.main;
    final bool selectCheapest = _same(displayedMain, group.cheapest);
    final bool selectBest = _same(displayedMain, group.bestReviewed);
    final bool selectFastest = _same(displayedMain, group.fastest);
    final bool selectMain = !(selectCheapest || selectBest || selectFastest);
    final Color c1 = colorScheme.primary.withValues(alpha: 0.1);
    final Color c2 = colorScheme.primaryFixed.withValues(alpha: 0.1);
    final Color c3 = colorScheme.primaryFixedDim.withValues(alpha: 0.15);
    final Color c4 = colorScheme.onPrimaryFixedVariant.withValues(alpha: 0.15);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double tileWidth =
            (constraints.maxWidth - AppConstants.spacingSm) / 2;
        return Wrap(
          spacing: AppConstants.spacingSm,
          runSpacing: AppConstants.spacingSm,
          children: [
            _MobileRecommendationTile(
              width: tileWidth,
              label: 'Main',
              item: group.main,
              bg: c1,
              selected: selectMain,
              onTap: () =>
                  controller.selectRecommendation(groupIndex, group.main),
            ),
            _MobileRecommendationTile(
              width: tileWidth,
              label: 'Cheapest',
              item: group.cheapest,
              bg: c2,
              selected: selectCheapest,
              onTap: () =>
                  controller.selectRecommendation(groupIndex, group.cheapest),
            ),
            _MobileRecommendationTile(
              width: tileWidth,
              label: 'Best reviewed',
              item: group.bestReviewed,
              bg: c3,
              selected: selectBest,
              onTap: () => controller.selectRecommendation(
                  groupIndex, group.bestReviewed),
            ),
            _MobileRecommendationTile(
              width: tileWidth,
              label: 'Fastest',
              item: group.fastest,
              bg: c4,
              selected: selectFastest,
              onTap: () =>
                  controller.selectRecommendation(groupIndex, group.fastest),
            ),
          ],
        );
      },
    );
  }
}

/// Single recommendation tile used inside the 2x2 grid.
class _MobileRecommendationTile extends StatelessWidget {
  const _MobileRecommendationTile({
    required this.width,
    required this.label,
    required this.item,
    required this.bg,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String label;
  final CartItem item;
  final Color bg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color borderColor =
        selected ? colorScheme.primary : Colors.transparent;
    final double borderWidth = selected ? 2 : 1;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          onTap: onTap,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  formatPrice(item.price),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXs / 2),
                CartRetailerChip(text: item.retailer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
