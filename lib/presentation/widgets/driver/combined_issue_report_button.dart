import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/sound_utils.dart';
import '../../../domain/entities/order_with_details.dart';
import '../../../domain/entities/order_detail.dart';
import '../../../domain/repositories/issue_repository.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';
import '../../features/orders/viewmodels/order_list_viewmodel.dart';
import '../../features/delivery/screens/issue_report_screen.dart';

/// Combined button for reporting both damage and order rejection issues
/// Navigates to full screen issue report form
class CombinedIssueReportButton extends StatelessWidget {
  final OrderWithDetails order;
  final VoidCallback onReported;
  final double? currentLatitude;
  final double? currentLongitude;
  final IssueRepository issueRepository;
  final OrderListViewModel orderListViewModel;

  const CombinedIssueReportButton({
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
      child: ElevatedButton.icon(
        onPressed: () => _navigateToIssueReportScreen(context),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
        label: const Text(
          'BÁO CÁO SỰ CỐ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.orange[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToIssueReportScreen(BuildContext context) async {
    // Play warning sound when navigating
    SoundUtils.playWarningSound();

    // Get current driver's vehicle assignment
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final currentUserPhone = authViewModel.driver?.userResponse.phoneNumber;

    if (currentUserPhone == null || currentUserPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Không thể xác định tài xế hiện tại'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Find vehicle assignment where current user is primary driver
    VehicleAssignment? currentVehicleAssignment;
    try {
      currentVehicleAssignment = order.vehicleAssignments.firstWhere(
        (va) {
          if (va.primaryDriver == null) return false;
          return currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Không tìm thấy chuyến xe của bạn'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Navigate to issue report screen
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => IssueReportScreen(
          order: order,
          vehicleAssignment: currentVehicleAssignment!,
          currentLatitude: currentLatitude,
          currentLongitude: currentLongitude,
          issueRepository: issueRepository,
        ),
      ),
    );

    // Handle result from screen
    if (result != null && result['success'] == true) {
      final shouldNavigateToCarrier = result['shouldNavigateToCarrier'] == true;

      if (shouldNavigateToCarrier) {
        // Only damage → Navigate to carrier (navigation screen)
        // Pop back to navigation screen
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        // Only rejection OR combined → Stay on order detail screen
        onReported(); // Trigger parent refresh
      }

      // Refresh order list
      try {
        orderListViewModel.refreshOrders();
      } catch (e) {
        // Silent fail
      }
    }
  }
}
