import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../domain/entities/issue.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/repositories/issue_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'report_seal_replacement_bottom_sheet.dart';
import 'damage_report_bottom_sheet.dart';

/// Bottom sheet widget để driver báo cáo issue
class ReportIssueBottomSheet extends StatefulWidget {
  final String vehicleAssignmentId;
  final LatLng? currentLocation;
  final OrderWithDetails? orderWithDetails;

  const ReportIssueBottomSheet({
    super.key,
    required this.vehicleAssignmentId,
    this.currentLocation,
    this.orderWithDetails,
  });

  @override
  State<ReportIssueBottomSheet> createState() => _ReportIssueBottomSheetState();
}

class _ReportIssueBottomSheetState extends State<ReportIssueBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _issueRepository = getIt<IssueRepository>();

  List<IssueType> _issueTypes = [];
  String? _selectedIssueTypeId;
  bool _isLoadingTypes = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadIssueTypes();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadIssueTypes() async {
    setState(() {
      _isLoadingTypes = true;
    });

    try {
      final types = await _issueRepository.getActiveIssueTypes();
      
      // debugPrint('📋 Loaded ${types.length} issue types:');
      // for (var type in types) {
      //   debugPrint('   - ${type.issueTypeName}: ${type.issueCategory.value}');
      // }
      
      setState(() {
        _issueTypes = types;
        _isLoadingTypes = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading issue types: $e');
      setState(() {
        _isLoadingTypes = false;
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

  Future<void> _handleIssueTypeSelection(String? issueTypeId) async {
    if (issueTypeId == null) return;

    // Find selected issue type
    final selectedType = _issueTypes.firstWhere(
      (type) => type.id == issueTypeId,
      orElse: () => _issueTypes.first,
    );

    debugPrint('📋 Selected issue type: ${selectedType.issueTypeName}');
    debugPrint('📋 Category: ${selectedType.issueCategory}');
    debugPrint('📋 Category value: ${selectedType.issueCategory.value}');

    // Check if it's SEAL_REPLACEMENT category
    if (selectedType.issueCategory == IssueCategory.sealReplacement) {
      debugPrint('🔓 SEAL_REPLACEMENT category detected, showing seal replacement form');
      
      // Close current bottom sheet
      Navigator.pop(context);
      
      // Show seal replacement bottom sheet
      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ReportSealReplacementBottomSheet(
          vehicleAssignmentId: widget.vehicleAssignmentId,
          issueTypeId: issueTypeId,
          currentLocation: widget.currentLocation,
        ),
      );

      // If issue was created successfully, refresh data
      if (result != null && mounted) {
        debugPrint('✅ Seal issue created, refreshing data...');
      }
    } else if (selectedType.issueCategory == IssueCategory.damage) {
      debugPrint('📦 DAMAGE category detected, showing damage report form');
      
      // Check if we have order details
      if (widget.orderWithDetails == null || widget.orderWithDetails!.orderDetails.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có thông tin đơn hàng để báo cáo hư hại'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Close current bottom sheet
      Navigator.pop(context);
      
      // Convert order details to simple list for dropdown
      final orderDetailsList = widget.orderWithDetails!.orderDetails.map((detail) {
        return {
          'id': detail.id,
          'description': detail.description,
          'trackingCode': detail.trackingCode,
          'unit': detail.unit,
        };
      }).toList();
      
      // Show damage report bottom sheet
      debugPrint('📍 [ReportIssueBottomSheet] Opening damage report with location:');
      debugPrint('   - Latitude: ${widget.currentLocation?.latitude}');
      debugPrint('   - Longitude: ${widget.currentLocation?.longitude}');
      
      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DamageReportBottomSheet(
          vehicleAssignmentId: widget.vehicleAssignmentId,
          issueTypeId: issueTypeId,
          currentLatitude: widget.currentLocation?.latitude,
          currentLongitude: widget.currentLocation?.longitude,
          orderDetails: orderDetailsList,
        ),
      );

      // If issue was created successfully, refresh data
      if (result != null && mounted) {
        debugPrint('✅ Damage report created, refreshing data...');
      }
    } else {
      // For other categories, just update selected ID
      setState(() {
        _selectedIssueTypeId = issueTypeId;
      });
    }
  }

  void _showIssueTypeModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Chọn loại sự cố',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            // Issue types list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _issueTypes.length,
                itemBuilder: (context, index) {
                  final type = _issueTypes[index];
                  final isSelected = type.id == _selectedIssueTypeId;
                  
                  return ListTile(
                    title: Text(
                      type.issueTypeName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.orange : Colors.black,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.orange)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _handleIssueTypeSelection(type.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedIssueTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn loại sự cố'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      debugPrint('📤 Submitting issue...');
      debugPrint('   - Description: ${_descriptionController.text}');
      debugPrint('   - Issue Type ID: $_selectedIssueTypeId');
      debugPrint('   - Vehicle Assignment ID: ${widget.vehicleAssignmentId}');
      debugPrint('   - Location: ${widget.currentLocation?.latitude}, ${widget.currentLocation?.longitude}');

      final issue = await _issueRepository.createIssue(
        description: _descriptionController.text.trim(),
        issueTypeId: _selectedIssueTypeId!,
        vehicleAssignmentId: widget.vehicleAssignmentId,
        locationLatitude: widget.currentLocation?.latitude,
        locationLongitude: widget.currentLocation?.longitude,
      );

      debugPrint('✅ Issue created successfully: ${issue.id}');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã báo cáo sự cố thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error submitting issue: $e');
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
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Báo cáo sự cố',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
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

                  // Issue Type Dropdown
                  Text(
                    'Loại sự cố',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isLoadingTypes
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : GestureDetector(
                          onTap: _isLoadingTypes ? null : () => _showIssueTypeModal(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade50,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedIssueTypeId == null
                                      ? 'Chọn loại sự cố'
                                      : _issueTypes
                                          .firstWhere(
                                            (type) => type.id == _selectedIssueTypeId,
                                            orElse: () => _issueTypes.first,
                                          )
                                          .issueTypeName,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: _selectedIssueTypeId == null
                                        ? Colors.grey.shade600
                                        : Colors.black,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),

                  // Description Field
                  Text(
                    'Mô tả chi tiết',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Mô tả vấn đề gặp phải...',
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
                      // if (value.trim().length <
                      //   return 'Mô tả phải có ít nhất 10 ký tự'; 10) {
                      // }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Location Info
                  if (widget.currentLocation != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.shade200,
                        ),
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

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitIssue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
