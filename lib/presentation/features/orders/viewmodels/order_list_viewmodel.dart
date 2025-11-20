import 'package:flutter/foundation.dart';

import '../../../../domain/entities/order.dart';
import '../../../../domain/usecases/orders/get_driver_orders_usecase.dart';
import '../../../common_widgets/base_viewmodel.dart';

enum OrderListState { initial, loading, loaded, error }

class OrderListViewModel extends BaseViewModel {
  final GetDriverOrdersUseCase _getDriverOrdersUseCase;

  OrderListState _state = OrderListState.initial;
  List<Order> _orders = [];
  String _errorMessage = '';

  OrderListState get state => _state;
  List<Order> get orders => _orders;
  String get errorMessage => _errorMessage;

  OrderListViewModel({required GetDriverOrdersUseCase getDriverOrdersUseCase})
    : _getDriverOrdersUseCase = getDriverOrdersUseCase;

  Future<void> getDriverOrders() async {
    if (_state == OrderListState.loading) return; // Tránh gọi nhiều lần

    _state = OrderListState.loading;
    notifyListeners();

    final result = await _getDriverOrdersUseCase();

    result.fold(
      (failure) async {
        _state = OrderListState.error;
        _errorMessage = failure.message;

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          // 
          await getDriverOrders();
          return;
        }

        notifyListeners();
      },
      (orders) {
        _state = OrderListState.loaded;
        _orders = orders;
        
        // Debug: Log all order statuses including CANCELLED
        for (var order in orders) {
        }
        final cancelledCount = orders.where((o) => o.status == 'CANCELLED').length;
        if (cancelledCount > 0) {
        }
        
        notifyListeners();
      },
    );
  }

  // Force refresh orders - bỏ qua kiểm tra loading state
  Future<void> refreshOrders() async {
    _state = OrderListState.loading;
    notifyListeners();

    final result = await _getDriverOrdersUseCase();

    result.fold(
      (failure) async {
        _state = OrderListState.error;
        _errorMessage = failure.message;

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          await refreshOrders();
          return;
        }

        notifyListeners();
      },
      (orders) {
        _state = OrderListState.loaded;
        _orders = orders;
        notifyListeners();
      },
    );
  }

  // Super force refresh - đảm bảo luôn được gọi, kể cả khi đang loading
  Future<void> superForceRefresh() async {
    _state = OrderListState.loading;
    notifyListeners();

    final result = await _getDriverOrdersUseCase();

    result.fold(
      (failure) async {
        _state = OrderListState.error;
        _errorMessage = failure.message;
        notifyListeners();
      },
      (orders) {
        _state = OrderListState.loaded;
        _orders = orders;
        
        // Debug: Log all order statuses including CANCELLED
        
        for (var order in orders) {
        }
        final cancelledCount = orders.where((o) => o.status == 'CANCELLED').length;
        if (cancelledCount > 0) {
        }
        notifyListeners();
      },
    );
  }

  // Lọc đơn hàng theo trạng thái
  List<Order> getOrdersByStatus(String status) {
    return _orders.where((order) => order.status == status).toList();
  }

  // Tìm kiếm đơn hàng
  List<Order> searchOrders(String query) {
    if (query.isEmpty) return _orders;

    final lowercaseQuery = query.toLowerCase();
    return _orders.where((order) {
      return order.orderCode.toLowerCase().contains(lowercaseQuery) ||
          order.receiverName.toLowerCase().contains(lowercaseQuery) ||
          order.receiverPhone.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}
