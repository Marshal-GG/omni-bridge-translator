import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  OmniBridge Design System – single source of truth
//  Sections:  Colors · Spacing & Shapes · Text Styles · Theme
// ═══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────
//  COLORS
// ─────────────────────────────────────────────────────────────────────────

class AppColors {
  // Brand accents
  static const Color accentCyan = Colors.cyanAccent;
  static const Color accentTeal = Colors.tealAccent;
  static const Color accentRed = Colors.redAccent;

  // Background ramp (darkest → elevated)
  static const Color bgDeepest = Color(0xFF0F0F0F);
  static const Color bgDeep = Color(0xFF121212);
  static const Color bgMedium = Color(0xFF161616);
  static const Color bgLight = Color(0xFF1A1A1A);
  static const Color bgElevated = Color(0xFF1E1E1E);
  static const Color bgMenu = Color(0xFF2C2C2C);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;
  static const Color textDisabled = Colors.white38;
  static const Color textFaint = Colors.white24;

  // Semantic feature colors
  static const Color semanticAsr = Color(0xFF6366F1); // Indigo
  static const Color semanticTranslation = Color(0xFF10B981); // Emerald
  static const Color translationTeal = Color(0xFF2DD4BF);

  // Ticket status
  static const Color statusOpen = Colors.blueAccent;
  static const Color statusInProgress = Colors.orangeAccent;
  static const Color statusResolved = Colors.greenAccent;
  static const Color statusClosed = Colors.grey;

  // Utility
  static const Color transparent = Colors.transparent;
  static const Color black = Colors.black;
  static const Color offWhite = Color(0xFFE8E8E8);
  static const Color errorDark = Color(0xFF2A1A1A);

  // Splash / onboarding
  static const Color splashBlue = Color(0xFF3B82F6);
  static const Color splashPurple = Color(0xFF8B5CF6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color orange = Color(0xFFEF4444);
  static const Color pink = Color(0xFFEC4899);

  // Borders / glass
  static const Color cardBackground = Color(0x0DFFFFFF); // ~5 % white
  static const Color cardBorder = Color(0x14FFFFFF); // ~8 % white

  // Opacity helpers (one mechanism only)
  static Color white(double opacity) => Colors.white.withValues(alpha: opacity);
  static Color black_(double opacity) =>
      Colors.black.withValues(alpha: opacity);
  static Color cyan(double opacity) => accentCyan.withValues(alpha: opacity);
  static Color teal(double opacity) => accentTeal.withValues(alpha: opacity);

  // ── Legacy aliases (kept so existing call sites don't break) ─────────────
  // Background
  static const Color surfaceTransparent = transparent;
  static const Color surfaceDarkest = bgDeepest;
  static const Color surfaceDeep = bgDeep;
  static const Color surfaceMedium = bgMedium;
  static const Color surfaceLight = bgLight;
  static const Color surfaceElevated = bgElevated;
  static const Color surfaceMenu = bgMenu;
  // Named opacity constants (use AppColors.white(opacity) in new code)
  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white12 = Color(0x1FFFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white38 = Colors.white38;
  static const Color white54 = Colors.white54;
  static const Color white70 = Colors.white70;
  // Helper
  static Color whiteOpacity(double opacity) =>
      Colors.white.withValues(alpha: opacity);
  static Color accentCyanOpacity(double opacity) =>
      accentCyan.withValues(alpha: opacity);
  static Color glassBackground(double opacity) =>
      const Color(0xFF1F2B49).withValues(alpha: opacity);

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [accentCyan, translationTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Color scheme (embedded — no separate file needed)
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,

    primary: accentTeal,
    onPrimary: black,
    primaryContainer: Color(0xFF0A3E38),
    onPrimaryContainer: accentTeal,

    secondary: accentCyan,
    onSecondary: black,
    secondaryContainer: Color(0xFF093740),
    onSecondaryContainer: accentCyan,

    tertiary: translationTeal,
    onTertiary: black,
    tertiaryContainer: bgLight,
    onTertiaryContainer: offWhite,

    error: accentRed,
    onError: textPrimary,
    errorContainer: errorDark,
    onErrorContainer: accentRed,

    surface: bgDeep,
    onSurface: textPrimary,
    surfaceContainerHighest: bgElevated,
    onSurfaceVariant: textSecondary,

    outline: cardBorder,
    outlineVariant: cardBackground,
    shadow: black,
    scrim: black,
  );
}

// ─────────────────────────────────────────────────────────────────────────
//  USAGE SCREEN COLORS
// ─────────────────────────────────────────────────────────────────────────

class UsageColors {
  // Card
  static const Color cardBackground = Color(0xFF1A1D2E);
  static const Color statBackground = Color(0x08FFFFFF); // ~3% white

  // Engine type accents
  static const Color asrAccent = Color(0xFF818CF8); // Lighter indigo
  static const Color translationAccent = Color(0xFF2DD4BF); // Teal
  static const Color disabledAccent = Color(0xFF64748B); // Slate grey

  // Progress / status
  static const Color errorRed = Color(0xFFEF4444);
  static const Color barTrack = Color(0x0FFFFFFF); // ~6% white

  // Text
  static const Color monthLabel = Color(0x40FFFFFF); // ~25% white
  static const Color limitText = Color(0x4DFFFFFF); // ~30% white
  static const Color statValue = Colors.white70;
  static const Color statLabel = Color(0x4DFFFFFF); // ~30% white

  // Helpers
  static Color accentFor({required bool isAsr, required bool isInPlan}) {
    if (!isInPlan) return disabledAccent;
    return isAsr ? asrAccent : translationAccent;
  }

  static Color barColor({required bool isExceeded, required Color accent}) {
    return isExceeded ? errorRed : accent.withValues(alpha: 0.6);
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  SPACING & SHAPES
// ─────────────────────────────────────────────────────────────────────────

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 40.0;
  static const double xxl = 64.0;

  static const double navRailWidth = 256.0;
  static const double navRailWidthCollapsed = 64.0;
  static const double ticketListWidth = 320.0;
  static const double sidebarWidth = 350.0;
  static const double windowHeaderHeight = 32.0;
  static const double maxDashboardWidth = 800.0;
}

class AppShapes {
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
  static const double radiusRound = 40.0;

  static final BorderRadius sm = BorderRadius.circular(radiusSm);
  static final BorderRadius md = BorderRadius.circular(radiusMd);
  static const BorderRadius lg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(radiusXl));
  static final BorderRadius round = BorderRadius.circular(radiusRound);
}

// ─────────────────────────────────────────────────────────────────────────
//  TEXT STYLES
// ─────────────────────────────────────────────────────────────────────────

class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle chatMessage = TextStyle(
    fontSize: 14,
    color: AppColors.offWhite,
    height: 1.4,
  );
  static const TextStyle labelTiny = TextStyle(
    fontSize: 9,
    color: AppColors.textDisabled,
  );
}

// ─────────────────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.transparent,
      canvasColor: AppColors.transparent,
      colorScheme: AppColors.darkColorScheme,
      useMaterial3: true,

