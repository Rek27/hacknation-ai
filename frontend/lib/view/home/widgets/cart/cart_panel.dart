import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_widget.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_controller.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:provider/provider.dart';
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
                          _formatPrice(controller.totalPrice),
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
                        onRetry: () => controller.loadDummyData(),
                      )
                    : controller.showSummary
                    ? const _CartSummaryPanel()
                    : controller.isEmpty
                    ? Center(
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
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                          top: AppConstants.spacingMd,
                          bottom: 104, // space for bottom bar height
                        ),
                        itemCount: controller.items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppConstants.spacingMd),
                        itemBuilder: (context, index) {
                          final CartItem item = controller.items[index];
                          final expanded = controller.isExpandedGroup(index);
                          return ChangeNotifierProvider<CartItemController>(
                            create: (_) => CartItemController(item: item),
                            child: CartItemWidget(
                              groupIndex: index,
                              item: item,
                              isExpanded: expanded,
                              onToggle: () =>
                                  controller.toggleExpandedGroup(index),
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
            !controller.showSummary)
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
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.3,
                      ),
                      width: 1,
                    ),
                  ),
                ),
                child: _CheckoutBar(
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

/// Fixed bottom checkout bar with confirm CTA and helper text.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.totalPrice,
    required this.retailerCount,
    required this.onCheckout,
  });

  final double totalPrice;
  final int retailerCount;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                  'Checkout All — ${_formatPrice(totalPrice)}',
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
      padding: const EdgeInsets.only(top: AppConstants.spacingMd, bottom: 104),
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
                  _SummaryImagePlaceholder(
                    size: 75,
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
                                color: _categoryBgForKey(context, categoryKey),
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
                                _labelForKey(categoryKey),
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
                              _formatPrice(item.price),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingSm),
                            _SummaryRetailerChip(text: item.retailer),
                          ],
                        ),
                        const SizedBox(height: AppConstants.spacingXs),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              _formatSummaryEstimatedDateFromNow(
                                item.deliveryTime,
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: AppConstants.spacingMd),
                            const Icon(Icons.shopping_bag_outlined, size: 14),
                            const SizedBox(width: 6),
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
                      onPressed: () {
                        // no-op for now
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Order placed (mock).')),
                        );
                      },
                      child: Text(
                        'Place order — ${_formatPrice(controller.totalPrice)}',
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

  String _labelForKey(String key) {
    switch (key) {
      case 'cheapest':
        return 'Cheapest';
      case 'best':
        return 'Best reviewed';
      case 'fastest':
        return 'Fastest';
      case 'main':
      default:
        return 'Main';
    }
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

class _SummaryImagePlaceholder extends StatelessWidget {
  const _SummaryImagePlaceholder({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: Container(
        width: size,
        height: size,
        color: color,
        child: const Icon(Icons.image, size: AppConstants.iconSizeSm),
      ),
    );
  }
}

class _SummaryRetailerChip extends StatelessWidget {
  const _SummaryRetailerChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingSm,
        vertical: AppConstants.spacingXs,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}

String _formatSummaryEstimatedDateFromNow(Duration d) {
  final date = DateTime.now().add(d);
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
  return '${months[date.month - 1]} ${date.day}';
}

/// Returns the same category background colors used in cart_item_widget.dart
Color _categoryBgForKey(BuildContext context, String key) {
  final cs = Theme.of(context).colorScheme;
  switch (key) {
    case 'cheapest':
      return cs.primaryFixed.withValues(alpha: 0.10);
    case 'best':
      return cs.primaryFixedDim.withValues(alpha: 0.15);
    case 'fastest':
      return cs.onPrimaryFixedVariant.withValues(alpha: 0.15);
    case 'main':
    default:
      return cs.primary.withValues(alpha: 0.10);
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
