import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../domain/entities/order.dart';
import '../../../../presentation/common_widgets/responsive_grid.dart';
import '../../../../presentation/common_widgets/responsive_layout_builder.dart';
import '../../../../presentation/common_widgets/skeleton_loader.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';
import '../../../features/auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/order_list_viewmodel.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  late final AuthViewModel _authViewModel;
  late final OrderListViewModel _orderListViewModel;
  String _selectedStatus = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _authViewModel = getIt<AuthViewModel>();
    _orderListViewModel = getIt<OrderListViewModel>();

    // Đăng ký observer để theo dõi trạng thái app
    WidgetsBinding.instance.addObserver(this);

    // Fetch orders when the screen initializes
    _loadOrders();
  }

  @override
  void dispose() {
    // Hủy đăng ký observer khi widget bị hủy
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tải lại dữ liệu khi app trở lại foreground
    if (state == AppLifecycleState.resumed) {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    await _orderListViewModel.getDriverOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách đơn hàng'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Loại bỏ nút back
        actions: [
          // Thêm nút refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _authViewModel),
          ChangeNotifierProvider.value(value: _orderListViewModel),
        ],
        child: Consumer2<AuthViewModel, OrderListViewModel>(
          builder: (context, authViewModel, orderListViewModel, _) {
            return ResponsiveLayoutBuilder(
              builder: (context, sizingInformation) {
                return Padding(
                  padding: SystemUiService.getContentPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterSection(context, orderListViewModel),
                      SizedBox(height: 16.h),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadOrders,
                          color: AppColors.primary,
                          child: _buildOrdersContent(
                            context,
                            orderListViewModel,
                            sizingInformation,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrdersContent(
    BuildContext context,
    OrderListViewModel viewModel,
    SizingInformation sizingInformation,
  ) {
    switch (viewModel.state) {
      case OrderListState.loading:
        return const OrdersSkeletonList(itemCount: 5);

      case OrderListState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 48.r),
              SizedBox(height: 16.h),
              Text('Đã xảy ra lỗi', style: AppTextStyles.titleMedium),
              SizedBox(height: 8.h),
              Text(
                viewModel.errorMessage,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () => viewModel.getDriverOrders(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        );

      case OrderListState.loaded:
        final orders = _getFilteredOrders(viewModel);

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  color: AppColors.textSecondary,
                  size: 48.r,
                ),
                SizedBox(height: 16.h),
                Text('Không có đơn hàng nào', style: AppTextStyles.titleMedium),
                SizedBox(height: 8.h),
                Text(
                  'Hiện tại bạn không có đơn hàng nào với trạng thái này',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return _buildOrdersList(context, orders, sizingInformation);

      default:
        return const OrdersSkeletonList(itemCount: 5);
    }
  }

  List<Order> _getFilteredOrders(OrderListViewModel viewModel) {
    if (_selectedStatus == 'Tất cả') {
      return viewModel.orders;
    } else {
      return viewModel.getOrdersByStatus(_selectedStatus);
    }
  }

  Widget _buildFilterSection(
    BuildContext context,
    OrderListViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lọc theo trạng thái', style: AppTextStyles.titleMedium),
        SizedBox(height: 8.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Tất cả', _selectedStatus == 'Tất cả', (
                selected,
              ) {
                if (selected) {
                  setState(() => _selectedStatus = 'Tất cả');
                }
              }),
              SizedBox(width: 8.w),
              _buildFilterChip(
                'Chờ lấy hàng',
                _selectedStatus == 'Chờ lấy hàng',
                (selected) {
                  if (selected) {
                    setState(() => _selectedStatus = 'Chờ lấy hàng');
                  }
                },
              ),
              SizedBox(width: 8.w),
              _buildFilterChip('Đang giao', _selectedStatus == 'Đang giao', (
                selected,
              ) {
                if (selected) {
                  setState(() => _selectedStatus = 'Đang giao');
                }
              }),
              SizedBox(width: 8.w),
              _buildFilterChip('Hoàn thành', _selectedStatus == 'Hoàn thành', (
                selected,
              ) {
                if (selected) {
                  setState(() => _selectedStatus = 'Hoàn thành');
                }
              }),
              SizedBox(width: 8.w),
              _buildFilterChip('Đã hủy', _selectedStatus == 'Đã hủy', (
                selected,
              ) {
                if (selected) {
                  setState(() => _selectedStatus = 'Đã hủy');
                }
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    Function(bool) onSelected,
  ) {
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      onSelected: onSelected,
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    List<Order> orders,
    SizingInformation sizingInformation,
  ) {
    // Sử dụng grid layout cho tablet và phone layout cho điện thoại
    if (sizingInformation.isTablet) {
      return ResponsiveGrid(
        smallScreenColumns: 1,
        mediumScreenColumns: 2,
        largeScreenColumns: 2,
        horizontalSpacing: 16.w,
        verticalSpacing: 16.h,
        children: orders.map((order) {
          return _buildOrderItem(context, order);
        }).toList(),
      );
    } else {
      return ListView.separated(
        itemCount: orders.length,
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          return _buildOrderItem(context, orders[index]);
        },
      );
    }
  }

  Widget _buildOrderItem(BuildContext context, Order order) {
    final statusColor = _getStatusColor(order.status);
    final formattedDate = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(order.createdAt);
    final statusText = _getStatusText(order.status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: InkWell(
        onTap: () {
          // Navigate to order details screen
          Navigator.pushNamed(context, '/order-detail', arguments: order.id);
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Mã đơn: #${order.orderCode}',
                      style: AppTextStyles.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    color: AppColors.textSecondary,
                    size: 16.r,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Người nhận: ${order.receiverName}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(Icons.phone, color: AppColors.textSecondary, size: 16.r),
                  SizedBox(width: 8.w),
                  Text(
                    'SĐT: ${order.receiverPhone}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppColors.textSecondary,
                    size: 16.r,
                  ),
                  SizedBox(width: 8.w),
                  Text(formattedDate, style: AppTextStyles.bodyMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ASSIGNED_TO_DRIVER':
        return AppColors.warning;
      case 'FULLY_PAID':
      case 'PICKING_UP':
        return Colors.orange;
      case 'IN_PROGRESS':
      case 'DELIVERING':
        return AppColors.inProgress;
      case 'COMPLETED':
      case 'DELIVERED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'ASSIGNED_TO_DRIVER':
        return 'Chờ lấy hàng';
      case 'FULLY_PAID':
      case 'PICKING_UP':
        return 'Đang lấy hàng';
      case 'IN_PROGRESS':
      case 'DELIVERING':
        return 'Đang giao';
      case 'COMPLETED':
      case 'DELIVERED':
        return 'Hoàn thành';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return status;
    }
  }
}

class OrdersSkeletonList extends StatelessWidget {
  final int itemCount;

  const OrdersSkeletonList({super.key, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: itemCount,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: SkeletonLoader(width: 120, height: 20),
                    ),
                    SizedBox(width: 8.w),
                    const SkeletonLoader(width: 80, height: 24),
                  ],
                ),
                SizedBox(height: 12.h),
                const SkeletonLoader(width: double.infinity, height: 16),
                SizedBox(height: 8.h),
                const SkeletonLoader(width: 150, height: 16),
                SizedBox(height: 8.h),
                const SkeletonLoader(width: 100, height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
