import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../account/screens/account_screen.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../home/screens/home_screen.dart';
import '../../orders/screens/orders_screen.dart';
import '../../orders/viewmodels/order_list_viewmodel.dart';
import '../../../../app/di/service_locator.dart';
import '../../../theme/app_colors.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;
  
  const MainScreen({super.key, this.initialTab = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  // Danh sách các màn hình tương ứng với từng tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Initialize selected index from widget parameter
    _selectedIndex = widget.initialTab;
    debugPrint('🏠 MainScreen initialized with tab: $_selectedIndex');
    
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

    // Luôn fetch lại dữ liệu khi nhấn vào tab, kể cả khi nhấn lại tab hiện tại
    // để đảm bảo data luôn mới nhất
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    if (authViewModel.status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (index) {
          case 0:
            // Tab Trang chủ - force refresh như OrdersScreen
            debugPrint('🔄 Tab Trang chủ: Force refreshing like OrdersScreen refresh button');
            if (authViewModel.user != null) {
              authViewModel.forceRefreshToken().then((success) {
                debugPrint('🔄 Tab Trang chủ: Force refresh token result: $success');
                if (success) {
                  authViewModel.refreshDriverInfo();
                }
              });
            }
            break;
          case 1:
            // Tab Đơn hàng - hoạt động Y HỆT như nút refresh trong OrdersScreen
            final orderListViewModel = getIt<OrderListViewModel>();
            debugPrint('🔄 Tab Đơn hàng: Triggering refresh EXACTLY like OrdersScreen refresh button');
            
            // Gọi trực tiếp như nút refresh, không delay
            orderListViewModel.superForceRefresh();
            break;
          case 2:
            // Tab Tài khoản - force refresh như OrdersScreen
            debugPrint('🔄 Tab Tài khoản: Force refreshing like OrdersScreen refresh button');
            if (authViewModel.user != null) {
              authViewModel.forceRefreshToken().then((success) {
                debugPrint('🔄 Tab Tài khoản: Force refresh token result: $success');
                if (success) {
                  authViewModel.refreshDriverInfo();
                }
              });
            }
            break;
        }
      });
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
