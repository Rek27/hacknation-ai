import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/home_controller.dart';
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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color borderColor = isExpanded
        ? colorScheme.primary
        : colorScheme.outlineVariant.withValues(alpha: 0.6);
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: AnimatedContainer(
          duration: AppConstants.durationMedium,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.all(AppConstants.spacingSm + 2),
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
        CartImagePlaceholder(
          size: AppConstants.cartImageSizeMobile,
          color: colorScheme.surfaceContainerHigh,
          imageUrl: item.imageUrl,
        ),
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
              if (item.reviewRating != null) ...[
                const SizedBox(height: AppConstants.spacingXs),
                StarRatingDisplay(rating: item.reviewRating!),
              ],
              const SizedBox(height: AppConstants.spacingXs),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: AppConstants.metaIconSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  Flexible(
                    child: Text(
                      formatEstimatedDateFromNow(item.deliveryTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: AppConstants.metaIconSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  Text(
                    'Qty:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingXs),
                  SizedBox(
                    width: AppConstants.qtyFieldWidth,
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
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHigh,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingXs,
                          vertical: AppConstants.spacingXs,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm,
                          ),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1,
                          ),
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
    return Icon(
      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
      size: AppConstants.iconSizeXs,
      color: colorScheme.onSurfaceVariant,
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
            color: colorScheme.surfaceContainerHigh,
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
                  Icon(
                    Icons.local_shipping_outlined,
                    size: AppConstants.metaIconSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppConstants.metaIconGap),
                  Text(
                    'Est. delivery: ${formatEstimatedDurationLabel(item.deliveryTime)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_money,
                    size: AppConstants.metaIconSize,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppConstants.metaIconGap),
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
        // AI Recommendation Reasoning button + display
        _MobileAiReasoningSection(groupIndex: groupIndex),
        if (group != null) ...[
          const SizedBox(height: AppConstants.spacingSm),
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
          _MobileRecommendationsGrid(groupIndex: groupIndex, group: group),
        ],
      ],
    );
  }
}

/// Section that shows a button to ask AI why the recommended item was chosen,
/// and displays the reasoning text once fetched (mobile layout).
class _MobileAiReasoningSection extends StatelessWidget {
  const _MobileAiReasoningSection({required this.groupIndex});
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

/// Column of 3 alternative recommendation tiles optimised for mobile screens.
/// Uses a vertical full-width layout for better readability and tap targets.
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
    final CartController controller = context.read<CartController>();
    final CartItem displayedMain =
        controller.getDisplayedMain(groupIndex) ?? group.main;
    final bool selectCheapest = _same(displayedMain, group.cheapest);
    final bool selectBest = _same(displayedMain, group.bestReviewed);
    final bool selectFastest = _same(displayedMain, group.fastest);

    return Column(
      children: [
        _MobileRecommendationTile(
          categoryKey: 'cheapest',
          label: 'Cheapest',
          item: group.cheapest,
          isSelected: selectCheapest,
          onTap: () =>
              controller.selectRecommendation(groupIndex, group.cheapest),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        _MobileRecommendationTile(
          categoryKey: 'best',
          label: 'Best reviewed',
          item: group.bestReviewed,
          isSelected: selectBest,
          onTap: () => controller.selectRecommendation(
            groupIndex,
            group.bestReviewed,
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        _MobileRecommendationTile(
          categoryKey: 'fastest',
          label: 'Fastest',
          item: group.fastest,
          isSelected: selectFastest,
          onTap: () =>
              controller.selectRecommendation(groupIndex, group.fastest),
        ),
      ],
    );
  }
}

/// Single full-width recommendation tile for mobile with category-specific
/// accent styling. Horizontal layout: icon badge | details | price.
class _MobileRecommendationTile extends StatelessWidget {
  const _MobileRecommendationTile({
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
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accent = categoryAccentColor(context, categoryKey);
    final Color bg = categorySoftTint(
      context,
      categoryKey,
      isSelected: isSelected,
    );
    final Color borderColor = isSelected
        ? accent
        : colorScheme.outlineVariant.withValues(alpha: 0.3);
    final double borderWidth = isSelected ? 1.5 : 0.5;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppConstants.durationFast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          padding: const EdgeInsets.all(AppConstants.spacingSm + 2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingSm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Icon(
                  iconForCategoryKey(categoryKey),
                  size: AppConstants.iconSizeXs,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: AppConstants.spacingXs),
                          Icon(
                            Icons.check_circle_rounded,
                            size: AppConstants.metaIconSize,
                            color: accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingXs / 2),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.reviewRating != null) ...[
                      const SizedBox(height: AppConstants.spacingXs / 2),
                      StarRatingDisplay(
                        rating: item.reviewRating!,
                        starSize: AppConstants.metaIconSize - 2,
                      ),
                    ],
                    const SizedBox(height: AppConstants.spacingXs / 2),
                    Row(
                      children: [
                        CartRetailerChip(text: item.retailer),
                        const SizedBox(width: AppConstants.spacingSm),
                        Icon(
                          Icons.local_shipping_outlined,
                          size: AppConstants.metaIconSize - 2,
                          color: categoryKey == 'fastest'
                              ? accent
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Text(
                          '~${formatEstimatedDurationLabel(item.deliveryTime)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: categoryKey == 'fastest'
                                ? accent
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                formatPrice(item.price),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: categoryKey == 'cheapest'
                      ? accent
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
