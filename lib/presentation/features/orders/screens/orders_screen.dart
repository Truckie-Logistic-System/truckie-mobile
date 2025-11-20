import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/di/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_status.dart';
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
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _authViewModel = getIt<AuthViewModel>();
    _orderListViewModel = getIt<OrderListViewModel>();

    // Đăng ký observer để theo dõi trạng thái app
    WidgetsBinding.instance.addObserver(this);

    // Set default filter to 'Tất cả' (which will show all orders from PICKING_UP onwards)
    _selectedStatus = 'Tất cả';

    // Lắng nghe thay đổi từ ViewModel
    _listenToViewModelChanges();

    // Fetch orders when the screen initializes
    if (_isInitialLoad) {
      _loadOrders();
      _isInitialLoad = false;
    }
  }

  @override
  void dispose() {
    // Hủy đăng ký observer khi widget bị hủy
    WidgetsBinding.instance.removeObserver(this);
    _orderListViewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Data will be loaded in initState when screen is first created
  }

  // Lắng nghe thay đổi từ OrderListViewModel để cập nhật UI
  void _listenToViewModelChanges() {
    _orderListViewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    // Force rebuild để đảm bảo UI cập nhật khi có refresh từ tab
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tải lại dữ liệu khi app trở lại foreground
    if (state == AppLifecycleState.resumed) {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    await _orderListViewModel.superForceRefresh();
  }

  // Public method để refresh data từ bên ngoài
  void refreshOrders() {
    _loadOrders();
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
            onPressed: () {
              _orderListViewModel.superForceRefresh();
            },
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
                          onRefresh: () async {
                            await _orderListViewModel.superForceRefresh();
                          },
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
                onPressed: () => viewModel.superForceRefresh(),
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

  /// Get list of valid statuses for driver (from FULLY_PAID onwards - ready for pickup)
  static const List<String> _validDriverStatuses = [
    'FULLY_PAID',
    'PICKING_UP',
    'ON_DELIVERED',
    'ONGOING_DELIVERED',
    'DELIVERED',
    'IN_TROUBLES',
    'RESOLVED',
    'COMPENSATION',
    'SUCCESSFUL',
    'RETURNING',
    'RETURNED',
    'CANCELLED',  // Include CANCELLED to show cancelled orders
  ];

  /// Check if order status is valid for driver view (FULLY_PAID or later)
  bool _isValidOrderStatus(String status) {
    return _validDriverStatuses.contains(status);
  }

  List<Order> _getFilteredOrders(OrderListViewModel viewModel) {
    // First, filter to only show orders from FULLY_PAID onwards
    final validOrders = viewModel.orders
        .where((order) => _isValidOrderStatus(order.status))
        .toList();

    if (_selectedStatus == 'Tất cả') {
      return validOrders;
    } else {
      return validOrders
          .where((order) => _getStatusText(order.status) == _selectedStatus)
          .toList();
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
              _buildFilterChip(
                'Đang lấy hàng',
                _selectedStatus == 'Đang lấy hàng',
                (selected) {
                  if (selected) {
                    setState(() => _selectedStatus = 'Đang lấy hàng');
                  }
                },
              ),
              SizedBox(width: 8.w),
              _buildFilterChip('Đang giao hàng', _selectedStatus == 'Đang giao hàng', (
                selected,
              ) {
                if (selected) {
                  setState(() => _selectedStatus = 'Đang giao hàng');
                }
              }),
              SizedBox(width: 8.w),
              _buildFilterChip('Đã giao hàng', _selectedStatus == 'Đã giao hàng', (
                selected,
              ) {
                if (selected) {
                  setState(() => _selectedStatus = 'Đã giao hàng');
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
              _buildFilterChip('Gặp sự cố', _selectedStatus == 'Gặp sự cố', (
                selected,
              ) {
                if (selected) {
                  setState(() => _selectedStatus = 'Gặp sự cố');
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
        onTap: () async {
          // Navigate to order details screen and reload when back
          final result = await Navigator.pushNamed(
            context,
            AppRoutes.orderDetail,
            arguments: order.id,
          );
          
          // Reload orders after returning from detail screen
          if (mounted && result == true) {
            _loadOrders();
          }
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
    final orderStatus = OrderStatus.fromString(status);
    switch (orderStatus) {
      case OrderStatus.pending:
      case OrderStatus.processing:
        return Colors.grey;
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.contractDraft:
      case OrderStatus.contractSigned:
      case OrderStatus.onPlanning:
        return Colors.blue;
      case OrderStatus.assignedToDriver:
      case OrderStatus.fullyPaid:
        return AppColors.warning;
      case OrderStatus.pickingUp:
        return Colors.orange;
      case OrderStatus.onDelivered:
      case OrderStatus.ongoingDelivered:
        return AppColors.inProgress;
      case OrderStatus.delivered:
      case OrderStatus.successful:
        return AppColors.success;
      case OrderStatus.inTroubles:
        return AppColors.error;
      case OrderStatus.resolved:
      case OrderStatus.compensation:
        return Colors.orange;
      case OrderStatus.rejectOrder:
        return AppColors.error;
      case OrderStatus.returning:
        return Colors.orange;
      case OrderStatus.returned:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    final orderStatus = OrderStatus.fromString(status);
    return orderStatus.toVietnamese();
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
