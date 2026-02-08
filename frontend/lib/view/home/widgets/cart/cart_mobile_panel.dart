import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:frontend/view/home/widgets/cart/cart_utils.dart';
import 'package:frontend/view/home/widgets/cart/cart_shared_widgets.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_mobile_widget.dart';
import 'package:frontend/view/home/widgets/cart_item/cart_item_controller.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:provider/provider.dart';
import 'package:frontend/view/home/widgets/cart/cart_loading_list.dart';
import 'package:frontend/view/home/widgets/cart/cart_error_widget.dart';

/// Mobile-optimised cart panel with a two-line header, compact item cards,
/// and a vertically stacked checkout summary form.
class CartMobilePanel extends StatelessWidget {
  const CartMobilePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final CartController controller = Provider.of<CartController>(context);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingSm,
            vertical: AppConstants.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line 1: icon + title + count chip
              Row(
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    size: AppConstants.iconSizeSm,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Text(
                    'Smart Cart',
                    style: theme.textTheme.titleMedium?.copyWith(
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
              // Line 2: estimated total, right-aligned
              if (!controller.isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: AppConstants.spacingXs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Estimated total  ',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatPrice(controller.totalPrice),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppConstants.spacingSm),
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
                            ? const _CartMobileSummaryPanel()
                            : controller.isEmpty
                                ? const CartEmptyState()
                                : ListView.separated(
                                    padding: const EdgeInsets.only(
                                      top: AppConstants.spacingSm,
                                      bottom: 96,
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
                                      final bool expanded =
                                          controller.isExpandedGroup(index);
                                      return ChangeNotifierProvider<
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
                                      );
                                    },
                                  ),
              ),
            ],
          ),
        ),
        // Fixed bottom checkout bar
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
                  vertical: AppConstants.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
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

/// Mobile checkout summary with vertically stacked form fields and buttons.
class _CartMobileSummaryPanel extends StatefulWidget {
  const _CartMobileSummaryPanel();

  @override
  State<_CartMobileSummaryPanel> createState() =>
      _CartMobileSummaryPanelState();
}

class _CartMobileSummaryPanelState extends State<_CartMobileSummaryPanel> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _payment = 'card';

  final TextEditingController _nameController =
      TextEditingController(text: '');
  final TextEditingController _streetController =
      TextEditingController(text: 'Alexanderplatz');
  final TextEditingController _streetNumberController =
      TextEditingController(text: '1');
  final TextEditingController _zipController =
      TextEditingController(text: '10178');
  final TextEditingController _cityController =
      TextEditingController(text: 'Berlin');
  final TextEditingController _countryController =
      TextEditingController(text: 'Germany');
  final TextEditingController _cardHolderController =
      TextEditingController(text: '');
  final TextEditingController _cardNumberController =
      TextEditingController(text: '');
  final TextEditingController _cardExpiryController =
      TextEditingController(text: '');
  final TextEditingController _cardCvvController =
      TextEditingController(text: '');

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
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final CartController controller = context.watch<CartController>();
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spacingSm,
        bottom: AppConstants.spacingLg,
      ),
      child: ListView(
        children: [
          // Back row + title stacked vertically
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => controller.cancelCheckout(),
                tooltip: 'Back to cart',
                style: IconButton.styleFrom(
                  side: BorderSide(color: cs.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusSm),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Expanded(
                child: Text(
                  'Checkout summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          const Divider(),
          const SizedBox(height: AppConstants.spacingSm),

          // Item cards (compact for mobile)
          ...List.generate(controller.items.length, (int index) {
            final CartItem item = controller.items[index];
            final String categoryKey =
                controller.displayedCategoryKey(index);
            return Container(
              margin:
                  const EdgeInsets.only(bottom: AppConstants.spacingSm),
              padding: const EdgeInsets.all(AppConstants.spacingSm),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CartImagePlaceholder(
                    size: 56,
                    color: cs.surfaceContainerHighest,
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingXs),
                            Container(
                              decoration: BoxDecoration(
                                color: categoryBgForKey(
                                    context, categoryKey),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusSm,
                                ),
                                border: Border.all(
                                  color: cs.outlineVariant,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.spacingXs,
                                vertical: AppConstants.spacingXs,
                              ),
                              child: Text(
                                labelForCategoryKey(categoryKey),
                                style:
                                    theme.textTheme.labelSmall?.copyWith(
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
                              style:
                                  theme.textTheme.titleSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: AppConstants.spacingSm),
                            CartRetailerChip(text: item.retailer),
                          ],
                        ),
                        const SizedBox(height: AppConstants.spacingXs),
                        Wrap(
                          spacing: AppConstants.spacingMd,
                          runSpacing: AppConstants.spacingXs,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  formatEstimatedDateFromNow(
                                      item.deliveryTime),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Qty: ${item.amount}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
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

          const SizedBox(height: AppConstants.spacingMd),
          Text('Buyer details', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppConstants.spacingSm),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Full name', context),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                // Street + Number
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _streetController,
                        decoration:
                            _inputDecoration('Street', context),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _streetNumberController,
                        decoration:
                            _inputDecoration('No.', context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                // ZIP + City
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _zipController,
                        decoration:
                            _inputDecoration('ZIP', context),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cityController,
                        decoration:
                            _inputDecoration('City', context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingSm),
                // Country full width
                TextFormField(
                  controller: _countryController,
                  decoration: _inputDecoration('Country', context),
                ),
                const SizedBox(height: AppConstants.spacingLg),
                Text('Payment method',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppConstants.spacingSm),
                _buildPaymentOption('card', 'Credit card'),
                _buildPaymentOption('apple', 'Apple Pay'),
                _buildPaymentOption('paypal', 'PayPal'),
                if (_payment == 'card') ...[
                  const SizedBox(height: AppConstants.spacingMd),
                  TextFormField(
                    controller: _cardHolderController,
                    textCapitalization: TextCapitalization.characters,
                    decoration:
                        _inputDecoration('Card holder', context),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  TextFormField(
                    controller: _cardNumberController,
                    decoration:
                        _inputDecoration('Card number', context),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cardExpiryController,
                          decoration:
                              _inputDecoration('MM/YY', context),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      Expanded(
                        child: TextFormField(
                          controller: _cardCvvController,
                          decoration:
                              _inputDecoration('CVV', context),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppConstants.spacingLg),
                // Full-width stacked buttons
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding:
                          const EdgeInsets.all(AppConstants.spacingMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Order placed (mock).')),
                      );
                    },
                    child: Text(
                      'Place order — ${formatPrice(controller.totalPrice)}',
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingSm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.all(AppConstants.spacingMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppConstants.radiusSm),
                      ),
                      side: BorderSide(color: cs.primary),
                    ),
                    onPressed: () => controller.cancelCheckout(),
                    child: const Text('Back to cart'),
                  ),
                ),
                const SizedBox(height: AppConstants.spacingLg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label) {
    final ThemeData theme = Theme.of(context);
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      groupValue: _payment,
      onChanged: (String? v) => setState(() => _payment = v ?? 'card'),
      title: Text(label, style: theme.textTheme.bodyMedium),
    );
  }

  InputDecoration _inputDecoration(String label, BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
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
