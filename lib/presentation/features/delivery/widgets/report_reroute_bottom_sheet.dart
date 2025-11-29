import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../app/di/service_locator.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/entities/order_detail.dart';
import '../../../../domain/entities/issue.dart';
import '../../../../domain/repositories/issue_repository.dart';
import '../../../../core/services/issue_resolution_handler.dart';
import '../../../../core/services/notification_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/waiting_for_resolution_dialog.dart';
import '../viewmodels/navigation_viewmodel.dart';

/// Bottom sheet for driver to report REROUTE issue
/// Driver selects affected journey segment and describes the problem
class ReportRerouteBottomSheet extends StatefulWidget {
  final String vehicleAssignmentId;
  final String issueTypeId;
  final LatLng? currentLocation;
  final OrderWithDetails orderWithDetails;
  final NavigationViewModel navigationViewModel;

  const ReportRerouteBottomSheet({
    super.key,
    required this.vehicleAssignmentId,
    required this.issueTypeId,
    this.currentLocation,
    required this.orderWithDetails,
    required this.navigationViewModel,
  });

  @override
  State<ReportRerouteBottomSheet> createState() =>
      _ReportRerouteBottomSheetState();
}

class _ReportRerouteBottomSheetState extends State<ReportRerouteBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _issueRepository = getIt<IssueRepository>();
  final ImagePicker _imagePicker = ImagePicker();
  late final IssueResolutionHandler _resolutionHandler;

  bool _isSubmitting = false;
  List<File> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _resolutionHandler = getIt<IssueResolutionHandler>();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _resolutionHandler.dispose();
    super.dispose();
  }

  /// Pick images from camera or gallery
  Future<void> _pickImages() async {
    try {
      // Show dialog to choose source
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chọn nguồn ảnh'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Chụp ảnh'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick image(s)
      final List<XFile>? pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(pickedFiles.map((xFile) => File(xFile.path)));
          // Limit to 5 images max
          if (_selectedImages.length > 5) {
            _selectedImages = _selectedImages.take(5).toList();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chỉ có thể chọn tối đa 5 ảnh'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chọn ảnh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Remove selected image
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  JourneySegment? _getCurrentActiveSegment() {
    // Get current vehicle assignment
    final vehicleAssignment = widget.orderWithDetails.vehicleAssignments
        .firstWhere((va) => va.id == widget.vehicleAssignmentId);

    // Get active journey
    final activeJourney = vehicleAssignment.journeyHistories
        .where((j) => j.status == 'ACTIVE')
        .toList();

    if (activeJourney.isEmpty) {
      return null;
    }

    // Use NavigationViewModel's current segment index if available
    if (widget.navigationViewModel.routeSegments.isNotEmpty &&
        widget.navigationViewModel.currentSegmentIndex <
            activeJourney.first.journeySegments.length) {
      return activeJourney.first.journeySegments[widget
          .navigationViewModel
          .currentSegmentIndex];
    }

    // Fallback: Get the first segment with status ACTIVE
    return activeJourney.first.journeySegments
        .where((seg) => seg.status == 'ACTIVE')
        .firstOrNull;
  }

  Future<void> _submitRerouteIssue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currentSegment = _getCurrentActiveSegment();
    if (currentSegment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy đoạn đường đang hoạt động'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1️⃣ Report issue to backend
      print('📤 Reporting reroute issue...');
      final issue = await _issueRepository.reportRerouteIssue(
        vehicleAssignmentId: widget.vehicleAssignmentId,
        issueTypeId: widget.issueTypeId,
        affectedSegmentId: currentSegment.id,
        description: _descriptionController.text.trim(),
        locationLatitude: widget.currentLocation?.latitude,
        locationLongitude: widget.currentLocation?.longitude,
        images: _selectedImages,
      );

      final issueId = issue.id;
      print('✅ Issue reported: $issueId');

      if (mounted) {
        // Close the report bottom sheet first
        Navigator.pop(context, true);

        // 2️⃣ Show waiting dialog - CANNOT be dismissed by driver
        // Driver must wait for staff resolution or timeout
        showDialog(
          context: context,
          barrierDismissible:
              false, // ⚠️ CRITICAL: Prevent tap outside to dismiss
          builder: (context) =>
              WaitingForResolutionDialog(issueCategory: IssueCategory.reroute),
        );

        // 3️⃣ Wait for resolution with Hybrid Pattern (WebSocket + Polling)
        final resolvedIssue = await _resolutionHandler
            .reportAndWaitForResolution(
              context: context,
              issueId: issueId,
              issueCategory: IssueCategory.reroute,
              onTimeout: () {
                // Timeout: Staff hasn't resolved after 5 minutes
                if (mounted) {
                  Navigator.of(context).pop(); // Close waiting dialog

                  showDialog(
                    context: context,
                    builder: (context) => ResolutionTimeoutDialog(
                      issueCategory: IssueCategory.reroute,
                      onDismiss: () => Navigator.of(context).pop(),
                    ),
                  );
                }
              },
            );

        // 4️⃣ Handle resolution
        if (resolvedIssue != null && mounted) {
          Navigator.of(context).pop(); // Close waiting dialog

          // ✅ FIX: Don't show duplicate dialog here
          // NotificationService will emit stream event and NavigationScreen will show dialog
          // This prevents dialog stacking issue where user has to dismiss 2 dialogs
          print('✅ Reroute resolved, NotificationService will handle dialog');
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể báo cáo sự cố: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// ⚠️ DEPRECATED: Removed to fix dialog stacking issue
  /// NotificationService now handles the resolved dialog
  @Deprecated('Use NotificationService stream instead')
  Future<void> _showRerouteResolvedDialog() async {
    // Dialog removed - NotificationService will show it via stream
  }

  String _getCurrentSegmentDisplay() {
    final currentSegment = _getCurrentActiveSegment();
    if (currentSegment == null) {
      return 'Không có đoạn đường nào đang hoạt động';
    }

    // Use NavigationViewModel's segment name if available
    if (widget.navigationViewModel.routeSegments.isNotEmpty &&
        widget.navigationViewModel.currentSegmentIndex <
            widget.navigationViewModel.routeSegments.length) {
      final routeSegmentName = widget.navigationViewModel
          .getCurrentSegmentName();
      return '${currentSegment.segmentOrder}. $routeSegmentName';
    }

    return '${currentSegment.segmentOrder}. ${currentSegment.startPointName} → ${currentSegment.endPointName}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.alt_route,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Báo cáo tái định tuyến',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Current Segment Info
                  Text(
                    'Đoạn đường đang hoạt động',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 1),
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.primary.withOpacity(0.05),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${_getCurrentActiveSegment()?.segmentOrder ?? widget.navigationViewModel.currentSegmentIndex + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getCurrentSegmentDisplay(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description Field
                  Text(
                    'Mô tả vấn đề',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText:
                          'Mô tả vấn đề gặp phải (đường bị sập, tắc đường...)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 4,
                    maxLength: 200,
                    style: AppTextStyles.bodyMedium,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập mô tả sự cố';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Image Upload Section (Optional)
                  Text(
                    'Hình ảnh (tùy chọn)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Selected Images Preview
                  if (_selectedImages.isNotEmpty)
                    Container(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          final imageFile = _selectedImages[index];
                          return Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      imageFile,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey.shade100,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                // Remove button
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  // Add Images Button
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _selectedImages.isEmpty
                          ? 'Thêm ảnh minh họa'
                          : 'Thêm ảnh khác (${_selectedImages.length}/5)',
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedImages.isEmpty)
                    Text(
                      'Bạn có thể thêm hình ảnh để minh họa cho sự cố (tối đa 5 ảnh)',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Location Info
                  if (widget.currentLocation != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Vị trí hiện tại sẽ được gửi kèm',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nhân viên sẽ tạo lộ trình mới tránh khu vực gặp sự cố. Bạn sẽ nhận thông báo khi lộ trình mới đã sẵn sàng.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRerouteIssue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Gửi báo cáo',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
