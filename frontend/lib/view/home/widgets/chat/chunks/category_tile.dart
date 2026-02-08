import 'package:flutter/material.dart';

import 'package:frontend/config/app_constants.dart';

/// A depth-aware pill-shaped category selector.
///
/// Renders as a capsule at every depth level with sizing and text style
/// determined by [depth] (0 = top-level, 1 = subcategory, 2 = leaf).
/// Provides smooth colour transitions on selection and subtle scale
/// feedback on press.
class CategoryPill extends StatefulWidget {
  const CategoryPill({
    super.key,
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
    this.depth = 0,
  });

  final String emoji;
  final String label;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;
  final int depth;

  @override
  State<CategoryPill> createState() => _CategoryPillState();
}

class _CategoryPillState extends State<CategoryPill>
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
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: AppConstants.treePillPressScale).animate(
          CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  // ── Depth-dependent style helpers ────────────────────────────────────

  EdgeInsets _paddingForDepth() {
    switch (widget.depth) {
      case 0:
        return AppConstants.treePillPaddingL0;
      case 1:
        return AppConstants.treePillPaddingL1;
      default:
        return AppConstants.treePillPaddingL2;
    }
  }

  double _emojiSizeForDepth() {
    switch (widget.depth) {
      case 0:
        return AppConstants.treePillEmojiSizeL0;
      case 1:
        return AppConstants.treePillEmojiSizeL1;
      default:
        return AppConstants.treePillEmojiSizeL2;
    }
  }

  TextStyle? _textStyleForDepth(ThemeData theme) {
    switch (widget.depth) {
      case 0:
        return theme.textTheme.bodyMedium;
      case 1:
        return theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500);
      default:
        return theme.textTheme.labelSmall;
    }
  }

  // ── Colour resolution ────────────────────────────────────────────────

  _PillColors _resolveColors(ColorScheme colorScheme) {
    if (widget.isDisabled && widget.isSelected) {
      return _PillColors(
        background: colorScheme.primaryContainer.withValues(alpha: 0.55),
        border: colorScheme.primary.withValues(alpha: 0.4),
        text: colorScheme.onPrimaryContainer.withValues(alpha: 0.65),
        borderWidth: 1.0,
      );
    }
    if (widget.isDisabled) {
      return _PillColors(
        background: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
        border: colorScheme.outlineVariant.withValues(alpha: 0.3),
        text: colorScheme.onSurface.withValues(alpha: 0.35),
        borderWidth: 0.5,
      );
    }
    if (widget.isSelected) {
      return _PillColors(
        background: colorScheme.primaryContainer,
        border: colorScheme.primary,
        text: colorScheme.onPrimaryContainer,
        borderWidth: 1.5,
      );
    }
    if (_isHovered) {
      return _PillColors(
        background: colorScheme.surfaceContainerHigh,
        border: colorScheme.primary.withValues(alpha: 0.25),
        text: colorScheme.onSurface,
        borderWidth: 0.5,
      );
    }
    return _PillColors(
      background: colorScheme.surfaceContainerLow,
      border: colorScheme.outlineVariant,
      text: colorScheme.onSurface,
      borderWidth: 0.5,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final _PillColors colors = _resolveColors(colorScheme);
    final EdgeInsets padding = _paddingForDepth();
    final double emojiSize = _emojiSizeForDepth();
    final TextStyle? textStyle = _textStyleForDepth(theme);
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
            padding: padding,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(
                color: colors.border,
                width: colors.borderWidth,
              ),
              boxShadow: widget.isSelected && !widget.isDisabled
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        blurRadius: AppConstants.elevationMd,
                        offset: const Offset(0, AppConstants.elevationSm),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.emoji, style: TextStyle(fontSize: emojiSize)),
                SizedBox(
                  width: widget.depth >= 2
                      ? AppConstants.spacingXs
                      : AppConstants.spacingSm,
                ),
                Flexible(
                  child: Text(
                    widget.label,
                    style: textStyle?.copyWith(
                      color: colors.text,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : textStyle.fontWeight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Resolved colour set for a pill in a given visual state.
class _PillColors {
  const _PillColors({
    required this.background,
    required this.border,
    required this.text,
    required this.borderWidth,
  });

  final Color background;
  final Color border;
  final Color text;
  final double borderWidth;
}
