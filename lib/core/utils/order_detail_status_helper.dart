import 'package:flutter/material.dart';

/// Helper class để xử lý OrderDetail status
class OrderDetailStatusHelper {
  /// Map OrderDetail status sang tiếng Việt
  static String getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Chờ xử lý';
      case 'ON_PLANNING':
        return 'Đang lập kế hoạch';
      case 'ASSIGNED_TO_DRIVER':
        return 'Đã phân tài xế';
      case 'PICKING_UP':
        return 'Đang lấy hàng';
      case 'ON_DELIVERED':
        return 'Đang giao hàng';
      case 'ONGOING_DELIVERED':
        return 'Đang trên đường giao';
      case 'DELIVERED':
        return 'Đã giao hàng';
      case 'SUCCESSFUL':
        return 'Hoàn thành';
      case 'IN_TROUBLES':
        return 'Có sự cố';
      case 'COMPENSATION':
        return 'Đền bù';
      case 'RETURNING':
        return 'Đang trả hàng';
      case 'RETURNED':
        return 'Đã trả hàng';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  /// Get màu nền cho status badge
  static Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.grey;
      case 'ON_PLANNING':
        return Colors.blue.shade300;
      case 'ASSIGNED_TO_DRIVER':
        return Colors.blue.shade600;
      case 'PICKING_UP':
        return Colors.orange.shade400;
      case 'ON_DELIVERED':
      case 'ONGOING_DELIVERED':
        return Colors.purple.shade400;
      case 'DELIVERED':
        return Colors.green.shade400;
      case 'SUCCESSFUL':
        return Colors.green.shade600;
      case 'IN_TROUBLES':
        return Colors.red.shade400;
      case 'COMPENSATION':
        return Colors.red.shade600;
      case 'RETURNING':
        return Colors.orange.shade600;
      case 'RETURNED':
        return Colors.brown.shade400;
      case 'CANCELLED':
        return Colors.grey.shade600;
      default:
        return Colors.grey;
    }
  }

  /// Get icon cho status
  static IconData getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.schedule;
      case 'ON_PLANNING':
        return Icons.route;
      case 'ASSIGNED_TO_DRIVER':
        return Icons.person_pin;
      case 'PICKING_UP':
        return Icons.inventory_2;
      case 'ON_DELIVERED':
      case 'ONGOING_DELIVERED':
        return Icons.local_shipping;
      case 'DELIVERED':
        return Icons.done;
      case 'SUCCESSFUL':
        return Icons.check_circle;
      case 'IN_TROUBLES':
        return Icons.warning;
      case 'COMPENSATION':
        return Icons.error;
      case 'RETURNING':
        return Icons.keyboard_return;
      case 'RETURNED':
        return Icons.assignment_return;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}
