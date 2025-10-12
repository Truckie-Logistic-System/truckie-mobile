import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/integrated_location_service.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../features/auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/order_detail_viewmodel.dart';
import '../viewmodels/order_list_viewmodel.dart';
import '../widgets/order_detail/index.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrderDetailViewModel _viewModel;
  late final AuthViewModel _authViewModel;
  late final OrderListViewModel _orderListViewModel;
  late final IntegratedLocationService _integratedLocationService;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<OrderDetailViewModel>();
    _authViewModel = getIt<AuthViewModel>();
    _orderListViewModel = getIt<OrderListViewModel>();
    _integratedLocationService = IntegratedLocationService.instance;
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
              OrderInfoSection(order: orderWithDetails),
              SizedBox(height: 16),
              TrackingCodeSection(order: orderWithDetails),
              SizedBox(height: 16),
              AddressSection(order: orderWithDetails),
              SizedBox(height: 16),
              JourneyTimeSection(order: orderWithDetails),
              SizedBox(height: 16),
              SenderSection(order: orderWithDetails),
              SizedBox(height: 16),
              ReceiverSection(order: orderWithDetails),
              SizedBox(height: 16),
              PackageSection(order: orderWithDetails),
              SizedBox(height: 24),
              VehicleSection(order: orderWithDetails),
              SizedBox(height: 24),
              
              // Nút bắt đầu dẫn đường (chỉ hiển thị khi chưa có tracking và có route data)
              if (hasRouteData && !_integratedLocationService.isActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Nút bắt đầu dẫn đường thực
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.navigation,
                            arguments: {
                              'orderId': orderWithDetails.id,
                              'isSimulationMode': false, // Real-time mode
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.navigation),
                            SizedBox(width: 8),
                            Text('Bắt đầu dẫn đường'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Nút mô phỏng
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.navigation,
                            arguments: {
                              'orderId': orderWithDetails.id,
                              'isSimulationMode': true, // Simulation mode
                            },
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car),
                            SizedBox(width: 8),
                            Text('Mô phỏng dẫn đường'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                final isConnected = _integratedLocationService.isActive;
                debugPrint('🔍 FAB - Integrated tracking active: $isConnected');
                
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
                          'isSimulationMode': false, // Will be ignored if already connected
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
                  backgroundColor: isConnected ? AppColors.success : AppColors.primary,
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
                        final result = await Navigator.pushNamed(
                          context,
                          AppRoutes.preDeliveryDocumentation,
                          arguments: orderWithDetails,
                        );

                        if (result == true) {
                          // Reload order details to reflect status change
                          _loadOrderDetails();

                          // If we're in simulation mode (tracking active), navigate back to continue simulation
                          if (_integratedLocationService.isActive) {
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
