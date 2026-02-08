import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_utils.dart';
import 'package:frontend/view/home/widgets/cart/cart_shared_widgets.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_mobile_widget.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_controller.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:frontend/view/home/widgets/cart/cart_loading_list.dart';
import 'package:frontend/view/home/widgets/cart/cart_error_widget.dart';

/// Mobile-optimised read-only cart panel with a two-line header and compact
/// item cards. Checkout is handled by the agent, not manually.
class CartMobilePanel extends StatelessWidget {
  const CartMobilePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final CartController controller = Provider.of<CartController>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header section ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingMd,
            AppConstants.spacingMd,
            AppConstants.spacingMd,
            AppConstants.spacingMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: icon + title + count chip
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: AppConstants.iconSizeSm,
                      color: colorScheme.onSurface,
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Flexible(
                      child: Text(
                        'Smart Cart',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!controller.isLoading) ...[
                      const SizedBox(width: AppConstants.spacingSm),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusFull,
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
                  ],
                ),
              ),
              // Right: estimated total + price (same baseline as left)
              if (!controller.isLoading)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Estimated total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Text(
                      formatPrice(controller.totalPrice),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // ── Content ───────────────────────────────────────────────────
        Expanded(
          child: controller.isLoading
              ? const CartLoadingList()
              : (controller.errorMessage != null)
                  ? CartErrorWidget(
                      title: 'Something went wrong',
                      subtitle: controller.errorMessage!,
                      onRetry: () => controller.clearError(),
                    )
                  : controller.isEmpty
                      ? const CartEmptyState()
                      : ListView.separated(
                          padding: EdgeInsets.only(
                            top: AppConstants.spacingMd,
                            left: AppConstants.spacingMd,
                            right: AppConstants.spacingMd,
                            bottom: controller.items.isNotEmpty
                                ? AppConstants.bottomBarHeight
                                : AppConstants.spacingMd,
                          ),
                          itemCount: controller.items.length,
                          separatorBuilder:
                              (BuildContext context, int index) =>
                                  const SizedBox(
                                      height: AppConstants.spacingSm),
                          itemBuilder:
                              (BuildContext context, int index) {
                            final CartItem item =
                                controller.items[index];
                            final String key = item.id ?? item.name;
                            final bool expanded =
                                controller.isExpandedGroup(index);
                            return Slidable(
                              key: ValueKey<String>(key),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio:
                                    AppConstants.cartActionExtentRatio,
                                dismissible: DismissiblePane(
                                  onDismissed: () =>
                                      controller.deleteItem(key),
                                ),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) =>
                                        controller.deleteItem(key),
                                    backgroundColor:
                                        AppConstants.cartDeleteColor,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete_outline,
                                    label: 'Delete',
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(
                                        AppConstants.radiusLg,
                                      ),
                                      bottomRight: Radius.circular(
                                        AppConstants.radiusLg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              child: ChangeNotifierProvider<
                                  CartItemController>(
                                create: (_) =>
                                    CartItemController(item: item),
                                child: CartItemMobileWidget(
                                  groupIndex: index,
                                  item: item,
                                  isExpanded: expanded,
                                  onToggle: () => controller
                                      .toggleExpandedGroup(index),
                                ),
                              ),
                            );
                          },
                        ),
        ),
        // ── Checkout bar ──────────────────────────────────────────────
        if (!controller.isLoading &&
            controller.errorMessage == null &&
            !controller.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingLg,
              AppConstants.spacingMd,
              AppConstants.spacingMd,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            ),
            child: SafeArea(
              top: false,
              child: CartCheckoutBar(
                totalPrice: controller.totalPrice,
                retailerCount: controller.retailerCount,
                onCheckout: () => controller.startCheckout(),
              ),
            ),
          ),
      ],
    );
  }
}
