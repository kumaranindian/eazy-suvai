import 'package:flutter/widgets.dart';

/// Window size classes from architecture §6.
enum Breakpoint {
  /// < 600 px: bottom navigation bar, single column.
  compact,

  /// 600–1023 px: navigation rail, two columns where useful.
  medium,

  /// ≥ 1024 px: 240 px side menu, list–detail panes.
  expanded;

  static const double mediumMin = 600;
  static const double expandedMin = 1024;

  /// Width of the side menu at [expanded].
  static const double sideMenuWidth = 240;

  /// Maximum content width at [expanded].
  static const double maxContentWidth = 1200;

  static Breakpoint fromWidth(double width) {
    if (width >= expandedMin) return Breakpoint.expanded;
    if (width >= mediumMin) return Breakpoint.medium;
    return Breakpoint.compact;
  }

  /// Breakpoint for the current window.
  static Breakpoint of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == Breakpoint.compact;
  bool get isMedium => this == Breakpoint.medium;
  bool get isExpanded => this == Breakpoint.expanded;
}
