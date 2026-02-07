import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';

class SelectableWidget extends StatelessWidget {
  const SelectableWidget({
    super.key,
    required this.onSelect,
    required this.isSelected,
    required this.text,
    required this.icon,
  });

  final Function() onSelect;
  final bool isSelected;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.5)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: colorScheme.primary.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppConstants.spacingSm,
            children: [
              Icon(icon, color: colorScheme.onSurface),
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
