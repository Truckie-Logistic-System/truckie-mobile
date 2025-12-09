import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/sound_utils.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/entities/order_detail.dart';
import '../../../../domain/entities/issue.dart';
import '../../../../domain/repositories/issue_repository.dart';
import '../../../../domain/repositories/photo_completion_repository.dart';
import '../../../../app/di/service_locator.dart';
import '../../../theme/app_colors.dart';
import '../widgets/issue_report/damage_section.dart';
import '../widgets/issue_report/rejection_section.dart';
import '../widgets/issue_report/delivery_confirmation_section.dart';
import '../../../widgets/waiting_dialog.dart';

/// Screen for reporting damage and/or order rejection issues
/// Full screen implementation with improved UI and better user experience
class IssueReportScreen extends StatefulWidget {
  final OrderWithDetails order;
  final VehicleAssignment vehicleAssignment;
  final double? currentLatitude;
  final double? currentLongitude;
  final IssueRepository issueRepository;

  const IssueReportScreen({
    super.key,
    required this.order,
    required this.vehicleAssignment,
    this.currentLatitude,
    this.currentLongitude,
    required this.issueRepository,
  });

  @override
  State<IssueReportScreen> createState() => _IssueReportScreenState();
}

class _IssueReportScreenState extends State<IssueReportScreen> {
  bool _isDamageExpanded = false;
  bool _isRejectionExpanded = false;
  bool _isSubmitting = false;

  // Damage section state
  final Set<String> _selectedDamageIds = {};
  List<File> _damageImages = [];
  String _damageDescription = '';
  IssueType? _selectedDamageType;
  List<IssueType> _damageTypes = [];

  // Rejection section state
  final Set<String> _selectedRejectionIds = {};

