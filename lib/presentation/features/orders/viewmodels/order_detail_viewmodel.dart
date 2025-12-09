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
import '../../../../domain/entities/order_detail_status.dart';
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
  double? _odometerReadingAtEnd; // Track if final odometer has been uploaded
  
  // Concurrent operation lock to prevent duplicate start
  bool _isStartingTrip = false;

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
  double? get odometerReadingAtEnd => _odometerReadingAtEnd;

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
          // 
          return phoneNumber;
        }
      }
    } catch (e) {
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
          // 
          await getOrderDetails(orderId);
          return;
        }

        notifyListeners();
      },
      (orderWithDetails) async {
        _state = OrderDetailState.loaded;
        _orderWithDetails = orderWithDetails;
        _parseRouteSegments();
        
        // Load fuel consumption data to check if final odometer has been uploaded
        // This is important to hide "Hoàn thành chuyến xe" button if already completed
        await loadFuelConsumptionData();
        
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

    // Select the journey based on order status
    // For ONGOING_DELIVERED, we need the journey regardless of its status
    JourneyHistory journeyHistory;
    try {
      // First try to find ACTIVE journey
      journeyHistory = vehicleAssignment.journeyHistories.firstWhere(
        (j) => j.status == 'ACTIVE',
      );
    } catch (e) {
      try {
        // If no ACTIVE journey, try to find INACTIVE journey (for ONGOING_DELIVERED status)
        journeyHistory = vehicleAssignment.journeyHistories.firstWhere(
          (j) => j.status == 'INACTIVE',
        );
      } catch (e2) {
        // Fallback to first journey if no specific status found
        journeyHistory = vehicleAssignment.journeyHistories.first;
      }
    }

    for (var segment in journeyHistory.journeySegments) {
      try {
        // Skip segments with null pathCoordinatesJson (e.g., return journey placeholder segments)
        if (segment.pathCoordinatesJson == null || segment.pathCoordinatesJson!.isEmpty) {
          continue;
        }

        final List<LatLng> points = [];
        final List<dynamic> coordinates = json.decode(
          segment.pathCoordinatesJson!,
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
      }
    }
  }

  /// Kiểm tra xem đơn hàng có thể bắt đầu giao hàng không
  /// Dựa trên OrderDetail Status của trip hiện tại, không chỉ dựa vào Order Status
  /// Điều này cho phép nhiều trip độc lập - Driver B có thể start trip 2 
  /// ngay cả khi Order đang PICKING_UP (do Trip 1 đã start)
  bool canStartDelivery() {
    if (_orderWithDetails == null) {
      // 
      return false;
    }
    
    // Must have vehicle assignments
    if (_orderWithDetails!.vehicleAssignments.isEmpty) {
      // 
      return false;
    }
    
    // Must have order details with vehicle assignment ID
    if (_orderWithDetails!.orderDetails.isEmpty) {
      // 
      return false;
    }
    
    // CRITICAL: Check OrderDetail Status of current driver's trip, not Order Status
    // This allows multi-trip orders where Trip 2 can start even if Order is PICKING_UP
    // because Trip 1 already started
    final detailStatus = getCurrentTripOrderDetailStatus();
    if (detailStatus == null) {
      // 
      return false;
    }
    
    // Can start delivery if current trip's OrderDetail status is ASSIGNED_TO_DRIVER
    // Order Status might be FULLY_PAID or PICKING_UP (if another trip started)
    if (detailStatus != 'ASSIGNED_TO_DRIVER') {
      // 
      return false;
    }
    
    // Order must be FULLY_PAID or PICKING_UP (another trip might have started)
    final orderStatus = _orderWithDetails!.status;
    if (orderStatus != 'FULLY_PAID' && orderStatus != 'PICKING_UP') {
      // 
      return false;
    }
    
    // CRITICAL FIX: Use getCurrentUserVehicleAssignment() instead of orderDetails.first
    // Bug: orderDetails.first might belong to another driver's trip in multi-trip orders
    final vehicleAssignment = getCurrentUserVehicleAssignment();
    if (vehicleAssignment == null) {
      // 
      return false;
    }
    
    // Vehicle assignment must exist and belong to current driver
    return true;
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
      return null;
    }

    if (userVehicleAssignment == null) {
      return null;
    }

    // Find first order detail that belongs to this vehicle assignment
    try {
      final orderDetail = _orderWithDetails!.orderDetails.firstWhere(
        (od) => od.vehicleAssignmentId == userVehicleAssignment?.id,
      );
      return orderDetail.status;
    } catch (e) {
      return null;
    }
  }

  /// Helper: Lấy OrderDetailStatus enum của trip hiện tại
  /// Trả về null nếu không tìm được hoặc status không hợp lệ
  OrderDetailStatus? getCurrentTripStatusEnum() {
    final statusString = getCurrentTripOrderDetailStatus();
    if (statusString == null) {
      return null;
    }

    try {
      return OrderDetailStatus.fromString(statusString);
    } catch (_) {
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
    
    final detailStatusEnum = getCurrentTripStatusEnum();
    if (detailStatusEnum == null) {
      // Nếu không xác định được status trip hiện tại, không cho phép action
      return false;
    }

    // Có thể xác nhận đóng gói & seal khi trip đang ở trạng thái PICKING_UP
    return detailStatusEnum == OrderDetailStatus.pickingUp;
  }

  /// Kiểm tra xem đơn hàng có thể xác nhận giao hàng không (chụp ảnh khách nhận hàng)
  /// Dựa trên OrderDetail Status của trip hiện tại
  bool canConfirmDelivery() {
    if (_orderWithDetails == null) return false;
    
    final detailStatusEnum = getCurrentTripStatusEnum();
    if (detailStatusEnum == null) {
      return false;
    }

    // Có thể xác nhận giao hàng khi trip đang ở ONGOING_DELIVERED
    return detailStatusEnum == OrderDetailStatus.ongoingDelivered;
  }

  /// Kiểm tra xem có thể upload odometer cuối không (khi đã về carrier)
  /// Dựa trên OrderDetail Status của trip hiện tại
  /// 
  /// CRITICAL: Driver PHẢI upload odometer cuối với TẤT CẢ các trường hợp END-OF-TRIP:
  /// - DELIVERED: Giao hàng thành công → SUCCESSFUL
  /// - IN_TROUBLES: Có sự cố (tai nạn, xe hỏng), staff chưa xử lý → GIỮ NGUYÊN
  /// - COMPENSATION: Hàng hư hại đã bồi thường → GIỮ NGUYÊN
  /// - RETURNED: Đã trả hàng về pickup (customer reject) → GIỮ NGUYÊN
  /// - CANCELLED: Khách không trả tiền return → GIỮ NGUYÊN
  /// - SUCCESSFUL: Đã upload rồi (allow re-upload)
  /// 
  /// ⚠️ KHÔNG bao gồm RETURNING: Driver PHẢI đến pickup trước, không có exception!
  /// RETURNING → confirmReturnDelivery → RETURNED → upload odo cuối
  /// 
  /// Backend logic: Chỉ DELIVERED → SUCCESSFUL, các status khác giữ nguyên
  /// 
  /// FIX: Không hiển thị nút nếu đã upload final odometer rồi (check qua _odometerReadingAtEnd)
  bool canUploadFinalOdometer() {
    if (_orderWithDetails == null) return false;
    
    // CRITICAL FIX: If final odometer already uploaded, don't show button
    // This prevents showing button after RETURNED status completed with odometer
    if (_odometerReadingAtEnd != null && _odometerReadingAtEnd! > 0) {
      // 
      return false;
    }
    
    // CRITICAL: Nếu có bất kỳ package nào đang RETURNING, không cho phép upload odometer
    // Driver phải hoàn thành việc trả hàng về pickup trước
    final userVehicleAssignment = getCurrentUserVehicleAssignment();
    if (userVehicleAssignment != null) {
      final hasReturningPackage = _orderWithDetails!.orderDetails.any(
        (od) => od.vehicleAssignmentId == userVehicleAssignment.id && 
                od.status == 'RETURNING'
      );
      if (hasReturningPackage) {
        return false;
      }
    }
    
    final detailStatus = getCurrentTripOrderDetailStatus();
    if (detailStatus == null) {
      // Fallback to Order Status if detail status not found
      return _orderWithDetails!.status == 'DELIVERED' || 
             _orderWithDetails!.status == 'IN_TROUBLES' ||
             _orderWithDetails!.status == 'COMPENSATION' ||
             _orderWithDetails!.status == 'RETURNED' ||
             _orderWithDetails!.status == 'CANCELLED';
    }
    
    // Can upload final odometer for ALL end-of-trip states
    // Driver MUST return to carrier regardless of delivery outcome
    // NOTE: RETURNING excluded - driver must reach pickup first!
    return detailStatus == 'DELIVERED' || 
           detailStatus == 'IN_TROUBLES' ||
           detailStatus == 'COMPENSATION' ||
           detailStatus == 'RETURNED' ||
           detailStatus == 'CANCELLED' ||
           detailStatus == 'SUCCESSFUL';
  }

  /// Kiểm tra xem có thể báo cáo người nhận từ chối nhận hàng không
  /// Dựa trên OrderDetail Status của trip hiện tại
  bool canReportOrderRejection() {
    if (_orderWithDetails == null) return false;
    
    final detailStatusEnum = getCurrentTripStatusEnum();
    if (detailStatusEnum == null) {
      return false;
    }

    // Có thể báo cáo từ chối khi:
    // - ON_DELIVERED: đang trên đường giao hàng (đã xác nhận seal + đóng gói)
    // - ONGOING_DELIVERED: đã tới điểm giao, đang giao hàng
    return detailStatusEnum == OrderDetailStatus.onDelivered ||
        detailStatusEnum == OrderDetailStatus.ongoingDelivered;
  }

  /// Quyết định xem có nên hiển thị nút điều hướng (Navigation) cho driver không
  /// Multi-trip safe: chỉ xét các OrderDetail thuộc vehicle assignment của tài xế hiện tại
  /// và đảm bảo trip này có journeyHistories (tức là đã có lộ trình)
  bool shouldShowNavigationButton() {
    if (_orderWithDetails == null) {
      return false;
    }

    // Lấy vehicle assignment của tài xế hiện tại
    final vehicleAssignment = getCurrentUserVehicleAssignment();
    if (vehicleAssignment == null) {
      return false;
    }

    // Nếu trip chưa có journey history thì chưa có lộ trình để điều hướng
    if (vehicleAssignment.journeyHistories.isEmpty) {
      return false;
    }

    // Kiểm tra xem trong trip hiện tại có ít nhất một OrderDetail không bị REJECTED
    // Điều này tương đương với việc trip này vẫn còn/đã từng active
    final hasNonRejectedDetail = _orderWithDetails!.orderDetails.any((od) {
      if (od.vehicleAssignmentId != vehicleAssignment.id) {
        return false;
      }

      final statusEnum = OrderDetailStatus.fromString(od.status);
      return statusEnum != OrderDetailStatus.rejected;
    });

    return hasNonRejectedDetail;
  }

  /// Kiểm tra xem có thể xác nhận trả hàng về pickup không
  /// Dựa trên OrderDetail Status của trip hiện tại
  bool canConfirmReturnDelivery() {
    if (_orderWithDetails == null) return false;
    
    // Kiểm tra orderRejectionIssue phải tồn tại
    if (_orderWithDetails!.orderRejectionIssue == null) {
      return false;
    }
    
    // Get current user's vehicle assignment
    final userVehicleAssignment = getCurrentUserVehicleAssignment();
    if (userVehicleAssignment == null) {
      return false;
    }
    
    // Kiểm tra nếu có ít nhất 1 OrderDetail với status RETURNING trong trip hiện tại
    final hasReturningPackage = _orderWithDetails!.orderDetails.any(
      (od) => od.vehicleAssignmentId == userVehicleAssignment.id && 
              od.status == 'RETURNING'
    );
    
    return hasReturningPackage;
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

  /// Validate all required data before starting trip
  /// Returns error message if validation fails, null if success
  String? _validateTripStartData() {
    // 1. Check order data loaded
    if (_orderWithDetails == null) {
      return 'Chưa tải được thông tin đơn hàng. Vui lòng thử lại.';
    }
    
    // 2. Check vehicle assignment exists
    final vehicleAssignment = getCurrentUserVehicleAssignment();
    if (vehicleAssignment == null) {
      return 'Không tìm thấy thông tin phân công xe.';
    }
    
    // 3. Check phone number (for WebSocket subscription)
    final phoneNumber = _getCurrentUserPhoneNumber();
    if (phoneNumber == null) {
      return 'Không tìm thấy thông tin tài xế.';
    }
    
    return null; // Validation success
  }
  
  /// Prepare image for upload (just return original)
  Future<File> _prepareOdometerImage(File originalImage) async {
    try {
      // Check original file size for logging only
      final originalSize = await originalImage.length();
      debugPrint('📷 Image size: ${(originalSize / 1024).toStringAsFixed(2)} KB');
      
      // Return original image without compression
      return originalImage;
    } catch (e) {
      debugPrint('❌ Image preparation error: $e');
      // Fallback to original on any error
      return originalImage;
    }
  }

  Future<bool> startDelivery({
    required Decimal odometerReading,
    required File odometerImage,
  }) async {
    // 🔒 Prevent concurrent start attempts
    if (_isStartingTrip) {
      debugPrint('⚠️ Trip start already in progress, ignoring duplicate call');
      return false;
    }
    
    _isStartingTrip = true;
    
    try {
      // ✅ Validate all required data first
      final validationError = _validateTripStartData();
      if (validationError != null) {
        _startDeliveryState = StartDeliveryState.error;
        _startDeliveryErrorMessage = validationError;
        notifyListeners();
        return false;
      }
      
      final vehicleAssignmentId = getVehicleAssignmentId();
      if (vehicleAssignmentId == null) {
        _startDeliveryState = StartDeliveryState.error;
        _startDeliveryErrorMessage = 'Không tìm thấy thông tin phương tiện';
        notifyListeners();
        return false;
      }

      _startDeliveryState = StartDeliveryState.loading;
      notifyListeners();
      
      // 📷 Prepare image for upload
      debugPrint('📷 Preparing odometer image...');
      final preparedImage = await _prepareOdometerImage(odometerImage);
      debugPrint('✅ Image ready for upload');

      
      final result = await _createVehicleFuelConsumptionUseCase(
        vehicleAssignmentId: vehicleAssignmentId,
        odometerReadingAtStart: odometerReading,
        odometerAtStartImage: preparedImage,
      );

      return result.fold(
        (failure) async {
          _startDeliveryState = StartDeliveryState.error;
          _startDeliveryErrorMessage = failure.message;
          // Sử dụng handleUnauthorizedError từ BaseViewModel
          final shouldRetry = await handleUnauthorizedError(failure.message);
          if (shouldRetry) {
            // Nếu refresh token thành công, thử lại
            _isStartingTrip = false; // Reset lock before retry
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
    } catch (e) {
      _startDeliveryState = StartDeliveryState.error;
      _startDeliveryErrorMessage = 'Lỗi không xác định: $e';
      notifyListeners();
      return false;
    } finally {
      // 🔓 Always release lock
      _isStartingTrip = false;
    }
  }
  
  void resetStartDeliveryState() {
    _startDeliveryState = StartDeliveryState.initial;
    _startDeliveryErrorMessage = '';
    _isStartingTrip = false; // Also reset lock
    notifyListeners();
  }

  Future<bool> uploadPhotoCompletion({
    required File imageFile,
    String? description,
  }) async {
    if (_orderWithDetails == null) {
      return false;
    }

    // Get vehicle assignment ID from current user's vehicle assignment
    final vehicleAssignmentId = getVehicleAssignmentId();

    if (vehicleAssignmentId == null) {
      _photoUploadError = 'Không tìm thấy thông tin phân công xe';
      notifyListeners();
      return false;
    }

    _isUploadingPhoto = true;
    _photoUploadError = '';
    notifyListeners();
    final result = await _photoCompletionRepository.uploadPhoto(
      vehicleAssignmentId,
      imageFile.path,
    );

    return result.fold(
      (failure) {
        _isUploadingPhoto = false;
        _photoUploadError = failure.message;
        notifyListeners();
        return false;
      },
      (success) {
        _isUploadingPhoto = false;
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
      return false;
    }

    if (imageFiles.isEmpty) {
      _photoUploadError = 'Vui lòng chụp ít nhất một ảnh';
      notifyListeners();
      return false;
    }

    // Get vehicle assignment ID from current user's vehicle assignment
    final vehicleAssignmentId = getVehicleAssignmentId();

    if (vehicleAssignmentId == null) {
      _photoUploadError = 'Không tìm thấy thông tin phân công xe';
      notifyListeners();
      return false;
    }

    _isUploadingPhoto = true;
    _photoUploadError = '';
    notifyListeners();
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
        notifyListeners();
        return false;
      },
      (success) {
        _isUploadingPhoto = false;
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
      return;
    }

    // Check current status - skip if already ONGOING_DELIVERED or DELIVERED
    final currentStatus = _orderWithDetails!.status;
    if (currentStatus == 'ONGOING_DELIVERED' || currentStatus == 'DELIVERED') {
      return;
    }
    final result = await _updateToOngoingDeliveredUseCase(_orderWithDetails!.id);
    
    result.fold(
      (failure) {
      },
      (success) {
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
    final result = await _fuelConsumptionRepository.getByVehicleAssignmentId(vehicleAssignmentId);
    
    result.fold(
      (failure) {
      },
      (response) {
        if (response['success'] == true && response['data'] != null) {
          _fuelConsumptionId = response['data']['id'];
          // Check if final odometer reading has been uploaded
          final odometerEnd = response['data']['odometerReadingAtEnd'];
          if (odometerEnd != null) {
            _odometerReadingAtEnd = (odometerEnd is num) ? odometerEnd.toDouble() : null;
          } else {
            _odometerReadingAtEnd = null;
          }
        } else {
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
      _odometerUploadError = 'Không tìm thấy thông tin nhiên liệu';
      notifyListeners();
      return false;
    }

    _isUploadingOdometer = true;
    _odometerUploadError = '';
    notifyListeners();
    final result = await _fuelConsumptionRepository.updateFinalReading(
      fuelConsumptionId: _fuelConsumptionId!,
      odometerReadingAtEnd: odometerReading,
      odometerImage: odometerImage,
    );

    return result.fold(
      (failure) {
        _isUploadingOdometer = false;
        _odometerUploadError = failure.message;
        notifyListeners();
        return false;
      },
      (success) {
        _isUploadingOdometer = false;
        // Mark as uploaded to prevent showing button again
        _odometerReadingAtEnd = odometerReading;
        notifyListeners();
        return true;
      },
    );
  }
}
