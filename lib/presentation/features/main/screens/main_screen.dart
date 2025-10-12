import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../account/screens/account_screen.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../home/screens/home_screen.dart';
import '../../orders/screens/orders_screen.dart';
import '../../../theme/app_colors.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Danh sách các màn hình tương ứng với từng tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Khởi tạo các màn hình khi widget được tạo
    _screens = [
      const HomeScreen(),
      const OrdersScreen(),
      const AccountScreen(), // Chỉ còn 3 màn hình
    ];
  }

  // Tải lại dữ liệu khi chuyển tab
  void _onItemTapped(int index) {
    // Lưu tab cũ để kiểm tra xem có chuyển tab không
    final oldIndex = _selectedIndex;

    setState(() {
      _selectedIndex = index;
    });

    // Nếu chuyển sang tab mới, đảm bảo token đã được refresh
    if (oldIndex != index) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

      // Thử refresh token trước khi hiển thị tab mới
      if (authViewModel.status == AuthStatus.authenticated) {
        // Chỉ refresh token nếu đang ở tab tài khoản hoặc trang chủ
        if (index == 0 || index == 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            authViewModel.forceRefreshToken().then((success) {
              debugPrint('Force refresh token result: $success');
            });
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the AuthViewModel from the parent provider
    final authViewModel = Provider.of<AuthViewModel>(context);

    // Redirect to login if unauthenticated
    if (authViewModel.status == AuthStatus.unauthenticated) {
      // Use a post-frame callback to avoid build-time navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      // Return an empty container while redirecting
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show a full-screen loading indicator if we're still in initial loading state
    if (authViewModel.status == AuthStatus.loading &&
        authViewModel.user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'Đang tải thông tin...',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show the main screen with bottom navigation
    return Scaffold(
      // Sử dụng SafeArea để đảm bảo nội dung không bị che bởi system insets
      body: SafeArea(
        // Đặt bottom: false để không tạo padding dưới cùng (vì đã xử lý trong bottomNavigationBar)
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: _screens),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home, 'Trang chủ'),
              _buildNavItem(1, Icons.list_alt, 'Đơn hàng'),
              // _buildNavItem(2, Icons.map, 'Dẫn đường'),
              _buildNavItem(2, Icons.person, 'Tài khoản'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
