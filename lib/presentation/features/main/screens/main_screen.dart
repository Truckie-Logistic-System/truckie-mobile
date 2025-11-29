import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../account/screens/account_screen.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../home/screens/home_screen.dart';
import '../../orders/screens/orders_screen.dart';
import '../../notification/viewmodels/notification_viewmodel.dart';
import '../../notification/widgets/notification_badge.dart';
import '../../notification/widgets/animated_bell_icon.dart';
import '../../notification/screens/notification_list_screen.dart';
import '../../../theme/app_colors.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/services/notification_service.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;

  const MainScreen({super.key, this.initialTab = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize selected index from widget parameter
    _selectedIndex = widget.initialTab;

    // Initialize NotificationViewModel when main screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.driver != null) {
        final notificationViewModel = Provider.of<NotificationViewModel>(
          context,
          listen: false,
        );
        notificationViewModel.initialize();
        
        // Subscribe to WebSocket for real-time badge updates
        _subscribeToWebSocket(notificationViewModel);
      }
    });
  }

  /// Subscribe to WebSocket notifications for real-time badge updates
  void _subscribeToWebSocket(NotificationViewModel notificationViewModel) {
    final notificationService = NotificationService();
    
    _notificationSubscription = notificationService.notificationStream.listen(
      (notification) {
        debugPrint('🔔 [MainScreen] New notification received - updating badge');
        // Refresh notification stats to update badge count
        notificationViewModel.refresh();
      },
      onError: (error) {
        debugPrint('❌ [MainScreen] WebSocket error: $error');
      },
    );
    
    debugPrint('✅ [MainScreen] Subscribed to WebSocket for badge updates');
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // Tạo màn hình tương ứng với tab được chọn
  Widget _getCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const OrdersScreen();
      case 2:
        return const NotificationListScreen();
      case 3:
        return const AccountScreen();
      default:
        return const HomeScreen();
    }
  }

  // Chuyển tab - screen sẽ được rebuild và fetch data mới
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
        child: _getCurrentScreen(),
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
              _buildNotificationNavItem(),
              _buildNavItem(3, Icons.person, 'Tài khoản'),
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

  Widget _buildNotificationNavItem() {
    final isSelected = _selectedIndex == 2;
    return Consumer<NotificationViewModel>(
      builder: (context, notificationViewModel, child) {
        final unreadCount = notificationViewModel.unreadCount;

        return InkWell(
          onTap: () => _onItemTapped(2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedBellIcon(
                      isSelected: isSelected,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Thông báo',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
