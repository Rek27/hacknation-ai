import 'package:flutter/material.dart';
import 'package:frontend/config/app_constants.dart';

/// Centralised application theme.
///
/// Exposes [lightTheme] and [darkTheme] for use in [MaterialApp].
/// All colours, typography, and component styles are defined here so that
/// individual widgets never need to hardcode visual values.
abstract final class AppTheme {
  AppTheme._();

  // ── Accent palette (teal) ────────────────────────────────────────────
  static const Color _teal = Color(0xFF14B8A6);
  static const Color _tealLight = Color(0xFF2DD4BF);
  static const Color _onTeal = Color(0xFFFFFFFF);

  // ── Semantic fixed colours ────────────────────────────────────────────
  static const Color success = Color(0xFF34C759);
  static const Color destructive = Color(0xFFEB2D2D);

  // ────────────────────────────────────────────────────────────────────
  //  LIGHT THEME
  // ────────────────────────────────────────────────────────────────────

  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: _teal,
    onPrimary: _onTeal,
    primaryContainer: Color(0xFFD5F5F0),
    onPrimaryContainer: Color(0xFF00332D),
    secondary: Color(0xFF4B6360),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFCDE8E4),
    onSecondaryContainer: Color(0xFF06201D),
    tertiary: Color(0xFF436278),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFC8E6FF),
    onTertiaryContainer: Color(0xFF001E30),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFAFAFA),
    onSurface: Color(0xFF1A1A1A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F5F5),
    surfaceContainer: Color(0xFFF0F0F0),
    surfaceContainerHigh: Color(0xFFEAEAEA),
    surfaceContainerHighest: Color(0xFFE0E0E0),
    onSurfaceVariant: Color(0xFF6B6B6B),
    outline: Color(0xFF8E8E8E),
    outlineVariant: Color(0xFFDCDCDC),
    shadow: Color(0xFF000000),
    inverseSurface: Color(0xFF1A1A1A),
    onInverseSurface: Color(0xFFF5F5F5),
    inversePrimary: _tealLight,
  );

  // ────────────────────────────────────────────────────────────────────
  //  DARK THEME
  // ────────────────────────────────────────────────────────────────────

  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: _tealLight,
    onPrimary: Color(0xFF003730),
    primaryContainer: Color(0xFF005048),
    onPrimaryContainer: Color(0xFFD5F5F0),
    secondary: Color(0xFFB1CCC8),
    onSecondary: Color(0xFF1C3532),
    secondaryContainer: Color(0xFF334B48),
    onSecondaryContainer: Color(0xFFCDE8E4),
    tertiary: Color(0xFFAACBE3),
    onTertiary: Color(0xFF103448),
    tertiaryContainer: Color(0xFF2B4A5F),
    onTertiaryContainer: Color(0xFFC8E6FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0A0A0A),
    onSurface: Color(0xFFF0F0F0),
    surfaceContainerLowest: Color(0xFF050505),
    surfaceContainerLow: Color(0xFF1C1C1E),
    surfaceContainer: Color(0xFF222224),
    surfaceContainerHigh: Color(0xFF2C2C2E),
    surfaceContainerHighest: Color(0xFF3A3A3C),
    onSurfaceVariant: Color(0xFF8E8E93),
    outline: Color(0xFF636366),
    outlineVariant: Color(0xFF38383A),
    shadow: Color(0xFF000000),
    inverseSurface: Color(0xFFF0F0F0),
    onInverseSurface: Color(0xFF1A1A1A),
    inversePrimary: _teal,
  );

  // ────────────────────────────────────────────────────────────────────
  //  TEXT THEME
  // ────────────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(Brightness brightness) {
    final TextTheme base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: base.bodyLarge?.copyWith(letterSpacing: 0),
      bodyMedium: base.bodyMedium?.copyWith(letterSpacing: 0),
      bodySmall: base.bodySmall?.copyWith(letterSpacing: 0.1),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  //  COMPONENT THEMES (shared builder)
  // ────────────────────────────────────────────────────────────────────

  static ThemeData _build(ColorScheme colorScheme, TextTheme textTheme) {
    final bool isDark = colorScheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      splashFactory: InkSparkle.splashFactory,

      // ── AppBar ───────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),

      // ── Divider ──────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Input decoration ─────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingSm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // ── FilledButton ─────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingSm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── ElevatedButton ───────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingSm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── OutlinedButton ───────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingLg,
            vertical: AppConstants.spacingSm + 4,
          ),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── TextButton ───────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingSm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── IconButton ───────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          padding: const EdgeInsets.all(AppConstants.spacingSm),
        ),
      ),

      // ── Card ─────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),

      // ── ListTile ─────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: 0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
      ),

      // ── Progress indicators ──────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: isDark
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerHighest,
        circularTrackColor: isDark
            ? colorScheme.surfaceContainerHigh
            : colorScheme.surfaceContainerHighest,
      ),

      // ── Bottom sheet ─────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),

      // ── SnackBar ─────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: AppConstants.elevationMd,
      ),

      // ── Tooltip ──────────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),

      // ── Radio ────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ────────────────────────────────────────────────────────────────────

  /// Light mode [ThemeData].
  static ThemeData get lightTheme =>
      _build(_lightScheme, _buildTextTheme(Brightness.light));

  /// Dark mode [ThemeData].
  static ThemeData get darkTheme =>
      _build(_darkScheme, _buildTextTheme(Brightness.dark));
}
