import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../app/di/service_locator.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../viewmodels/pre_delivery_documentation_viewmodel.dart';

class PreDeliveryDocumentationSection extends StatefulWidget {
  final OrderWithDetails order;
  final VoidCallback? onSubmitSuccess;

  const PreDeliveryDocumentationSection({
    super.key,
    required this.order,
    this.onSubmitSuccess,
  });

  @override
  State<PreDeliveryDocumentationSection> createState() =>
      _PreDeliveryDocumentationSectionState();
}

class _PreDeliveryDocumentationSectionState
    extends State<PreDeliveryDocumentationSection> {
  late final PreDeliveryDocumentationViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<PreDeliveryDocumentationViewModel>();
  }

  List<VehicleSeal> _getAvailableSeals() {
    if (widget.order.orderDetails.isEmpty || widget.order.vehicleAssignments.isEmpty) {
      return [];
    }
    
    final vehicleAssignment = _getCurrentUserVehicleAssignment();
    return vehicleAssignment?.seals ?? [];
  }

  Future<void> _pickPackingProofImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        // Allow multiple image selection from gallery
        final List<XFile> images = await _picker.pickMultiImage(
          imageQuality: 80,
        );
        if (images.isNotEmpty) {
          for (final image in images) {
            _viewModel.addPackingProofImage(File(image.path));
          }
        }
      } else {
        // Single image from camera
        final XFile? image = await _picker.pickImage(
          source: source,
          imageQuality: 80,
        );
        if (image != null) {
          _viewModel.addPackingProofImage(File(image.path));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  Future<void> _pickSealImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image != null) {
        _viewModel.setSealImage(File(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  void _showImageSourceOptions(bool isPackingProof) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Chụp ảnh mới'),
                onTap: () {
                  Navigator.pop(context);
                  if (isPackingProof) {
                    _pickPackingProofImage(ImageSource.camera);
                  } else {
                    _pickSealImage(ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  if (isPackingProof) {
                    _pickPackingProofImage(ImageSource.gallery);
                  } else {
                    _pickSealImage(ImageSource.gallery);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  VehicleAssignment? _getCurrentUserVehicleAssignment() {
    if (widget.order.orderDetails.isEmpty || widget.order.vehicleAssignments.isEmpty) {
      return null;
    }
    
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final currentUserPhone = authViewModel.driver?.userResponse.phoneNumber;
    
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
      // Fallback to first vehicle assignment
      return widget.order.vehicleAssignments.isNotEmpty 
          ? widget.order.vehicleAssignments.first 
          : null;
    }
  }

  String? _getVehicleAssignmentId() {
    if (widget.order.orderDetails.isEmpty || widget.order.vehicleAssignments.isEmpty) {
      return null;
    }
    
    final vehicleAssignment = _getCurrentUserVehicleAssignment();
    return vehicleAssignment?.id;
  }

  Future<void> _submitDocumentation() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      final vehicleAssignmentId = _getVehicleAssignmentId();
      if (vehicleAssignmentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy thông tin phương tiện')),
        );
        return;
      }

      final result = await _viewModel.submitDocumentation(
        vehicleAssignmentId: vehicleAssignmentId,
      );

      if (result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác nhận hàng hóa và seal thành công'),
            backgroundColor: Colors.green,
          ),
        );

        // Call the success callback if provided, otherwise pop the context
        if (widget.onSubmitSuccess != null) {
          widget.onSubmitSuccess!();
        } else {
          Navigator.of(context).pop(true); // Return success to previous screen
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<PreDeliveryDocumentationViewModel>(
        builder: (context, viewModel, _) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xác nhận hàng hóa và seal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSealSelectionSection(viewModel),
                const SizedBox(height: 24),
                _buildPackingProofImagesSection(viewModel),
                const SizedBox(height: 24),
                _buildSealImageSection(viewModel),
                const SizedBox(height: 24),
                if (viewModel.state == PreDeliveryDocumentationState.error)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      viewModel.errorMessage,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        viewModel.state == PreDeliveryDocumentationState.loading
                        ? null
                        : _submitDocumentation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child:
                        viewModel.state == PreDeliveryDocumentationState.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Xác nhận hàng hóa và seal'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSealSelectionSection(
    PreDeliveryDocumentationViewModel viewModel,
  ) {
    final availableSeals = _getAvailableSeals();
    final selectableSeals = availableSeals.where((seal) => seal.canBeSelected).toList();
    final inUsedSeal = availableSeals.where((seal) => seal.isInUsed).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Chọn seal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Text(
              '(Bắt buộc)',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Show current seal in use if exists
        if (inUsedSeal != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seal đang sử dụng',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        inUsedSeal.sealCode,
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        
        // Seal selection cards
        if (selectableSeals.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: viewModel.selectedSeal == null 
                    ? Colors.red.shade300 
                    : Colors.grey.shade300,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: selectableSeals.asMap().entries.map((entry) {
                final index = entry.key;
                final seal = entry.value;
                final isSelected = viewModel.selectedSeal?.sealCode == seal.sealCode;
                final isLast = index == selectableSeals.length - 1;
                
                return InkWell(
                  onTap: () => viewModel.setSelectedSeal(seal),
                  borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(12) : Radius.zero,
                    bottom: isLast ? const Radius.circular(12) : Radius.zero,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary.withValues(alpha: 0.1) 
                          : Colors.transparent,
                      border: !isLast 
                          ? Border(bottom: BorderSide(color: Colors.grey.shade200))
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Radio button
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? AppColors.primary : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        
                        // Seal code badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getSealStatusColor(seal.status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getSealStatusColor(seal.status).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            seal.sealCode,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _getSealStatusColor(seal.status),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Status text
                        Expanded(
                          child: Text(
                            _getSealStatusText(seal.status),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        
        // Show message if no seals available
        if (selectableSeals.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded, 
                    color: Colors.orange.shade700, 
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Không có seal khả dụng. Vui lòng liên hệ staff để được cấp seal.',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Color _getSealStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'IN_USED':
        return Colors.blue;
      case 'REMOVED':
        return Colors.red;
      case 'USED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  String _getSealStatusText(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'Sẵn sàng sử dụng';
      case 'IN_USED':
        return 'Đang sử dụng';
      case 'REMOVED':
        return 'Đã gỡ bỏ';
      case 'USED':
        return 'Đã hoàn thành';
      default:
        return status;
    }
  }

  Widget _buildPackingProofImagesSection(
    PreDeliveryDocumentationViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Hình ảnh hàng hóa',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Text(
              '(Bắt buộc)',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(
              color: viewModel.packingProofImages.isEmpty
                  ? Colors.red.shade300
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.packingProofImages.length + 1,
            itemBuilder: (context, index) {
              if (index == viewModel.packingProofImages.length) {
                return _buildAddImageButton(
                  () => _showImageSourceOptions(true),
                );
              }
              return _buildImageThumbnail(
                viewModel.packingProofImages[index],
                () => viewModel.removePackingProofImage(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSealImageSection(PreDeliveryDocumentationViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Hình ảnh seal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Text(
              '(Bắt buộc)',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(
              color: viewModel.sealImage == null
                  ? Colors.red.shade300
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: viewModel.sealImage == null
              ? _buildAddImageButton(() => _showImageSourceOptions(false))
              : _buildImageThumbnail(
                  viewModel.sealImage!,
                  () => viewModel.clearSealImage(),
                ),
        ),
      ],
    );
  }

  Widget _buildAddImageButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 32, color: AppColors.primary),
            SizedBox(height: 8),
            Text('Thêm ảnh', style: TextStyle(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(File image, VoidCallback onRemove) {
    return Stack(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(image: FileImage(image), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
