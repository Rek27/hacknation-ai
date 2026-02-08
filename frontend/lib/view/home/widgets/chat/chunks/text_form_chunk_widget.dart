import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:frontend/config/app_constants.dart';
import 'package:frontend/model/chat_models.dart';
import 'package:frontend/view/home/widgets/chat/chat_controller.dart';

const List<String> _eventDateMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatEventDate(DateTime d) {
  return '${_eventDateMonths[d.month - 1]} ${d.day}, ${d.year}';
}

String _formatEventDateForSubmit(DateTime d) {
  final String m = d.month.toString().padLeft(2, '0');
  final String day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

DateTime? _tryParseEventDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final DateTime? parsed = DateTime.tryParse(s.trim());
  if (parsed != null) return parsed;
  final RegExp long = RegExp(r'(\w+)\s+(\d+),\s*(\d+)');
  final Match? match = long.firstMatch(s);
  if (match != null) {
    final int monthIndex = _eventDateMonths.indexOf(match.group(1)!);
    if (monthIndex >= 0) {
      final int day = int.tryParse(match.group(2)!) ?? 0;
      final int year = int.tryParse(match.group(3)!) ?? 0;
      if (day >= 1 && day <= 31 && year >= 1970) {
        return DateTime(year, monthIndex + 1, day);
      }
    }
  }
  return null;
}

/// Popover overlay: barrier + positioned date picker card (desktop-friendly).
class _DatePickerPopover extends StatefulWidget {
  const _DatePickerPopover({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.initialDate,
    required this.onDone,
    required this.onDismiss,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final DateTime initialDate;
  final void Function(DateTime date) onDone;
  final VoidCallback onDismiss;

  @override
  State<_DatePickerPopover> createState() => _DatePickerPopoverState();
}

class _DatePickerPopoverState extends State<_DatePickerPopover> {
  late DateTime _current;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _current = widget.initialDate;
    _focusedDay = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final DateTime now = DateTime.now();
    final DateTime firstDay = DateTime(now.year - 2, now.month, now.day);
    final DateTime lastDay = DateTime(now.year + 5, now.month, now.day);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          width: widget.width,
          height: widget.height,
          child: Material(
            elevation: AppConstants.elevationLg,
            shadowColor: colorScheme.shadow,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingSm),
                child: SizedBox(
                  height: widget.height - 2 * AppConstants.spacingSm,
                  width: widget.width - 2 * AppConstants.spacingSm,
                  child: TableCalendar<Object>(
                    firstDay: firstDay,
                    lastDay: lastDay,
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (DateTime day) => isSameDay(day, _current),
                    onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
                      setState(() {
                        _current = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      widget.onDone(selectedDay);
                    },
                      onPageChanged: (DateTime focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                      },
                      calendarFormat: CalendarFormat.month,
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedTextStyle: TextStyle(color: colorScheme.onPrimary),
                        defaultTextStyle: theme.textTheme.bodyMedium!,
                        weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        outsideTextStyle: theme.textTheme.bodySmall!.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        markerDecoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: theme.textTheme.titleSmall!.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left_rounded,
                          color: colorScheme.primary,
                          size: AppConstants.iconSizeSm,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.primary,
                          size: AppConstants.iconSizeSm,
                        ),
                        headerPadding: const EdgeInsets.symmetric(
                          vertical: AppConstants.spacingSm,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


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
  late final TextEditingController _durationController;
  late final TextEditingController _attendeesController;

  DateTime? _selectedDate;

  final GlobalKey _dateFieldKey = GlobalKey();

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
    _selectedDate = _tryParseEventDate(widget.chunk.date.content) ?? DateTime.now();
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
    _durationController.dispose();
    _attendeesController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    context.read<ChatController>().submitTextForm({
      'address': _addressController.text.trim(),
      'budget': _budgetController.text.trim(),
      'date': _selectedDate != null ? _formatEventDateForSubmit(_selectedDate!) : '',
      'duration': _durationController.text.trim(),
      'numberOfAttendees': _attendeesController.text.trim(),
    });
  }

  void _openDatePicker() {
    if (widget.isDisabled) return;
    final RenderBox? box = _dateFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final OverlayState overlayState = Overlay.of(context);
    final RenderBox overlayBox = overlayState.context.findRenderObject() as RenderBox;
    final Offset topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final Size anchorSize = box.size;
    const double popupWidth = 320.0;
    const double popupHeight = 340.0;
    const double gap = 4.0;
    final double popupLeft = (topLeft.dx + anchorSize.width / 2 - popupWidth / 2)
        .clamp(8.0, overlayBox.size.width - popupWidth - 8.0);
    final double popupTop = (topLeft.dy + anchorSize.height + gap)
        .clamp(8.0, overlayBox.size.height - popupHeight - 8.0);

    late OverlayEntry overlayEntry;
    void removeOverlay() {
      overlayEntry.remove();
    }
    overlayEntry = OverlayEntry(
      builder: (BuildContext overlayContext) => _DatePickerPopover(
        left: popupLeft,
        top: popupTop,
        width: popupWidth,
        height: popupHeight,
        initialDate: _selectedDate ?? DateTime.now(),
        onDone: (DateTime date) {
          setState(() => _selectedDate = date);
          removeOverlay();
        },
        onDismiss: removeOverlay,
      ),
    );
    overlayState.insert(overlayEntry);
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
    final Animation<Offset> slide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          ),
        );
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
              _animateItem(itemIndex++, _buildHeader(theme, colorScheme)),
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
                            child: _DateFormField(
                              key: _dateFieldKey,
                              label: widget.chunk.date.label,
                              selectedDate: _selectedDate,
                              isReadOnly: isReadOnly,
                              icon: Icons.calendar_today_rounded,
                              onTap: _openDatePicker,
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
            Icon(
              icon,
              size: AppConstants.metaIconSize,
              color: colorScheme.onSurfaceVariant,
            ),
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
        SizedBox(
          height: AppConstants.formFieldMinHeight,
          child: TextField(
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
        ),
      ],
    );
  }
}

/// Date form field that opens a calendar date picker on tap.
class _DateFormField extends StatelessWidget {
  const _DateFormField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.isReadOnly,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final DateTime? selectedDate;
  final bool isReadOnly;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String displayText = selectedDate != null
        ? _formatEventDate(selectedDate!)
        : 'Select date';
    final bool canTap = !isReadOnly;
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
        SizedBox(
          height: AppConstants.formFieldMinHeight,
          child: Material(
            color: isReadOnly
                ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.5)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            child: InkWell(
              onTap: canTap ? onTap : null,
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: AppConstants.spacingSm,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isReadOnly
                            ? colorScheme.onSurface.withValues(alpha: 0.6)
                            : selectedDate != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (canTap)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: AppConstants.iconSizeSm,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
        ),
      ],
    );
  }
}
