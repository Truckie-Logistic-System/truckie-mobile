import 'package:flutter/material.dart';

import '../../../domain/entities/order_with_details.dart';
import '../../../domain/repositories/issue_repository.dart';
import '../../features/orders/viewmodels/order_list_viewmodel.dart';
import 'order_rejection_package_selector.dart';

/// Button widget để báo cáo người nhận từ chối nhận hàng
/// Hiển thị modal để driver chọn các kiện hàng cần trả
class OrderRejectionButton extends StatelessWidget {
  final OrderWithDetails order;
  final VoidCallback onReported;
  final double? currentLatitude;
  final double? currentLongitude;
  final IssueRepository issueRepository;
  final OrderListViewModel orderListViewModel;

  const OrderRejectionButton({
    super.key,
    required this.order,
    required this.onReported,
    this.currentLatitude,
    this.currentLongitude,
    required this.issueRepository,
    required this.orderListViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showOrderRejectionDialog(context),
        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
        label: const Text(
          'NGƯỜI NHẬN TỪ CHỐI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.red, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _showOrderRejectionDialog(BuildContext context) async {
    // Convert OrderDetails to PackageItems
    final packages = order.orderDetails
        .map((detail) => PackageItem(
              id: detail.id,
              trackingCode: detail.trackingCode,
              description: detail.description,
              weight: detail.weightBaseUnit,
              unit: detail.unit,
            ))
        .toList();

    if (packages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Không tìm thấy kiện hàng nào'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get vehicleAssignmentId before opening modal
    final vehicleAssignmentId = order.orderDetails.isNotEmpty
        ? order.orderDetails.first.vehicleAssignmentId
        : null;

    if (vehicleAssignmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Không tìm thấy thông tin phân công xe'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show package selector modal
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => OrderRejectionPackageSelector(
        packages: packages,
        onConfirm: (selectedIds) async {
          Navigator.pop(modalContext); // Close modal
          // Use parent context for API call
          await _reportOrderRejection(
            context, // Parent context with ScaffoldMessenger
            vehicleAssignmentId,
            selectedIds,
            issueRepository,
            orderListViewModel,
          );
        },
      ),
    );
  }

  Future<void> _reportOrderRejection(
    BuildContext context,
    String vehicleAssignmentId,
    List<String> orderDetailIds,
    IssueRepository issueRepository,
    OrderListViewModel orderListViewModel,
  ) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang báo cáo...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await issueRepository.reportOrderRejection(
        vehicleAssignmentId: vehicleAssignmentId,
        orderDetailIds: orderDetailIds,
        locationLatitude: currentLatitude,
        locationLongitude: currentLongitude,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Đã báo cáo ${orderDetailIds.length} kiện hàng bị từ chối!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Trigger refresh
        onReported();

        // Refresh order list
        try {
          orderListViewModel.refreshOrders();
        } catch (e) {
          debugPrint('⚠️ Could not refresh order list: $e');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
