import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/app_routes.dart';
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

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<OrderDetailViewModel>();
    _authViewModel = getIt<AuthViewModel>();
    _orderListViewModel = getIt<OrderListViewModel>();
    _loadOrderDetails();
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

    return Stack(
      children: [
        SingleChildScrollView(
          padding: SystemUiService.getContentPadding(context).copyWith(
            bottom: (canStartDelivery || canConfirmPreDelivery)
                ? 100
                : 24, // Add extra padding at bottom when button is visible
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
              RouteMapSection(viewModel: viewModel),
              SizedBox(height: 24),
              VehicleSection(order: orderWithDetails),
              SizedBox(height: 24),
            ],
          ),
        ),

        // Sticky Start Delivery Button
        if (canStartDelivery)
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
              child: StartDeliverySection(order: orderWithDetails),
            ),
          ),

        // Sticky Pre-Delivery Documentation Button
        if (canConfirmPreDelivery)
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
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      AppRoutes.preDeliveryDocumentation,
                      arguments: orderWithDetails,
                    );

                    if (result == true) {
                      // Reload order details to reflect status change
                      _loadOrderDetails();
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
                  child: const Text('Xác nhận đóng gói và seal'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
