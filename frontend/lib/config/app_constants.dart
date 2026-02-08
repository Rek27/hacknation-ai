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
  static const double radiusXxs = 2.0;
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;

  // Icon sizes
  static const double iconSizeXxs = 8.0;
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 24.0;
  static const double iconSizeMd = 48.0;
  static const double iconSizeLg = 64.0;

  // Layout
  /// Width of the documents sidebar on desktop.
  static const double sidebarWidthDesktop = 280.0;

  // Chat
  /// Maximum width of a chat bubble.
  static const double chatBubbleMaxWidth = 600.0;

  /// Size of the sender avatar circle.
  static const double chatAvatarSize = 32.0;

  /// Minimum width of a category tile in the tree selector.
  static const double categoryTileMinWidth = 110.0;

  /// Fixed height for category tiles to keep them equal.
  static const double categoryTileHeight = 90.0;

  /// Maximum width of the pinned text form.
  static const double textFormMaxWidth = 680.0;

  /// Width of sample prompt cards.
  static const double samplePromptWidth = 260.0;
}
