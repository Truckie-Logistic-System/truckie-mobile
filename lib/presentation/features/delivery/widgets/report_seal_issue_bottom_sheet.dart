import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/di/service_locator.dart';
import '../../../theme/app_colors.dart';
import '../../../../domain/entities/issue.dart';
import '../../../../domain/repositories/issue_repository.dart';
import '../../../../domain/entities/order_detail.dart';

/// Bottom sheet for driver to report seal removal issue
class ReportSealIssueBottomSheet extends StatefulWidget {
  final String vehicleAssignmentId;
  final double? currentLatitude;
  final double? currentLongitude;
  final List<VehicleSeal> availableSeals; // Seals with status IN_USE

  const ReportSealIssueBottomSheet({
    super.key,
    required this.vehicleAssignmentId,
    this.currentLatitude,
    this.currentLongitude,
    required this.availableSeals,
  });

  @override
  State<ReportSealIssueBottomSheet> createState() =>
      _ReportSealIssueBottomSheetState();
}

class _ReportSealIssueBottomSheetState
    extends State<ReportSealIssueBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _issueRepository = getIt<IssueRepository>();
  final _imagePicker = ImagePicker();

  String? _selectedSealId;
  String? _selectedIssueTypeId;
  File? _sealRemovalImage;
  bool _isSubmitting = false;
  List<IssueType> _issueTypes = [];
  bool _loadingIssueTypes = true;

  @override
  void initState() {
    super.initState();
    _loadIssueTypes();
    
    // Auto-select seal if only one available
    if (widget.availableSeals.length == 1) {
      _selectedSealId = widget.availableSeals.first.id;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadIssueTypes() async {
    try {
      final types = await _issueRepository.getActiveIssueTypes();
      setState(() {
        _issueTypes = types;
        _loadingIssueTypes = false;
        
        // Auto-select SEAL_REPLACEMENT issue type if available
        final sealIssueType = _issueTypes.firstWhere(
          (type) => type.issueCategory == IssueCategory.sealReplacement,
          orElse: () => _issueTypes.first,
        );
        _selectedIssueTypeId = sealIssueType.id;
      });
    } catch (e) {
      setState(() => _loadingIssueTypes = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tải loại sự cố: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show dialog to choose camera or gallery
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

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        setState(() {
          _sealRemovalImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn ảnh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _translateSealStatus(String status) {
    switch (status.toUpperCase()) {
      case 'IN_USE':
        return 'Đang sử dụng';
      case 'AVAILABLE':
        return 'Có sẵn';
      case 'REMOVED':
        return 'Đã gỡ';
      case 'DAMAGED':
        return 'Hư hỏng';
      default:
        return status;
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSealId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn seal bị gỡ'),
          backgroundColor: Colors.orange,
        ),
      );
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
    if (_sealRemovalImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chụp ảnh seal đã gỡ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // TODO: Upload image to server and get URL
      // For now, use local path (in production, upload to cloud storage)
      final sealRemovalImageUrl = _sealRemovalImage!.path;

      final issue = await _issueRepository.reportSealIssue(
        vehicleAssignmentId: widget.vehicleAssignmentId,
        issueTypeId: _selectedIssueTypeId!,
        sealId: _selectedSealId!,
        description: _descriptionController.text.trim(),
        sealRemovalImage: sealRemovalImageUrl,
        locationLatitude: widget.currentLatitude,
        locationLongitude: widget.currentLongitude,
      );

      if (mounted) {
        Navigator.pop(context, issue);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã báo cáo sự cố seal thành công! Staff sẽ xử lý sớm.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể báo cáo sự cố: $e'),
            backgroundColor: Colors.red,
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
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Báo cáo seal bị gỡ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Seal bị gỡ do cảnh sát giao thông yêu cầu hoặc đã đến điểm giao hàng',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Seal selection
                      const Text(
                        'Chọn seal bị gỡ *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // If only one seal, show it as read-only; otherwise show dropdown
                      widget.availableSeals.length == 1
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline, color: Colors.blue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Seal đang sử dụng',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.availableSeals.first.sealCode,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _translateSealStatus(widget.availableSeals.first.status),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedSealId,
                              decoration: InputDecoration(
                                hintText: 'Chọn seal đang sử dụng',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: widget.availableSeals.map((seal) {
                                return DropdownMenuItem<String>(
                                  value: seal.id,
                                  child: Text(
                                    '${seal.sealCode} - ${_translateSealStatus(seal.status)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedSealId = value);
                              },
                            ),

                      const SizedBox(height: 20),

                      // Issue type selection
                      const Text(
                        'Loại sự cố *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _loadingIssueTypes
                          ? const Center(child: CircularProgressIndicator())
                          : _selectedIssueTypeId != null &&
                                  _issueTypes.any((type) =>
                                      type.id == _selectedIssueTypeId &&
                                      type.issueCategory == IssueCategory.sealReplacement)
                              // Show as read-only if SEAL_REPLACEMENT is auto-selected
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.category_outlined, color: Colors.blue),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Loại sự cố',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _issueTypes.firstWhere((t) => t.id == _selectedIssueTypeId).issueTypeName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  value: _selectedIssueTypeId,
                                  decoration: InputDecoration(
                                    hintText: 'Chọn loại sự cố',
                                    prefixIcon: const Icon(Icons.category_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  items: _issueTypes.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type.id,
                                      child: Text(
                                        type.issueTypeName,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _selectedIssueTypeId = value);
                                  },
                                ),

                      const SizedBox(height: 20),

                      // Description
                      const Text(
                        'Mô tả chi tiết *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        maxLength: 200,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập mô tả';
                          }
                          // if (value.trim().length < 10) {
                          //   return 'Mô tả phải có ít nhất 10 ký tự';
                          // }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Image picker
                      const Text(
                        'Ảnh seal đã gỡ *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _sealRemovalImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _sealRemovalImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Chụp hoặc chọn ảnh seal đã gỡ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit button
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Gửi báo cáo',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
