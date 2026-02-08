import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';

/// Centered, reusable error view with icon, title, subtitle and retry.
class CartErrorWidget extends StatelessWidget {
  const CartErrorWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppConstants.errorIconSize,
            height: AppConstants.errorIconSize,
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Icon(
              Icons.error_outline,
              color: cs.onErrorContainer,
              size: AppConstants.iconSizeMd,
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          if (onRetry != null)
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.primary, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
              ),
              child: const Text('Try again'),
            ),
        ],
      ),
    );
  }
}
