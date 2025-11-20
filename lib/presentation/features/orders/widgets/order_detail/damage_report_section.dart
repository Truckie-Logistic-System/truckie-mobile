import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../app/di/service_locator.dart';
import '../../../../../domain/entities/issue.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../domain/repositories/issue_repository.dart';
import '../../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';
import '../../../delivery/widgets/damage_report_bottom_sheet.dart';

class DamageReportSection extends StatefulWidget {
  final OrderWithDetails order;
  final VoidCallback onReported;
  final double? currentLatitude;
  final double? currentLongitude;

  const DamageReportSection({
    super.key,
    required this.order,
    required this.onReported,
    this.currentLatitude,
    this.currentLongitude,
  });

  @override
  State<DamageReportSection> createState() => _DamageReportSectionState();
}

class _DamageReportSectionState extends State<DamageReportSection> {
  final List<File> _damageImages = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descriptionController = TextEditingController();
  final IssueRepository _issueRepository = getIt<IssueRepository>();
  
  bool _isLoading = false;
  bool _showForm = false;
  bool _showImagePreview = false;
  int? _previewImageIndex;
  List<IssueType> _damageIssueTypes = [];
  IssueType? _selectedIssueType;
  String? _selectedOrderDetailId;  // Selected order detail (package)

  @override
  void initState() {
    super.initState();
    _loadDamageIssueTypes();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDamageIssueTypes() async {
    try {
      final types = await _issueRepository.getActiveIssueTypes();
      // Filter only DAMAGE category issue types
      final damageTypes = types.where((type) => 
        type.issueCategory?.value == 'DAMAGE'
      ).toList();
      
      setState(() {
        _damageIssueTypes = damageTypes;
        if (damageTypes.isNotEmpty) {
          _selectedIssueType = damageTypes.first;
        }
      });
    } catch (e) {
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

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Chụp ảnh mới'),
                subtitle: const Text('Chụp 1 ảnh từ camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                subtitle: const Text('Chọn nhiều ảnh cùng lúc'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _damageImages.add(File(image.path));
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 80,
    );

    if (images.isNotEmpty) {
      setState(() {
        _damageImages.addAll(images.map((xfile) => File(xfile.path)));
      });
    }
  }

  void _showImagePreviewDialog(int index) {
    if (_damageImages.isEmpty) return;

    setState(() {
      _showImagePreview = true;
      _previewImageIndex = index;
    });
  }

  void _removeImage(int index) {
    setState(() {
      _damageImages.removeAt(index);
    });
  }

  /// Get vehicle assignment of current driver
  VehicleAssignment? _getCurrentUserVehicleAssignment(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final currentUserPhone = authViewModel.driver?.userResponse?.phoneNumber;
    
    if (currentUserPhone == null || currentUserPhone.isEmpty) {
      return null;
    }
    
    try {
      return widget.order.vehicleAssignments.firstWhere(
        (va) {
          if (va.primaryDriver == null) return false;
          return currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
        },
      );
    } catch (e) {
      return null;
    }
  }

  void _showDamageReportBottomSheet() {
    // CRITICAL FIX: Get vehicle assignment of CURRENT DRIVER
    // Bug: vehicleAssignments.first might belong to another driver in multi-trip orders
    final vehicleAssignment = _getCurrentUserVehicleAssignment(context);
    
    if (vehicleAssignment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Không tìm thấy chuyến xe của bạn'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get damage issue type
    _issueRepository.getActiveIssueTypes().then((types) {
      final damageType = types.firstWhere(
        (type) => type.issueCategory?.value == 'DAMAGE',
        orElse: () => types.first,
      );

      // Convert order details to simple list for dropdown
      final orderDetailsList = widget.order.orderDetails.map((detail) {
        return {
          'id': detail.id,
          'description': detail.description,
          'trackingCode': detail.trackingCode,
          'unit': detail.unit,
        };
      }).toList();

      // Show bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DamageReportBottomSheet(
          vehicleAssignmentId: vehicleAssignment.id,
          issueTypeId: damageType.id,
          currentLatitude: widget.currentLatitude,
          currentLongitude: widget.currentLongitude,
          orderDetails: orderDetailsList,
        ),
      ).then((result) {
        if (result == true && mounted) {
          // Pop back to navigation screen so driver can continue trip and resume simulator
          // Pass true to indicate issue was reported successfully
          Navigator.of(context).pop(true);
        }
      });
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  Future<void> _reportDamage(BuildContext context) async {
    if (_selectedOrderDetailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn kiện hàng bị hư hại'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_damageImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chụp ít nhất một ảnh hàng hóa hư hại'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng mô tả tình trạng hư hại'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedIssueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy loại sự cố phù hợp'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      // Use location passed from parent widget (consistent with seal report approach)
      // CRITICAL FIX: Get vehicle assignment ID from CURRENT DRIVER
      // Bug: vehicleAssignments.first might belong to another driver in multi-trip orders
      final vehicleAssignment = _getCurrentUserVehicleAssignment(context);
      if (vehicleAssignment == null) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Không tìm thấy chuyến xe của bạn'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Report damage issue
      await _issueRepository.reportDamageIssue(
        vehicleAssignmentId: vehicleAssignment.id,
        issueTypeId: _selectedIssueType!.id,
        orderDetailId: _selectedOrderDetailId!,
        description: _descriptionController.text.trim(),
        damageImagePaths: _damageImages.map((file) => file.path).toList(),
        locationLatitude: widget.currentLatitude,
        locationLongitude: widget.currentLongitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã báo cáo hàng hư hại thành công! Bạn có thể tiếp tục chuyến đi. Staff sẽ xử lý hoàn tiền sau.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Call callback to refresh order details
        widget.onReported();

        // Close the form
        setState(() {
          _showForm = false;
          _damageImages.clear();
          _descriptionController.clear();
          _selectedOrderDetailId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showImagePreview) {
      return _buildImagePreview();
    } else if (_showForm) {
      return _buildForm();
    } else {
      return _buildButton();
    }
  }

  Widget _buildImagePreview() {
    if (_damageImages.isEmpty || _previewImageIndex == null) {
      setState(() {
        _showImagePreview = false;
      });
      return _buildForm();
    }

    final currentImage = _damageImages[_previewImageIndex!];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Xem ảnh hàng hư hại',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _showImagePreview = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              currentImage,
              fit: BoxFit.contain,
              height: 200,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ảnh ${_previewImageIndex! + 1}/${_damageImages.length}',
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showImageSourceOptions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('CHỤP LẠI'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _showImagePreview = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('XÁC NHẬN'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.deepOrange.shade700],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _showDamageReportBottomSheet,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.report_problem_outlined, size: 20),
            SizedBox(width: 8),
            Text('BÁO CÁO HÀNG HƯ HẠI'),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Báo cáo hàng hóa hư hại',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Order Detail Selection
          Text(
            'Chọn kiện hàng bị hư hại',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Chọn kiện hàng...'),
                value: _selectedOrderDetailId,
                items: widget.order.orderDetails.map((orderDetail) {
                  return DropdownMenuItem<String>(
                    value: orderDetail.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Kiện #${widget.order.orderDetails.indexOf(orderDetail) + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (orderDetail.description.isNotEmpty)
                          Text(
                            orderDetail.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (orderDetail.trackingCode != null)
                          Text(
                            'Mã: ${orderDetail.trackingCode}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOrderDetailId = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Description field
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Mô tả tình trạng hư hại...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          
          // Images grid
          if (_damageImages.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đã chọn ${_damageImages.length} ảnh',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_damageImages.length}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _damageImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _damageImages.length) {
                      return InkWell(
                        onTap: _showImageSourceOptions,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.border,
                              style: BorderStyle.solid,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_a_photo,
                              size: 32,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      );
                    }
                    
                    return Stack(
                      children: [
                        InkWell(
                          onTap: () => _showImagePreviewDialog(index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _damageImages[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            )
          else
            InkWell(
              onTap: _showImageSourceOptions,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chụp ảnh hàng hư hại',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Có thể chọn nhiều ảnh cùng lúc',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _showForm = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('HỦY'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _reportDamage(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('GỬI BÁO CÁO'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
