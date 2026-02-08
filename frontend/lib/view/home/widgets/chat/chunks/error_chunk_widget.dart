import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';

/// Renders an error output with a retry button.
class ErrorChunkWidget extends StatelessWidget {
  const ErrorChunkWidget({super.key, required this.error});

  final ErrorOutput error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: AppConstants.iconSizeSm,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Flexible(
            child: Text(
              error.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spacingMd),
          TextButton.icon(
            onPressed: () {
              context.read<ChatController>().retryLastMessage();
            },
            icon: Icon(
              Icons.refresh_rounded,
              size: AppConstants.iconSizeXs,
              color: colorScheme.onErrorContainer,
            ),
            label: Text(
              'Retry',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
