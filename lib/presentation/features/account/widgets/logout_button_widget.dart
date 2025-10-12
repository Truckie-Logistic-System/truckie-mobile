import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/theme/app_colors.dart';

/// Widget hiển thị nút đăng xuất
class LogoutButtonWidget extends StatefulWidget {
  final AuthViewModel authViewModel;

  const LogoutButtonWidget({Key? key, required this.authViewModel})
    : super(key: key);

  @override
  State<LogoutButtonWidget> createState() => _LogoutButtonWidgetState();
}

class _LogoutButtonWidgetState extends State<LogoutButtonWidget> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoggingOut
          ? null
          : () async {
              // Hiển thị dialog xác nhận
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Xác nhận đăng xuất'),
                  content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        'Đăng xuất',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true && mounted) {
                setState(() {
                  _isLoggingOut = true;
                });

                try {
                  // Get token before clearing data
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('auth_token');

                  // Clear local data
                  await prefs.remove('auth_token');
                  await prefs.remove('refresh_token');
                  await prefs.remove('user_info');

                  // Then navigate to login screen
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }

                  // Make a direct HTTP request to logout API instead of using AuthViewModel
                  if (token != null) {
                    try {
                      await http.post(
                        Uri.parse('http://10.0.2.2:8080/api/v1/auths/logout'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                      );
                      // Ignore the response
                    } catch (e) {
                      // Ignore errors during logout API call
                      debugPrint('Error calling logout API: $e');
                    }
                  }
                } catch (e) {
                  debugPrint('Error during logout: $e');
                  // If there's an error, still try to navigate to login
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                }
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        elevation: 2,
        minimumSize: Size(double.infinity, 56.h),
      ),
      icon: _isLoggingOut
          ? SizedBox(
              height: 20.r,
              width: 20.r,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(Icons.logout, size: 24.r),
      label: Text(
        _isLoggingOut ? 'Đang đăng xuất...' : 'Đăng xuất',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
      ),
    );
  }
}
