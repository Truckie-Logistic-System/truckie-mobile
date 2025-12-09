import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/utils/responsive_extensions.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/driver_onboarding_viewmodel.dart';

/// Step 2: Face capture widget with ML Kit face detection
class FaceCaptureStep extends StatefulWidget {
  final DriverOnboardingViewModel viewModel;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  const FaceCaptureStep({
    super.key,
    required this.viewModel,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  State<FaceCaptureStep> createState() => _FaceCaptureStepState();
}

class _FaceCaptureStepState extends State<FaceCaptureStep> {
  final ImagePicker _imagePicker = ImagePicker();
  late FaceDetector _faceDetector;
  bool _isProcessing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: false,
        enableTracking: false,
        enableLandmarks: false,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15, // Minimum face size relative to image
      ),
    );
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi chụp ảnh: ${e.toString()}';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi chọn ảnh: ${e.toString()}';
      });
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Đang phân tích khuôn mặt...';
    });

    try {
      // Detect faces using ML Kit
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = 'Không phát hiện khuôn mặt. Vui lòng chụp lại.';
          _isProcessing = false;
        });
        widget.viewModel.setFaceDetected(false);
        return;
      }

      if (faces.length > 1) {
        setState(() {
          _statusMessage = 'Phát hiện nhiều khuôn mặt. Vui lòng chỉ chụp 1 người.';
          _isProcessing = false;
        });
        widget.viewModel.setFaceDetected(false);
        return;
      }

      // Check face size (should be reasonably large in the image)
      final face = faces.first;
      final boundingBox = face.boundingBox;
      
      // Get image dimensions
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = await decodeImageFromList(imageBytes);
      final imageWidth = decodedImage.width.toDouble();
      final imageHeight = decodedImage.height.toDouble();

      final faceWidth = boundingBox.width;
      final faceHeight = boundingBox.height;
      final faceArea = faceWidth * faceHeight;
      final imageArea = imageWidth * imageHeight;
      final faceRatio = faceArea / imageArea;

      if (faceRatio < 0.05) {
        setState(() {
          _statusMessage = 'Khuôn mặt quá nhỏ. Vui lòng đưa camera gần hơn.';
          _isProcessing = false;
        });
        widget.viewModel.setFaceDetected(false);
        return;
      }

      // Face detected successfully
      widget.viewModel.setFaceImageFile(imageFile);
      widget.viewModel.setFaceDetected(true);

      setState(() {
        _statusMessage = 'Đã phát hiện khuôn mặt thành công!';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi xử lý ảnh: ${e.toString()}';
        _isProcessing = false;
      });
      widget.viewModel.setFaceDetected(false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!widget.viewModel.canSubmit) {
      setState(() {
        _statusMessage = 'Vui lòng hoàn thành tất cả các bước';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Đang kích hoạt tài khoản...';
    });

    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Icon(
            Icons.face,
            size: 64.r,
            color: AppColors.primary,
          ),
          SizedBox(height: 16.h),
          Text(
            'Chụp ảnh khuôn mặt',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'Chụp ảnh khuôn mặt rõ ràng để xác thực danh tính. Ảnh này sẽ được sử dụng làm ảnh đại diện.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),

          // Face image preview
          Container(
            height: 280.h,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: widget.viewModel.isFaceDetected
                    ? AppColors.success
                    : AppColors.grey300,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: widget.viewModel.faceImageFile != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          widget.viewModel.faceImageFile!,
                          fit: BoxFit.cover,
                        ),
                        if (widget.viewModel.isFaceDetected)
                          Positioned(
                            top: 8.r,
                            right: 8.r,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 16.r,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Đã xác thực',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 64.r,
                            color: AppColors.grey400,
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Chưa có ảnh',
                            style: TextStyle(
                              color: AppColors.grey500,
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          SizedBox(height: 16.h),

          // Status message
          if (_statusMessage.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: widget.viewModel.isFaceDetected
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    Icon(
                      widget.viewModel.isFaceDetected
                          ? Icons.check_circle
                          : Icons.info_outline,
                      color: widget.viewModel.isFaceDetected
                          ? AppColors.success
                          : AppColors.warning,
                      size: 20.r,
                    ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: widget.viewModel.isFaceDetected
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 24.h),

          // Capture buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _pickFromGallery,
                  icon: Icon(Icons.photo_library, size: 20.r),
                  label: Text('Thư viện'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _captureImage,
                  icon: Icon(Icons.camera_alt, size: 20.r),
                  label: Text('Chụp ảnh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 32.h),

          // Tips
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hướng dẫn chụp ảnh:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                    color: AppColors.info,
                  ),
                ),
                SizedBox(height: 8.h),
                _buildTip('Đảm bảo ánh sáng đầy đủ'),
                _buildTip('Nhìn thẳng vào camera'),
                _buildTip('Không đeo kính râm hoặc khẩu trang'),
                _buildTip('Giữ khuôn mặt trong khung hình'),
              ],
            ),
          ),
          SizedBox(height: 32.h),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : widget.onBack,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    side: BorderSide(color: AppColors.grey400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'Quay lại',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.grey600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: widget.viewModel.canSubmit && !_isProcessing
                      ? _handleSubmit
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    disabledBackgroundColor: AppColors.grey300,
                  ),
                  child: _isProcessing && widget.viewModel.isLoading
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Kích hoạt tài khoản',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16.r,
            color: AppColors.info,
          ),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
}
