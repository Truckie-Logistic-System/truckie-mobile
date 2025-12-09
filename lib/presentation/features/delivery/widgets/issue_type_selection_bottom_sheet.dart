import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../domain/entities/issue.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/repositories/issue_repository.dart';
import '../../../theme/app_text_styles.dart';
import 'report_seal_replacement_bottom_sheet.dart';
import 'damage_report_bottom_sheet.dart';
import 'penalty_report_bottom_sheet.dart';
import 'report_reroute_bottom_sheet.dart';
import '../viewmodels/navigation_viewmodel.dart';
import 'report_issue_bottom_sheet.dart';

/// Bottom sheet hiển thị danh sách loại sự cố để driver chọn
/// Thay thế dropdown bằng grid layout đẹp và dễ sử dụng hơn
class IssueTypeSelectionBottomSheet extends StatefulWidget {
  final String vehicleAssignmentId;
  final LatLng? currentLocation;
  final OrderWithDetails? orderWithDetails;
  final NavigationViewModel? navigationViewModel;

  const IssueTypeSelectionBottomSheet({
    super.key,
    required this.vehicleAssignmentId,
    this.currentLocation,
    this.orderWithDetails,
    this.navigationViewModel,
  });

  @override
  State<IssueTypeSelectionBottomSheet> createState() =>
      _IssueTypeSelectionBottomSheetState();
}

