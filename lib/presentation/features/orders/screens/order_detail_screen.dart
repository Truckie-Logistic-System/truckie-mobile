import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/global_location_manager.dart';
import '../../../../app/di/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../../utils/driver_role_checker.dart';
import '../../../../domain/entities/order_status.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../viewmodels/order_detail_viewmodel.dart';
import '../viewmodels/order_list_viewmodel.dart';
import '../widgets/order_detail/index.dart';
import '../widgets/order_detail/delivery_confirmation_section.dart';
import '../widgets/order_detail/final_odometer_section.dart';

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
    
    // Load order details and try to restore navigation state
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load order details first
      await _loadOrderDetails();
      
      debugPrint('🔍 OrderDetailScreen - Checking restore conditions:');
      debugPrint('   - Current order ID: ${widget.orderId}');
      debugPrint('   - Order status: ${_viewModel.orderWithDetails?.status}');
      debugPrint('   - Active tracking order: ${_globalLocationManager.currentOrderId}');
      debugPrint('   - Is tracking active: ${_globalLocationManager.isGlobalTrackingActive}');
      
      // Try to restore navigation state if app was restarted during delivery
      // Check if there's a saved navigation state for this order
      final activeOrderId = _globalLocationManager.currentOrderId;
      
      if (activeOrderId == null || activeOrderId != widget.orderId) {
        // Only try to restore if order is in active delivery state
        final orderStatusString = _viewModel.orderWithDetails?.status;
        if (orderStatusString != null) {
          final orderStatus = OrderStatus.fromString(orderStatusString);
          
          debugPrint('   - Order status enum: ${orderStatus.name}');
          debugPrint('   - Is active delivery: ${orderStatus.isActiveDelivery}');
          
          if (orderStatus.isActiveDelivery) {
            debugPrint('🔄 Attempting to restore navigation state...');
            // No active tracking or different order - try to restore
            final restored = await _globalLocationManager.tryRestoreNavigationState();
            if (restored) {
              debugPrint('✅ Navigation state restored - WebSocket reconnected');
              // Check if restored order matches current order
              if (_globalLocationManager.currentOrderId == widget.orderId) {
                if (mounted) {
                  setState(() {}); // Update UI to show navigation button
                }
              }
            } else {
              debugPrint('❌ Failed to restore navigation state');
            }
          } else {
            debugPrint('ℹ️ Order not in active delivery state (${orderStatus.toVietnamese()}), skipping restore');
          }
        } else {
          debugPrint('⚠️ Order status is null, cannot check restore conditions');
        }
      } else {
        debugPrint('ℹ️ Already tracking this order: $activeOrderId');
        // Already tracking this order, just update UI
        if (mounted) {
          setState(() {});
        }
      }
      
      if (_authViewModel.status == AuthStatus.authenticated) {
        // Nếu chưa có driver info hoặc cần refresh, gọi refreshDriverInfo
        if (_authViewModel.driver == null) {
          await _authViewModel.refreshDriverInfo();
          // Sau khi có driver info, reload order details để cập nhật UI
          if (mounted) {
            setState(() {});
          }
        }
      }
    });

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
      child: WillPopScope(
        onWillPop: () async {
          // Check if navigation is active - if yes, we came from NavigationScreen
          debugPrint('🔙 OrderDetail back pressed');
          
          final isNavigationActive = _globalLocationManager.isGlobalTrackingActive &&
                                     _globalLocationManager.currentOrderId == widget.orderId;
          
          if (isNavigationActive) {
            // Came from NavigationScreen, go to main screen Orders tab
            debugPrint('   - Navigation active, going to main screen Orders tab');
            // Pop all routes and push MainScreen with Orders tab (index 1)
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.main,
              (route) => false, // Remove all routes
              arguments: {'initialTab': 1}, // Orders tab
            );
          } else {
            // Normal case: just pop back
            debugPrint('   - Normal pop back');
            Navigator.of(context).pop(true);
          }
          
          return false; // Prevent default pop since we handle it manually
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Chi tiết đơn hàng'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                // Check if navigation is active
                debugPrint('🔙 OrderDetail back button pressed');
                
                final isNavigationActive = _globalLocationManager.isGlobalTrackingActive &&
                                           _globalLocationManager.currentOrderId == widget.orderId;
                
                if (isNavigationActive) {
                  // Came from NavigationScreen, go to main screen Orders tab
                  debugPrint('   - Navigation active, going to main screen Orders tab');
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.main,
                    (route) => false, // Remove all routes
                    arguments: {'initialTab': 1}, // Orders tab
                  );
                } else {
                  // Normal case: just pop back
                  debugPrint('   - Normal pop back');
                  Navigator.of(context).pop(true);
                }
              },
              tooltip: 'Quay lại',
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
      ),
    );
  }

  Widget _buildOrderDetailContent(OrderDetailViewModel viewModel) {
    final orderWithDetails = viewModel.orderWithDetails!;
    final bool canStartDelivery = viewModel.canStartDelivery();
    final bool canConfirmPreDelivery = viewModel.canConfirmPreDelivery();
    final bool canConfirmDelivery = viewModel.canConfirmDelivery();
    final bool canUploadFinalOdometer = viewModel.canUploadFinalOdometer();
    final bool hasRouteData = viewModel.routeSegments.isNotEmpty;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: SystemUiService.getContentPadding(context).copyWith(
            bottom: (canStartDelivery || canConfirmPreDelivery || canConfirmDelivery || canUploadFinalOdometer)
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
              SizedBox(height: 16),

              // Journey info section (khoảng cách, phí cầu đường, v.v.)
              // For multi-trip orders: show only current driver's trip info
              if (orderWithDetails.vehicleAssignments.isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final currentUserVehicleAssignment = viewModel.getCurrentUserVehicleAssignment();
                    if (currentUserVehicleAssignment != null && 
                        currentUserVehicleAssignment.journeyHistories.isNotEmpty) {
                      return Column(
                        children: [
                          JourneyInfoSection(
                            journeyHistories: currentUserVehicleAssignment.journeyHistories,
                          ),
                          SizedBox(height: 16),
                        ],
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ],

              // Seal info section
              // For multi-trip orders: show only current driver's trip seals
              if (orderWithDetails.vehicleAssignments.isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final currentUserVehicleAssignment = viewModel.getCurrentUserVehicleAssignment();
                    if (currentUserVehicleAssignment != null && 
                        currentUserVehicleAssignment.orderSeals.isNotEmpty) {
                      return Column(
                        children: [
                          SealInfoSection(
                            seals: currentUserVehicleAssignment.orderSeals,
                          ),
                          SizedBox(height: 16),
                        ],
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ],

              // Final odometer upload section (when order is DELIVERED)
              if (canUploadFinalOdometer)
                FinalOdometerSection(order: orderWithDetails),
              
              SizedBox(height: 24),
            ],
          ),
        ),

        // Route Details / Navigation Button
        // Always show if has route data, but behavior changes based on WebSocket status
        if (hasRouteData)
          Positioned(
            bottom: (canStartDelivery || canConfirmPreDelivery || canConfirmDelivery || canUploadFinalOdometer) ? 120 : 16,
            right: 16,
            child: Builder(
              builder: (context) {
                // Use GlobalLocationManager to check if tracking is active for this order
                final isConnected = _globalLocationManager.isTrackingOrder(orderWithDetails.id);

                return FloatingActionButton.extended(
                  onPressed: () {
                    if (isConnected) {
                      // CRITICAL: Check if NavigationScreen exists in stack
                      debugPrint('🔙 Returning to existing NavigationScreen');
                      debugPrint('   - Current route stack:');
                      
                      // Check if NavigationScreen exists in the navigation stack
                      bool hasNavigationScreen = false;
                      Navigator.of(context).popUntil((route) {
                        debugPrint('   - Checking route: ${route.settings.name}');
                        if (route.settings.name == AppRoutes.navigation) {
                          hasNavigationScreen = true;
                          return true; // Stop here, found NavigationScreen
                        }
                        if (route.isFirst) {
                          return true; // Stop at root
                        }
                        return false; // Keep checking
                      });
                      
                      // If NavigationScreen not found, push a new one
                      if (!hasNavigationScreen) {
                        debugPrint('⚠️ NavigationScreen not in stack, pushing new one');
                        Navigator.pushNamed(
                          context,
                          AppRoutes.navigation,
                          arguments: {
                            'orderId': orderWithDetails.id,
                            'isSimulationMode': true, // Resume in simulation mode
                          },
                        );
                      } else {
                        debugPrint('✅ Found and returned to NavigationScreen');
                      }
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
        if (canStartDelivery || canConfirmPreDelivery || canConfirmDelivery || canUploadFinalOdometer)
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
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 12 + MediaQuery.of(context).padding.bottom,
              ),
              child: canStartDelivery
                  ? StartDeliverySection(order: orderWithDetails)
                  : canUploadFinalOdometer
                      ? FinalOdometerSection(order: orderWithDetails)
                      : canConfirmDelivery
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DeliveryConfirmationSection(order: orderWithDetails),
                                if (orderWithDetails.orderDetails.isNotEmpty)
                                  DamageReportWithLocation(
                                    order: orderWithDetails,
                                    onReported: _loadOrderDetails,
                                  ),
                              ],
                            )
                          : ElevatedButton(
                      onPressed: () async {
                        // Kiểm tra driver role trước khi cho phép thực hiện action
                        if (!DriverRoleChecker.canPerformActions(orderWithDetails, _authViewModel)) {
                          // Không hiển thị thông báo, chỉ return để thân thiện với user
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

                          // If tracking is active, just pop back to NavigationScreen
                          // DO NOT create new NavigationScreen with pushNamed
                          if (_globalLocationManager.isGlobalTrackingActive &&
                              _globalLocationManager.currentOrderId == orderWithDetails.id) {
                            debugPrint('✅ Seal confirmed, popping back to NavigationScreen with result = true');
                            Navigator.of(context).pop(true); // Pop with result to signal resume
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
