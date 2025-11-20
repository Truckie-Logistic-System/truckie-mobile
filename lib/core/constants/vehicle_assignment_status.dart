import 'package:flutter/material.dart';

/// Vehicle Assignment Status Constants
/// Matches backend VehicleAssignmentStatusEnum
class VehicleAssignmentStatus {
  static const String active = 'ACTIVE';
  static const String inactive = 'INACTIVE';
  static const String completed = 'COMPLETED';

  /// Get status label in Vietnamese
  static String getLabel(String status) {
    switch (status.toUpperCase()) {
      case active:
        return 'Đang hoạt động';
      case inactive:
        return 'Không hoạt động';
      case completed:
        return 'Hoàn thành';
      default:
        return status;
    }
  }

  /// Get status color
  static Color getColor(String status) {
    switch (status.toUpperCase()) {
      case active:
        return const Color(0xFF3B82F6); // Blue 500
      case inactive:
        return const Color(0xFF9CA3AF); // Gray 400
      case completed:
        return const Color(0xFF059669); // Green 600
      default:
        return const Color(0xFF6B7280); // Gray 500
    }
  }

  /// Get status background color for badges/chips
  static Color getBackgroundColor(String status) {
    switch (status.toUpperCase()) {
      case active:
        return const Color(0xFFDBEAFE); // Blue 100
      case inactive:
        return const Color(0xFFF3F4F6); // Gray 100
      case completed:
        return const Color(0xFFD1FAE5); // Green 100
      default:
        return const Color(0xFFF3F4F6); // Gray 100
    }
  }
}
