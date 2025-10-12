import 'package:flutter/material.dart';

/// Responsive UI helper class to handle different screen sizes
class ResponsiveUI {
  /// Extra small screen breakpoint (phones)
  static const double extraSmallBreakpoint = 360;

  /// Small screen breakpoint (large phones)
  static const double smallBreakpoint = 480;

  /// Medium screen breakpoint (tablets)
  static const double mediumBreakpoint = 768;

  /// Large screen breakpoint (desktops)
  static const double largeBreakpoint = 1024;

  /// Extra large screen breakpoint (large desktops)
  static const double extraLargeBreakpoint = 1440;

  /// Check if the screen is extra small
  static bool isExtraSmall(BuildContext context) {
    return MediaQuery.of(context).size.width < extraSmallBreakpoint;
  }

  /// Check if the screen is small
  static bool isSmall(BuildContext context) {
    return MediaQuery.of(context).size.width >= extraSmallBreakpoint &&
        MediaQuery.of(context).size.width < smallBreakpoint;
  }

  /// Check if the screen is medium
  static bool isMedium(BuildContext context) {
    return MediaQuery.of(context).size.width >= smallBreakpoint &&
        MediaQuery.of(context).size.width < mediumBreakpoint;
  }

  /// Check if the screen is large
  static bool isLarge(BuildContext context) {
    return MediaQuery.of(context).size.width >= mediumBreakpoint &&
        MediaQuery.of(context).size.width < largeBreakpoint;
  }

  /// Check if the screen is extra large
  static bool isExtraLarge(BuildContext context) {
    return MediaQuery.of(context).size.width >= largeBreakpoint;
  }

  /// Get the number of columns for a grid based on screen size
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < extraSmallBreakpoint) {
      return 1;
    } else if (width < smallBreakpoint) {
      return 2;
    } else if (width < mediumBreakpoint) {
      return 3;
    } else if (width < largeBreakpoint) {
      return 4;
    } else {
      return 5;
    }
  }

  /// Get responsive padding based on screen size
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < extraSmallBreakpoint) {
      return const EdgeInsets.all(8.0);
    } else if (width < smallBreakpoint) {
      return const EdgeInsets.all(12.0);
    } else if (width < mediumBreakpoint) {
      return const EdgeInsets.all(16.0);
    } else {
      return const EdgeInsets.all(24.0);
    }
  }

  /// Get responsive spacing based on screen size
  static double getResponsiveSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < extraSmallBreakpoint) {
      return 8.0;
    } else if (width < smallBreakpoint) {
      return 12.0;
    } else if (width < mediumBreakpoint) {
      return 16.0;
    } else {
      return 24.0;
    }
  }

  /// Get responsive font size based on screen size
  static double getResponsiveFontSize(
    BuildContext context,
    double baseFontSize,
  ) {
    final width = MediaQuery.of(context).size.width;
    if (width < extraSmallBreakpoint) {
      return baseFontSize * 0.8;
    } else if (width < smallBreakpoint) {
      return baseFontSize * 0.9;
    } else if (width < mediumBreakpoint) {
      return baseFontSize;
    } else if (width < largeBreakpoint) {
      return baseFontSize * 1.1;
    } else {
      return baseFontSize * 1.2;
    }
  }

  /// Get responsive widget based on screen size
  static Widget getResponsiveWidget({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= largeBreakpoint && desktop != null) {
      return desktop;
    } else if (width >= mediumBreakpoint && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }

  /// Get responsive value based on screen size
  static T getResponsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= largeBreakpoint && desktop != null) {
      return desktop;
    } else if (width >= mediumBreakpoint && tablet != null) {
      return tablet;
    } else {
      return mobile;
    }
  }
}
