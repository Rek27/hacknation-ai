import 'package:flutter/material.dart';

/// Shared formatting and helper utilities used by both desktop and mobile cart widgets.

/// Formats a price in euro style (e.g. 1.234,56 €).
String formatPrice(double price) {
  final bool isNegative = price < 0;
  final double abs = price.abs();
  final String fixed = abs.toStringAsFixed(2);
  final List<String> parts = fixed.split('.');
  final String intPart = parts[0];
  final String decPart = parts[1];
  final List<String> chars = intPart.split('').reversed.toList();
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < chars.length; i++) {
    buf.write(chars[i]);
    if ((i + 1) % 3 == 0 && i + 1 != chars.length) {
      buf.write('.');
    }
  }
  final String grouped = buf.toString().split('').reversed.join();
  final String sign = isNegative ? '-' : '';
  return '$sign$grouped,$decPart €';
}

/// Returns a short date like "Feb 10" computed from now + [d].
String formatEstimatedDateFromNow(Duration d) {
  final DateTime date = DateTime.now().add(d);
  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

/// Short human label for a duration (e.g. 2d, 5h, 30m).
String formatEstimatedDurationLabel(Duration d) {
  if (d.inDays >= 1) return '${d.inDays}d';
  if (d.inHours >= 1) return '${d.inHours}h';
  return '${d.inMinutes}m';
}

/// Returns the category background color for recommendation chips.
Color categoryBgForKey(BuildContext context, String key) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  switch (key) {
    case 'cheapest':
      return cs.primaryFixed.withValues(alpha: 0.10);
    case 'best':
      return cs.primaryFixedDim.withValues(alpha: 0.15);
    case 'fastest':
      return cs.onPrimaryFixedVariant.withValues(alpha: 0.15);
    case 'main':
    default:
      return cs.primary.withValues(alpha: 0.10);
  }
}

/// Returns a user-facing label for a category key.
String labelForCategoryKey(String key) {
  switch (key) {
    case 'cheapest':
      return 'Cheapest';
    case 'best':
      return 'Best reviewed';
    case 'fastest':
      return 'Fastest';
    case 'main':
    default:
      return 'Main';
  }
}
