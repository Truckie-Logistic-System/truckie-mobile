import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/screens/account_screen.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../home/screens/home_screen.dart';
import '../../orders/screens/orders_screen.dart';
import '../../notification/viewmodels/notification_viewmodel.dart';
import '../../notification/screens/notification_list_screen.dart';
import '../../chat/chat_screen.dart';
import '../../../theme/app_colors.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/chat_notification_service.dart';

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

    // Initialize NotificationViewModel and ChatNotificationService when main screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.driver != null) {
        final notificationViewModel = Provider.of<NotificationViewModel>(
          context,
          listen: false,
        );
        notificationViewModel.initialize(showLoading: false);
        
        // Initialize ChatNotificationService with driver ID
        final chatNotificationService = Provider.of<ChatNotificationService>(
          context,
          listen: false,
        );
        final driverId = authViewModel.driver!.id;
        chatNotificationService.initialize(driverId);
        
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Thông báo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
