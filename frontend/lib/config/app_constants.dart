import 'package:flutter/material.dart';

/// Application-wide layout and styling constants.
/// Use these instead of magic numbers for consistent design.
abstract final class AppConstants {
  AppConstants._();

  // ── Breakpoints ──────────────────────────────────────────────────────
  /// Screens with width below this use mobile layout; otherwise desktop layout.
  static const double kMobileBreakpoint = 600.0;

  // ── Spacing (8 px grid) ──────────────────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // ── Border radius ────────────────────────────────────────────────────
  static const double radiusXs = 4.0;
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  // ── Elevation / shadow ───────────────────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 6.0;
  static const double elevationLg = 12.0;

  // ── Animation durations ──────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 200);
  static const Duration durationSlow = Duration(milliseconds: 300);

  // ── Icon sizes ───────────────────────────────────────────────────────
  static const double iconSizeXxs = 8.0;
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 24.0;
  static const double iconSizeMd = 48.0;
  static const double iconSizeLg = 64.0;

  // ── Layout ───────────────────────────────────────────────────────────
  /// Width of the documents sidebar on desktop.
  static const double sidebarWidthDesktop = 280.0;

  /// Height of the fixed bottom bar (checkout / input areas).
  static const double bottomBarHeight = 104.0;

  // ── Chat ─────────────────────────────────────────────────────────────
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

  // ── Cart ──────────────────────────────────────────────────────────────
  /// Size of the product image thumbnail in cart items.
  static const double cartImageSize = 80.0;

  /// Size of the product image thumbnail in mobile cart items.
  static const double cartImageSizeMobile = 56.0;

  /// Size of the product image in the checkout summary.
  static const double cartSummaryImageSize = 75.0;

  /// Width of the quantity input field.
  static const double qtyFieldWidth = 40.0;

  /// Size of the error icon container.
  static const double errorIconSize = 75.0;

  // ── Skeleton loading ──────────────────────────────────────────────────
  static const double skeletonImageSize = 80.0;
  static const double skeletonTitleWidth = 250.0;
  static const double skeletonTitleHeight = 16.0;
  static const double skeletonSubtitleWidth = 170.0;
  static const double skeletonSubtitleHeight = 14.0;

  // ── Call-style UI (mobile) ────────────────────────────────────────────
  /// Size of the assistant avatar on the call screen.
  static const double callUiAvatarSize = 120.0;

  /// Size of the end-call button on the call screen.
  static const double callUiEndButtonSize = 72.0;

  /// Display name for the assistant on the call screen.
  static const String callUiAssistantName = 'Assistant';

  /// Icon size used inside call action buttons.
  static const double callUiActionIconSize = 36.0;

  /// Minimum touch target for call action buttons.
  static const double callUiTouchTarget = 44.0;

  // ── Call UI colours (always-dark call screen) ─────────────────────────
  static const Color callBgTop = Color(0xFF1C1C1E);
  static const Color callBgMid = Color(0xFF2C2C2E);
  static const Color callBgBottom = Color(0xFF000000);
  static const Color callAccept = Color(0xFF34C759);
  static const Color callReject = Color(0xFFEB2D2D);

  // ── Voice wave animation ──────────────────────────────────────────────
  /// Number of bars in the voice wave visualizer.
  static const int waveBarCount = 24;

  /// Width of each individual wave bar.
  static const double waveBarWidth = 3.0;

  /// Maximum height a wave bar reaches while animating.
  static const double waveBarMaxHeight = 32.0;

  /// Uniform height of all bars in the idle (flat) state.
  static const double waveBarIdleHeight = 3.0;

  /// Horizontal spacing between wave bars.
  static const double waveBarSpacing = 2.0;

  /// Opacity of wave bars in the idle (flat) state.
  static const double waveBarIdleOpacity = 0.35;

  /// Opacity of wave bars in the active (animating) state.
  static const double waveBarActiveOpacity = 0.85;

  // ── Category tile icon sizes (per depth level) ────────────────────────
  static const double categoryEmojiSizeLg = 24.0;
  static const double categoryEmojiSizeMd = 18.0;
  static const double categoryEmojiSizeSm = 14.0;

  // ── Small metadata icon size ──────────────────────────────────────────
  static const double metaIconSize = 14.0;
  static const double metaIconGap = 6.0;
}
