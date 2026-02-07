import 'package:flutter/material.dart';
import 'package:frontend/view/home/widgets/cart/cart_controller.dart';
import 'package:provider/provider.dart';
import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/home_controller.dart';
import 'package:frontend/view/home/widgets/chat_area.dart';
import 'package:frontend/view/home/widgets/cart/cart_view.dart';

/// Desktop/web layout: chat area and cart view in a Row.
class HomeDesktopLayout extends StatelessWidget {
  const HomeDesktopLayout({
    super.key,
    required this.scrollController,
    required this.inputController,
  });

  final ScrollController scrollController;
  final TextEditingController inputController;

  @override
  Widget build(BuildContext context) {
    final HomeController controller = context.watch<HomeController>();
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (controller.errorMessage != null)
          _ErrorBanner(message: controller.errorMessage!),
        Expanded(
          child: Row(
            children: [
              // Chat area takes 1/3 of the remaining width.
              Expanded(
                flex: 1,
                child: ChatArea(
                  scrollController: scrollController,
                  inputController: inputController,
                ),
              ),
              // Cart view takes 2/3 of the remaining width.
              Expanded(
                flex: 2,
                child: ChangeNotifierProvider<CartController>(
                  create: (_) => CartController(),
                  child: CartView(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingSm,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
