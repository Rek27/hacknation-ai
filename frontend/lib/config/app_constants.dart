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

  /// Horizontal padding for chat bubbles (avatar size + spacing).
  static const double chatBubbleHorizontalPadding = chatAvatarSize + spacingSm;

  // ── Tree pill constants (per depth level) ───────────────────────────
  /// Padding for level-0 category pills.
  static const EdgeInsets treePillPaddingL0 = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  /// Padding for level-1 subcategory pills.
  static const EdgeInsets treePillPaddingL1 = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 5,
  );

  /// Padding for level-2 leaf pills.
  static const EdgeInsets treePillPaddingL2 = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 3,
  );

  /// Emoji size inside level-0 pills.
  static const double treePillEmojiSizeL0 = 20.0;

  /// Emoji size inside level-1 pills.
  static const double treePillEmojiSizeL1 = 16.0;

  /// Emoji size inside level-2 pills.
  static const double treePillEmojiSizeL2 = 13.0;

  /// Width of the vertical indent bar next to subcategory groups.
  static const double treeIndentBarWidth = 1.5;

  /// Duration for tree expand / collapse animations.
  static const Duration treeExpandDuration = Duration(milliseconds: 300);

  /// Per-item stagger delay for subcategory entrance animation.
  static const Duration treeStaggerDelay = Duration(milliseconds: 30);

  /// Disabled-state opacity for submitted trees.
  static const double treeDisabledOpacity = 0.5;

  /// Total duration of the sequential build-up entrance animation.
  static const Duration treeEntranceDuration = Duration(milliseconds: 2400);

  // ── Text typing animation ──────────────────────────────────────────────
  /// Delay between each word appearing in the typing animation.
  static const Duration textWordDelay = Duration(milliseconds: 30);

  // ── Chunk stagger animation ───────────────────────────────────────────
  /// Delay before revealing the next non-text chunk in a staggered sequence.
  static const Duration chunkStaggerDelay = Duration(milliseconds: 500);

  // ── Form entrance animation ────────────────────────────────────────────
  /// Total duration for the form field-by-field entrance animation.
  static const Duration formEntranceDuration = Duration(milliseconds: 1200);

  /// Maximum width of the pinned text form.
  static const double textFormMaxWidth = 680.0;

  /// Minimum height of form input fields (text and date) for consistent layout.
  static const double formFieldMinHeight = 36.0;

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

  /// Size of the Rive animation in the cart empty state.
  static const double cartEmptyAnimationSize = 180.0;

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

  // ── Tree pill scale ─────────────────────────────────────────────────
  /// Scale factor applied on tap-down for press feedback.
  static const double treePillPressScale = 0.97;

  // ── Cart swipe-to-delete ─────────────────────────────────────────────
  /// Background colour of the swipe-to-delete action (macOS destructive red).
  static const Color cartDeleteColor = Color(0xFFEB2D2D);

  /// How far the user must drag before auto-dismiss triggers (0–1).
  static const double cartDismissThreshold = 0.4;

  /// Fraction of the item width occupied by the revealed action pane.
  static const double cartActionExtentRatio = 0.25;

  // ── Star rating ──────────────────────────────────────────────────────
  /// Number of stars in the rating display.
  static const int starCount = 5;

  /// Horizontal gap between individual star icons.
  static const double starSpacing = 1.0;

  // ── Small metadata icon size ──────────────────────────────────────────
  static const double metaIconSize = 14.0;
  static const double metaIconGap = 6.0;

  // ── Resizable divider ──────────────────────────────────────────────
  /// Width of the invisible hit area for the resize divider.
  static const double resizeDividerHitWidth = 8.0;

  /// Width of the visible divider line when hovered or dragged.
  static const double resizeDividerActiveWidth = 4.0;

  /// Width of the grip indicator pill.
  static const double resizeDividerIndicatorWidth = 14.0;

  /// Height of the grip indicator pill.
  static const double resizeDividerIndicatorHeight = 36.0;

  /// Default fraction of total width allocated to the chat panel.
  static const double defaultChatWidthFraction = 0.375;

  /// Minimum fraction of total width for any panel.
  static const double panelMinWidthFraction = 0.2;
}
