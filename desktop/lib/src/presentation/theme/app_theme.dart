import 'package:flutter/material.dart';

/// The application palette, taken from `ui.txt` section 9.
///
/// Kept as a [ThemeExtension] rather than only a `ColorScheme` because the
/// specification needs semantic colours — positive, warning, error, info — that do
/// not map cleanly onto Material's roles. Being a theme extension means a screen
/// can read `context.appPalette.positive` and a designer can change the whole
/// palette in one place.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.raisedSurface,
    required this.divider,
    required this.strongRule,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
    required this.positive,
    required this.warning,
    required this.error,
    required this.info,
    required this.neutral,
  });

  /// Page background. A warm white rather than pure white, which softens the
  /// long tables a user spends a day reading.
  final Color canvas;

  /// Panels and content areas.
  final Color surface;

  /// Menus, dialogs, and anything that sits above another surface.
  final Color raisedSurface;

  /// Ordinary separators between rows and sections.
  final Color divider;

  /// The heavier rule under a page title or major section, in the newspaper sense.
  final Color strongRule;

  final Color primaryText;

  final Color secondaryText;

  /// The single accent colour. One accent, used sparingly, as specified.
  final Color accent;

  /// Gains, settled balances, successful states.
  final Color positive;

  /// Attention without alarm.
  final Color warning;

  /// Errors and negative balances.
  final Color error;

  final Color info;

  final Color neutral;

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? raisedSurface,
    Color? divider,
    Color? strongRule,
    Color? primaryText,
    Color? secondaryText,
    Color? accent,
    Color? positive,
    Color? warning,
    Color? error,
    Color? info,
    Color? neutral,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      raisedSurface: raisedSurface ?? this.raisedSurface,
      divider: divider ?? this.divider,
      strongRule: strongRule ?? this.strongRule,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      accent: accent ?? this.accent,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raisedSurface: Color.lerp(raisedSurface, other.raisedSurface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      strongRule: Color.lerp(strongRule, other.strongRule, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

/// The light palette. A restrained, slightly warm neutral base, as `ui.txt`
/// section 9 requires.
const AppPalette appLightPalette = AppPalette(
  canvas: Color(0xFFF4F3F0),
  surface: Color(0xFFFFFFFF),
  raisedSurface: Color(0xFFFFFFFF),
  divider: Color(0xFFD6D3CE),
  strongRule: Color(0xFF1C1C1A),
  primaryText: Color(0xFF1C1C1A),
  secondaryText: Color(0xFF5F5C57),
  accent: Color(0xFF1F6FB2),
  positive: Color(0xFF2E7D32),
  warning: Color(0xFF9A6400),
  error: Color(0xFFC62828),
  info: Color(0xFF1F6FB2),
  neutral: Color(0xFF6B6862),
);

/// The dark palette, following `ui.txt` section 34.
const AppPalette appDarkPalette = AppPalette(
  canvas: Color(0xFF1A1A19),
  surface: Color(0xFF242422),
  raisedSurface: Color(0xFF2E2E2C),
  divider: Color(0xFF3C3C39),
  strongRule: Color(0xFFF0EFEC),
  primaryText: Color(0xFFF0EFEC),
  secondaryText: Color(0xFFA8A5A0),
  accent: Color(0xFF5AA9E6),
  positive: Color(0xFF66BB6A),
  warning: Color(0xFFE0A94A),
  error: Color(0xFFEF6C6C),
  info: Color(0xFF5AA9E6),
  neutral: Color(0xFF9A9792),
);

/// Spacing scale, from `ui.txt` section 24, which asks for a comfortable density
/// and warns against wasting vertical space.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii, from `ui.txt` section 23: small, and never mobile-bank-app round.
abstract final class AppRadius {
  /// Flat, for data and report elements.
  static const double none = 0;

  /// Controls.
  static const double control = 3;

  /// Containers.
  static const double container = 4;

  /// Prominent elements. This is the maximum.
  static const double prominent = 6;
}

/// The application theme.
///
/// Sized from `ui.txt` section 7. A newspaper gets its hierarchy from relative
/// importance rather than oversized text everywhere, so the steps below are
/// deliberately close together and the page title is the only large size.
abstract final class AppTheme {
  /// UI font. Segoe UI is the Windows 7/8 system face, which is what the
  /// specification is imitating; the fallbacks keep it sane on Linux and macOS.
  static const String _fontFamily = 'Segoe UI';
  static const List<String> _fontFallback = <String>[
    'Noto Sans',
    'DejaVu Sans',
    'Arial',
    'Helvetica',
  ];

  /// The application name, shown in the window and the shell.
  static const String applicationName = 'financeapp';

  static ThemeData light() => _build(appLightPalette, Brightness.light);

  static ThemeData dark() => _build(appDarkPalette, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // The font belongs on the constructor: `ThemeData.copyWith` has no
      // fontFamily parameter.
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFallback,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
      ),
    );

    return base
        .copyWith(
      scaffoldBackgroundColor: palette.canvas,
      dividerColor: palette.divider,
      // Flat geometry, as Windows 8 influence asks. Shadows are reserved for
      // things that genuinely sit above another surface.
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius:
              const BorderRadius.all(Radius.circular(AppRadius.container)),
          side: BorderSide(color: palette.divider),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: AppSpacing.lg,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        minVerticalPadding: AppSpacing.xs,
      ),
      tooltipTheme: const TooltipThemeData(waitDuration: Duration.zero),
      visualDensity: VisualDensity.comfortable,
      textTheme: _textTheme(base.textTheme, palette),
    )
        .copyWith(
      // The palette rides along on the theme so any screen can read it.
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }

  /// Type scale, from `ui.txt` section 7.
  static TextTheme _textTheme(TextTheme base, AppPalette palette) {
    return base.copyWith(
      // Page title: 32-36 in the specification.
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: palette.primaryText,
        height: 1.2,
      ),
      // Major section: 22-26.
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: palette.primaryText,
        height: 1.25,
      ),
      // Section heading: 16-20.
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.primaryText,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: palette.primaryText,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.primaryText,
      ),
      // Normal UI text: 13-15.
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 14,
        color: palette.primaryText,
        height: 1.45,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        color: palette.primaryText,
        height: 1.45,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13,
        color: palette.secondaryText,
        height: 1.4,
      ),
      // Secondary information: 11-13.
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 12,
        color: palette.secondaryText,
        letterSpacing: 0.2,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.primaryText,
      ),
    );
  }
}

/// The palette carried on the current theme.
///
/// Throws a descriptive error rather than returning null, because a screen that
/// cannot find the palette is a wiring mistake and should say so plainly.
extension AppPaletteAccess on BuildContext {
  AppPalette get palette {
    final palette = Theme.of(this).extension<AppPalette>();
    if (palette == null) {
      throw StateError(
        'No AppPalette on this theme. The widget reading it must sit below the '
        'MaterialApp that installs AppTheme; check that the screen is under '
        'FinanceApp.',
      );
    }
    return palette;
  }
}
