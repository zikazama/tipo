import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Shared breakpoints for the citizen app (phone + narrow web preview frame).
abstract final class CitizenLayout {
  static const narrowWidth = 400;
  static const tightWidth = 340;

  static bool isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < narrowWidth;

  static bool isTight(BuildContext context) => MediaQuery.sizeOf(context).width < tightWidth;

  static EdgeInsets pagePadding(BuildContext context) {
    final h = isNarrow(context) ? Space.lg : Space.xl - 4;
    return EdgeInsets.fromLTRB(h, Space.xs, h, Space.xxl);
  }

  static EdgeInsets listPadding(BuildContext context) => EdgeInsets.all(isNarrow(context) ? Space.lg : Space.lg);

  static TextStyle? sectionTitleStyle(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return isNarrow(context) ? theme.titleMedium?.copyWith(fontWeight: FontWeight.w700) : theme.titleLarge;
  }

  static TextStyle? pageHeadlineStyle(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return isNarrow(context) ? theme.headlineSmall?.copyWith(height: 1.25) : theme.headlineMedium?.copyWith(height: 1.25);
  }
}
