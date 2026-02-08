import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_utils.dart';
import 'package:frontend/view/home/widgets/cart/cart_shared_widgets.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_widget.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_controller.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
                          formatPrice(controller.totalPrice),
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
                        onRetry: () => controller.clearError(),
                      )
                    : controller.phase == CheckoutPhase.ordering
                    ? const _RetailerOrderingScreen()
                    : controller.phase == CheckoutPhase.complete
                    ? const _OrderCompleteSummary()
                    : controller.showSummary
                    ? const _CartSummaryPanel()
                    : controller.isEmpty
                    ? const CartEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                          top: AppConstants.spacingMd,
                          bottom: AppConstants.bottomBarHeight,
                        ),
                        itemCount: controller.items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppConstants.spacingMd),
                        itemBuilder: (context, index) {
                          final CartItem item = controller.items[index];
                          final String key = item.id ?? item.name;
                          final expanded = controller.isExpandedGroup(index);
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
                                      AppConstants.radiusMd,
                                    ),
                                    bottomRight: Radius.circular(
                                      AppConstants.radiusMd,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            child:
                                ChangeNotifierProvider<CartItemController>(
                              create: (_) =>
                                  CartItemController(item: item),
                              child: CartItemWidget(
                                groupIndex: index,
                                item: item,
                                isExpanded: expanded,
                                onToggle: () =>
                                    controller.toggleExpandedGroup(index),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        // Edge-to-edge fixed bottom confirm bar (outside page padding)
        if (!controller.isLoading &&
            controller.errorMessage == null &&
            controller.phase == CheckoutPhase.cart &&
            !controller.isEmpty)
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
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: CartCheckoutBar(
                  totalPrice: controller.totalPrice,
                  retailerCount: controller.retailerCount,
                  onCheckout: () => controller.startCheckout(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CartSummaryPanel extends StatefulWidget {
  const _CartSummaryPanel();
  @override
  State<_CartSummaryPanel> createState() => _CartSummaryPanelState();
}

class _CartSummaryPanelState extends State<_CartSummaryPanel> {
  final _formKey = GlobalKey<FormState>();
  String _payment = 'card';

  // Mock prefilled address/name
  final _nameController = TextEditingController(text: '');
  final _streetController = TextEditingController(text: 'Alexanderplatz');
  final _streetNumberController = TextEditingController(text: '1');
  final _zipController = TextEditingController(text: '10178');
  final _cityController = TextEditingController(text: 'Berlin');
  final _countryController = TextEditingController(text: 'Germany');
  final _cardHolderController = TextEditingController(text: '');
  final _cardNumberController = TextEditingController(text: '');
  final _cardExpiryController = TextEditingController(text: '');
  final _cardCvvController = TextEditingController(text: '');

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _streetNumberController.dispose();
    _zipController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final controller = context.watch<CartController>();
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spacingMd,
        bottom: AppConstants.bottomBarHeight,
      ),
      child: ListView(
        children: [
          // Header with back
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(AppConstants.spacingLg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  side: BorderSide(color: cs.primary),
                ),
                onPressed: () => controller.cancelCheckout(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to cart'),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              Text(
                'Checkout summary',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          const Divider(),
          const SizedBox(height: AppConstants.spacingMd),

          // Items selected
          ...List.generate(controller.items.length, (index) {
            final item = controller.items[index];
            final categoryKey = controller.displayedCategoryKey(index);
            return Container(
              margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CartImagePlaceholder(
                    size: AppConstants.cartSummaryImageSize,
                    color: cs.surfaceContainerHighest,
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingSm),
                            Container(
                              decoration: BoxDecoration(
                                color: categoryBgForKey(context, categoryKey),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusSm,
                                ),
                                border: Border.all(
                                  color: cs.outlineVariant,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingSm,
                                vertical: AppConstants.spacingXs,
                              ),
                              child: Text(
                                labelForCategoryKey(categoryKey),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.spacingXs),
                        Row(
                          children: [
                            Text(
                              formatPrice(item.price),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.primary,
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
                              size: AppConstants.metaIconSize,
                            ),
                            const SizedBox(width: AppConstants.metaIconGap),
                            Text(
                              formatEstimatedDateFromNow(item.deliveryTime),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: AppConstants.spacingMd),
                            const Icon(
                              Icons.shopping_bag_outlined,
                              size: AppConstants.metaIconSize,
                            ),
                            const SizedBox(width: AppConstants.metaIconGap),
                            Text(
                              'Qty: ${item.amount}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: AppConstants.spacingLg),
          Text('Buyer details', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppConstants.spacingMd),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Full name', context),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _streetController,
                        decoration: _inputDecoration('Street', context),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _streetNumberController,
                        decoration: _inputDecoration('No.', context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _zipController,
                        decoration: _inputDecoration('ZIP', context),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: _inputDecoration('City', context),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _countryController,
                        decoration: _inputDecoration('Country', context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXl),
                Text('Payment method', style: theme.textTheme.titleMedium),
                const SizedBox(height: AppConstants.spacingSm),
                _paymentOption('card', 'Credit card'),
                _paymentOption('apple', 'Apple Pay'),
                _paymentOption('paypal', 'PayPal'),
                if (_payment == 'card') ...[
                  const SizedBox(height: AppConstants.spacingLg),
                  TextFormField(
                    controller: _cardHolderController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _inputDecoration('Card holder', context),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  TextFormField(
                    controller: _cardNumberController,
                    decoration: _inputDecoration('Card number', context),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cardExpiryController,
                          decoration: _inputDecoration('MM/YY', context),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: TextFormField(
                          controller: _cardCvvController,
                          decoration: _inputDecoration('CVV', context),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppConstants.spacingXl),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(AppConstants.spacingLg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm,
                          ),
                        ),
                        side: BorderSide(color: cs.primary),
                      ),
                      onPressed: () => controller.cancelCheckout(),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(AppConstants.spacingLg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm,
                          ),
                        ),
                      ),
                      onPressed: () => controller.placeOrder(),
                      child: Text(
                        'Place order — ${formatPrice(controller.totalPrice)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentOption(String value, String label) {
    final theme = Theme.of(context);
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      groupValue: _payment,
      onChanged: (v) => setState(() => _payment = v ?? 'card'),
      title: Text(label, style: theme.textTheme.bodyMedium),
    );
  }

  InputDecoration _inputDecoration(String label, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        borderSide: BorderSide(color: cs.primary),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingMd,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Retailer ordering animation screen
// ---------------------------------------------------------------------------

/// Mock retailer logo colours (deterministic per retailer name).
Color _retailerColor(String name) {
  final colors = [
    const Color(0xFF1565C0), // blue
    const Color(0xFFE65100), // orange
    const Color(0xFF2E7D32), // green
    const Color(0xFF6A1B9A), // purple
    const Color(0xFFC62828), // red
    const Color(0xFF00838F), // teal
    const Color(0xFF4E342E), // brown
    const Color(0xFF283593), // indigo
  ];
  return colors[name.hashCode.abs() % colors.length];
}

/// First two letters of the retailer name, used as a mock logo.
String _retailerInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.length <= 2) return trimmed.toUpperCase();
  return trimmed.substring(0, 2).toUpperCase();
}

class _RetailerOrderingScreen extends StatelessWidget {
  const _RetailerOrderingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final controller = context.watch<CartController>();
    final retailers = controller.uniqueRetailers;
    final confirmed = controller.confirmedRetailers;
    final allDone = confirmed.length == retailers.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingMd),
      child: Column(
        children: [
          // Title
          Icon(
            allDone ? Icons.check_circle_rounded : Icons.sync_rounded,
            size: AppConstants.iconSizeMd,
            color: allDone ? const Color(0xFF34C759) : cs.primary,
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Text(
            allDone ? 'All orders placed!' : 'Placing orders...',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            allDone
                ? 'Every retailer has confirmed your order.'
                : 'Contacting ${retailers.length} retailers. This won\'t take long.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingXl),
          // Retailer grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(
                bottom: AppConstants.spacingXl,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: AppConstants.spacingMd,
                crossAxisSpacing: AppConstants.spacingMd,
                childAspectRatio: 1.0,
              ),
              itemCount: retailers.length,
              itemBuilder: (context, index) {
                final name = retailers[index];
                final done = confirmed.contains(name);
                return _RetailerCard(name: name, confirmed: done);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RetailerCard extends StatelessWidget {
  const _RetailerCard({required this.name, required this.confirmed});
  final String name;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _retailerColor(name);

    return AnimatedContainer(
      duration: AppConstants.durationSlow,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: confirmed ? const Color(0xFF34C759) : cs.outlineVariant,
          width: confirmed ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Main content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mock logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _retailerInitials(name),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Text(
                  name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppConstants.spacingXs),
                // Status indicator
                AnimatedSwitcher(
                  duration: AppConstants.durationMedium,
                  child: confirmed
                      ? Row(
                          key: const ValueKey('done'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Color(0xFF34C759),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Confirmed',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF34C759),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          key: const ValueKey('loading'),
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Overlay green checkmark badge (top-right)
          if (confirmed)
            Positioned(
              top: AppConstants.spacingSm,
              right: AppConstants.spacingSm,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 18, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order complete summary
// ---------------------------------------------------------------------------

class _OrderCompleteSummary extends StatelessWidget {
  const _OrderCompleteSummary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final controller = context.watch<CartController>();
    final items = controller.items;
    final retailers = controller.uniqueRetailers;

    // Group items by retailer
    final Map<String, List<CartItem>> byRetailer = {};
    for (final item in items) {
      byRetailer.putIfAbsent(item.retailer, () => []).add(item);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingMd),
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppConstants.spacingXl),
        children: [
          // Success header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingMd),
                Text(
                  'Order confirmed!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                Text(
                  '${items.length} items from ${retailers.length} retailers',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingXl),
          const Divider(),
          const SizedBox(height: AppConstants.spacingMd),

          // Per-retailer breakdown
          ...byRetailer.entries.expand((entry) {
            final retailer = entry.key;
            final retailerItems = entry.value;
            final retailerTotal = retailerItems.fold<double>(
              0.0,
              (sum, it) => sum + it.price * it.amount,
            );
            return [
              // Retailer header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _retailerColor(retailer).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSm,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _retailerInitials(retailer),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _retailerColor(retailer),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Text(
                      retailer,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    formatPrice(retailerTotal),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingSm),
              // Items under this retailer
              ...retailerItems.map((item) => Padding(
                padding: const EdgeInsets.only(
                  left: AppConstants.spacingXl + AppConstants.spacingSm,
                  bottom: AppConstants.spacingSm,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Color(0xFF34C759),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      child: Text(
                        '${item.name} x${item.amount}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatPrice(item.price * item.amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: AppConstants.spacingSm),
              const Divider(),
              const SizedBox(height: AppConstants.spacingMd),
            ];
          }),

          // Grand total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              Text(
                formatPrice(controller.totalPrice),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXl),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(AppConstants.spacingMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSm,
                      ),
                    ),
                    side: BorderSide(color: cs.primary),
                  ),
                  onPressed: () => controller.resetToCart(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to cart'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
