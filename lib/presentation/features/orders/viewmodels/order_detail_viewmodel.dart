import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show debugPrint;

import '../../../../core/errors/failures.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/entities/order_detail.dart';
import '../../../../domain/repositories/photo_completion_repository.dart';
import '../../../../domain/repositories/vehicle_fuel_consumption_repository.dart';
import '../../../../domain/usecases/orders/get_order_details_usecase.dart';
import '../../../../domain/usecases/orders/update_order_to_delivered_usecase.dart';
import '../../../../domain/usecases/orders/update_order_to_ongoing_delivered_usecase.dart';
import '../../../../domain/usecases/vehicle/create_vehicle_fuel_consumption_usecase.dart';
import '../../../common_widgets/base_viewmodel.dart';
import '../../../../app/di/service_locator.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

enum OrderDetailState { initial, loading, loaded, error }

enum StartDeliveryState { initial, loading, success, error }

class OrderDetailViewModel extends BaseViewModel {
  final GetOrderDetailsUseCase _getOrderDetailsUseCase;
  final CreateVehicleFuelConsumptionUseCase _createVehicleFuelConsumptionUseCase;
  final PhotoCompletionRepository _photoCompletionRepository;
  final VehicleFuelConsumptionRepository _fuelConsumptionRepository;
  final UpdateOrderToDeliveredUseCase _updateToDeliveredUseCase;
  final UpdateOrderToOngoingDeliveredUseCase _updateToOngoingDeliveredUseCase;
  final AuthViewModel _authViewModel;

  OrderDetailState _state = OrderDetailState.initial;
  StartDeliveryState _startDeliveryState = StartDeliveryState.initial;
  OrderWithDetails? _orderWithDetails;
  String _errorMessage = '';
  String _startDeliveryErrorMessage = '';
  List<List<LatLng>> _routeSegments = [];
  int _selectedSegmentIndex = 0;
  
  // Photo completion state
  bool _isUploadingPhoto = false;
  String _photoUploadError = '';
  
  // Odometer state
  bool _isUploadingOdometer = false;
  String _odometerUploadError = '';
  String? _fuelConsumptionId;

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
  
  bool get isUploadingPhoto => _isUploadingPhoto;
  String get photoUploadError => _photoUploadError;
  bool get isUploadingOdometer => _isUploadingOdometer;
  String get odometerUploadError => _odometerUploadError;

  OrderDetailViewModel({
    required GetOrderDetailsUseCase getOrderDetailsUseCase,
    required CreateVehicleFuelConsumptionUseCase createVehicleFuelConsumptionUseCase,
    required PhotoCompletionRepository photoCompletionRepository,
    required VehicleFuelConsumptionRepository fuelConsumptionRepository,
    required UpdateOrderToDeliveredUseCase updateToDeliveredUseCase,
    required UpdateOrderToOngoingDeliveredUseCase updateToOngoingDeliveredUseCase,
    required AuthViewModel authViewModel,
  }) : _getOrderDetailsUseCase = getOrderDetailsUseCase,
       _createVehicleFuelConsumptionUseCase = createVehicleFuelConsumptionUseCase,
       _photoCompletionRepository = photoCompletionRepository,
       _fuelConsumptionRepository = fuelConsumptionRepository,
       _updateToDeliveredUseCase = updateToDeliveredUseCase,
       _updateToOngoingDeliveredUseCase = updateToOngoingDeliveredUseCase,
       _authViewModel = authViewModel;

