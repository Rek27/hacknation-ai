import 'package:flutter/material.dart';

import 'package:frontend/config/app_constants.dart';

/// Visual states for a category tile.
enum CategoryTileState { unselected, hover, selected, disabled }

/// A single selectable category tile with emoji, label, and visual states.
class CategoryTile extends StatefulWidget {
  const CategoryTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  State<CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<CategoryTile>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color borderColor;
    double borderWidth;
    Color textColor;

    if (widget.isDisabled) {
      backgroundColor = colorScheme.surfaceContainerHigh.withValues(alpha: 0.5);
      borderColor = colorScheme.outlineVariant.withValues(alpha: 0.4);
      borderWidth = 1.0;
      textColor = colorScheme.onSurface.withValues(alpha: 0.38);
    } else if (widget.isSelected) {
      backgroundColor = colorScheme.primaryContainer;
      borderColor = colorScheme.primary;
      borderWidth = 2.0;
      textColor = colorScheme.onPrimaryContainer;
    } else if (_isHovered) {
      backgroundColor = colorScheme.surfaceContainerHigh;
      borderColor = colorScheme.primary.withValues(alpha: 0.3);
      borderWidth = 1.5;
      textColor = colorScheme.onSurface;
    } else {
      backgroundColor = colorScheme.surfaceContainerLow;
      borderColor = colorScheme.outlineVariant;
      borderWidth = 1.0;
      textColor = colorScheme.onSurface;
    }

    return MouseRegion(
      onEnter: widget.isDisabled ? null : (_) => setState(() => _isHovered = true),
      onExit: widget.isDisabled ? null : (_) => setState(() => _isHovered = false),
      cursor: widget.isDisabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: widget.isDisabled ? null : (_) => _scaleController.forward(),
        onTapUp: widget.isDisabled ? null : (_) => _scaleController.reverse(),
        onTapCancel: widget.isDisabled ? null : () => _scaleController.reverse(),
        onTap: widget.isDisabled ? null : widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: AppConstants.categoryTileMinWidth,
            height: AppConstants.categoryTileHeight,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: widget.isSelected && !widget.isDisabled
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  widget.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
