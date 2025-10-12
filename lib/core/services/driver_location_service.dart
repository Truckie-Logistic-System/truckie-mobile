import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'vehicle_websocket_service.dart';

class DriverLocationService {
  final VehicleWebSocketService _wsService;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _sendTimer;

  final String vehicleId;
  final String licensePlateNumber;
  final Duration sendInterval;

  Position? _lastPosition;
  DateTime? _lastSent;

  DriverLocationService({
    required VehicleWebSocketService wsService,
    required this.vehicleId,
    required this.licensePlateNumber,
    this.sendInterval = const Duration(seconds: 3), // Client-side rate limiting
  }) : _wsService = wsService;

  Future<bool> requestLocationPermissions() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  Future<void> startLocationTracking({
    required String jwtToken,
    VoidCallback? onConnected,
    Function(String)? onError,
    Function(Map<String, dynamic>)? onLocationBroadcast,
  }) async {
    // Request permissions
    if (!await requestLocationPermissions()) {
      onError?.call('Location permission denied');
      return;
    }

    // Connect WebSocket
    await _wsService.connect(
      jwtToken: jwtToken,
      vehicleId: vehicleId,
      onConnected: () {
        print(
          '🚗 Driver connected for vehicle: $vehicleId ($licensePlateNumber)',
        );
        onConnected?.call();
        _startLocationUpdates();
      },
      onError: onError,
      onLocationBroadcast: onLocationBroadcast,
    );
  }

  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Only update if moved 5+ meters
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _lastPosition = position;
            print(
              '📍 New position: ${position.latitude}, ${position.longitude}',
            );

            // Send immediately if using server-side rate limiting
            _sendLocationUpdate(position);
          },
          onError: (error) {
            print('❌ Location stream error: $error');
          },
        );

    // Optional: Use timer for consistent interval sending
    // _sendTimer = Timer.periodic(sendInterval, (timer) {
    //   if (_lastPosition != null) {
    //     _sendLocationUpdate(_lastPosition!);
    //   }
    // });
  }

  void _sendLocationUpdate(Position position) {
    final now = DateTime.now();

    // Client-side rate limiting (optional, since server has its own)
    if (_lastSent != null && now.difference(_lastSent!) < sendInterval) {
      print('⏳ Skipping send due to rate limit');
      return;
    }

    _lastSent = now;

    // Use rate-limited endpoint (recommended)
    _wsService.sendLocationUpdateRateLimited(
      vehicleId: vehicleId,
      latitude: position.latitude,
      longitude: position.longitude,
      licensePlateNumber: licensePlateNumber,
    );
  }

  Future<void> stopLocationTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    _sendTimer?.cancel();
    _sendTimer = null;

    await _wsService.disconnect();
    print('🛑 Location tracking stopped for vehicle: $vehicleId');
  }

  bool get isTracking =>
      _positionSubscription != null && _wsService.isConnected;
  Position? get lastPosition => _lastPosition;
}