  /// Get current user phone number from AuthViewModel
  String? _getCurrentUserPhoneNumber() {
    try {
      final driver = _authViewModel.driver;
      if (driver != null) {
        final phoneNumber = driver.userResponse?.phoneNumber;
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          // debugPrint('✅ Got current user phone: $phoneNumber');
          return phoneNumber;
        }
      }
      debugPrint('⚠️ Could not get current user phone from AuthViewModel');
    } catch (e) {
      debugPrint('❌ Error getting current user phone: $e');
    }
    return null;
  }

  Future<void> getOrderDetails(String orderId) async {
    if (_state == OrderDetailState.loading) return; 

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
          // debugPrint('Token refreshed, retrying to get order details...');
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

    if (_orderWithDetails == null) {
      return;
    }

    // Get current user's vehicle assignment (for multi-trip orders)
    final vehicleAssignment = getCurrentUserVehicleAssignment();
    if (vehicleAssignment == null || vehicleAssignment.journeyHistories.isEmpty) {
      return;
    }

    // Select the active journey (prefer ACTIVE status, fallback to first)
    JourneyHistory journeyHistory;
    try {
      journeyHistory = vehicleAssignment.journeyHistories.firstWhere(
        (j) => j.status == 'ACTIVE',
      );
    } catch (e) {
      journeyHistory = vehicleAssignment.journeyHistories.first;
    }

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
  /// Dựa trên OrderDetail Status của trip hiện tại, không chỉ dựa vào Order Status
  /// Điều này cho phép nhiều trip độc lập - Driver B có thể start trip 2 
  /// ngay cả khi Order đang PICKING_UP (do Trip 1 đã start)
  bool canStartDelivery() {
    if (_orderWithDetails == null) {
      // debugPrint('❌ canStartDelivery: orderWithDetails is null');
      return false;
    }
    
    // Must have vehicle assignments
    if (_orderWithDetails!.vehicleAssignments.isEmpty) {
      // debugPrint('❌ canStartDelivery: no vehicle assignments');
      return false;
    }
    
    // Must have order details with vehicle assignment ID
    if (_orderWithDetails!.orderDetails.isEmpty) {
      // debugPrint('❌ canStartDelivery: no order details');
      return false;
    }
    
    // CRITICAL: Check OrderDetail Status of current driver's trip, not Order Status
    // This allows multi-trip orders where Trip 2 can start even if Order is PICKING_UP
    // because Trip 1 already started
    final detailStatus = getCurrentTripOrderDetailStatus();
    if (detailStatus == null) {
      // debugPrint('❌ canStartDelivery: cannot get current trip detail status');
      return false;
    }
    
    // Can start delivery if current trip's OrderDetail status is ASSIGNED_TO_DRIVER
    // Order Status might be FULLY_PAID or PICKING_UP (if another trip started)
    if (detailStatus != 'ASSIGNED_TO_DRIVER') {
      // debugPrint('❌ canStartDelivery: detail status is $detailStatus, not ASSIGNED_TO_DRIVER');
      return false;
    }
    
    // Order must be FULLY_PAID or PICKING_UP (another trip might have started)
    final orderStatus = _orderWithDetails!.status;
    if (orderStatus != 'FULLY_PAID' && orderStatus != 'PICKING_UP') {
      // debugPrint('❌ canStartDelivery: order status is $orderStatus, not FULLY_PAID or PICKING_UP');
      return false;
    }
    
    final vehicleAssignmentId = _orderWithDetails!.orderDetails.first.vehicleAssignmentId;
    if (vehicleAssignmentId == null) {
      return false;
    }
    
    // Vehicle assignment must exist
    try {
      _orderWithDetails!.vehicleAssignments.firstWhere(
        (va) => va.id == vehicleAssignmentId,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Lấy OrderDetail Status của trip hiện tại (trip của driver hiện tại)
  /// Dùng phone number để match với primary driver
  String? getCurrentTripOrderDetailStatus() {
    if (_orderWithDetails == null || _orderWithDetails!.orderDetails.isEmpty) {
      return null;
    }

    // Get current user phone number
    final currentUserPhone = _getCurrentUserPhoneNumber();
    if (currentUserPhone == null || currentUserPhone.isEmpty) {
      return null;
    }

    // Find vehicle assignment where current user is primary driver
    VehicleAssignment? userVehicleAssignment;
    try {
      userVehicleAssignment = _orderWithDetails!.vehicleAssignments.firstWhere(
        (va) {
          if (va.primaryDriver == null) return false;
          return currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
        },
      );
    } catch (e) {
      debugPrint('❌ Could not find vehicle assignment for current user');
      return null;
    }

    if (userVehicleAssignment == null) {
      return null;
    }

    // Find order detail that belongs to this vehicle assignment
    try {
      final orderDetail = _orderWithDetails!.orderDetails.firstWhere(
        (od) => od.vehicleAssignmentId == userVehicleAssignment?.id,
      );
      return orderDetail.status;
    } catch (e) {
      debugPrint('❌ Could not find order detail for vehicle assignment');
      return null;
    }
  }

  /// Kiểm tra xem có thể bắt đầu lấy hàng không
  /// Dựa trên OrderDetail Status của trip hiện tại, không phải Order Status
  bool canStartPickup() {
    if (_orderWithDetails == null) return false;
    
    final detailStatus = getCurrentTripOrderDetailStatus();
    if (detailStatus == null) return false;
    
    // Can start pickup if detail status is ASSIGNED_TO_DRIVER or FULLY_PAID
    return detailStatus == 'ASSIGNED_TO_DRIVER' || detailStatus == 'FULLY_PAID';
  }

  /// Kiểm tra xem đơn hàng có thể xác nhận đóng gói và seal không
  /// Dựa trên OrderDetail Status của trip hiện tại
  bool canConfirmPreDelivery() {
    if (_orderWithDetails == null) return false;
    
    final detailStatus = getCurrentTripOrderDetailStatus();
    if (detailStatus == null) {
      // Fallback to Order Status if detail status not found
      return _orderWithDetails!.status == 'PICKING_UP';
    }
    
    // Can confirm pre-delivery if detail status is PICKING_UP
    return detailStatus == 'PICKING_UP';
  }

  /// Kiểm tra xem đơn hàng có thể xác nhận giao hàng không (chụp ảnh khách nhận hàng)
  /// Dựa trên OrderDetail Status của trip hiện tại
  bool canConfirmDelivery() {
    if (_orderWithDetails == null) return false;
    
    final detailStatus = getCurrentTripOrderDetailStatus();
    if (detailStatus == null) {
      // Fallback to Order Status if detail status not found
      return _orderWithDetails!.status == 'ONGOING_DELIVERED';
    }
    
    // Can confirm delivery if detail status is ONGOING_DELIVERED
    return detailStatus == 'ONGOING_DELIVERED';
  }

  /// Kiểm tra xem có thể upload odometer cuối không (khi đã về carrier)
  /// Dựa trên OrderDetail Status của trip hiện tại
  bool canUploadFinalOdometer() {
    if (_orderWithDetails == null) return false;
    
    final detailStatus = getCurrentTripOrderDetailStatus();
    if (detailStatus == null) {
      // Fallback to Order Status if detail status not found
      return _orderWithDetails!.status == 'DELIVERED';
    }
    
    // Can upload final odometer if detail status is DELIVERED or SUCCESSFUL
    return detailStatus == 'DELIVERED' || detailStatus == 'SUCCESSFUL';
  }

  /// Lấy vehicle assignment của driver hiện tại (primary driver)
  /// Dùng cho multi-trip orders để hiển thị đúng thông tin chuyến của driver
  VehicleAssignment? getCurrentUserVehicleAssignment() {
    if (_orderWithDetails == null || _orderWithDetails!.vehicleAssignments.isEmpty) {
      return null;
    }

    // Get current user phone number
    final currentUserPhone = _getCurrentUserPhoneNumber();
    if (currentUserPhone == null || currentUserPhone.isEmpty) {
      return null;
    }

    // Find vehicle assignment where current user is primary driver
    try {
      return _orderWithDetails!.vehicleAssignments.firstWhere(
        (va) {
          if (va.primaryDriver == null) return false;
          return currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
        },
      );
    } catch (e) {
      debugPrint('❌ Could not find vehicle assignment for current user: $e');
      // Fallback to first vehicle assignment if not found
      return _orderWithDetails!.vehicleAssignments.isNotEmpty 
          ? _orderWithDetails!.vehicleAssignments.first 
          : null;
    }
  }

  /// Lấy ID của vehicle assignment của driver hiện tại
  /// Dùng cho multi-trip orders để lấy ID chuyến của driver
  String? getVehicleAssignmentId() {
    final vehicleAssignment = getCurrentUserVehicleAssignment();
    return vehicleAssignment?.id;
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

    debugPrint(
      '🚗 Bắt đầu gửi thông tin odometer: ${odometerReading.toString()}',
    );
    debugPrint('🚗 Đường dẫn ảnh odometer: ${odometerImage.path}');
    debugPrint('🚗 Vehicle Assignment ID: $vehicleAssignmentId');

    try {
      final result = await _createVehicleFuelConsumptionUseCase(
        vehicleAssignmentId: vehicleAssignmentId,
        odometerReadingAtStart: odometerReading,
        odometerAtStartImage: odometerImage,
      );

      return result.fold(
        (failure) async {
          _startDeliveryState = StartDeliveryState.error;
          _startDeliveryErrorMessage = failure.message;
          debugPrint('❌ Lỗi khi bắt đầu chuyến xe: ${failure.message}');

          // Sử dụng handleUnauthorizedError từ BaseViewModel
          final shouldRetry = await handleUnauthorizedError(failure.message);
          if (shouldRetry) {
            // Nếu refresh token thành công, thử lại
            debugPrint('🔄 Token đã được làm mới, thử lại...');
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
          debugPrint('✅ Bắt đầu chuyến xe thành công!');
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      debugPrint('❌ Lỗi không xác định khi bắt đầu chuyến xe: $e');
      _startDeliveryState = StartDeliveryState.error;
      _startDeliveryErrorMessage = 'Lỗi không xác định: $e';
      notifyListeners();
      return false;
    }
  }

  void resetStartDeliveryState() {
    _startDeliveryState = StartDeliveryState.initial;
    _startDeliveryErrorMessage = '';
    notifyListeners();
  }

  Future<bool> uploadPhotoCompletion({
    required File imageFile,
    String? description,
  }) async {
    if (_orderWithDetails == null) {
      debugPrint('❌ Cannot upload photo: no order details');
      return false;
    }

    // Get vehicle assignment ID from current user's vehicle assignment
    final vehicleAssignmentId = getVehicleAssignmentId();

    if (vehicleAssignmentId == null) {
      debugPrint('❌ Cannot upload photo: no vehicle assignment ID');
      _photoUploadError = 'Không tìm thấy thông tin phân công xe';
      notifyListeners();
      return false;
    }

    _isUploadingPhoto = true;
    _photoUploadError = '';
    notifyListeners();

    debugPrint('📸 Uploading photo completion...');
    final result = await _photoCompletionRepository.uploadPhoto(
      vehicleAssignmentId,
      imageFile.path,
    );

    return result.fold(
      (failure) {
        _isUploadingPhoto = false;
        _photoUploadError = failure.message;
        debugPrint('❌ Failed to upload photo completion: ${failure.message}');
        notifyListeners();
        return false;
      },
      (success) {
        _isUploadingPhoto = false;
        debugPrint('✅ Photo completion uploaded successfully');
        notifyListeners();
        return true;
      },
    );
  }

  /// Upload multiple photo completions at delivery point
  Future<bool> uploadMultiplePhotoCompletion({
    required List<File> imageFiles,
    String? description,
  }) async {
    if (_orderWithDetails == null) {
      debugPrint('❌ Cannot upload photos: no order details');
      return false;
    }

    if (imageFiles.isEmpty) {
      debugPrint('❌ Cannot upload photos: no images provided');
      _photoUploadError = 'Vui lòng chụp ít nhất một ảnh';
      notifyListeners();
      return false;
    }

    // Get vehicle assignment ID from current user's vehicle assignment
    final vehicleAssignmentId = getVehicleAssignmentId();

    if (vehicleAssignmentId == null) {
      debugPrint('❌ Cannot upload photos: no vehicle assignment ID');
      _photoUploadError = 'Không tìm thấy thông tin phân công xe';
      notifyListeners();
      return false;
    }

    _isUploadingPhoto = true;
    _photoUploadError = '';
    notifyListeners();

    debugPrint('📸 Uploading ${imageFiles.length} photo completions...');
    // Upload all photos using the correct API endpoint
    final Either<Failure, bool> result = await _photoCompletionRepository.uploadMultiplePhotoCompletion(
      imageFiles: imageFiles,
      vehicleAssignmentId: vehicleAssignmentId,
      description: 'Photo completion at delivery',
    );

    return result.fold(
      (failure) {
        _isUploadingPhoto = false;
        _photoUploadError = failure.message;
        debugPrint('❌ Failed to upload photo completions: ${failure.message}');
        notifyListeners();
        return false;
      },
      (success) {
        _isUploadingPhoto = false;
        debugPrint('✅ Photo completions uploaded successfully');
        
        // NOTE: Backend handles status update automatically
        // When photo is uploaded, backend updates:
        // 1. OrderDetail status to DELIVERED (this trip)
        // 2. Order status (aggregated from all trips)
        
        notifyListeners();
        return true;
      },
    );
  }

  /// Update order status to ONGOING_DELIVERED when near delivery point (3km)
  Future<void> updateOrderStatusToOngoingDelivered() async {
    if (_orderWithDetails == null) {
      debugPrint('❌ Cannot update status: no order details');
      return;
    }

    // Check current status - skip if already ONGOING_DELIVERED or DELIVERED
    final currentStatus = _orderWithDetails!.status;
    debugPrint('📊 Current order status: $currentStatus');
    
    if (currentStatus == 'ONGOING_DELIVERED' || currentStatus == 'DELIVERED') {
      debugPrint('⏭️ Order already in $currentStatus status, skipping update');
      return;
    }

    debugPrint('🔄 Updating order status to ONGOING_DELIVERED...');
    final result = await _updateToOngoingDeliveredUseCase(_orderWithDetails!.id);
    
    result.fold(
      (failure) {
        debugPrint('❌ Failed to update order status to ONGOING_DELIVERED: ${failure.message}');
      },
      (success) {
        debugPrint('✅ Successfully updated order status to ONGOING_DELIVERED');
        // Reload order details to reflect new status
        getOrderDetails(_orderWithDetails!.id);
      },
    );
  }

  /// Load fuel consumption data to get ID for odometer update
  Future<void> loadFuelConsumptionData() async {
    if (_orderWithDetails == null) return;

    final vehicleAssignmentId = getVehicleAssignmentId();

    if (vehicleAssignmentId == null) return;

    debugPrint('🔍 Loading fuel consumption data...');
    final result = await _fuelConsumptionRepository.getByVehicleAssignmentId(vehicleAssignmentId);
    
    result.fold(
      (failure) {
        debugPrint('⚠️ Failed to load fuel consumption data: ${failure.message}');
      },
      (response) {
        debugPrint('📋 Fuel consumption response: $response');
        debugPrint('   - Type: ${response.runtimeType}');
        if (response['success'] == true && response['data'] != null) {
          _fuelConsumptionId = response['data']['id'];
          debugPrint('✅ Fuel consumption ID loaded: $_fuelConsumptionId');
        } else {
          debugPrint('⚠️ Response success=false or data is null');
          debugPrint('   - success: ${response['success']}');
          debugPrint('   - data: ${response['data']}');
        }
      },
    );
  }

  /// Upload final odometer reading at carrier
  Future<bool> uploadOdometerEnd({
    required File odometerImage,
    required double odometerReading,
  }) async {
    // Load fuel consumption ID if not already loaded
    if (_fuelConsumptionId == null) {
      await loadFuelConsumptionData();
    }

    if (_fuelConsumptionId == null) {
      debugPrint('❌ Cannot upload odometer: no fuel consumption ID');
      _odometerUploadError = 'Không tìm thấy thông tin nhiên liệu';
      notifyListeners();
      return false;
    }

    _isUploadingOdometer = true;
    _odometerUploadError = '';
    notifyListeners();

    debugPrint('📸 Uploading odometer end reading...');
    final result = await _fuelConsumptionRepository.updateFinalReading(
      fuelConsumptionId: _fuelConsumptionId!,
      odometerReadingAtEnd: odometerReading,
      odometerImage: odometerImage,
    );

    return result.fold(
      (failure) {
        _isUploadingOdometer = false;
        _odometerUploadError = failure.message;
        debugPrint('❌ Failed to upload odometer end: ${failure.message}');
        notifyListeners();
        return false;
      },
      (success) {
        _isUploadingOdometer = false;
        debugPrint('✅ Odometer end reading uploaded successfully');
        notifyListeners();
        return true;
      },
    );
  }
}
