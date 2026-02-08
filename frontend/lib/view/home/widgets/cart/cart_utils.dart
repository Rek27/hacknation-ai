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

/// Returns a category-specific icon for alternative recommendation tiles.
IconData iconForCategoryKey(String key) {
  switch (key) {
    case 'cheapest':
      return Icons.savings_outlined;
    case 'best':
      return Icons.star_rounded;
    case 'fastest':
      return Icons.bolt_rounded;
    case 'main':
    default:
      return Icons.auto_awesome_outlined;
  }
}

/// Returns a semantic accent color for a recommendation category.
/// Green for cheapest, amber for best reviewed, blue for fastest.
Color categoryAccentColor(BuildContext context, String key) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  switch (key) {
    case 'cheapest':
      return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    case 'best':
      return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    case 'fastest':
      return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    case 'main':
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

/// Returns the relative URL path for a retailer logo image.
/// The backend stores logos as `/images/retailers/{sanitized_name}.png`
/// where spaces become underscores and slashes become underscores.
String retailerLogoUrl(String retailerName) {
  final sanitized = retailerName.replaceAll(' ', '_').replaceAll('/', '_');
  return '/images/retailers/$sanitized.png';
}

/// Returns a soft tinted background for a recommendation category tile.
/// When [isSelected] is true the tint is stronger to reinforce the selection.
Color categorySoftTint(
  BuildContext context,
  String key, {
  bool isSelected = false,
}) {
  final Color accent = categoryAccentColor(context, key);
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  if (isSelected) {
    return accent.withValues(alpha: isDark ? 0.18 : 0.12);
  }
  return accent.withValues(alpha: isDark ? 0.08 : 0.05);
}
