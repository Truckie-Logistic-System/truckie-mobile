import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/service_locator.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/account_viewmodel.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Use the singleton AuthViewModel
  late final AuthViewModel _authViewModel;
  late final AccountViewModel _accountViewModel;

  @override
  void initState() {
    super.initState();
    // Get the singleton instances from GetIt
    _authViewModel = getIt<AuthViewModel>();
    _accountViewModel = getIt<AccountViewModel>();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    // Don't dispose the view models as they're managed by GetIt
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _authViewModel),
          ChangeNotifierProvider.value(value: _accountViewModel),
        ],
        child: Consumer2<AuthViewModel, AccountViewModel>(
          builder: (context, authViewModel, accountViewModel, _) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        controller: _oldPasswordController,
                        label: 'Mật khẩu hiện tại',
                        obscure: _obscureOldPassword,
                        toggleObscure: () {
                          setState(() {
                            _obscureOldPassword = !_obscureOldPassword;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu hiện tại';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        controller: _newPasswordController,
                        label: 'Mật khẩu mới',
                        obscure: _obscureNewPassword,
                        toggleObscure: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu mới';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: 'Xác nhận mật khẩu mới',
                        obscure: _obscureConfirmPassword,
                        toggleObscure: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng xác nhận mật khẩu mới';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Mật khẩu xác nhận không khớp';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      _buildChangePasswordButton(
                        context,
                        authViewModel,
                        accountViewModel,
                      ),
                      if (accountViewModel.status ==
                          AccountStatus.passwordError)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            accountViewModel.errorMessage,
                            style: const TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggleObscure,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggleObscure,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildChangePasswordButton(
    BuildContext context,
    AuthViewModel authViewModel,
    AccountViewModel accountViewModel,
  ) {
    return ElevatedButton(
      onPressed: _isLoading
          ? null
          : () =>
                _handleChangePassword(context, authViewModel, accountViewModel),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
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
          : const Text(
              'Đổi mật khẩu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  Future<void> _handleChangePassword(
    BuildContext context,
    AuthViewModel authViewModel,
    AccountViewModel accountViewModel,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (authViewModel.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần đăng nhập để thực hiện chức năng này'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await accountViewModel.changePassword(
      username: authViewModel.user!.username,
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmNewPassword: _confirmPasswordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accountViewModel.errorMessage.isNotEmpty
                ? accountViewModel.errorMessage
                : 'Đổi mật khẩu thất bại',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
