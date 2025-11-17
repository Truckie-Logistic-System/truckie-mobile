import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import '../widgets/order_detail/issue_location_widget.dart';
import '../../../widgets/driver/return_delivery_confirmation_button.dart';

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
  Timer? _refreshTimer; // Timer for periodic UI refresh

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
    // CRITICAL: Use Timer.periodic instead of recursive Future.delayed
    // to prevent memory leaks and ensure proper cleanup
    _refreshTimer?.cancel(); // Cancel existing timer if any
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {}); // Refresh UI to update button state
      } else {
        timer.cancel(); // Auto-cleanup if widget disposed
      }
    });
  }

  @override
  void dispose() {
    // CRITICAL: Cancel periodic refresh timer to prevent memory leak
    _refreshTimer?.cancel();
    _refreshTimer = null;
    
    // Unregister this screen from GlobalLocationManager
    _globalLocationManager.unregisterScreen('OrderDetailScreen');
    super.dispose();
  }

  Future<void> _loadOrderDetails() async {
    await _viewModel.getOrderDetails(widget.orderId);
  }

  /// Handle return delivery confirmation and navigate back to NavigationScreen
  Future<void> _handleReturnDeliveryConfirmed() async {
    debugPrint('✅ OrderDetailScreen: Return delivery confirmed, handling navigation');
    
    // Reload order details to reflect status change
    await _loadOrderDetails();

    // Wait a bit for data to load
    await Future.delayed(const Duration(milliseconds: 500));

    // If tracking is active, pop back to NavigationScreen with result = true
    if (_globalLocationManager.isGlobalTrackingActive &&
        _globalLocationManager.currentOrderId == widget.orderId) {
      debugPrint('✅ Return delivery confirmed, popping back to NavigationScreen with result = true');
      if (mounted) {
        Navigator.of(context).pop(true); // Pop with result to signal resume
      }
    }
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
    final bool canReportOrderRejection = viewModel.canReportOrderRejection();
    final bool canConfirmReturnDelivery = viewModel.canConfirmReturnDelivery();
    final bool hasRouteData = viewModel.routeSegments.isNotEmpty;
    
    // Count issues for tab badge
    int totalIssues = 0;
    for (var va in orderWithDetails.vehicleAssignments) {
      totalIssues += va.issues.length;
    }
    
    // Check if navigation button should be shown (from FULLY_PAID to final status)
    final orderStatus = OrderStatus.fromString(orderWithDetails.status);
    final bool shouldShowNavigationButton = orderStatus == OrderStatus.fullyPaid ||
        orderStatus == OrderStatus.pickingUp ||
        orderStatus == OrderStatus.onDelivered ||
        orderStatus == OrderStatus.ongoingDelivered ||
        orderStatus == OrderStatus.delivered ||
        orderStatus == OrderStatus.inTroubles ||
        orderStatus == OrderStatus.resolved ||
        orderStatus == OrderStatus.compensation ||
        orderStatus == OrderStatus.successful ||
        orderStatus == OrderStatus.returning ||
        orderStatus == OrderStatus.returned;

    // Calculate bottom section height
    final bool hasActionButtons = canStartDelivery || canConfirmPreDelivery || canConfirmDelivery || canUploadFinalOdometer || canReportOrderRejection || canConfirmReturnDelivery;
    final double bottomPadding = hasActionButtons || shouldShowNavigationButton ? 200 : 24;

    return Stack(
      children: [
        DefaultTabController(
          length: 4,
          child: Column(
            children: [
              // Tab Bar
              Container(
                color: AppColors.primary,
                child: TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(text: 'Thông tin'),
                    Tab(text: 'Hàng hóa'),
                    Tab(text: 'Chuyến xe'),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Sự cố'),
                          if (totalIssues > 0) ...[
                            SizedBox(width: 4),
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                totalIssues.toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tab Views
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Thông tin đơn
                    _buildInfoTab(orderWithDetails, viewModel),
                    // Tab 2: Hàng hóa
                    _buildPackageTab(orderWithDetails),
                    // Tab 3: Chuyến xe & Lộ trình
                    _buildVehicleTab(orderWithDetails, viewModel),
                    // Tab 4: Sự cố
                    _buildIssuesTab(orderWithDetails, viewModel),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom Section with Navigation Button and Action Buttons
        if (shouldShowNavigationButton || hasActionButtons)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Navigation Button with transparent background (outside white container)
                if (shouldShowNavigationButton) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: hasActionButtons ? 8 : 12 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Builder(
                        builder: (context) {
                          final isConnected = _globalLocationManager.isTrackingOrder(orderWithDetails.id);
                          return FloatingActionButton.extended(
                            onPressed: () {
                              if (isConnected) {
                                bool hasNavigationScreen = false;
                                Navigator.of(context).popUntil((route) {
                                  if (route.settings.name == AppRoutes.navigation) {
                                    hasNavigationScreen = true;
                                    return true;
                                  }
                                  if (route.isFirst) return true;
                                  return false;
                                });
                                if (!hasNavigationScreen) {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.navigation,
                                    arguments: {
                                      'orderId': orderWithDetails.id,
                                      'isSimulationMode': true,
                                    },
                                  );
                                }
                              } else {
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
                              size: 20,
                            ),
                            label: Text(
                              isConnected ? 'Dẫn đường' : 'Lộ trình',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                
                // Action Buttons with white background
                if (hasActionButtons)
                  Container(
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Action Buttons
                        canStartDelivery
                        ? StartDeliverySection(order: orderWithDetails)
                        : canUploadFinalOdometer
                            ? FinalOdometerSection(order: orderWithDetails)
                            : canConfirmDelivery
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Nút xác nhận giao hàng (ONGOING_DELIVERED)
                                      DeliveryConfirmationSection(order: orderWithDetails),
                                      if (orderWithDetails.orderDetails.isNotEmpty) ...[  
                                        const SizedBox(height: 8),
                                        // Nút báo cáo hàng hư hại
                                        DamageReportWithLocation(
                                          order: orderWithDetails,
                                          onReported: _loadOrderDetails,
                                        ),
                                        const SizedBox(height: 8),
                                        // Nút báo cáo người nhận từ chối
                                        OrderRejectionWithLocation(
                                          order: orderWithDetails,
                                          onReported: _loadOrderDetails,
                                        ),
                                      ],
                                    ],
                                  )
                                : canReportOrderRejection
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Nút báo cáo người nhận từ chối (IN_TRANSIT only)
                                          OrderRejectionWithLocation(
                                            order: orderWithDetails,
                                            onReported: _loadOrderDetails,
                                          ),
                                        ],
                                      )
                                    : canConfirmReturnDelivery
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              // Return delivery confirmation button
                                              // Text(
                                              //   'Xác nhận trả hàng về pickup',
                                              //   style: TextStyle(
                                              //     fontSize: 16,
                                              //     fontWeight: FontWeight.bold,
                                              //     color: AppColors.primary,
                                              //   ),
                                              // ),
                                              // const SizedBox(height: 8),
                                              // Text(
                                              //   'Chụp ảnh xác nhận trả hàng về điểm lấy hàng',
                                              //   style: TextStyle(
                                              //     color: Colors.grey[600],
                                              //     fontSize: 14,
                                              //   ),
                                              // ),
                                              const SizedBox(height: 12),
                                              ReturnDeliveryConfirmationButton(
                                                issue: orderWithDetails.orderRejectionIssue!,
                                                onConfirmed: _handleReturnDeliveryConfirmed,
                                                issueRepository: getIt(),
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
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // Tab 1: Thông tin đơn hàng
  Widget _buildInfoTab(dynamic orderWithDetails, OrderDetailViewModel viewModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
          SizedBox(height: 120), // Bottom padding for buttons
        ],
      ),
    );
  }

  // Tab 2: Hàng hóa
  Widget _buildPackageTab(dynamic orderWithDetails) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PackageSection(order: orderWithDetails),
          SizedBox(height: 120), // Bottom padding for buttons
        ],
      ),
    );
  }

  // Tab 3: Chuyến xe & Lộ trình
  Widget _buildVehicleTab(dynamic orderWithDetails, OrderDetailViewModel viewModel) {
    final currentUserVehicleAssignment = viewModel.getCurrentUserVehicleAssignment();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thông tin chuyến xe và tài xế
          OrderDetailsSection(order: orderWithDetails),
          SizedBox(height: 16),
          
          // Journey info (chỉ hiển thị journey mới nhất)
          if (currentUserVehicleAssignment != null && 
              currentUserVehicleAssignment.journeyHistories.isNotEmpty) ...[
            JourneyInfoSection(
              journeyHistories: [currentUserVehicleAssignment.journeyHistories.first],
            ),
            SizedBox(height: 16),
          ],
          
          // Seal info
          if (currentUserVehicleAssignment != null && 
              currentUserVehicleAssignment.seals.isNotEmpty) ...[
            SealInfoSection(
              seals: currentUserVehicleAssignment.seals,
            ),
            SizedBox(height: 16),
          ],
          SizedBox(height: 120), // Bottom padding for buttons
        ],
      ),
    );
  }

  // Tab 4: Sự cố
  Widget _buildIssuesTab(dynamic orderWithDetails, OrderDetailViewModel viewModel) {
    final currentUserVehicleAssignment = viewModel.getCurrentUserVehicleAssignment();
    
    if (currentUserVehicleAssignment == null || currentUserVehicleAssignment.issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.success,
            ),
            SizedBox(height: 16),
            Text(
              'Không có sự cố nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 120, // Extra padding to avoid being covered by action button
      ),
      itemCount: currentUserVehicleAssignment.issues.length,
      itemBuilder: (context, index) {
        final issue = currentUserVehicleAssignment.issues[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _getIssueColor(issue.issueCategory),
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () {
              // Navigate to issue detail screen
              Navigator.pushNamed(
                context,
                AppRoutes.issueDetail,
                arguments: issue,
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getIssueColor(issue.issueCategory).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: _getIssueColor(issue.issueCategory),
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  issue.issueTypeName ?? 'Sự cố',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (issue.reportedAt != null) ...[
                                  SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Báo cáo: ${_formatDateTime(issue.reportedAt!)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getIssueStatusColor(issue.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getIssueStatusLabel(issue.status),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Description
                  if (issue.description != null && issue.description!.isNotEmpty) ...[
                    Text(
                      'Mô tả:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        issue.description!,
                        style: TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                  // Location with reverse geocoding
                  if (issue.locationLatitude != null && issue.locationLongitude != null) ...[
                    IssueLocationWidget(
                      latitude: issue.locationLatitude!,
                      longitude: issue.locationLongitude!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getIssueColor(String? category) {
    switch (category) {
      case 'ORDER_REJECTION':
        return Colors.red;
      case 'SEAL_REPLACEMENT':
        return Colors.orange;
      case 'DAMAGE':
        return Colors.deepOrange;
      default:
        return AppColors.primary;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  Color _getIssueStatusColor(String? status) {
    switch (status) {
      case 'OPEN':
        return AppColors.primary; // Blue
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.green;
      case 'PAYMENT_OVERDUE':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  String _getIssueStatusLabel(String? status) {
    switch (status) {
      case 'OPEN':
        return 'Chờ xử lý';
      case 'IN_PROGRESS':
        return 'Đang xử lý';
      case 'RESOLVED':
        return 'Đã giải quyết';
      case 'PAYMENT_OVERDUE':
        return 'Quá hạn thanh toán';
      default:
        return status ?? 'Không rõ';
    }
  }

  /// Format DateTime to Vietnamese format (dd/MM/yyyy HH:mm)
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm', 'vi').format(dateTime);
  }
}