  // Delivery confirmation section state
  List<File> _deliveryConfirmationImages = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDamageTypes();
  }

  Future<void> _loadDamageTypes() async {
    try {
      final types = await widget.issueRepository.getActiveIssueTypes();
      final damageTypes =
          types.where((type) => type.issueCategory.value == 'DAMAGE').toList();

      setState(() {
        _damageTypes = damageTypes;
        if (damageTypes.isNotEmpty) {
          _selectedDamageType = damageTypes.first;
        }
      });
    } catch (e) {
      // Silent fail
    }
  }

  /// Get packages that belong to current driver's trip
  List<OrderDetail> get _currentTripPackages {
    return widget.order.orderDetails
        .where((od) => od.vehicleAssignmentId == widget.vehicleAssignment.id)
        .toList();
  }

  /// Get successful packages (not reported in damage or rejection)
  List<OrderDetail> get _successfulPackages {
    final reportedIds = {..._selectedDamageIds, ..._selectedRejectionIds};
    return _currentTripPackages
        .where((pkg) => !reportedIds.contains(pkg.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Info banner
          _buildInfoBanner(),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Damage section
                  DamageSection(
                    packages: _currentTripPackages,
                    selectedIds: _selectedDamageIds,
                    disabledIds: _selectedRejectionIds,
                    images: _damageImages,
                    description: _damageDescription,
                    isExpanded: _isDamageExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() => _isDamageExpanded = expanded);
                    },
                    onSelectionChanged: (id, isSelected) {
                      setState(() {
                        if (isSelected) {
                          _selectedDamageIds.add(id);
                        } else {
                          _selectedDamageIds.remove(id);
                        }
                      });
                    },
                    onDescriptionChanged: (desc) {
                      _damageDescription = desc;
                    },
                    onPickImages: _pickSharedDamageImages,
                    onRemoveImage: _removeSharedDamageImage,
                  ),

                  const SizedBox(height: 16),

                  // Rejection section
                  RejectionSection(
                    packages: _currentTripPackages,
                    selectedIds: _selectedRejectionIds,
                    disabledIds: _selectedDamageIds,
                    isExpanded: _isRejectionExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() => _isRejectionExpanded = expanded);
                    },
                    onSelectionChanged: (id, isSelected) {
                      setState(() {
                        if (isSelected) {
                          _selectedRejectionIds.add(id);
                        } else {
                          _selectedRejectionIds.remove(id);
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Delivery confirmation section
                  if (_successfulPackages.isNotEmpty)
                    DeliveryConfirmationSection(
                      packages: _successfulPackages,
                      images: _deliveryConfirmationImages,
                      hasIssues: _selectedDamageIds.isNotEmpty ||
                          _selectedRejectionIds.isNotEmpty,
                      onPickImages: _pickDeliveryConfirmationImages,
                      onRemoveImage: _removeDeliveryConfirmationImage,
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Submit button
          _buildBottomBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Báo cáo sự cố',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade100, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bạn có thể chọn một hoặc cả hai loại sự cố cùng lúc',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasSelection =
        _selectedDamageIds.isNotEmpty || _selectedRejectionIds.isNotEmpty;
    final canSubmit = hasSelection && !_isSubmitting;

    final hasDamageIssues = _selectedDamageIds.isNotEmpty;
    final hasDamageImages = _damageImages.isNotEmpty;
    final needsDeliveryConfirmation = _successfulPackages.isNotEmpty;
    final hasDeliveryConfirmationPhotos = _deliveryConfirmationImages.isNotEmpty;

    String buttonText;
    if (!hasSelection) {
      buttonText = 'Chọn ít nhất 1 kiện hàng';
    } else if (_isSubmitting) {
      buttonText = 'Đang gửi báo cáo...';
    } else if (hasDamageIssues && !hasDamageImages) {
      buttonText = 'Vui lòng thêm ảnh hư hại';
    } else if (needsDeliveryConfirmation && !hasDeliveryConfirmationPhotos) {
      buttonText = 'Vui lòng thêm ảnh xác nhận giao hàng';
    } else {
      int totalCount = _selectedDamageIds.length + _selectedRejectionIds.length;
      buttonText = 'Xác nhận báo cáo ($totalCount kiện)';
    }

    final bool isValid = canSubmit &&
        (!hasDamageIssues || hasDamageImages) &&
        (!needsDeliveryConfirmation || hasDeliveryConfirmationPhotos);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isValid ? _handleSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: isValid ? 2 : 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Show confirmation dialog before submitting
  Future<void> _handleSubmit() async {
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isSubmitting = true;
    });

    bool damageSuccess = false;
    bool rejectionSuccess = false;
    String? errorMessage;

    try {
      // Submit damage reports
      if (_selectedDamageIds.isNotEmpty) {
        try {
          await _submitDamageReports();
          damageSuccess = true;
        } catch (e) {
          errorMessage = 'Lỗi báo cáo hư hại: ${e.toString()}';
          throw e;
        }
      }

      // Submit rejection report
      if (_selectedRejectionIds.isNotEmpty) {
        try {
          await _submitRejectionReport();
          rejectionSuccess = true;
          
          // Show waiting dialog for customer payment
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const WaitingReturnPaymentDialog(),
            );
            print('✅ Order rejection reported, showing waiting dialog for customer payment...');
          }
        } catch (e) {
          errorMessage = 'Lỗi báo cáo trả hàng: ${e.toString()}';
          throw e;
        }
      }

      // Upload delivery confirmation photos
      bool deliverySuccess = false;
      if (_deliveryConfirmationImages.isNotEmpty) {
        try {
          await _uploadDeliveryConfirmationPhotos();
          deliverySuccess = true;
        } catch (e) {
          errorMessage = 'Lỗi upload ảnh giao hàng: ${e.toString()}';
          throw e;
        }
      }

      if (mounted) {
        SoundUtils.playSuccessSound();

        List<String> successParts = [];
        if (damageSuccess) {
          successParts.add('${_selectedDamageIds.length} kiện hư hại');
        }
        if (rejectionSuccess) {
          successParts.add('${_selectedRejectionIds.length} kiện trả hàng');
        }
        if (deliverySuccess) {
          successParts.add('${_successfulPackages.length} kiện giao thành công');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã hoàn thành: ${successParts.join(', ')}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate back to order detail with result
        // Only navigate back if no rejection report (rejection shows waiting dialog)
        final bool hasRejection = rejectionSuccess;
        final bool onlyDamage = damageSuccess && !rejectionSuccess;
        
        if (!hasRejection && mounted) {
          Navigator.pop(context, {
            'success': true,
            'shouldNavigateToCarrier': onlyDamage,
          });
        }
        // For rejection reports, the waiting dialog handles the flow
        // Navigation will happen after customer payment completes
      }
    } catch (e) {
      if (mounted) {
        SoundUtils.playErrorSound();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('❌ ${errorMessage ?? 'Lỗi không xác định'}'),
                if (damageSuccess || rejectionSuccess) ...[
                  const SizedBox(height: 4),
                  Text(
                    '✅ Đã báo cáo: ${damageSuccess ? '${_selectedDamageIds.length} kiện hư hại' : ''}${damageSuccess && rejectionSuccess ? ', ' : ''}${rejectionSuccess ? '${_selectedRejectionIds.length} kiện trả hàng' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 7),
            behavior: SnackBarBehavior.floating,
          ),
        );

        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitDamageReports() async {
    if (_selectedDamageType == null) {
      throw Exception('Vui lòng chọn loại sự cố hư hại');
    }

    if (_damageImages.isEmpty) {
      throw Exception('Vui lòng thêm ảnh hư hại');
    }

    final description = _damageDescription.trim().isEmpty
        ? 'Hàng bị hư hại'
        : _damageDescription.trim();

    // Compress shared images once
    final compressedPaths = <String>[];
    for (final image in _damageImages) {
      final compressed = await ImageCompressor.compressImage(file: image);
      if (compressed != null) {
        compressedPaths.add(compressed.path);
      }
    }

    // Report damage for each selected package
    for (final packageId in _selectedDamageIds) {
      await widget.issueRepository.reportDamageIssue(
        vehicleAssignmentId: widget.vehicleAssignment.id,
        issueTypeId: _selectedDamageType!.id,
        orderDetailId: packageId,
        description: description,
        damageImagePaths: compressedPaths,
        locationLatitude: widget.currentLatitude,
        locationLongitude: widget.currentLongitude,
      );
    }
  }

  Future<void> _submitRejectionReport() async {
    // Map từ id đã chọn sang trackingCode tương ứng vì backend yêu cầu trackingCode
    final rejectionTrackingCodes = _currentTripPackages
        .where((pkg) => _selectedRejectionIds.contains(pkg.id))
        .map((pkg) => pkg.trackingCode)
        .toList();

    await widget.issueRepository.reportOrderRejection(
      vehicleAssignmentId: widget.vehicleAssignment.id,
      orderDetailIds: rejectionTrackingCodes,
      locationLatitude: widget.currentLatitude,
      locationLongitude: widget.currentLongitude,
    );
  }

  Future<void> _pickSharedDamageImages() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_camera, color: Colors.blue.shade700),
              ),
              title: const Text('Chụp ảnh',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() {
                    _damageImages.add(File(image.path));
                  });
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_library, color: Colors.green.shade700),
              ),
              title: const Text('Chọn từ thư viện',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile> images = await _picker.pickMultiImage(
                  imageQuality: 80,
                );
                if (images.isNotEmpty) {
                  setState(() {
                    _damageImages.addAll(
                      images.map((xfile) => File(xfile.path)),
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _removeSharedDamageImage(int index) {
    setState(() {
      _damageImages.removeAt(index);
    });
  }

  Future<void> _pickDeliveryConfirmationImages() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_camera, color: Colors.blue.shade700),
              ),
              title: const Text('Chụp ảnh',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() {
                    _deliveryConfirmationImages.add(File(image.path));
                  });
                }
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_library, color: Colors.green.shade700),
              ),
              title: const Text('Chọn từ thư viện',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final List<XFile> images = await _picker.pickMultiImage(
                  imageQuality: 80,
                );
                if (images.isNotEmpty) {
                  setState(() {
                    _deliveryConfirmationImages.addAll(
                      images.map((xfile) => File(xfile.path)),
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _removeDeliveryConfirmationImage(int index) {
    setState(() {
      _deliveryConfirmationImages.removeAt(index);
    });
  }

  Future<void> _uploadDeliveryConfirmationPhotos() async {
    if (_deliveryConfirmationImages.isEmpty) return;

    final compressedImages = <File>[];
    for (final image in _deliveryConfirmationImages) {
      final compressed = await ImageCompressor.compressImage(file: image);
      if (compressed != null) {
        compressedImages.add(compressed);
      } else {
        compressedImages.add(image);
      }
    }

    final photoCompletionRepository = getIt<PhotoCompletionRepository>();
    await photoCompletionRepository.uploadMultiplePhotoCompletion(
      vehicleAssignmentId: widget.vehicleAssignment.id,
      imageFiles: compressedImages,
      description:
          'Xác nhận giao hàng thành công cho ${_successfulPackages.length} kiện',
    );
  }

  /// Show confirmation dialog with package summary
  Future<bool> _showConfirmationDialog() async {
    final damagePackages = _currentTripPackages
        .where((pkg) => _selectedDamageIds.contains(pkg.id))
        .toList();
    final rejectionPackages = _currentTripPackages
        .where((pkg) => _selectedRejectionIds.contains(pkg.id))
        .toList();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Xác nhận báo cáo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary header - simple text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vui lòng kiểm tra thông tin trước khi xác nhận',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Damage packages detail
              if (damagePackages.isNotEmpty) ...[
                _buildPackageSection(
                  title: 'Kiện hư hỏng',
                  emoji: '🔴',
                  packages: damagePackages,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
              ],

              // Rejection packages detail
              if (rejectionPackages.isNotEmpty) ...[
                _buildPackageSection(
                  title: 'Kiện trả về',
                  emoji: '🟠',
                  packages: rejectionPackages,
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
              ],

              // Successful packages detail
              if (_successfulPackages.isNotEmpty)
                _buildPackageSection(
                  title: 'Kiện giao thành công',
                  emoji: '🟢',
                  packages: _successfulPackages,
                  color: Colors.green,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Hủy',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Xác nhận',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _buildPackageSection({
    required String emoji,
    required String title,
    required List<OrderDetail> packages,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title with emoji and badge count
        Row(
          children: [
            Text(
              '$emoji $title',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color.lerp(color, Colors.black, 0.3)!,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                '${packages.length} kiện',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color.lerp(color, Colors.black, 0.3)!,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Color.lerp(color, Colors.white, 0.9)!,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color.lerp(color, Colors.white, 0.6)!),
          ),
          child: Column(
            children: packages.asMap().entries.map((entry) {
              final index = entry.key;
              final pkg = entry.value;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: index < packages.length - 1
                        ? BorderSide(color: Color.lerp(color, Colors.white, 0.6)!)
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Number badge
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color.lerp(color, Colors.white, 0.8)!,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color.lerp(color, Colors.black, 0.3)!,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Package details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tracking code
                          Row(
                            children: [
                              Icon(
                                Icons.qr_code_2,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  pkg.trackingCode,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Description
                          Text(
                            pkg.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Weight
                          Row(
                            children: [
                              Icon(
                                Icons.scale,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${pkg.weightBaseUnit} ${pkg.unit}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