class _IssueTypeSelectionBottomSheetState
    extends State<IssueTypeSelectionBottomSheet> {
  final _issueRepository = getIt<IssueRepository>();

  List<IssueType> _issueTypes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIssueTypes();
  }

  /// Business rule cho phép báo seal dựa trên segment hiện tại thay vì chỉ status
  /// - Nếu đoạn hiện tại là "Đơn vị vận chuyển → Điểm lấy hàng" thì KHÔNG cho báo seal
  /// - Các đoạn còn lại (Pickup → Delivery, Delivery → Return, ...) thì cho phép
  bool _canReportSealOnCurrentSegment() {
    // Nếu không có NavigationViewModel thì fallback theo order status cũ
    if (widget.navigationViewModel == null) {
      return _isOrderStatusPickingUpOrLater();
    }

    final segmentName = widget.navigationViewModel!.getCurrentSegmentName();

    // SegmentName đã được translate trong NavigationViewModel, ví dụ:
    // "Đơn vị vận chuyển → Điểm lấy hàng"
    final isCarrierToPickup =
        segmentName.contains('Đơn vị vận chuyển') &&
        segmentName.contains('Điểm lấy hàng');

    if (isCarrierToPickup) {
      return false;
    }

    return true;
  }

  Future<void> _loadIssueTypes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final types = await _issueRepository.getActiveIssueTypes();
      final filteredTypes = _filterIssueTypes(types);
      setState(() {
        _issueTypes = filteredTypes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải danh sách loại sự cố: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Filter issue types based on business rules
  List<IssueType> _filterIssueTypes(List<IssueType> types) {
    return types.where((type) {
      // Hide damage and order rejection issues
      if (type.issueCategory == IssueCategory.damage ||
          type.issueCategory == IssueCategory.orderRejection ||
          type.issueCategory == IssueCategory.offRouteRunaway) {
        return false;
      }
      
      // Only show seal replacement khi driver đã rời khỏi chặng "Đơn vị vận chuyển → Điểm lấy hàng"
      // Tránh cho phép báo seal khi còn đang chạy từ kho ra điểm lấy hàng
      if (type.issueCategory == IssueCategory.sealReplacement) {
        return _canReportSealOnCurrentSegment();
      }
      
      // Show all other types
      return true;
    }).toList();
  }

  /// Check if order status is picking_up or later
  bool _isOrderStatusPickingUpOrLater() {
    if (widget.orderWithDetails?.orderDetails.isEmpty ?? true) {
      return false;
    }
    
    // Get the status of the first order detail (for current trip)
    final orderDetail = widget.orderWithDetails!.orderDetails.first;
    final status = orderDetail.status?.toLowerCase();
    
    if (status == null) return false;
    
    // Define the order of statuses
    final statusOrder = [
      'pending',
      'processing', 
      'contract_draft',
      'contract_signed',
      'on_planning',
      'assigned_to_driver',
      'picking_up', // From this status onward, seal replacement is allowed
      'on_delivered',
      'ongoing_delivered',
      'delivered',
      'returning',
      'returned',
      'cancelled',
      'compensation'
    ];
    
    final currentIndex = statusOrder.indexOf(status);
    final pickingUpIndex = statusOrder.indexOf('picking_up');
    
    return currentIndex >= pickingUpIndex;
  }

  /// Get icon and color for issue category
  Map<String, dynamic> _getIssueTypeStyle(IssueCategory category) {
    switch (category) {
      case IssueCategory.damage:
        return {
          'icon': Icons.broken_image_outlined,
          'color': Colors.orange,
          'bgColor': Colors.orange.withValues(alpha: 0.1),
        };
      case IssueCategory.sealReplacement:
        return {
          'icon': Icons.verified_user_outlined,
          'color': Colors.blue,
          'bgColor': Colors.blue.withValues(alpha: 0.1),
        };
      case IssueCategory.penalty:
        return {
          'icon': Icons.gavel_outlined,
          'color': Colors.red.shade700,
          'bgColor': Colors.red.withValues(alpha: 0.1),
        };
      case IssueCategory.reroute:
        return {
          'icon': Icons.alt_route,
          'color': Colors.purple,
          'bgColor': Colors.purple.withValues(alpha: 0.1),
        };
      default:
        return {
          'icon': Icons.warning_amber_rounded,
          'color': Colors.amber.shade700,
          'bgColor': Colors.amber.withValues(alpha: 0.1),
        };
    }
  }

  Future<void> _handleIssueTypeSelection(IssueType issueType) async {
    // Close current bottom sheet first
    Navigator.pop(context);

    // Wait a bit for smooth transition
    await Future.delayed(const Duration(milliseconds: 200));

    // Handle different issue categories
    switch (issueType.issueCategory) {
      case IssueCategory.sealReplacement:
        if (!mounted) return;
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ReportSealReplacementBottomSheet(
            vehicleAssignmentId: widget.vehicleAssignmentId,
            issueTypeId: issueType.id,
            currentLocation: widget.currentLocation,
          ),
        );
        if (result != null && mounted) {
          // Success feedback handled by parent
        }
        break;

      case IssueCategory.damage:
        if (widget.orderWithDetails == null ||
            widget.orderWithDetails!.orderDetails.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không có thông tin đơn hàng để báo cáo hư hại'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        final orderDetailsList =
            widget.orderWithDetails!.orderDetails.map((detail) {
          return {
            'id': detail.id,
            'description': detail.description,
            'trackingCode': detail.trackingCode,
            'unit': detail.unit,
          };
        }).toList();

        if (!mounted) return;
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DamageReportBottomSheet(
            vehicleAssignmentId: widget.vehicleAssignmentId,
            issueTypeId: issueType.id,
            currentLatitude: widget.currentLocation?.latitude,
            currentLongitude: widget.currentLocation?.longitude,
            orderDetails: orderDetailsList,
          ),
        );
        if (result == true && mounted) {
          // Success feedback handled by parent
        }
        break;

      case IssueCategory.penalty:
        if (!mounted) return;
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PenaltyReportBottomSheet(
            vehicleAssignmentId: widget.vehicleAssignmentId,
            issueTypeId: issueType.id,
            currentLatitude: widget.currentLocation?.latitude,
            currentLongitude: widget.currentLocation?.longitude,
          ),
        );
        if (result != null && mounted) {
          // Success feedback handled by parent
        }
        break;

      case IssueCategory.reroute:
        if (widget.orderWithDetails == null ||
            widget.navigationViewModel == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy thông tin điều hướng'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        if (!mounted) return;
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ReportRerouteBottomSheet(
            vehicleAssignmentId: widget.vehicleAssignmentId,
            issueTypeId: issueType.id,
            currentLocation: widget.currentLocation,
            orderWithDetails: widget.orderWithDetails!,
            navigationViewModel: widget.navigationViewModel!,
          ),
        );
        if (result == true) {
          // Success feedback handled by parent
        }
        break;

      default:
        // For other general issues, show the standard report form
        if (!mounted) return;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ReportIssueBottomSheet(
            vehicleAssignmentId: widget.vehicleAssignmentId,
            currentLocation: widget.currentLocation,
            orderWithDetails: widget.orderWithDetails,
            navigationViewModel: widget.navigationViewModel,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header với drag handle
            Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.report_problem_outlined,
                          color: Colors.red,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Báo cáo sự cố',
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              'Chọn loại sự cố gặp phải',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Issue types grid
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else if (_issueTypes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Không có loại sự cố nào',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: _issueTypes.map((issueType) {
                      final style = _getIssueTypeStyle(issueType.issueCategory);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _IssueTypeCard(
                          issueType: issueType,
                          icon: style['icon'] as IconData,
                          color: style['color'] as Color,
                          bgColor: style['bgColor'] as Color,
                          onTap: () => _handleIssueTypeSelection(issueType),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Card hiển thị từng loại sự cố
class _IssueTypeCard extends StatelessWidget {
  final IssueType issueType;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _IssueTypeCard({
    required this.issueType,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issueType.issueTypeName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (issueType.description != null &&
                        issueType.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        issueType.description!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
