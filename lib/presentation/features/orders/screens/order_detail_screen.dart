import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/global_location_manager.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../../../core/utils/driver_role_checker.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../viewmodels/order_detail_viewmodel.dart';
import '../viewmodels/order_list_viewmodel.dart';
import '../widgets/order_detail/index.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrderDetailViewModel _viewModel;
  late final AuthViewModel _authViewModel;
  late final OrderListViewModel _orderListViewModel;
  late final GlobalLocationManager _globalLocationManager;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<OrderDetailViewModel>();
    _authViewModel = getIt<AuthViewModel>();
    _orderListViewModel = getIt<OrderListViewModel>();
    _globalLocationManager = getIt<GlobalLocationManager>();
    
    // Register this screen with GlobalLocationManager
    _globalLocationManager.registerScreen('OrderDetailScreen');
    
    _loadOrderDetails();

    // Rebuild UI periodically to check WebSocket status
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _startPeriodicRefresh();
      }
    });
  }

  void _startPeriodicRefresh() {
    // Refresh UI every 2 seconds to update button state
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {});
        _startPeriodicRefresh();
      }
    });
  }

  @override
  void dispose() {
    // Unregister this screen from GlobalLocationManager
    _globalLocationManager.unregisterScreen('OrderDetailScreen');
    
    // Tải lại danh sách đơn hàng khi màn hình chi tiết bị đóng
    _orderListViewModel.getDriverOrders();
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    await _viewModel.getOrderDetails(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _viewModel),
        ChangeNotifierProvider.value(value: _authViewModel),
        ChangeNotifierProvider.value(value: _orderListViewModel),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết đơn hàng'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Pop back to orders screen
              Navigator.of(context).popUntil((route) {
                return route.settings.name == AppRoutes.orders ||
                    route.settings.name == AppRoutes.main ||
                    route.isFirst;
              });
            },
            tooltip: 'Quay lại danh sách đơn hàng',
          ),
          actions: [
            // Thêm nút refresh
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrderDetails,
              tooltip: 'Làm mới',
            ),
          ],
        ),
        body: Consumer2<OrderDetailViewModel, AuthViewModel>(
          builder: (context, viewModel, authViewModel, _) {
            switch (viewModel.state) {
              case OrderDetailState.loading:
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              case OrderDetailState.error:
                return ErrorView(
                  message: viewModel.errorMessage,
                  onRetry: _loadOrderDetails,
                );
              case OrderDetailState.loaded:
                if (viewModel.orderWithDetails == null) {
                  return ErrorView(
                    message: 'Không tìm thấy thông tin đơn hàng',
                    onRetry: _loadOrderDetails,
                  );
                }
                return _buildOrderDetailContent(viewModel);
              default:
                return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  Widget _buildOrderDetailContent(OrderDetailViewModel viewModel) {
    final orderWithDetails = viewModel.orderWithDetails!;
    final bool canStartDelivery = viewModel.canStartDelivery();
    final bool canConfirmPreDelivery = viewModel.canConfirmPreDelivery();
    final bool hasRouteData = viewModel.routeSegments.isNotEmpty;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: SystemUiService.getContentPadding(context).copyWith(
            bottom: (canStartDelivery || canConfirmPreDelivery)
                ? 100
                : (hasRouteData
                      ? 70
                      : 24), // Add extra padding at bottom when buttons are visible
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin cơ bản đơn hàng
              OrderInfoSection(order: orderWithDetails),
              SizedBox(height: 16),

              // Mã đơn hàng
              TrackingCodeSection(order: orderWithDetails),
              SizedBox(height: 16),

              // Địa chỉ lấy/giao hàng
              AddressSection(order: orderWithDetails),
              SizedBox(height: 16),

              // Thời gian dự kiến
              JourneyTimeSection(order: orderWithDetails),
              SizedBox(height: 16),

              // Thông tin người gửi
              SenderSection(order: orderWithDetails),
              SizedBox(height: 16),

              // Thông tin người nhận
              ReceiverSection(order: orderWithDetails),
              SizedBox(height: 16),

              // Thông tin hàng hóa
              PackageSection(order: orderWithDetails),
              SizedBox(height: 16),

              // Chi tiết đơn hàng + Vehicle Assignment + Tài xế
              OrderDetailsSection(order: orderWithDetails),
              SizedBox(height: 24),
            ],
          ),
        ),

        // Route Details / Navigation Button
        // Always show if has route data, but behavior changes based on WebSocket status
        if (hasRouteData)
          Positioned(
            bottom: (canStartDelivery || canConfirmPreDelivery) ? 100 : 16,
            right: 16,
            child: Builder(
              builder: (context) {
                // Use GlobalLocationManager to check if tracking is active for this order
                final isConnected = _globalLocationManager.isTrackingOrder(orderWithDetails.id);
                debugPrint('🔍 FAB - Global tracking active for order ${orderWithDetails.id}: $isConnected');

                return FloatingActionButton.extended(
                  onPressed: () {
                    if (isConnected) {
                      // Return to navigation screen (already has active connection)
                      // Just navigate back, the screen will detect existing connection
                      Navigator.pushNamed(
                        context,
                        AppRoutes.navigation,
                        arguments: {
                          'orderId': orderWithDetails.id,
                          'isSimulationMode':
                              false, // Will be ignored if already connected
                        },
                      );
                    } else {
                      // Go to route details to start navigation
                      Navigator.pushNamed(
                        context,
                        AppRoutes.routeDetails,
                        arguments: viewModel,
                      );
                    }
                  },
                  heroTag: 'routeDetailsButton',
                  backgroundColor: isConnected
                      ? AppColors.success
                      : AppColors.primary,
                  elevation: 4,
                  icon: Icon(
                    isConnected ? Icons.navigation : Icons.map_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    isConnected ? 'Dẫn đường' : 'Lộ trình',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),

        // Action Buttons Row (white background)
        if (canStartDelivery || canConfirmPreDelivery)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: canStartDelivery
                  ? StartDeliverySection(order: orderWithDetails)
                  : ElevatedButton(
                      onPressed: () async {
                        // Kiểm tra driver role trước khi cho phép thực hiện action
                        if (!DriverRoleChecker.canPerformActions(orderWithDetails, _authViewModel)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(DriverRoleChecker.getSecondaryDriverActionMessage()),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          return;
                        }

                        final result = await Navigator.pushNamed(
                          context,
                          AppRoutes.preDeliveryDocumentation,
                          arguments: orderWithDetails,
                        );

                        if (result == true) {
                          // Reload order details to reflect status change
                          _loadOrderDetails();

                          // If tracking is active, navigate back to continue
                          if (_globalLocationManager.isGlobalTrackingActive) {
                            Navigator.of(context).pushNamed(
                              AppRoutes.navigation,
                              arguments: {
                                'orderId': orderWithDetails.id,
                                'isSimulationMode': true,
                              },
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Xác nhận hàng hóa và seal'),
                    ),
            ),
          ),
      ],
    );
  }
}
