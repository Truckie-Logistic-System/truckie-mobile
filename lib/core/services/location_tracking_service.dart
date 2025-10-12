import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'service_locator.dart';
import 'token_storage_service.dart';
import 'vehicle_websocket_service.dart';

/// Service quản lý việc theo dõi vị trí và cập nhật qua WebSocket
class LocationTrackingService {
  // WebSocket service
  final VehicleWebSocketService _webSocketService;

  // Trạng thái kết nối
  bool _isConnected = false;
  String? _vehicleId;
  String? _licensePlateNumber;

  // Stream controller cho các cập nhật vị trí
  final StreamController<Map<String, dynamic>> _locationUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream cho các cập nhật vị trí
  Stream<Map<String, dynamic>> get locationUpdates =>
      _locationUpdatesController.stream;

  // Getter cho trạng thái kết nối
  bool get isConnected => _isConnected;
  String? get vehicleId => _vehicleId;
  String? get licensePlateNumber => _licensePlateNumber;

  LocationTrackingService({VehicleWebSocketService? webSocketService})
    : _webSocketService = webSocketService ?? getIt<VehicleWebSocketService>();

  /// Kết nối WebSocket và bắt đầu theo dõi vị trí
  Future<bool> startTracking({
    String? vehicleId,
    String? licensePlateNumber,
    String? jwtToken,
    Function(Map<String, dynamic>)? onLocationUpdate,
    Function(String)? onError,
  }) async {
    if (_isConnected) return true;

    try {
      // Lấy token nếu không được cung cấp
      String? token = jwtToken;
      if (token == null) {
        final tokenService = getIt<TokenStorageService>();
        token = tokenService.getAccessToken();
      }

      if (token == null) {
        final errorMsg = 'Không thể kết nối: Không có token';
        debugPrint('❌ $errorMsg');
        onError?.call(errorMsg);
        return false;
      }

      // Kiểm tra thông tin xe
      if (vehicleId == null || licensePlateNumber == null) {
        final errorMsg = 'Không thể kết nối: Thiếu thông tin xe';
        debugPrint('❌ $errorMsg');
        onError?.call(errorMsg);
        return false;
      }

      _vehicleId = vehicleId;
      _licensePlateNumber = licensePlateNumber;

      // Sử dụng Completer để đảm bảo chỉ trả về khi kết nối thành công hoặc thất bại
      final Completer<bool> connectionCompleter = Completer<bool>();

      // Kết nối WebSocket
      await _webSocketService.connect(
        jwtToken: token,
        vehicleId: vehicleId,
        onConnected: () {
          _isConnected = true;
          debugPrint('✅ WebSocket kết nối thành công cho xe: $vehicleId');
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(true);
          }
        },
        onError: (error) {
          _isConnected = false;
          debugPrint('❌ Lỗi WebSocket: $error');
          onError?.call(error);
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(false);
          }
        },
        onLocationBroadcast: (data) {
          debugPrint('📍 Nhận vị trí từ server: $data');
          _locationUpdatesController.add(data);
          onLocationUpdate?.call(data);
        },
      );

      // Đặt timeout để tránh treo vô hạn
      Timer(Duration(seconds: 10), () {
        if (!connectionCompleter.isCompleted) {
          debugPrint('⏱️ Timeout kết nối WebSocket sau 10 giây');
          connectionCompleter.complete(false);
        }
      });

      // Đợi kết quả kết nối thực sự
      final result = await connectionCompleter.future;
      return result;
    } catch (e) {
      final errorMsg = 'Lỗi khi kết nối: $e';
      debugPrint('❌ $errorMsg');
      onError?.call(errorMsg);
      return false;
    }
  }

  /// Ngắt kết nối WebSocket và dừng theo dõi vị trí
  Future<void> stopTracking() async {
    if (!_isConnected) return;

    try {
      await _webSocketService.disconnect();
      _isConnected = false;
      debugPrint('🔌 Đã ngắt kết nối WebSocket');
    } catch (e) {
      debugPrint('❌ Lỗi khi ngắt kết nối WebSocket: $e');
    }
  }

  /// Gửi cập nhật vị trí qua WebSocket
  void sendLocationUpdate({
    required double latitude,
    required double longitude,
    double? bearing,
    double? speed,
  }) {
    if (!_isConnected || _vehicleId == null || _licensePlateNumber == null) {
      debugPrint(
        '❌ Không thể gửi vị trí: WebSocket chưa kết nối hoặc thiếu thông tin xe',
      );
      return;
    }

    try {
      _webSocketService.sendLocationUpdateRateLimited(
        vehicleId: _vehicleId!,
        latitude: latitude,
        longitude: longitude,
        licensePlateNumber: _licensePlateNumber!,
      );

      debugPrint('📤 Đã gửi vị trí: lat=$latitude, lng=$longitude');
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi vị trí: $e');
    }
  }

  /// Gửi vị trí hiện tại
  void sendLocation(LatLng location, {double? bearing}) {
    if (!_isConnected || _vehicleId == null || _licensePlateNumber == null) {
      debugPrint(
        '❌ Không thể gửi vị trí: Chưa kết nối hoặc thiếu thông tin xe',
      );
      // Thử kết nối lại nếu chưa kết nối
      if (!_isConnected && _vehicleId != null && _licensePlateNumber != null) {
        debugPrint('🔄 Đang thử kết nối lại WebSocket...');
        startTracking(
          vehicleId: _vehicleId!,
          licensePlateNumber: _licensePlateNumber!,
        ).then((success) {
          if (success) {
            // Kết nối thành công, gửi lại vị trí
            sendLocation(location, bearing: bearing);
          }
        });
      }
      return;
    }

    try {
      _webSocketService.sendLocationUpdateRateLimited(
        vehicleId: _vehicleId!,
        latitude: location.latitude,
        longitude: location.longitude,
        licensePlateNumber: _licensePlateNumber!,
      );
      debugPrint(
        '📤 Đã gửi vị trí: lat=${location.latitude}, lng=${location.longitude}',
      );
    } catch (e) {
      debugPrint('❌ Lỗi khi gửi vị trí: $e');
    }
  }

  /// Giải phóng tài nguyên
  void dispose() {
    stopTracking();
    _locationUpdatesController.close();
  }
}
