import 'package:flutter/material.dart';

/// Brand palette from the TIPO logo pack, plus the tints the product needs.
class TipoColors {
  static const navy = Color(0xFF0B1F3A);
  static const navyDeep = Color(0xFF071529);
  static const navyPanel = Color(0xFF0F2747);
  static const navyRaised = Color(0xFF16335A);
  static const navyLine = Color(0xFF24446F);
  static const orange = Color(0xFFFF7A1A);
  static const orangeSoft = Color(0xFFFF9A4D);
  static const orangeTint = Color(0xFFFFE9D9);

  /// Orange that keeps 4.5:1 on white, for text and links on light surfaces.
  static const orangeInk = Color(0xFFA84300);
  static const white = Color(0xFFFFFFFF);

  static const paper = Color(0xFFF5F7FA);
  static const ink = navy;
  static const inkSoft = Color(0xFF4A5B73);
  static const line = Color(0xFFDDE3EA);

  static const text = Color(0xFFF2F5F9);
  static const muted = Color(0xFFA9B6C8);

  static const critical = Color(0xFFE5383B);
  static const high = orange;
  static const medium = Color(0xFFF2B705);
  static const low = Color(0xFF2E9E6A);
  static const info = Color(0xFF5B9BFF);

  static const criticalOnDark = Color(0xFFFF6B6B);
  static const highOnDark = orangeSoft;
  static const mediumOnDark = Color(0xFFFFD24D);
  static const lowOnDark = Color(0xFF5FD39A);

  static const criticalInk = Color(0xFFB42318);
  static const mediumInk = Color(0xFF7A5600);
  static const lowInk = Color(0xFF1B6E47);
}

/// 4-point spacing scale. Every gap and padding in the app comes from here.
class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

class Motion {
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
}

const headingFont = 'Poppins';
const bodyFont = 'Inter';

/// Severity colour for fills, markers, and meters.
Color bandColor(String band, {bool onDark = true}) {
  switch (band) {
    case 'critical':
      return onDark ? TipoColors.criticalOnDark : TipoColors.critical;
    case 'high':
      return onDark ? TipoColors.highOnDark : TipoColors.high;
    case 'medium':
      return onDark ? TipoColors.mediumOnDark : TipoColors.medium;
    default:
      return onDark ? TipoColors.lowOnDark : TipoColors.low;
  }
}

/// Severity colour for text on light surfaces, kept at WCAG AA.
Color bandInk(String band) {
  switch (band) {
    case 'critical':
      return TipoColors.criticalInk;
    case 'high':
      return TipoColors.orangeInk;
    case 'medium':
      return TipoColors.mediumInk;
    default:
      return TipoColors.lowInk;
  }
}

String bandLabelId(String band) {
  switch (band) {
    case 'critical':
      return 'Kritis';
    case 'high':
      return 'Tinggi';
    case 'medium':
      return 'Sedang';
    default:
      return 'Rendah';
  }
}

IconData hazardIcon(String hazard) {
  switch (hazard) {
    case 'flood':
      return Icons.flood_rounded;
    case 'landslide':
      return Icons.landslide_rounded;
    case 'earthquake':
      return Icons.vibration_rounded;
    case 'fire':
      return Icons.local_fire_department_rounded;
    default:
      return Icons.report_rounded;
  }
}

String hazardLabel(String hazard) {
  switch (hazard) {
    case 'flood':
      return 'Flood';
    case 'landslide':
      return 'Landslide';
    case 'earthquake':
      return 'Earthquake';
    case 'fire':
      return 'Fire';
    default:
      return 'Other';
  }
}

TextStyle displayStyle({double size = 32, Color? color, FontWeight weight = FontWeight.w700}) {
  return TextStyle(fontFamily: headingFont, fontSize: size, fontWeight: weight, color: color, height: 1.15, letterSpacing: -0.3);
}

TextTheme _textTheme(Color text, Color muted) {
  TextStyle h(double size, FontWeight weight, {double height = 1.2}) =>
      TextStyle(fontFamily: headingFont, fontSize: size, fontWeight: weight, color: text, height: height, letterSpacing: -0.2);
  TextStyle b(double size, FontWeight weight, {Color? color, double height = 1.45}) =>
      TextStyle(fontFamily: bodyFont, fontSize: size, fontWeight: weight, color: color ?? text, height: height);
  return TextTheme(
    displayLarge: h(48, FontWeight.w800, height: 1.08),
    displayMedium: h(40, FontWeight.w800, height: 1.1),
    displaySmall: h(32, FontWeight.w700, height: 1.12),
    headlineLarge: h(28, FontWeight.w700),
    headlineMedium: h(24, FontWeight.w700),
    headlineSmall: h(20, FontWeight.w700),
    titleLarge: h(18, FontWeight.w600),
    titleMedium: b(16, FontWeight.w600),
    titleSmall: b(14, FontWeight.w600),
    bodyLarge: b(16, FontWeight.w400),
    bodyMedium: b(14, FontWeight.w400),
    bodySmall: b(12.5, FontWeight.w400, color: muted),
    labelLarge: b(14, FontWeight.w600, height: 1.2),
    labelMedium: b(12.5, FontWeight.w600, height: 1.2),
    labelSmall: b(11, FontWeight.w600, height: 1.2).copyWith(letterSpacing: 0.4),
  );
}

