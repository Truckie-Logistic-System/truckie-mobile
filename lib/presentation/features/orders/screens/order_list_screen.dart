import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/order_list_viewmodel.dart';
import '../widgets/order_item.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = '';

  final List<Map<String, dynamic>> _statusFilters = [
    {'value': '', 'label': 'Tất cả'},
    {'value': 'ASSIGNED_TO_DRIVER', 'label': 'Đã giao cho tài xế'},
    {'value': 'PICKED_UP', 'label': 'Đã lấy hàng'},
    {'value': 'DELIVERING', 'label': 'Đang giao'},
    {'value': 'DELIVERED', 'label': 'Đã giao'},
    {'value': 'CANCELLED', 'label': 'Đã hủy'},
  ];

  @override
  void initState() {
    super.initState();

    // Lấy danh sách đơn hàng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tải lại dữ liệu khi màn hình được hiển thị lại
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      await Provider.of<OrderListViewModel>(
        context,
        listen: false,
      ).getDriverOrders();
    } catch (e) {
      debugPrint('Error loading orders: $e');
      // Nếu có lỗi, thử lại sau 1 giây
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _loadOrders();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách đơn hàng')),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatusFilter(),
          Expanded(
            child: Consumer<OrderListViewModel>(
              builder: (context, viewModel, child) {
                if (viewModel.state == OrderListState.loading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (viewModel.state == OrderListState.error) {
                  return _buildErrorView(viewModel.errorMessage);
                } else if (viewModel.state == OrderListState.loaded) {
                  final filteredOrders = _getFilteredOrders(viewModel);

                  if (filteredOrders.isEmpty) {
                    return _buildEmptyView();
                  }

                  return RefreshIndicator(
                    onRefresh: _loadOrders,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return OrderItem(
                          order: order,
                          onTap: () => _navigateToOrderDetail(order.id),
                        );
                      },
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm đơn hàng...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _statusFilters.length,
        itemBuilder: (context, index) {
          final filter = _statusFilters[index];
          final isSelected = _selectedStatus == filter['value'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter['label']),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedStatus = selected ? filter['value'] : '';
                });
              },
              backgroundColor: Colors.grey.shade100,
              selectedColor: Colors.blue.shade100,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue.shade800 : Colors.grey.shade800,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          const Text(
            'Đã xảy ra lỗi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(errorMessage, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadOrders, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Không có đơn hàng nào',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedStatus.isNotEmpty || _searchQuery.isNotEmpty
                ? 'Không tìm thấy đơn hàng phù hợp với bộ lọc'
                : 'Hiện tại bạn chưa có đơn hàng nào',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  List<dynamic> _getFilteredOrders(OrderListViewModel viewModel) {
    var filteredOrders = viewModel.orders;

    // Lọc theo trạng thái
    if (_selectedStatus.isNotEmpty) {
      filteredOrders = viewModel.getOrdersByStatus(_selectedStatus);
    }

    // Lọc theo từ khóa tìm kiếm
    if (_searchQuery.isNotEmpty) {
      filteredOrders = viewModel.searchOrders(_searchQuery);

      // Nếu đang lọc theo trạng thái, cần lọc thêm lần nữa
      if (_selectedStatus.isNotEmpty) {
        filteredOrders = filteredOrders
            .where((order) => order.status == _selectedStatus)
            .toList();
      }
    }

    return filteredOrders;
  }

  void _navigateToOrderDetail(String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(orderId: orderId),
      ),
    );
  }
}
