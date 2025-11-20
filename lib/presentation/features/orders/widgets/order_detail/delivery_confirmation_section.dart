import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../core/services/global_location_manager.dart';
import '../../../../../core/utils/sound_utils.dart';
import '../../../../../app/di/service_locator.dart';
import '../../../../utils/driver_role_checker.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';
import '../../viewmodels/order_detail_viewmodel.dart';

class DeliveryConfirmationSection extends StatefulWidget {
  final OrderWithDetails order;

  const DeliveryConfirmationSection({super.key, required this.order});

  @override
  State<DeliveryConfirmationSection> createState() => _DeliveryConfirmationSectionState();
}

class _DeliveryConfirmationSectionState extends State<DeliveryConfirmationSection> {
  final List<File> _confirmationImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _showForm = false;
  bool _showImagePreview = false;
  int? _previewImageIndex;
  final GlobalLocationManager _globalLocationManager = getIt<GlobalLocationManager>();

  @override
  void dispose() {
    super.dispose();
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
        _confirmationImages.add(File(image.path));
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 80,
    );

    if (images.isNotEmpty) {
      setState(() {
        _confirmationImages.addAll(images.map((xfile) => File(xfile.path)));
      });
    }
  }

  void _showImagePreviewDialog(int index) {
    if (_confirmationImages.isEmpty) return;

    setState(() {
      _showImagePreview = true;
      _previewImageIndex = index;
    });
  }

  void _removeImage(int index) {
    setState(() {
      _confirmationImages.removeAt(index);
    });
  }

  Future<void> _confirmDelivery(BuildContext context) async {
    // Kiểm tra driver role trước khi cho phép thực hiện action
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (!DriverRoleChecker.canPerformActions(widget.order, authViewModel)) {
      // Không hiển thị thông báo, chỉ return để thân thiện với user
      return;
    }

    if (_confirmationImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chụp ít nhất một ảnh xác nhận khách hàng nhận hàng'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final viewModel = Provider.of<OrderDetailViewModel>(
        context,
        listen: false,
      );
      final success = await viewModel.uploadMultiplePhotoCompletion(
        imageFiles: _confirmationImages,
        description: 'Ảnh xác nhận khách hàng nhận hàng',
      );
      if (success) {
        // Play success sound for delivery confirmation
        SoundUtils.playSuccessSound();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xác nhận giao hàng thành công!'),
              backgroundColor: Colors.green,
            ),
          );

          // Wait a bit for snackbar to show
          await Future.delayed(const Duration(milliseconds: 500));

          // CRITICAL: Only pop if tracking is active (came from NavigationScreen)
          // NavigationScreen is waiting for this result via await pushNamed()
          if (_globalLocationManager.isGlobalTrackingActive &&
              _globalLocationManager.currentOrderId == widget.order.id) {
            Navigator.of(context).pop(true);
          }
        }
      } else {
        // Play error sound for failed delivery confirmation
        SoundUtils.playErrorSound();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.photoUploadError.isNotEmpty 
                ? viewModel.photoUploadError 
                : 'Không thể tải ảnh lên. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Play error sound for exception
      SoundUtils.playErrorSound();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi không xác định: $e'),
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
    final viewModel = Provider.of<OrderDetailViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);

    if (!viewModel.canConfirmDelivery()) {
      return const SizedBox.shrink();
    }

    // Kiểm tra driver role - ẩn toàn bộ section nếu không có quyền
    if (!DriverRoleChecker.canPerformActions(widget.order, authViewModel)) {
      return const SizedBox.shrink();
    }

    if (_showImagePreview) {
      return _buildImagePreview();
    } else if (_showForm) {
      return _buildForm();
    } else {
      return _buildButton();
    }
  }

  Widget _buildImagePreview() {
    if (_confirmationImages.isEmpty || _previewImageIndex == null) {
      setState(() {
        _showImagePreview = false;
      });
      return _buildForm();
    }

    final currentImage = _confirmationImages[_previewImageIndex!];

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
                'Xem ảnh xác nhận',
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
            'Ảnh ${_previewImageIndex! + 1}/${_confirmationImages.length}',
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.success, Colors.green.shade700],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => setState(() => _showForm = true),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: AppTextStyles.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle_outline, size: 24),
            SizedBox(width: 8),
            Text('XÁC NHẬN GIAO HÀNG'),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
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
            'Chụp ảnh xác nhận khách hàng nhận hàng',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // Images grid
          if (_confirmationImages.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đã chọn ${_confirmationImages.length} ảnh',
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
                        '${_confirmationImages.length}',
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
                  itemCount: _confirmationImages.length + 1, // +1 for add button
                  itemBuilder: (context, index) {
                    if (index == _confirmationImages.length) {
                      // Add more button
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
                    
                    // Image thumbnail
                    return Stack(
                      children: [
                        InkWell(
                          onTap: () => _showImagePreviewDialog(index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _confirmationImages[index],
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
                        'Chụp ảnh xác nhận',
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
                  onPressed: _isLoading ? null : () => _confirmDelivery(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
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
                      : const Text('XÁC NHẬN'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