ThemeData _build(ColorScheme scheme, {required Color scaffold, required Color muted, required Color line, required Color linkColor}) {
  final text = _textTheme(scheme.onSurface, muted);
  final shape12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: scheme.brightness,
    scaffoldBackgroundColor: scaffold,
    fontFamily: bodyFont,
    textTheme: text,
    dividerColor: line,
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg), side: BorderSide(color: line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TipoColors.orange,
        foregroundColor: TipoColors.navy,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.45),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
        textStyle: text.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
        shape: shape12,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(64, 48),
        side: BorderSide(color: scheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        textStyle: text.labelLarge,
        shape: shape12,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: linkColor,
        minimumSize: const Size(48, 44),
        textStyle: text.labelLarge,
        shape: shape12,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.secondaryContainer,
      side: BorderSide(color: line),
      labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
      checkmarkColor: scheme.onSecondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.all(Space.lg),
      hintStyle: text.bodyMedium?.copyWith(color: muted),
      labelStyle: text.bodyMedium?.copyWith(color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: const BorderSide(color: TipoColors.orange, width: 2)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? TipoColors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? (scheme.brightness == Brightness.light ? TipoColors.navy : TipoColors.orange) : null,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: TipoColors.orange.withValues(alpha: scheme.brightness == Brightness.light ? 0.22 : 0.28),
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.onSurface : muted, size: 26),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: line),
        textStyle: text.labelLarge,
        minimumSize: const Size(48, 44),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TipoColors.navy,
      contentTextStyle: text.bodyMedium?.copyWith(color: TipoColors.white),
      actionTextColor: TipoColors.orangeSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
      titleTextStyle: text.headlineSmall,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: TipoColors.orange),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: TipoColors.navyRaised, borderRadius: BorderRadius.circular(Radii.sm)),
      textStyle: text.bodySmall?.copyWith(color: TipoColors.white),
    ),
  );
}

ThemeData citizenTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: TipoColors.orange,
    onPrimary: TipoColors.navy,
    primaryContainer: TipoColors.orangeTint,
    onPrimaryContainer: Color(0xFF5A2300),
    secondary: TipoColors.navy,
    onSecondary: TipoColors.white,
    secondaryContainer: Color(0xFFDCE6F5),
    onSecondaryContainer: TipoColors.navy,
    tertiary: TipoColors.lowInk,
    onTertiary: TipoColors.white,
    error: TipoColors.criticalInk,
    onError: TipoColors.white,
    surface: TipoColors.white,
    onSurface: TipoColors.navy,
    onSurfaceVariant: TipoColors.inkSoft,
    surfaceContainerHighest: Color(0xFFE9EDF2),
    outline: Color(0xFF8D9AAD),
    outlineVariant: TipoColors.line,
  );
  return _build(scheme, scaffold: TipoColors.paper, muted: TipoColors.inkSoft, line: TipoColors.line, linkColor: TipoColors.orangeInk);
}

ThemeData citizenDarkTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: TipoColors.orange,
    onPrimary: TipoColors.navy,
    primaryContainer: Color(0xFF4A2408),
    onPrimaryContainer: TipoColors.orangeTint,
    secondary: TipoColors.orangeSoft,
    onSecondary: TipoColors.navy,
    secondaryContainer: TipoColors.navyRaised,
    onSecondaryContainer: TipoColors.text,
    tertiary: TipoColors.lowOnDark,
    onTertiary: TipoColors.navy,
    error: TipoColors.criticalOnDark,
    onError: TipoColors.navy,
    surface: TipoColors.navyPanel,
    onSurface: TipoColors.text,
    onSurfaceVariant: TipoColors.muted,
    surfaceContainerHighest: TipoColors.navyRaised,
    outline: Color(0xFF5A7192),
    outlineVariant: TipoColors.navyLine,
  );
  return _build(scheme, scaffold: TipoColors.navyDeep, muted: TipoColors.muted, line: TipoColors.navyLine, linkColor: TipoColors.orangeSoft);
}

ThemeData opsTheme() => citizenDarkTheme().copyWith(scaffoldBackgroundColor: TipoColors.navyDeep);

/// Theme-aware helpers so widgets don't branch on brightness by hand.
extension TipoThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get muted => isDark ? TipoColors.muted : TipoColors.inkSoft;
  Color get line => isDark ? TipoColors.navyLine : TipoColors.line;
  Color get link => isDark ? TipoColors.orangeSoft : TipoColors.orangeInk;
  Color bandText(String band) => isDark ? bandColor(band) : bandInk(band);
  Color bandFill(String band) => bandColor(band, onDark: isDark);
}
