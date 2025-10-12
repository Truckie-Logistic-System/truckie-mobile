import 'dart:io';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';
import '../../viewmodels/order_detail_viewmodel.dart';

class StartDeliverySection extends StatefulWidget {
  final OrderWithDetails order;

  const StartDeliverySection({Key? key, required this.order}) : super(key: key);

  @override
  State<StartDeliverySection> createState() => _StartDeliverySectionState();
}

class _StartDeliverySectionState extends State<StartDeliverySection> {
  final TextEditingController _odometerController = TextEditingController();
  File? _odometerImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _showForm = false;
  bool _showImagePreview = false;

  @override
  void dispose() {
    _odometerController.dispose();
    super.dispose();
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
      });
    }
  }

  void _showImagePreviewDialog() {
    if (_odometerImage == null) return;

    setState(() {
      _showImagePreview = true;
    });
  }

  Future<void> _startDelivery(BuildContext context) async {
    if (_odometerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập chỉ số công tơ mét'),
          backgroundColor: Colors.red,
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

    debugPrint('🚀 Bắt đầu gửi thông tin công tơ mét...');
    debugPrint('🚀 Chỉ số công tơ mét: ${_odometerController.text}');
    debugPrint('🚀 Đường dẫn ảnh: ${_odometerImage!.path}');

    try {
      final viewModel = Provider.of<OrderDetailViewModel>(
        context,
        listen: false,
      );
      final success = await viewModel.startDelivery(
        odometerReading: Decimal.parse(_odometerController.text),
        odometerImage: _odometerImage!,
      );

      debugPrint('🚀 Kết quả gửi thông tin: $success');

      if (success) {
        // Lưu lại context và orderId để sử dụng sau khi tải lại order
        final navigatorContext = context;
        final orderId = widget.order.id;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bắt đầu chuyến xe thành công'),
            backgroundColor: Colors.green,
          ),
        );

        // Chuyển đến màn hình dẫn đường ngay lập tức, không đợi tải lại dữ liệu order
        debugPrint('🚀 Chuyển đến màn hình dẫn đường với orderId: $orderId');

        if (mounted) {
          Navigator.of(navigatorContext).pushReplacementNamed(
            AppRoutes.navigation,
            arguments: {'orderId': orderId, 'isSimulationMode': false},
          );
        }
      } else {
        debugPrint('❌ Lỗi: ${viewModel.startDeliveryErrorMessage}');
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
      debugPrint('❌ Exception khi bắt đầu chuyến xe: $e');
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

    if (!viewModel.canStartDelivery()) {
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
                  onPressed: _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
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
            color: AppColors.primary.withOpacity(0.3),
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
            'Nhập thông tin công tơ mét',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _odometerController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Chỉ số công tơ mét (km)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _odometerImage == null
                    ? _pickImage
                    : _showImagePreviewDialog,
                child: Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: _odometerImage != null
                        ? AppColors.success
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _odometerImage != null
                          ? const Icon(Icons.check, color: Colors.white)
                          : const Icon(Icons.camera_alt, color: Colors.white),
                      if (_odometerImage == null) const SizedBox(height: 2),
                      if (_odometerImage == null)
                        Text(
                          'Chụp',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      if (_odometerImage != null) const SizedBox(height: 2),
                      if (_odometerImage != null)
                        Text(
                          'Xem',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                    ],
                  ),
                ),
              ),
            ],
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
                  onPressed: _isLoading ? null : () => _startDelivery(context),
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
