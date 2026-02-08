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
    this.width,
    this.height,
    this.contentScale = 1.0,
    this.depth = 0,
  });

  final String emoji;
  final String label;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final double contentScale;
  final int depth;

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
      duration: AppConstants.durationFast,
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
    final bool isCompact = widget.depth >= 1;
    final bool isChip = widget.depth >= 2;

    Color backgroundColor;
    Color borderColor;
    double borderWidth;
    Color textColor;

    if (widget.isDisabled && widget.isSelected) {
      backgroundColor = colorScheme.primaryContainer.withValues(alpha: 0.6);
      borderColor = colorScheme.primary.withValues(alpha: 0.5);
      borderWidth = isChip ? 1.0 : 2.0;
      textColor = colorScheme.onPrimaryContainer.withValues(alpha: 0.7);
    } else if (widget.isDisabled) {
      backgroundColor = colorScheme.surfaceContainerHigh.withValues(alpha: 0.5);
      borderColor = colorScheme.outlineVariant.withValues(alpha: 0.4);
      borderWidth = 1.0;
      textColor = colorScheme.onSurface.withValues(alpha: 0.38);
    } else if (widget.isSelected) {
      backgroundColor = colorScheme.primaryContainer;
      borderColor = colorScheme.primary;
      borderWidth = isChip ? 1.5 : 2.0;
      textColor = colorScheme.onPrimaryContainer;
    } else if (_isHovered) {
      backgroundColor = colorScheme.surfaceContainerHigh;
      borderColor = colorScheme.primary.withValues(alpha: 0.3);
      borderWidth = 1.5;
      textColor = colorScheme.onSurface;
    } else {
      backgroundColor = isCompact
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
          : colorScheme.surfaceContainerLow;
      borderColor = isCompact
          ? colorScheme.outlineVariant.withValues(alpha: 0.6)
          : colorScheme.outlineVariant;
      borderWidth = 1.0;
      textColor = colorScheme.onSurface;
    }

    final double radius = isChip
        ? AppConstants.radiusXs
        : (isCompact ? AppConstants.radiusSm : AppConstants.radiusMd);

    return MouseRegion(
      onEnter: widget.isDisabled
          ? null
          : (_) => setState(() => _isHovered = true),
      onExit: widget.isDisabled
          ? null
          : (_) => setState(() => _isHovered = false),
      cursor: widget.isDisabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: widget.isDisabled ? null : (_) => _scaleController.forward(),
        onTapUp: widget.isDisabled ? null : (_) => _scaleController.reverse(),
        onTapCancel: widget.isDisabled
            ? null
            : () => _scaleController.reverse(),
        onTap: widget.isDisabled ? null : widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: AppConstants.durationMedium,
            curve: Curves.easeOut,
            width: widget.width ?? AppConstants.categoryTileMinWidth,
            height: widget.height ?? AppConstants.categoryTileHeight,
            padding: EdgeInsets.symmetric(
              horizontal: isChip ? AppConstants.spacingXs : (isCompact ? AppConstants.spacingSm : AppConstants.spacingSm),
              vertical: isChip ? AppConstants.spacingXs : AppConstants.spacingXs,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: widget.isSelected && !widget.isDisabled && !isChip
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        blurRadius: AppConstants.elevationMd,
                        offset: const Offset(0, AppConstants.elevationSm),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isChip
                  ? _buildChipContent(theme, textColor)
                  : isCompact
                      ? _buildCompactContent(theme, textColor)
                      : _buildCardContent(theme, textColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(ThemeData theme, Color textColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.emoji,
          style: TextStyle(fontSize: AppConstants.categoryEmojiSizeLg * widget.contentScale),
        ),
        SizedBox(height: AppConstants.spacingXs * widget.contentScale),
        Text(
          widget.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColor,
            fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) *
                widget.contentScale,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCompactContent(ThemeData theme, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.emoji,
          style: TextStyle(fontSize: AppConstants.categoryEmojiSizeMd * widget.contentScale),
        ),
        SizedBox(width: AppConstants.spacingXs),
        Flexible(
          child: Text(
            widget.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) *
                  widget.contentScale,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildChipContent(ThemeData theme, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.emoji,
          style: TextStyle(fontSize: AppConstants.categoryEmojiSizeSm * widget.contentScale),
        ),
        SizedBox(width: AppConstants.spacingXs),
        Flexible(
          child: Text(
            widget.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: (theme.textTheme.labelMedium?.fontSize ?? 11) *
                  widget.contentScale,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
