import 'package:flutter/material.dart';
import 'responsive_size_utils.dart';

/// Extensions for responsive sizing on numbers
extension ResponsiveExtension on num {
  /// Convert to responsive width
  double get w => ResponsiveSizeUtils.getWidth(toDouble());

  /// Convert to responsive height
  double get h => ResponsiveSizeUtils.getHeight(toDouble());

  /// Convert to responsive font size
  double get sp => ResponsiveSizeUtils.getFontSize(toDouble());

  /// Convert to responsive value based on shortest dimension
  double get r =>
      ResponsiveSizeUtils.screenWidth < ResponsiveSizeUtils.screenHeight
      ? ResponsiveSizeUtils.getWidth(toDouble())
      : ResponsiveSizeUtils.getHeight(toDouble());
}

/// Extensions for responsive widgets
extension ResponsiveWidgetExtension on Widget {
  /// Add responsive padding to a widget
  Widget withResponsivePadding({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: (left ?? horizontal ?? all ?? 0).w,
        top: (top ?? vertical ?? all ?? 0).h,
        right: (right ?? horizontal ?? all ?? 0).w,
        bottom: (bottom ?? vertical ?? all ?? 0).h,
      ),
      child: this,
    );
  }

  /// Make a widget responsive to screen size
  Widget responsive({Widget? phone, Widget? tablet}) {
    return Builder(
      builder: (context) {
        if (ResponsiveSizeUtils.isTablet) {
          return tablet ?? this;
        } else {
          return phone ?? this;
        }
      },
    );
  }

  /// Center a widget with responsive padding
  Widget centeredWithPadding({double padding = 16.0}) {
    return Center(
      child: Padding(padding: EdgeInsets.all(padding.r), child: this),
    );
  }

  /// Add responsive margin to a widget
  Widget withResponsiveMargin({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return Container(
      margin: EdgeInsets.only(
        left: (left ?? horizontal ?? all ?? 0).w,
        top: (top ?? vertical ?? all ?? 0).h,
        right: (right ?? horizontal ?? all ?? 0).w,
        bottom: (bottom ?? vertical ?? all ?? 0).h,
      ),
      child: this,
    );
  }
}

/// Extensions for BuildContext
extension ResponsiveContextExtension on BuildContext {
  /// Get screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Check if device is in portrait mode
  bool get isPortrait =>
      MediaQuery.of(this).orientation == Orientation.portrait;

  /// Check if device is in landscape mode
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;

  /// Check if device is a phone (smaller screen)
  bool get isPhone => screenWidth < 600;

  /// Check if device is a tablet (larger screen)
  bool get isTablet => screenWidth >= 600;

  /// Get responsive padding based on screen size
  EdgeInsets get responsivePadding {
    if (screenWidth < 360) {
      return const EdgeInsets.all(8.0);
    } else if (screenWidth < 600) {
      return const EdgeInsets.all(16.0);
    } else {
      return const EdgeInsets.all(24.0);
    }
  }

  /// Get theme data
  ThemeData get theme => Theme.of(this);

  /// Get text theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Get color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
}
