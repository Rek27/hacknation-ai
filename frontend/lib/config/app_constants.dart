import 'package:flutter/material.dart';

/// Application-wide layout and styling constants.
/// Use these instead of magic numbers for consistent design.
abstract final class AppConstants {
  AppConstants._();

  // Breakpoints
  /// Screens with width below this use mobile layout; otherwise desktop layout.
  static const double kMobileBreakpoint = 600.0;

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;

  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;

  // Layout
  /// Width of the documents sidebar on desktop.
  static const double sidebarWidthDesktop = 280.0;
}
