import 'dart:io';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../core/services/ocr_service.dart';
import '../../../../../core/utils/sound_utils.dart';
import '../../../../utils/driver_role_checker.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';
import '../../viewmodels/order_detail_viewmodel.dart';

class StartDeliverySection extends StatefulWidget {
  final OrderWithDetails order;

  const StartDeliverySection({super.key, required this.order});

  @override
  State<StartDeliverySection> createState() => _StartDeliverySectionState();
}

class _StartDeliverySectionState extends State<StartDeliverySection> {
  final TextEditingController _odometerController = TextEditingController();
  File? _odometerImage;
  final ImagePicker _picker = ImagePicker();
  final OCRService _ocrService = OCRService();
  bool _isLoading = false;
  bool _showForm = false;
  bool _showImagePreview = false;
  bool _isProcessingOCR = false;

  @override
  void dispose() {
    _odometerController.dispose();
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
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
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
        _odometerImage = File(image.path);
        _isProcessingOCR = true;
      });

      // Tự động xử lý OCR để đọc số từ ảnh
      await _processOCR();
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _odometerImage = File(image.path);
        _isProcessingOCR = true;
      });

      // Tự động xử lý OCR để đọc số từ ảnh
      await _processOCR();
    }
  }

  Future<void> _processOCR() async {
    if (_odometerImage == null) return;

    try {
      final extractedText = await _ocrService.extractOdometerReading(
        _odometerImage!,
      );

      if (extractedText != null && extractedText.isNotEmpty) {
        setState(() {
          _odometerController.text = extractedText;
        });

      } else {
        // Không đọc được số, hiển thị thông báo
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể đọc số từ ảnh. Vui lòng chụp lại ảnh rõ hơn.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi đọc ảnh. Vui lòng chụp lại.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOCR = false;
        });
      }
    }
  }

  void _showImagePreviewDialog() {
    if (_odometerImage == null) return;

    setState(() {
      _showImagePreview = true;
    });
  }

  Future<void> _startDelivery(BuildContext context) async {
    // Kiểm tra driver role trước khi cho phép thực hiện action
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    if (!DriverRoleChecker.canPerformActions(widget.order, authViewModel)) {
      // Không hiển thị thông báo, chỉ return để thân thiện với user
      return;
    }

    if (_odometerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chụp ảnh công tơ mét để đọc số'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_odometerImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chụp ảnh công tơ mét'),
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
      final success = await viewModel.startDelivery(
        odometerReading: Decimal.parse(_odometerController.text),
        odometerImage: _odometerImage!,
      );

      if (success) {
        // Play success sound for starting delivery
        SoundUtils.playSuccessSound();
        
        // Lưu lại context và orderId để sử dụng sau khi tải lại order
        final navigatorContext = context;
        final orderId = widget.order.id;

        // Chuyển đến màn hình dẫn đường ngay lập tức, không đợi tải lại dữ liệu order

        if (mounted) {
          Navigator.of(navigatorContext).pushReplacementNamed(
            AppRoutes.navigation,
            arguments: {'orderId': orderId, 'isSimulationMode': false},
          );
        }
      } else {
        // Play error sound for failed delivery start
        SoundUtils.playErrorSound();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.startDeliveryErrorMessage),
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
    if (!viewModel.canStartDelivery()) {
      return const SizedBox.shrink();
    }

    // Kiểm tra driver role - ẩn toàn bộ section nếu không có quyền
    final canPerform = DriverRoleChecker.canPerformActions(widget.order, authViewModel);
    
    if (!canPerform) {
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
    if (_odometerImage == null) {
      setState(() {
        _showImagePreview = false;
      });
      return _buildForm();
    }

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
                'Xem ảnh công tơ mét',
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
              _odometerImage!,
              fit: BoxFit.contain,
              height: 200,
              width: double.infinity,
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
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
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
          children: [
            Icon(Icons.play_circle_outline, size: 24),
            SizedBox(width: 8),
            Text('BẮT ĐẦU CHUYẾN XE'),
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
            'Chụp ảnh công tơ mét đầu',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_odometerImage != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ảnh đã chụp',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showImageSourceOptions,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Chụp lại'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _odometerImage!,
                    fit: BoxFit.cover,
                    height: 150,
                    width: double.infinity,
                  ),
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
                        'Chụp ảnh công tơ mét',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _odometerController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Chỉ số công tơ mét',
              hintText: 'Sẽ tự động điền từ ảnh',
              prefixIcon: const Icon(Icons.speed),
              suffixText: 'km',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              fillColor: Colors.grey.shade50,
              filled: true,
              suffixIcon: _odometerController.text.isNotEmpty
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
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
                  child: const Text('HủY'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _isProcessingOCR
                      ? null
                      : () => _startDelivery(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