      textTheme: const TextTheme(
        displayLarge: AppTextStyles.display,
        headlineMedium: AppTextStyles.title,
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: AppTextStyles.body,
        bodyMedium: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        bodySmall: AppTextStyles.caption,
        labelLarge: AppTextStyles.label,
        labelMedium: AppTextStyles.caption,
        labelSmall: TextStyle(fontSize: 10, color: AppColors.textMuted),
      ),

      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: AppShapes.sm,
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        margin: EdgeInsets.zero,
        elevation: 0,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.cardBackground,
        thickness: 1,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.accentTeal
              : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.teal(0.5)
              : AppColors.white(0.24),
        ),
      ),

      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accentTeal,
        thumbColor: AppColors.accentTeal,
        inactiveTrackColor: AppColors.textFaint,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal(0.1),
          foregroundColor: AppColors.accentTeal,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppShapes.md),
          textStyle: AppTextStyles.label,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentTeal,
          side: BorderSide(color: AppColors.teal(0.3)),
          shape: RoundedRectangleBorder(borderRadius: AppShapes.md),
          textStyle: AppTextStyles.label,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentTeal,
          textStyle: AppTextStyles.caption,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.white(0.05),
        hintStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textFaint,
          height: 1.5,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: AppShapes.sm,
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShapes.sm,
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShapes.sm,
          borderSide: const BorderSide(color: AppColors.accentTeal, width: 1.5),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentCyan,
        foregroundColor: AppColors.bgDeepest,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: AppShapes.md),
      ),
    );
  }
}

// TextTheme extension for any semantic styles not in the standard scale.
extension AppTextTheme on TextTheme {
  TextStyle get chatMessage => AppTextStyles.chatMessage;
  TextStyle get labelTiny => AppTextStyles.labelTiny;
}
