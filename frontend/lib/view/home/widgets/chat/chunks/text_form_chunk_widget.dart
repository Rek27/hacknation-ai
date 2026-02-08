import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';

/// Renders the TextFormChunk as an Apple-inspired grouped form.
/// Supports pinned, history, and disabled modes.
///
/// On first mount the form builds up field-by-field with a sequential
/// fade + slide entrance animation.
class TextFormChunkWidget extends StatefulWidget {
  const TextFormChunkWidget({
    super.key,
    required this.chunk,
    required this.messageId,
    required this.isDisabled,
    required this.isPinned,
  });

  final TextFormChunk chunk;
  final String messageId;
  final bool isDisabled;
  final bool isPinned;

  @override
  State<TextFormChunkWidget> createState() => _TextFormChunkWidgetState();
}

class _TextFormChunkWidgetState extends State<TextFormChunkWidget>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _addressController;
  late final TextEditingController _budgetController;
  late final TextEditingController _dateController;
  late final TextEditingController _durationController;
  late final TextEditingController _attendeesController;

  late final AnimationController _entranceController;

  /// Animated items: header, address, budget+date row, duration+attendees row,
  /// and (when not disabled) the action button.
  int get _totalItems => widget.isDisabled ? 4 : 5;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.chunk.address.content ?? '',
    );
    _budgetController = TextEditingController(
      text: widget.chunk.budget.content ?? '',
    );
    _dateController = TextEditingController(
      text: widget.chunk.date.content ?? '',
    );
    _durationController = TextEditingController(
      text: widget.chunk.durationOfEvent.content ?? '',
    );
    _attendeesController = TextEditingController(
      text: widget.chunk.numberOfAttendees.content ?? '',
    );
    _entranceController = AnimationController(
      vsync: this,
      duration: AppConstants.formEntranceDuration,
      value: widget.isDisabled ? 1.0 : 0.0,
    );
    if (!widget.isDisabled) {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _budgetController.dispose();
    _dateController.dispose();
    _durationController.dispose();
    _attendeesController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    context.read<ChatController>().submitTextForm({
      'address': _addressController.text.trim(),
      'budget': _budgetController.text.trim(),
      'date': _dateController.text.trim(),
      'duration': _durationController.text.trim(),
      'numberOfAttendees': _attendeesController.text.trim(),
    });
  }

  /// Wraps [child] in a sequential fade + slide for the entrance animation.
  Widget _animateItem(int index, Widget child) {
    final int total = _totalItems;
    if (total <= 1) return child;
    final double start = index / total;
    final double end = (index + 1) / total;
    final Animation<double> opacity = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    final Animation<Offset> slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ));
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: opacity, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isReadOnly = widget.isDisabled;
    return Container(
      constraints: const BoxConstraints(
        maxWidth: AppConstants.textFormMaxWidth,
      ),
      margin: widget.isPinned
          ? EdgeInsets.zero
          : const EdgeInsets.only(top: AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: widget.isPinned
            ? const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusLg),
              )
            : BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: widget.isPinned
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
        ),
        boxShadow: widget.isPinned
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.1),
                  blurRadius: AppConstants.elevationLg,
                  offset: const Offset(0, -AppConstants.spacingXs),
                ),
              ]
            : null,
      ),
      child: AnimatedBuilder(
        animation: _entranceController,
        builder: (BuildContext context, Widget? _) {
          int itemIndex = 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _animateItem(
                itemIndex++,
                _buildHeader(theme, colorScheme),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingLg,
                  AppConstants.spacingSm,
                  AppConstants.spacingLg,
                  AppConstants.spacingLg,
                ),
                child: Column(
                  children: [
                    // Full-width address field
                    _animateItem(
                      itemIndex++,
                      _FormField(
                        label: widget.chunk.address.label,
                        controller: _addressController,
                        isReadOnly: isReadOnly,
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    // Two-column row: budget + date
                    _animateItem(
                      itemIndex++,
                      Row(
                        children: [
                          Expanded(
                            child: _FormField(
                              label: widget.chunk.budget.label,
                              controller: _budgetController,
                              isReadOnly: isReadOnly,
                              icon: Icons.attach_money_rounded,
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingMd),
                          Expanded(
                            child: _FormField(
                              label: widget.chunk.date.label,
                              controller: _dateController,
                              isReadOnly: isReadOnly,
                              icon: Icons.calendar_today_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    // Two-column row: duration + attendees
                    _animateItem(
                      itemIndex++,
                      Row(
                        children: [
                          Expanded(
                            child: _FormField(
                              label: widget.chunk.durationOfEvent.label,
                              controller: _durationController,
                              isReadOnly: isReadOnly,
                              icon: Icons.timer_outlined,
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingMd),
                          Expanded(
                            child: _FormField(
                              label: widget.chunk.numberOfAttendees.label,
                              controller: _attendeesController,
                              isReadOnly: isReadOnly,
                              icon: Icons.group_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isDisabled) ...[
                      const SizedBox(height: AppConstants.spacingLg),
                      _animateItem(
                        itemIndex++,
                        _buildActions(theme, colorScheme),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingLg,
        vertical: AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: widget.isPinned
            ? const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusLg),
              )
            : const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusMd),
              ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_note_rounded,
            size: AppConstants.iconSizeSm,
            color: colorScheme.primary,
          ),
          const SizedBox(width: AppConstants.spacingSm),
          Text(
            'Event Details',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          if (widget.isPinned) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingSm,
                vertical: AppConstants.spacingXs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Text(
                'Final Step',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme, ColorScheme colorScheme) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: _handleSubmit,
        icon: const Icon(Icons.check_rounded, size: AppConstants.iconSizeXs),
        label: const Text('Confirm Details'),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingXl,
            vertical: AppConstants.spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
        ),
      ),
    );
  }
}

/// Individual labeled form field with icon.
class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    required this.isReadOnly,
    required this.icon,
  });

  final String label;
  final TextEditingController controller;
  final bool isReadOnly;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: AppConstants.metaIconSize, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppConstants.spacingXs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingXs),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isReadOnly
                ? colorScheme.onSurface.withValues(alpha: 0.6)
                : colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isReadOnly
                ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
