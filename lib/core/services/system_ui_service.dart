import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/responsive_size_utils.dart';

/// Service to handle system UI related configurations
class SystemUiService {
  /// Cấu hình SystemChrome để xử lý thanh navigation bar và status bar
  static void configureSystemUI() {
    // Đặt màu trong suốt cho navigation bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        // Status bar
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,

        // Navigation bar
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Đảm bảo nội dung hiển thị bên dưới thanh navigation bar
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }

  /// Tính toán padding phù hợp cho bottom navigation
  static EdgeInsets getBottomPadding(BuildContext context) {
    try {
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      // Sử dụng responsive sizing để đảm bảo padding phù hợp với kích thước màn hình
      final basePadding = ResponsiveSizeUtils.isTablet ? 12.0 : 8.0;
      return EdgeInsets.only(
        bottom: bottomPadding > 0 ? bottomPadding : basePadding,
      );
    } catch (e) {
      // Fallback if ResponsiveSizeUtils is not initialized
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      return EdgeInsets.only(bottom: bottomPadding > 0 ? bottomPadding : 8.0);
    }
  }

  /// Tạo padding cho nội dung để tránh bị che bởi navigation bar
  static EdgeInsets getContentPadding(
    BuildContext context, {
    double basePadding = 16,
  }) {
    try {
      final bottomPadding = MediaQuery.of(context).padding.bottom;

      // Sử dụng responsive sizing để đảm bảo padding phù hợp với kích thước màn hình
      double responsivePadding;
      if (ResponsiveSizeUtils.isTablet) {
        responsivePadding = 24.0; // Larger padding for tablets
      } else if (ResponsiveSizeUtils.screenWidth < 360) {
        responsivePadding = 12.0; // Smaller padding for small phones
      } else {
        responsivePadding = basePadding; // Default padding
      }

      return EdgeInsets.fromLTRB(
        responsivePadding,
        responsivePadding,
        responsivePadding,
        responsivePadding + (bottomPadding > 0 ? bottomPadding : 0),
      );
    } catch (e) {
      // Fallback if ResponsiveSizeUtils is not initialized
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      return EdgeInsets.fromLTRB(
        basePadding,
        basePadding,
        basePadding,
        basePadding + (bottomPadding > 0 ? bottomPadding : 0),
      );
    }
  }
}
