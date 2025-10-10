import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show debugPrint;

import '../../../../domain/entities/order_detail.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/usecases/orders/get_order_details_usecase.dart';
import '../../../../domain/usecases/vehicle/create_vehicle_fuel_consumption_usecase.dart';
import '../../../common_widgets/base_viewmodel.dart';

enum OrderDetailState { initial, loading, loaded, error }

enum StartDeliveryState { initial, loading, success, error }

class OrderDetailViewModel extends BaseViewModel {
  final GetOrderDetailsUseCase _getOrderDetailsUseCase;
  final CreateVehicleFuelConsumptionUseCase
  _createVehicleFuelConsumptionUseCase;

  OrderDetailState _state = OrderDetailState.initial;
  StartDeliveryState _startDeliveryState = StartDeliveryState.initial;
  OrderWithDetails? _orderWithDetails;
  String _errorMessage = '';
  String _startDeliveryErrorMessage = '';
  List<List<LatLng>> _routeSegments = [];
  int _selectedSegmentIndex = 0;

  OrderDetailState get state => _state;
  StartDeliveryState get startDeliveryState => _startDeliveryState;
  OrderWithDetails? get orderWithDetails => _orderWithDetails;
  String get errorMessage => _errorMessage;
  String get startDeliveryErrorMessage => _startDeliveryErrorMessage;
  List<List<LatLng>> get routeSegments => _routeSegments;
  int get selectedSegmentIndex => _selectedSegmentIndex;
  List<LatLng> get selectedRoute =>
      _routeSegments.isNotEmpty && _selectedSegmentIndex < _routeSegments.length
      ? _routeSegments[_selectedSegmentIndex]
      : [];

  OrderDetailViewModel({
    required GetOrderDetailsUseCase getOrderDetailsUseCase,
    required CreateVehicleFuelConsumptionUseCase
    createVehicleFuelConsumptionUseCase,
  }) : _getOrderDetailsUseCase = getOrderDetailsUseCase,
       _createVehicleFuelConsumptionUseCase =
           createVehicleFuelConsumptionUseCase;

  Future<void> getOrderDetails(String orderId) async {
    if (_state == OrderDetailState.loading) return; // Tránh gọi nhiều lần

    _state = OrderDetailState.loading;
    notifyListeners();

    final result = await _getOrderDetailsUseCase(orderId);

    result.fold(
      (failure) async {
        _state = OrderDetailState.error;
        _errorMessage = failure.message;

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          debugPrint('Token refreshed, retrying to get order details...');
          await getOrderDetails(orderId);
          return;
        }

        notifyListeners();
      },
      (orderWithDetails) {
        _state = OrderDetailState.loaded;
        _orderWithDetails = orderWithDetails;
        _parseRouteSegments();
        notifyListeners();
      },
    );
  }

  void selectSegment(int index) {
    if (index >= 0 && index < _routeSegments.length) {
      _selectedSegmentIndex = index;
      notifyListeners();
    }
  }

  void _parseRouteSegments() {
    _routeSegments = [];

    if (_orderWithDetails == null || _orderWithDetails!.orderDetails.isEmpty) {
      return;
    }

    final orderDetail = _orderWithDetails!.orderDetails.first;
    if (orderDetail.vehicleAssignment == null ||
        orderDetail.vehicleAssignment!.journeyHistories.isEmpty) {
      return;
    }

    final journeyHistory =
        orderDetail.vehicleAssignment!.journeyHistories.first;

    for (var segment in journeyHistory.journeySegments) {
      try {
        final List<LatLng> points = [];
        final List<dynamic> coordinates = json.decode(
          segment.pathCoordinatesJson,
        );

        for (var coordinate in coordinates) {
          if (coordinate is List && coordinate.length >= 2) {
            // Chú ý: Trong JSON, tọa độ được lưu dưới dạng [longitude, latitude]
            final double lng = coordinate[0].toDouble();
            final double lat = coordinate[1].toDouble();
            points.add(LatLng(lat, lng));
          }
        }

        if (points.isNotEmpty) {
          _routeSegments.add(points);
        }
      } catch (e) {
        debugPrint('Error parsing route segment: $e');
      }
    }
  }

  /// Kiểm tra xem đơn hàng có thể bắt đầu giao hàng không
  bool canStartDelivery() {
    if (_orderWithDetails == null) return false;
    return _orderWithDetails!.status == 'FULLY_PURCHASED';
  }

  /// Kiểm tra xem đơn hàng có thể xác nhận đóng gói và seal không
  bool canConfirmPreDelivery() {
    if (_orderWithDetails == null) return false;
    return _orderWithDetails!.status == 'PICKING_UP' ||
        _orderWithDetails!.status == 'FULLY_PURCHASED';
  }

  /// Lấy ID của vehicle assignment
  String? getVehicleAssignmentId() {
    if (_orderWithDetails == null || _orderWithDetails!.orderDetails.isEmpty) {
      return null;
    }

    final orderDetail = _orderWithDetails!.orderDetails.first;
    if (orderDetail.vehicleAssignment == null) {
      return null;
    }

    return orderDetail.vehicleAssignment!.id;
  }

  /// Bắt đầu giao hàng
  Future<bool> startDelivery({
    required Decimal odometerReading,
    required File odometerImage,
  }) async {
    final vehicleAssignmentId = getVehicleAssignmentId();
    if (vehicleAssignmentId == null) {
      _startDeliveryState = StartDeliveryState.error;
      _startDeliveryErrorMessage = 'Không tìm thấy thông tin phương tiện';
      notifyListeners();
      return false;
    }

    _startDeliveryState = StartDeliveryState.loading;
    notifyListeners();

    final result = await _createVehicleFuelConsumptionUseCase(
      vehicleAssignmentId: vehicleAssignmentId,
      odometerReadingAtStart: odometerReading,
      odometerAtStartImage: odometerImage,
    );

    return result.fold(
      (failure) async {
        _startDeliveryState = StartDeliveryState.error;
        _startDeliveryErrorMessage = failure.message;

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          return startDelivery(
            odometerReading: odometerReading,
            odometerImage: odometerImage,
          );
        }

        notifyListeners();
        return false;
      },
      (success) {
        _startDeliveryState = StartDeliveryState.success;
        notifyListeners();
        return true;
      },
    );
  }

  void resetStartDeliveryState() {
    _startDeliveryState = StartDeliveryState.initial;
    _startDeliveryErrorMessage = '';
    notifyListeners();
  }
}
