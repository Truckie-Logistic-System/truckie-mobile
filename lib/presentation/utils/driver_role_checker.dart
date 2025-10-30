import 'package:flutter/material.dart';
import '../../domain/entities/order_with_details.dart';
import '../features/auth/viewmodels/auth_viewmodel.dart';

/// Utility class để kiểm tra driver role và permissions
class DriverRoleChecker {
  /// Kiểm tra xem user hiện tại có phải là primary driver của order không
  /// Sử dụng phone number làm unique identifier (ID có thể khác giữa auth và order response)
  /// Với multi-trip orders, tìm vehicle assignment của user hiện tại
  static bool isPrimaryDriver(OrderWithDetails order, AuthViewModel authViewModel) {
    if (order.orderDetails.isEmpty || order.vehicleAssignments.isEmpty) {
      return false;
    }
    
    // Get current user phone number (most reliable identifier)
    final currentUserPhone = authViewModel.driver?.userResponse.phoneNumber;
    if (currentUserPhone == null || currentUserPhone.isEmpty) {
      return false;
    }
    
    // For multi-trip orders: Find the vehicle assignment where current user is primary driver
    // Instead of just using first orderDetail, check all assignments
    final userVehicleAssignment = order.vehicleAssignments.cast<dynamic>().firstWhere(
      (va) {
        if (va == null) return false;
        final primaryDriver = va.primaryDriver;
        if (primaryDriver == null) return false;
        return currentUserPhone.trim() == primaryDriver.phoneNumber.trim();
      },
      orElse: () => null,
    );
    
    if (userVehicleAssignment == null) {
      debugPrint('   ❌ NOT MATCHED: Current user is not primary driver of any vehicle assignment');
      return false;
    }
    
    // debugPrint('   ✅ MATCHED: Current user IS PRIMARY DRIVER');
    return true;
  }
  
  /// Kiểm tra xem user hiện tại có phải là secondary driver của order không
  /// Sử dụng phone number làm unique identifier
  /// Với multi-trip orders, tìm vehicle assignment của user hiện tại
  static bool isSecondaryDriver(OrderWithDetails order, AuthViewModel authViewModel) {
    if (order.orderDetails.isEmpty || order.vehicleAssignments.isEmpty) return false;
    
    // Get current user phone number (most reliable identifier)
    final currentUserPhone = authViewModel.driver?.userResponse.phoneNumber;
    if (currentUserPhone == null || currentUserPhone.isEmpty) return false;
    
    // For multi-trip orders: Find the vehicle assignment where current user is secondary driver
    final userVehicleAssignment = order.vehicleAssignments.cast<dynamic>().firstWhere(
      (va) {
        if (va == null) return false;
        final secondaryDriver = va.secondaryDriver;
        if (secondaryDriver == null) return false;
        return currentUserPhone.trim() == secondaryDriver.phoneNumber.trim();
      },
      orElse: () => null,
    );
    
    return userVehicleAssignment != null;
  }
  
  /// Kiểm tra xem user hiện tại có được phép thực hiện actions trên order không
  /// Chỉ primary driver mới được phép thực hiện actions
  static bool canPerformActions(OrderWithDetails order, AuthViewModel authViewModel) {
    return isPrimaryDriver(order, authViewModel);
  }
  
  /// Lấy thông tin role của user hiện tại
  static String getUserRole(OrderWithDetails order, AuthViewModel authViewModel) {
    if (isPrimaryDriver(order, authViewModel)) {
      return 'primary_driver';
    } else if (isSecondaryDriver(order, authViewModel)) {
      return 'secondary_driver';
    } else {
      return 'unknown';
    }
  }
  
  /// Lấy thông tin role hiển thị cho user
  static String getUserRoleDisplayName(OrderWithDetails order, AuthViewModel authViewModel) {
    if (isPrimaryDriver(order, authViewModel)) {
      return 'Tài xế chính';
    } else if (isSecondaryDriver(order, authViewModel)) {
      return 'Tài xế phụ';
    } else {
      return 'Không xác định';
    }
  }
  
  /// Lấy thông báo khi secondary driver cố gắng thực hiện action
  static String getSecondaryDriverActionMessage() {
    return 'Chỉ tài xế chính mới có thể thực hiện hành động này. Bạn đang đăng nhập với tài khoản tài xế phụ.';
  }
  
  /// Hiển thị thông báo khi secondary driver cố gắng thực hiện action
  static void showSecondaryDriverActionDialog(BuildContext context, OrderWithDetails order, AuthViewModel authViewModel) {
    if (!canPerformActions(order, authViewModel)) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade700,
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Text('Quyền hạn bị giới hạn'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(getSecondaryDriverActionMessage()),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Vai trò hiện tại: ${getUserRoleDisplayName(order, authViewModel)}',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đã hiểu'),
              ),
            ],
          );
        },
      );
    }
  }
}
