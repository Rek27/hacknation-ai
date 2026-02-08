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

  /// Minimum width of a category tile in the tree selector (level 0).
  static const double categoryTileMinWidth = 100.0;

  /// Fixed height for category tiles at level 0.
  static const double categoryTileHeight = 76.0;

  /// Fixed scales for the 3-level hierarchy: categories > subcategories > sub-subcategories.
  /// Level 0 (categories): 1.0, Level 1: 0.60, Level 2: 0.42.
  static const List<double> categoryTileDepthScales = [1.0, 0.60, 0.42];

  /// Height scale for level 2 (chip style) - shorter than proportional.
  static const double categoryTileLevel2HeightScale = 0.38;

  /// Maximum width of the pinned text form.
  static const double textFormMaxWidth = 680.0;

  /// Width of sample prompt cards.
  static const double samplePromptWidth = 260.0;

  // Call-style UI (mobile)
  /// Size of the assistant avatar on the call screen.
  static const double callUiAvatarSize = 120.0;

  /// Size of the end-call button on the call screen.
  static const double callUiEndButtonSize = 72.0;

  /// Display name for the assistant on the call screen.
  static const String callUiAssistantName = 'Assistant';
}
