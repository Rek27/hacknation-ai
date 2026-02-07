import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/view/home/home_controller.dart';
import 'package:frontend/view/home/widgets/chat_area.dart';
import 'package:frontend/view/home/widgets/documents_sidebar_content.dart';

/// Desktop/web layout: persistent sidebar + chat area in a Row.
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      children: [
        if (controller.errorMessage != null) _ErrorBanner(message: controller.errorMessage!),
        Expanded(
          child: Row(
            children: [
              Container(
                width: AppConstants.sidebarWidthDesktop,
                color: colorScheme.surfaceContainerHighest,
                child: const DocumentsSidebarContent(),
              ),
              Expanded(
                child: ChatArea(
                  scrollController: scrollController,
                  inputController: inputController,
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
