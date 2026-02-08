import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/home_controller.dart';
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
        CartImagePlaceholder(
          size: AppConstants.cartImageSize,
          imageUrl: item.imageUrl,
        ),
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
                  CartItemPriceWithDiscount(item: item),
                  const SizedBox(width: AppConstants.spacingSm),
                  CartRetailerChip(text: item.retailer),
                ],
              ),
              if (item.reviewRating != null) ...[
                const SizedBox(height: AppConstants.spacingXs),
                StarRatingDisplay(rating: item.reviewRating!),
              ],
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
        Icon(
          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: colorScheme.onSurfaceVariant,
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
              CartItemTotalWithDiscount(item: item),
            ],
          ),
        ),
        // AI Recommendation Reasoning button + display
        _AiReasoningSection(groupIndex: groupIndex),
        if (group != null) ...[
          const SizedBox(height: AppConstants.spacingMd),
          Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: AppConstants.metaIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppConstants.metaIconGap),
              Text(
                'Alternatives',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (controller.isAlternativeActive(groupIndex))
                InkWell(
                  onTap: () => controller.resetToMain(groupIndex),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingSm,
                      vertical: AppConstants.spacingXs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restart_alt_rounded,
                          size: AppConstants.metaIconSize,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Text(
                          'Use recommended',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          _RecommendationsRow(groupIndex: groupIndex, group: group),
        ],
      ],
    );
  }
}

/// Section that shows a button to ask AI why the recommended item was chosen,
/// and displays the reasoning text once fetched.
class _AiReasoningSection extends StatelessWidget {
  const _AiReasoningSection({required this.groupIndex});
  final int groupIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = context.watch<CartController>();
    final isLoading = controller.isReasoningLoading(groupIndex);
    final reasoning = controller.getAiReasoning(groupIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppConstants.spacingSm),
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              onTap: isLoading
                  ? null
                  : () {
                      final api = context.read<HomeController>().api;
                      controller.fetchRecommendationReason(groupIndex, api);
                    },
              child: AnimatedContainer(
                duration: AppConstants.durationFast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm + 2,
                  vertical: AppConstants.spacingXs + 2,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: AppConstants.iconSizeXs,
                        height: AppConstants.iconSizeXs,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    else
                      Icon(
                        Icons.auto_awesome,
                        size: AppConstants.iconSizeXs,
                        color: colorScheme.primary,
                      ),
                    const SizedBox(width: AppConstants.spacingXs),
                    Text(
                      reasoning != null ? 'Ask AI again' : 'Why this item?',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (reasoning != null) ...[
          const SizedBox(height: AppConstants.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingSm + 2),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: AppConstants.metaIconSize,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: Text(
                    reasoning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Row of 3 alternative recommendation tiles: Cheapest, Best reviewed, Fastest.
/// Each tile uses a category-specific accent colour and icon for visual clarity.
class _RecommendationsRow extends StatelessWidget {
  const _RecommendationsRow({required this.groupIndex, required this.group});
  final int groupIndex;
  final RecommendedItem group;

  bool _same(CartItem a, CartItem b) => (a.id ?? a.name) == (b.id ?? b.name);

  @override
  Widget build(BuildContext context) {
    final CartController controller = context.read<CartController>();
    final CartItem displayedMain =
        controller.getDisplayedMain(groupIndex) ?? group.main;
    final bool selectCheapest = _same(displayedMain, group.cheapest);
    final bool selectBest = _same(displayedMain, group.bestReviewed);
    final bool selectFastest = _same(displayedMain, group.fastest);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _RecommendationTile(
            categoryKey: 'cheapest',
            label: 'Cheapest',
            item: group.cheapest,
            isSelected: selectCheapest,
            onTap: () =>
                controller.selectRecommendation(groupIndex, group.cheapest),
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: _RecommendationTile(
            categoryKey: 'best',
            label: 'Best reviewed',
            item: group.bestReviewed,
            isSelected: selectBest,
            onTap: () =>
                controller.selectRecommendation(groupIndex, group.bestReviewed),
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: _RecommendationTile(
            categoryKey: 'fastest',
            label: 'Fastest',
            item: group.fastest,
            isSelected: selectFastest,
            onTap: () =>
                controller.selectRecommendation(groupIndex, group.fastest),
          ),
        ),
      ],
    );
  }
}

/// A single alternative recommendation tile with category-specific styling.
/// Displays a coloured icon badge, product name, price, retailer, and delivery
/// time. The key differentiating metric is highlighted in the accent colour
/// (price for cheapest, delivery time for fastest).
class _RecommendationTile extends StatefulWidget {
  const _RecommendationTile({
    required this.categoryKey,
    required this.label,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final String categoryKey;
  final String label;
  final CartItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_RecommendationTile> createState() => _RecommendationTileState();
}

class _RecommendationTileState extends State<_RecommendationTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accent = categoryAccentColor(context, widget.categoryKey);
    final Color bg = categorySoftTint(
      context,
      widget.categoryKey,
      isSelected: widget.isSelected,
    );
    final Color borderColor = widget.isSelected
        ? accent
        : (_hovered
              ? accent.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.3));
    final double borderWidth = widget.isSelected ? 1.5 : 1;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          hoverColor: Colors.transparent,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppConstants.durationFast,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            padding: const EdgeInsets.all(AppConstants.spacingSm + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppConstants.spacingXs),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusXs,
                        ),
                      ),
                      child: Icon(
                        iconForCategoryKey(widget.categoryKey),
                        size: AppConstants.metaIconSize,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: AppConstants.metaIconGap),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: AppConstants.iconSizeXs,
                        color: accent,
                      ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Text(
                  widget.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.item.reviewRating != null) ...[
                  const SizedBox(height: AppConstants.spacingXs),
                  StarRatingDisplay(
                    rating: widget.item.reviewRating!,
                    starSize: AppConstants.metaIconSize - 2,
                  ),
                ],
                const SizedBox(height: AppConstants.spacingXs),
                Row(
                  children: [
                    Text(
                      formatPrice(widget.item.price),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: widget.categoryKey == 'cheapest'
                            ? accent
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Flexible(
                      child: CartRetailerChip(text: widget.item.retailer),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: AppConstants.metaIconSize - 2,
                      color: widget.categoryKey == 'fastest'
                          ? accent
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppConstants.spacingXs),
                    Text(
                      '~${formatEstimatedDurationLabel(widget.item.deliveryTime)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: widget.categoryKey == 'fastest'
                            ? accent
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
