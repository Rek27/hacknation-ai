import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';

/// A vertical divider that can be dragged to resize adjacent panels.
/// Shows a subtle grip indicator on hover to signal draggability.
class ResizableDivider extends StatefulWidget {
  const ResizableDivider({super.key, required this.onDragUpdate});

  final ValueChanged<double> onDragUpdate;

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  bool get _isActive => _isHovered || _isDragging;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          widget.onDragUpdate(details.delta.dx);
        },
        onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
        onHorizontalDragCancel: () => setState(() => _isDragging = false),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: AppConstants.resizeDividerHitWidth,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vertical line
              AnimatedContainer(
                duration: AppConstants.durationFast,
                width: _isActive ? AppConstants.resizeDividerActiveWidth : 1.0,
                decoration: BoxDecoration(
                  color: _isActive
                      ? colorScheme.primary.withValues(alpha: 0.4)
                      : colorScheme.outlineVariant,
                  borderRadius: _isActive
                      ? BorderRadius.circular(AppConstants.radiusFull)
                      : null,
                ),
              ),
              // Grip indicator
              AnimatedOpacity(
                duration: AppConstants.durationFast,
                opacity: _isActive ? 1.0 : 0.0,
                child: _GripIndicator(colorScheme: colorScheme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill-shaped grip indicator shown at the center of the divider.
class _GripIndicator extends StatelessWidget {
  const _GripIndicator({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppConstants.resizeDividerIndicatorWidth,
      height: AppConstants.resizeDividerIndicatorHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: AppConstants.elevationSm,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(3, (int index) {
          return Padding(
            padding: EdgeInsets.only(
              top: index > 0 ? AppConstants.spacingXs / 2 : 0.0,
            ),
            child: Container(
              width: AppConstants.resizeDividerHitWidth,
              height: 1.5,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(1.0),
              ),
            ),
          );
        }),
      ),
    );
  }
}
