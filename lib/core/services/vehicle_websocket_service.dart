import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

enum WebSocketConnectionStatus { disconnected, connecting, connected, error }

class VehicleWebSocketService {
  StompClient? _client;
  final String baseUrl;
  String? _currentVehicleId;
  WebSocketConnectionStatus _connectionStatus =
      WebSocketConnectionStatus.disconnected;
  String? _lastError;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  // Stream controllers for connection status updates
  final StreamController<WebSocketConnectionStatus>
  _connectionStatusController =
      StreamController<WebSocketConnectionStatus>.broadcast();

  VehicleWebSocketService({String? baseUrl})
    : baseUrl = baseUrl ?? 'ws://10.0.2.2:8080';

  Stream<WebSocketConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  WebSocketConnectionStatus get connectionStatus => _connectionStatus;
  String? get lastError => _lastError;

  String _cleanToken(String raw) => raw.replaceAll('#', '').trim();

  Future<void> connect({
    required String jwtToken,
    required String vehicleId,
    VoidCallback? onConnected,
    Function(String)? onError,
    Function(Map<String, dynamic>)? onLocationBroadcast,
  }) async {
    // Update connection status
    _connectionStatus = WebSocketConnectionStatus.connecting;
    _connectionStatusController.add(_connectionStatus);
    _lastError = null;

    final cleanToken = _cleanToken(jwtToken);
    _currentVehicleId = vehicleId;

    // Disconnect existing client
    await disconnect();

    // Sử dụng endpoint mới /vehicle-tracking
    final wsUrl = '$baseUrl/vehicle-tracking';
    debugPrint('Connecting to WebSocket URL: $wsUrl');

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        webSocketConnectHeaders: {'Authorization': 'Bearer $cleanToken'},
        onConnect: (frame) {
          debugPrint('✅ WebSocket connected for vehicle: $vehicleId');

          // Reset reconnect attempts on successful connection
          _reconnectAttempts = 0;

          // Update connection status
          _connectionStatus = WebSocketConnectionStatus.connected;
          _connectionStatusController.add(_connectionStatus);

          // Subscribe to vehicle-specific broadcasts
          _subscribeToVehicleUpdates(vehicleId, onLocationBroadcast);

          // Subscribe to all vehicles broadcasts (optional)
          _subscribeToAllVehicles(onLocationBroadcast);

          onConnected?.call();
        },
        onStompError: (frame) {
          final errorMsg = 'STOMP Error: ${frame.body}';
          debugPrint('❌ $errorMsg');

          _lastError = errorMsg;
          _connectionStatus = WebSocketConnectionStatus.error;
          _connectionStatusController.add(_connectionStatus);

          onError?.call(errorMsg);

          // Try to reconnect if appropriate
          _scheduleReconnect(
            jwtToken,
            vehicleId,
            onConnected,
            onError,
            onLocationBroadcast,
          );
        },
        onWebSocketError: (error) {
          final errorMsg = 'WebSocket Error: $error';
          debugPrint('❌ $errorMsg');

          _lastError = errorMsg;
          _connectionStatus = WebSocketConnectionStatus.error;
          _connectionStatusController.add(_connectionStatus);

          onError?.call(errorMsg);

          // Try to reconnect if appropriate
          _scheduleReconnect(
            jwtToken,
            vehicleId,
            onConnected,
            onError,
            onLocationBroadcast,
          );
        },
        onDisconnect: (frame) {
          debugPrint('🔌 WebSocket disconnected');

          _connectionStatus = WebSocketConnectionStatus.disconnected;
          _connectionStatusController.add(_connectionStatus);
        },
        reconnectDelay: const Duration(milliseconds: 5000),
        heartbeatOutgoing: const Duration(milliseconds: 20000),
        heartbeatIncoming: const Duration(milliseconds: 20000),
      ),
    );

    try {
      _client!.activate();
    } catch (e) {
      final errorMsg = 'Connection failed: $e';
      debugPrint('❌ $errorMsg');

      _lastError = errorMsg;
      _connectionStatus = WebSocketConnectionStatus.error;
      _connectionStatusController.add(_connectionStatus);

      onError?.call(errorMsg);

      // Try to reconnect if appropriate
      _scheduleReconnect(
        jwtToken,
        vehicleId,
        onConnected,
        onError,
        onLocationBroadcast,
      );
    }
  }

  void _scheduleReconnect(
    String jwtToken,
    String vehicleId,
    VoidCallback? onConnected,
    Function(String)? onError,
    Function(Map<String, dynamic>)? onLocationBroadcast,
  ) {
    // Cancel any existing reconnect timer
    _reconnectTimer?.cancel();

    // Only attempt to reconnect if we haven't exceeded the maximum attempts
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;

      // Exponential backoff: 2^n * 1000 ms (1s, 2s, 4s, 8s, 16s)
      final delay = Duration(
        milliseconds: (1000 * _pow(2, _reconnectAttempts - 1)).toInt(),
      );

      debugPrint(
        '📅 Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s',
      );

      _reconnectTimer = Timer(delay, () {
        debugPrint(
          '🔄 Attempting to reconnect (attempt $_reconnectAttempts)...',
        );
        connect(
          jwtToken: jwtToken,
          vehicleId: vehicleId,
          onConnected: onConnected,
          onError: onError,
          onLocationBroadcast: onLocationBroadcast,
        );
      });
    } else {
      debugPrint('❌ Maximum reconnect attempts reached');
    }
  }

  void _subscribeToVehicleUpdates(
    String vehicleId,
    Function(Map<String, dynamic>)? onMessage,
  ) {
    if (_client?.connected != true) return;

    _client!.subscribe(
      destination: '/topic/vehicles/$vehicleId',
      callback: (frame) {
        try {
          final data = jsonDecode(frame.body ?? '{}') as Map<String, dynamic>;
          debugPrint('📍 Vehicle $vehicleId location update: $data');
          onMessage?.call(data);
        } catch (e) {
          debugPrint('Error parsing vehicle update: $e');
        }
      },
    );
  }

  void _subscribeToAllVehicles(Function(Map<String, dynamic>)? onMessage) {
    if (_client?.connected != true) return;

    _client!.subscribe(
      destination: '/topic/vehicles/locations',
      callback: (frame) {
        try {
          final data = jsonDecode(frame.body ?? '{}') as Map<String, dynamic>;
          debugPrint('📍 All vehicles location update: $data');
          onMessage?.call(data);
        } catch (e) {
          debugPrint('Error parsing all vehicles update: $e');
        }
      },
    );
  }

  // Send location update (immediate)
  void sendLocationUpdate({
    required String vehicleId,
    required double latitude,
    required double longitude,
    required String licensePlateNumber,
  }) {
    if (_client?.connected != true) {
      debugPrint('❌ Cannot send location: WebSocket not connected');
      return;
    }

    final message = {
      'latitude': latitude,
      'longitude': longitude,
      'licensePlateNumber': licensePlateNumber,
    };

    _client!.send(
      destination: '/app/vehicle/$vehicleId/location',
      body: jsonEncode(message),
    );

    debugPrint(
      '📤 Sent location update for vehicle $vehicleId: lat=$latitude, lng=$longitude',
    );
  }

  // Send location update with rate limiting (5 seconds server-side)
  void sendLocationUpdateRateLimited({
    required String vehicleId,
    required double latitude,
    required double longitude,
    required String licensePlateNumber,
  }) {
    if (_client?.connected != true) {
      debugPrint('❌ Cannot send location: WebSocket not connected');
      return;
    }

    final message = {
      'latitude': latitude,
      'longitude': longitude,
      'licensePlateNumber': licensePlateNumber,
    };

    final destination = '/app/vehicle/$vehicleId/location-rate-limited';
    
    debugPrint('📤 Sending STOMP message:');
    debugPrint('   - Destination: $destination');
    debugPrint('   - VehicleId: $vehicleId');
    debugPrint('   - Location: ($latitude, $longitude)');
    debugPrint('   - License Plate: $licensePlateNumber');
    debugPrint('   - Body: ${jsonEncode(message)}');

    _client!.send(
      destination: destination,
      body: jsonEncode(message),
    );

    debugPrint('✅ STOMP message sent successfully');
  }

  Future<void> disconnect() async {
    // Cancel any pending reconnect attempts
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_client != null) {
      _client!.deactivate();
      _client = null;

      _connectionStatus = WebSocketConnectionStatus.disconnected;
      _connectionStatusController.add(_connectionStatus);
    }
  }

  // Clean up resources
  void dispose() {
    disconnect();
    _connectionStatusController.close();
  }

  bool get isConnected => _client?.connected ?? false;
  String? get currentVehicleId => _currentVehicleId;

  // Helper method to calculate exponential values
  int _pow(int base, int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
