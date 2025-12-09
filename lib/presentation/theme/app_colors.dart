import 'package:flutter/material.dart';

class AppColors {
  // Màu chính của ứng dụng logistics
  static const Color primary = Color(0xFF1E5BB0); // Xanh dương đậm
  static const Color secondary = Color(0xFF3C8CE7); // Xanh dương nhạt
  static const Color accent = Color(0xFFFF8C00); // Cam đậm

  // Màu nền
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;

  // Màu chữ
  static const Color textPrimary = Color(0xFF2D3142);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textLight = Color(0xFFADB5BD);

  // Màu trạng thái
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFDC3545);
  static const Color info = Color(0xFF17A2B8);

  // Màu viền
  static const Color border = Color(0xFFDEE2E6);

  // Màu cho dark mode
  static const Color darkBackground = Color(0xFF1A1D21);
  static const Color darkSurface = Color(0xFF2D3035);
  static const Color darkBorder = Color(0xFF3E4248);

  // Màu trạng thái đơn hàng
  static const Color pending = Color(0xFFFFC107); // Đang chờ
  static const Color inProgress = Color(0xFF3C8CE7); // Đang giao
  static const Color completed = Color(0xFF28A745); // Hoàn thành
  static const Color cancelled = Color(0xFFDC3545); // Đã hủy

  // Màu xám (grey scale)
  static const Color grey100 = Color(0xFFF8F9FA);
  static const Color grey200 = Color(0xFFE9ECEF);
  static const Color grey300 = Color(0xFFDEE2E6);
  static const Color grey400 = Color(0xFFCED4DA);
  static const Color grey500 = Color(0xFFADB5BD);
  static const Color grey600 = Color(0xFF6C757D);
  static const Color grey700 = Color(0xFF495057);
  static const Color grey800 = Color(0xFF343A40);
  static const Color grey900 = Color(0xFF212529);
}
