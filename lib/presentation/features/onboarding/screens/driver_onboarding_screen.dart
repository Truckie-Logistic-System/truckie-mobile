import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../theme/app_colors.dart';
import '../viewmodels/driver_onboarding_viewmodel.dart';
import '../widgets/change_password_step.dart';
import '../widgets/face_capture_step.dart';
import '../widgets/onboarding_progress_indicator.dart';

/// Driver onboarding screen for first-time login.
/// Requires driver to:
/// 1. Change temporary password
/// 2. Capture face image for identification
class DriverOnboardingScreen extends StatefulWidget {
  /// The temporary password provided by admin (used for validation)
  final String currentPassword;

  const DriverOnboardingScreen({
    super.key,
    required this.currentPassword,
  });

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  late DriverOnboardingViewModel _viewModel;
  final PageController _pageController = PageController();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<DriverOnboardingViewModel>();
    _viewModel.setCurrentPassword(widget.currentPassword);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitOnboarding() async {
    final success = await _viewModel.submitOnboarding();
    if (success && mounted) {
      // Sau khi onboarding thành công, bắt buộc đăng nhập lại với mật khẩu mới
      // Để đảm bảo token và trạng thái được đồng bộ đúng với tài khoản ACTIVE
      final authViewModel = context.read<AuthViewModel>();
      await authViewModel.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kích hoạt tài khoản'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            OnboardingProgressIndicator(
              currentStep: _currentStep,
              totalSteps: 2,
              stepLabels: const ['Đổi mật khẩu', 'Chụp ảnh khuôn mặt'],
            ),

            // Page content
            Expanded(
              child: Consumer<DriverOnboardingViewModel>(
                builder: (context, viewModel, _) {
                  return PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentStep = index;
                      });
                    },
                    children: [
                      // Step 1: Change password
                      ChangePasswordStep(
                        viewModel: viewModel,
                        onNext: _nextStep,
                      ),

                      // Step 2: Face capture
                      FaceCaptureStep(
                        viewModel: viewModel,
                        onBack: _previousStep,
                        onSubmit: _submitOnboarding,
                      ),
                    ],
                  );
                },
              ),
            ),

            // Error message
            Consumer<DriverOnboardingViewModel>(
              builder: (context, viewModel, _) {
                if (viewModel.errorMessage.isNotEmpty) {
                  return Container(
                    padding: EdgeInsets.all(16.r),
                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error, size: 20.r),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            viewModel.errorMessage,
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}
