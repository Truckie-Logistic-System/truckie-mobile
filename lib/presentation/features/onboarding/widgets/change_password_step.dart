import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_extensions.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/driver_onboarding_viewmodel.dart';

/// Step 1: Change password widget
class ChangePasswordStep extends StatefulWidget {
  final DriverOnboardingViewModel viewModel;
  final VoidCallback onNext;

  const ChangePasswordStep({
    super.key,
    required this.viewModel,
    required this.onNext,
  });

  @override
  State<ChangePasswordStep> createState() => _ChangePasswordStepState();
}

class _ChangePasswordStepState extends State<ChangePasswordStep> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_formKey.currentState!.validate() && widget.viewModel.isPasswordValid) {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.r),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Icon(
              Icons.lock_reset,
              size: 64.r,
              color: AppColors.primary,
            ),
            SizedBox(height: 16.h),
            Text(
              'Đổi mật khẩu',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'Vui lòng đổi mật khẩu tạm thời được cấp bởi quản trị viên để bảo mật tài khoản của bạn.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),

            // New password field
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                prefixIcon: Icon(Icons.lock, size: 24.r),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword ? Icons.visibility : Icons.visibility_off,
                    size: 24.r,
                  ),
                  onPressed: () {
                    setState(() {
                      _showNewPassword = !_showNewPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                helperText: 'Tối thiểu 6 ký tự',
              ),
              onChanged: (value) {
                widget.viewModel.setNewPassword(value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập mật khẩu mới';
                }
                if (value.length < 6) {
                  return 'Mật khẩu phải có ít nhất 6 ký tự';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),

            // Confirm password field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Xác nhận mật khẩu mới',
                prefixIcon: Icon(Icons.lock_outline, size: 24.r),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    size: 24.r,
                  ),
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onChanged: (value) {
                widget.viewModel.setConfirmPassword(value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng xác nhận mật khẩu';
                }
                if (value != _newPasswordController.text) {
                  return 'Mật khẩu xác nhận không khớp';
                }
                return null;
              },
            ),
            SizedBox(height: 32.h),

            // Password requirements
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
                    'Yêu cầu mật khẩu:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                      color: AppColors.info,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _buildRequirement(
                    'Ít nhất 6 ký tự',
                    _newPasswordController.text.length >= 6,
                  ),
                  _buildRequirement(
                    'Khác mật khẩu tạm thời',
                    _newPasswordController.text.isNotEmpty &&
                        _newPasswordController.text != widget.viewModel.currentPassword,
                  ),
                  _buildRequirement(
                    'Mật khẩu xác nhận khớp',
                    _confirmPasswordController.text.isNotEmpty &&
                        _confirmPasswordController.text == _newPasswordController.text,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),

            // Next button
            ElevatedButton(
              onPressed: widget.viewModel.isPasswordValid ? _handleNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                disabledBackgroundColor: AppColors.grey300,
              ),
              child: Text(
                'Tiếp tục',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16.r,
            color: isMet ? AppColors.success : AppColors.grey400,
          ),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              color: isMet ? AppColors.success : AppColors.grey600,
            ),
          ),
        ],
      ),
    );
  }
}
