import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/di/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../../../core/services/chat_notification_service.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/common_widgets/responsive_layout_builder.dart';
import '../../../../presentation/common_widgets/skeleton_loader.dart';
import '../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../presentation/features/orders/viewmodels/order_list_viewmodel.dart';
import '../../chat/chat_screen.dart';
import '../widgets/index.dart';
import '../widgets/simplified_dashboard_card.dart';
import '../widgets/simplified_recent_orders_card.dart';
import '../viewmodels/dashboard_viewmodel.dart';

/// Màn hình trang chủ của ứng dụng với Dashboard KPI
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthViewModel _authViewModel;
  late final DashboardViewModel _dashboardViewModel;
  late final OrderListViewModel _orderListViewModel;

  @override
  void initState() {
    super.initState();
    _authViewModel = getIt<AuthViewModel>();
    _dashboardViewModel = getIt<DashboardViewModel>();
    _orderListViewModel = getIt<OrderListViewModel>();

    // Đảm bảo token được refresh khi vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_authViewModel.status == AuthStatus.authenticated) {
        // Chờ refresh token xong rồi mới gọi API dashboard/orders
        final success = await _authViewModel.forceRefreshToken();
        if (success) {
          // Load dashboard data
          await _dashboardViewModel.loadDashboard();
          // Load recent orders
          await _orderListViewModel.getDriverOrders();
        }
      }
    });
  }

  @override
  void dispose() {
    _dashboardViewModel.reset();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Tải lại thông tin tài xế khi màn hình được hiển thị lại
    if (_authViewModel.status == AuthStatus.authenticated) {
      _authViewModel.refreshDriverInfo();
      // Refresh dashboard if needed
      if (!_dashboardViewModel.hasData && !_dashboardViewModel.isLoading) {
        _dashboardViewModel.loadDashboard();
      }
      // Load recent orders if needed
      if (_orderListViewModel.state == OrderListState.initial) {
        _orderListViewModel.getDriverOrders();
      }
    }
  }

  // Public method để refresh data từ bên ngoài
  void refreshHomeData() {
    if (_authViewModel.status == AuthStatus.authenticated) {
      // Force refresh token trước, sau đó refresh driver info và dashboard
      _authViewModel.forceRefreshToken().then((success) {
        if (success) {
          _authViewModel.refreshDriverInfo();
          _dashboardViewModel.refresh();
          _orderListViewModel.refreshOrders();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _authViewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Truckie Driver'),
          centerTitle: true,
          automaticallyImplyLeading: false, // Loại bỏ nút back
          actions: [
            // Chat icon with badge
            Consumer<ChatNotificationService>(
              builder: (context, chatService, child) {
                final unreadCount = chatService.unreadCount;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: () {
                        chatService.markAsRead();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatScreen(
                              trackingCode: null,
                              vehicleAssignmentId: null,
                              fromTabNavigation: false,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Hỗ trợ trực tuyến',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
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
                );
              },
            ),
          ],
        ),
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: _authViewModel),
            ChangeNotifierProvider.value(value: _dashboardViewModel),
            ChangeNotifierProvider.value(value: _orderListViewModel),
          ],
          child: Consumer3<AuthViewModel, DashboardViewModel, OrderListViewModel>(
            builder: (context, authViewModel, dashboardViewModel, orderListViewModel, _) {
              final user = authViewModel.user;
              final driver = authViewModel.driver;
              final dashboard = dashboardViewModel.dashboard;
              final isDashboardLoading = dashboardViewModel.isLoading;

              // Always show content, use skeleton loaders when data is not available
              return SafeArea(
                // Đặt bottom: false vì đã xử lý trong MainScreen
                bottom: false,
                child: SingleChildScrollView(
                  // Thêm padding bottom để đảm bảo nội dung không bị che bởi navigation bar
                  padding: SystemUiService.getContentPadding(context),
                  child: ResponsiveLayoutBuilder(
                    builder: (context, sizingInformation) {
                      // Use different layouts based on screen size
                      if (sizingInformation.isTablet) {
                        // Tablet layout with 2 columns
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Driver info with skeleton loading
                            if (user == null || driver == null)
                              const DriverInfoSkeletonCard()
                            else
                              DriverInfoCard(user: user, driver: driver),
                            SizedBox(height: 16.h),

                            // Dashboard Filter
                            DashboardFilterBar(
                              selectedRange: dashboardViewModel.currentRange,
                              onRangeChanged: (range) {
                                _dashboardViewModel.loadDashboard(range: range);
                              },
                            ),
                            SizedBox(height: 16.h),

                            // AI Summary
                            AiSummaryCard(
                              summary: _dashboardViewModel.aiSummary,
                              isLoading: _dashboardViewModel.isAiSummaryLoading,
                              error: _dashboardViewModel.aiSummaryError,
                              onRetry: _dashboardViewModel.retryAiSummary,
                            ),
                            SizedBox(height: 16.h),

                            // Simplified Dashboard Summary
                            SimplifiedDashboardCard(
                              dashboard: dashboard,
                              isLoading: isDashboardLoading,
                              periodLabel: _getPeriodLabel(dashboardViewModel.currentRange),
                            ),
                            SizedBox(height: 16.h),

                            // Trip Trend Chart
                            TripTrendChart(
                              trendData: dashboardViewModel.tripTrend,
                              isLoading: isDashboardLoading,
                            ),
                            SizedBox(height: 16.h),

                            // Simplified Recent Orders
                            SimplifiedRecentOrdersCard(
                              orders: dashboard?.recentOrders ?? [],
                              isLoading: isDashboardLoading,
                              onViewAll: () {
                                // Điều hướng tới MainScreen với tab Đơn hàng (giữ bottom navigation)
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.main,
                                  arguments: const {
                                    'initialTab': 1, // 0 = Home, 1 = Orders
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      } else {
                        // Phone layout with single column
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Driver info with skeleton loading
                            if (user == null || driver == null)
                              const DriverInfoSkeletonCard()
                            else
                              DriverInfoCard(user: user, driver: driver),
                            SizedBox(height: 16.h),

                            // Dashboard Filter
                            DashboardFilterBar(
                              selectedRange: dashboardViewModel.currentRange,
                              onRangeChanged: (range) {
                                _dashboardViewModel.loadDashboard(range: range);
                              },
                            ),
                            SizedBox(height: 16.h),

                            // AI Summary
                            AiSummaryCard(
                              summary: _dashboardViewModel.aiSummary,
                              isLoading: _dashboardViewModel.isAiSummaryLoading,
                              error: _dashboardViewModel.aiSummaryError,
                              onRetry: _dashboardViewModel.retryAiSummary,
                            ),
                            SizedBox(height: 16.h),

                            // Simplified Dashboard Summary
                            SimplifiedDashboardCard(
                              dashboard: dashboard,
                              isLoading: isDashboardLoading,
                              periodLabel: _getPeriodLabel(dashboardViewModel.currentRange),
                            ),
                            SizedBox(height: 16.h),

                            // Trip Trend Chart
                            TripTrendChart(
                              trendData: dashboardViewModel.tripTrend,
                              isLoading: isDashboardLoading,
                            ),
                            SizedBox(height: 16.h),

                            // Simplified Recent Orders
                            SimplifiedRecentOrdersCard(
                              orders: dashboard?.recentOrders ?? [],
                              isLoading: isDashboardLoading,
                              onViewAll: () {
                                // Điều hướng tới MainScreen với tab Đơn hàng (giữ bottom navigation)
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.main,
                                  arguments: const {
                                    'initialTab': 1, // 0 = Home, 1 = Orders
                                  },
                                );
                              },
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _getPeriodLabel(String range) {
    switch (range) {
      case 'WEEK':
        return 'Tổng quan tuần này';
      case 'MONTH':
        return 'Tổng quan tháng này';
      case 'YEAR':
        return 'Tổng quan năm nay';
      default:
        return 'Tổng quan';
    }
  }
}
