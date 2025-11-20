import 'package:flutter/material.dart';

/// Utility class to handle responsive sizing across different screen sizes
class ResponsiveSizeUtils {
  /// Design reference width (based on standard mobile design)
  static const double _designWidth = 375;

  /// Design reference height (based on standard mobile design)
  static const double _designHeight = 812;

  /// Singleton instance
  static ResponsiveSizeUtils? _instance;

  /// Screen width
  late double _screenWidth;

  /// Screen height
  late double _screenHeight;

  /// Width scale factor
  late double _widthScaleFactor;

  /// Height scale factor
  late double _heightScaleFactor;

  /// Device pixel ratio
  late double _pixelRatio;

  /// Status bar height
  late double _statusBarHeight;

  /// Bottom padding (for notches, home indicators, etc.)
  late double _bottomPadding;

  /// Text scale factor
  late double _textScaleFactor;

  /// Default font size if not initialized
  static const double _defaultFontSize = 14.0;

  /// Factory constructor
  factory ResponsiveSizeUtils() {
    _instance ??= ResponsiveSizeUtils._();
    return _instance!;
  }

  /// Initialize with BuildContext
  void init(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
    _widthScaleFactor = _screenWidth / _designWidth;
    _heightScaleFactor = _screenHeight / _designHeight;
    _pixelRatio = mediaQuery.devicePixelRatio;
    _statusBarHeight = mediaQuery.padding.top;
    _bottomPadding = mediaQuery.padding.bottom;
    _textScaleFactor = mediaQuery.textScaleFactor;

    // Debug log to confirm initialization
    // 
    // 
  }

  /// Private constructor
  ResponsiveSizeUtils._();

  /// Check if initialized
  static bool get isInitialized => _instance != null;

  /// Get responsive width
  static double getWidth(double width) {
    if (_instance == null) {
      // 
      return width;
    }
    return width * _instance!._widthScaleFactor;
  }

  /// Get responsive height
  static double getHeight(double height) {
    if (_instance == null) {
      // 
      return height;
    }
    return height * _instance!._heightScaleFactor;
  }

  /// Get responsive font size
  static double getFontSize(double fontSize) {
    if (_instance == null) {
      // 
      return fontSize;
    }

    // Use the smaller of the two scale factors to ensure text isn't too large on wide devices
    final scaleFactor =
        _instance!._widthScaleFactor < _instance!._heightScaleFactor
        ? _instance!._widthScaleFactor
        : _instance!._heightScaleFactor;

    // Apply a dampening factor to prevent text from scaling too aggressively
    final dampening = 0.25;
    final adjustedScaleFactor = 1 + ((scaleFactor - 1) * (1 - dampening));

    // Ensure font size is never too small
    final calculatedSize = fontSize * adjustedScaleFactor;
    final minSize = fontSize * 0.8; // Minimum 80% of original size

    return calculatedSize < minSize ? minSize : calculatedSize;
  }

  /// Get screen width
  static double get screenWidth {
    if (_instance == null) {
      // 
      return 375.0;
    }
    return _instance!._screenWidth;
  }

  /// Get screen height
  static double get screenHeight {
    if (_instance == null) {
      // 
      return 812.0;
    }
    return _instance!._screenHeight;
  }

  /// Get status bar height
  static double get statusBarHeight {
    if (_instance == null) {
      // 
      return 24.0;
    }
    return _instance!._statusBarHeight;
  }

  /// Get bottom padding
  static double get bottomPadding {
    if (_instance == null) {
      // 
      return 0.0;
    }
    return _instance!._bottomPadding;
  }

  /// Check if device is a phone (smaller screen)
  static bool get isPhone {
    if (_instance == null) {
      // 
      return true;
    }
    return _instance!._screenWidth < 600;
  }

  /// Check if device is a tablet (larger screen)
  static bool get isTablet {
    if (_instance == null) {
      // 
      return false;
    }
    return _instance!._screenWidth >= 600;
  }

  /// Get adaptive padding based on screen size
  static EdgeInsets getAdaptivePadding({
    double small = 8.0,
    double medium = 16.0,
    double large = 24.0,
  }) {
    if (_instance == null) {
      // 
      return EdgeInsets.all(medium);
    }

    if (_instance!._screenWidth < 360) {
      return EdgeInsets.all(small);
    } else if (_instance!._screenWidth < 600) {
      return EdgeInsets.all(medium);
    } else {
      return EdgeInsets.all(large);
    }
  }

  /// Get responsive spacing
  static double getResponsiveSpacing({
    double small = 8.0,
    double medium = 16.0,
    double large = 24.0,
  }) {
    if (_instance == null) {
      // 
      return medium;
    }

    if (_instance!._screenWidth < 360) {
      return small;
    } else if (_instance!._screenWidth < 600) {
      return medium;
    } else {
      return large;
    }
  }
}
