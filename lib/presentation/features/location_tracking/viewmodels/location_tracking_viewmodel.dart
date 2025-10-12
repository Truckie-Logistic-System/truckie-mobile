import 'package:flutter/foundation.dart';
import '../../../../core/services/driver_location_service.dart';
import '../../../../core/services/vehicle_websocket_service.dart';

class LocationTrackingViewModel extends ChangeNotifier {
  final VehicleWebSocketService _webSocketService;
  late final DriverLocationService _locationService;

  bool _isTracking = false;
  String _status = 'Chưa kết nối';
  String _lastUpdate = 'Chưa có';
  Map<String, dynamic>? _lastLocationData;

  LocationTrackingViewModel({VehicleWebSocketService? webSocketService})
    : _webSocketService = webSocketService ?? VehicleWebSocketService();

  void initialize({
    required String vehicleId,
    required String licensePlateNumber,
  }) {
    _locationService = DriverLocationService(
      wsService: _webSocketService,
      vehicleId: vehicleId,
      licensePlateNumber: licensePlateNumber,
    );
  }

  Future<void> startTracking(String jwtToken) async {
    _status = 'Đang kết nối...';
    notifyListeners();

    await _locationService.startLocationTracking(
      jwtToken: jwtToken,
      onConnected: () {
        _isTracking = true;
        _status = 'Đã kết nối & đang theo dõi';
        notifyListeners();
      },
      onError: (error) {
        _status = 'Lỗi: $error';
        _isTracking = false;
        notifyListeners();
      },
      onLocationBroadcast: (data) {
        _lastLocationData = data;
        final now = DateTime.now();
        _lastUpdate =
            '${data['latitude']}, ${data['longitude']} lúc ${now.hour}:${now.minute}:${now.second}';
        notifyListeners();
      },
    );
  }

  Future<void> stopTracking() async {
    await _locationService.stopLocationTracking();
    _isTracking = false;
    _status = 'Đã ngắt kết nối';
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }

  // Getters
  bool get isTracking => _isTracking;
  String get status => _status;
  String get lastUpdate => _lastUpdate;
  Map<String, dynamic>? get lastLocationData => _lastLocationData;
}
