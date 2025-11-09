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
          // debugPrint('Token refreshed, retrying to get orders...');
          await getDriverOrders();
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

  // Force refresh orders - bỏ qua kiểm tra loading state
  Future<void> refreshOrders() async {
    debugPrint('🔄 OrderListViewModel: Force refreshing orders...');
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
          debugPrint('🔄 OrderListViewModel: Token refreshed, retrying force refresh...');
          await refreshOrders();
          return;
        }

        notifyListeners();
      },
      (orders) {
        _state = OrderListState.loaded;
        _orders = orders;
        debugPrint('✅ OrderListViewModel: Force refresh completed, got ${orders.length} orders');
        notifyListeners();
      },
    );
  }

  // Super force refresh - đảm bảo luôn được gọi, kể cả khi đang loading
  Future<void> superForceRefresh() async {
    debugPrint('🔄 OrderListViewModel: SUPER FORCE refreshing orders...');
    _state = OrderListState.loading;
    notifyListeners();

    final result = await _getDriverOrdersUseCase();

    result.fold(
      (failure) async {
        _state = OrderListState.error;
        _errorMessage = failure.message;
        debugPrint('❌ OrderListViewModel: Super force refresh failed: ${failure.message}');
        notifyListeners();
      },
      (orders) {
        _state = OrderListState.loaded;
        _orders = orders;
        debugPrint('✅ OrderListViewModel: Super force refresh completed, got ${orders.length} orders');
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
