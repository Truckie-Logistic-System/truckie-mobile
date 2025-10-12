import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'vehicle_websocket_service.dart';

/// Mock implementation of VehicleWebSocketService for testing
class MockVehicleWebSocketService extends VehicleWebSocketService {
  bool _isConnected = false;
  String? _currentVehicleId;
  Timer? _mockUpdateTimer;
  final Random _random = Random();
  WebSocketConnectionStatus _connectionStatus =
      WebSocketConnectionStatus.disconnected;

  // Stream controller for simulating location updates
  final StreamController<Map<String, dynamic>> _locationUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream controller for connection status
  final StreamController<WebSocketConnectionStatus>
  _connectionStatusController =
      StreamController<WebSocketConnectionStatus>.broadcast();

  Stream<Map<String, dynamic>> get locationUpdates =>
      _locationUpdatesController.stream;

  @override
  Stream<WebSocketConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  @override
  WebSocketConnectionStatus get connectionStatus => _connectionStatus;

  MockVehicleWebSocketService({super.baseUrl = 'ws://mock-server'});

  @override
  Future<void> connect({
    required String jwtToken,
    required String vehicleId,
    VoidCallback? onConnected,
    Function(String)? onError,
    Function(Map<String, dynamic>)? onLocationBroadcast,
  }) async {
    // Update status to connecting
    _connectionStatus = WebSocketConnectionStatus.connecting;
    _connectionStatusController.add(_connectionStatus);

    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulate random connection failure (10% chance)
    if (_random.nextInt(10) == 0) {
      final errorMsg = 'Mock connection failure (simulated)';
      debugPrint('❌ $errorMsg');

      _connectionStatus = WebSocketConnectionStatus.error;
      _connectionStatusController.add(_connectionStatus);

      onError?.call(errorMsg);
      return;
    }

    _isConnected = true;
    _currentVehicleId = vehicleId;
    _connectionStatus = WebSocketConnectionStatus.connected;
    _connectionStatusController.add(_connectionStatus);

    // Notify connection success
    onConnected?.call();

    // Start generating mock location updates
    _startMockLocationUpdates(vehicleId, onLocationBroadcast);

    debugPrint('✅ Mock WebSocket connected for vehicle: $vehicleId');
  }

  void _startMockLocationUpdates(
    String vehicleId,
    Function(Map<String, dynamic>)? onLocationBroadcast,
  ) {
    // Cancel any existing timer
    _mockUpdateTimer?.cancel();

    // Base location (Ho Chi Minh City)
    double baseLat = 10.762622;
    double baseLng = 106.660172;

    // Start periodic updates
    _mockUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }

      // Generate random movement (±0.001 degrees, roughly 100m)
      final latDelta = (_random.nextDouble() - 0.5) * 0.002;
      final lngDelta = (_random.nextDouble() - 0.5) * 0.002;

      final locationData = {
        'vehicleId': vehicleId,
        'latitude': baseLat + latDelta,
        'longitude': baseLng + lngDelta,
        'licensePlateNumber': '51F-123.45',
        'timestamp': DateTime.now().toIso8601String(),
        'speed': _random.nextInt(80) + 10, // Random speed between 10-90 km/h
        'heading': _random.nextInt(360), // Random heading 0-359 degrees
      };

      // Notify listeners
      onLocationBroadcast?.call(locationData);
      _locationUpdatesController.add(locationData);

      // Update base location for next update (simulate movement)
      baseLat += latDelta;
      baseLng += lngDelta;

      debugPrint('📍 Mock location update: $locationData');
    });
  }

  @override
  void sendLocationUpdate({
    required String vehicleId,
    required double latitude,
    required double longitude,
    required String licensePlateNumber,
  }) {
    if (!_isConnected) {
      debugPrint('❌ Cannot send location: WebSocket not connected');
      return;
    }

    debugPrint('📤 Mock sent location update: lat=$latitude, lng=$longitude');

    // Simulate echo back from server after a short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      final locationData = {
        'vehicleId': vehicleId,
        'latitude': latitude,
        'longitude': longitude,
        'licensePlateNumber': licensePlateNumber,
        'timestamp': DateTime.now().toIso8601String(),
        'speed': _random.nextInt(80) + 10,
        'heading': _random.nextInt(360),
      };

      _locationUpdatesController.add(locationData);
    });
  }

  @override
  void sendLocationUpdateRateLimited({
    required String vehicleId,
    required double latitude,
    required double longitude,
    required String licensePlateNumber,
  }) {
    sendLocationUpdate(
      vehicleId: vehicleId,
      latitude: latitude,
      longitude: longitude,
      licensePlateNumber: licensePlateNumber,
    );
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _currentVehicleId = null;
    _mockUpdateTimer?.cancel();
    _mockUpdateTimer = null;

    _connectionStatus = WebSocketConnectionStatus.disconnected;
    _connectionStatusController.add(_connectionStatus);

    debugPrint('🔌 Mock WebSocket disconnected');
  }

  @override
  void dispose() {
    disconnect();
    _locationUpdatesController.close();
    _connectionStatusController.close();
  }

  @override
  bool get isConnected => _isConnected;

  @override
  String? get currentVehicleId => _currentVehicleId;
}
