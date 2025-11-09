import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:get_it/get_it.dart';
import 'token_storage_service.dart';
import '../../data/datasources/api_client.dart';

enum WebSocketConnectionStatus { disconnected, connecting, connected, error }

class VehicleWebSocketService {
  StompClient? _client;
  final String baseUrl;
  String? _currentVehicleId;
  WebSocketConnectionStatus _connectionStatus =
      WebSocketConnectionStatus.disconnected;
  String? _lastError;
  Timer? _reconnectTimer;
  Timer? _connectionTimeoutTimer; // Timeout for connection attempts
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  final int _connectionTimeoutSeconds = 10; // Timeout after 10 seconds

  // Store callbacks for reconnection
  String? _storedJwtToken;
  VoidCallback? _storedOnConnected;
  Function(String)? _storedOnError;
  Function(Map<String, dynamic>)? _storedOnLocationBroadcast;

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

  /// Try to refresh token when 401 error occurs
  Future<String?> _tryRefreshToken() async {
    try {
      debugPrint('🔄 Attempting to refresh token due to 401 error...');
      
      final tokenStorageService = GetIt.instance<TokenStorageService>();
      final refreshToken = await tokenStorageService.getRefreshToken();
      
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('❌ No refresh token available');
        return null;
      }
      
      debugPrint('✅ Refresh token found, calling refresh API...');
      
      // CRITICAL: Call actual refresh token API
      try {
        final apiClient = GetIt.instance<ApiClient>();
        // Mobile app sends refreshToken in request body (not in cookie like web)
        final requestData = {
          'refreshToken': refreshToken,
        };
        debugPrint('🔄 [VehicleWebSocket] Request data: $requestData');
        debugPrint('🔄 [VehicleWebSocket] Request data type: ${requestData.runtimeType}');
        
        // Try manual JSON encoding to ensure body is sent correctly
        final response = await apiClient.dio.post(
          '/auths/mobile/token/refresh',
          data: jsonEncode(requestData),
        );
        
        if (response.data['success'] == true && response.data['data'] != null) {
          final tokenData = response.data['data'];
          final newAccessToken = tokenData['accessToken'];
          final newRefreshToken = tokenData['refreshToken'];
          
          if (newAccessToken == null || newAccessToken.isEmpty) {
            debugPrint('❌ Backend did not return new access token');
            return null;
          }
          
          if (newRefreshToken == null || newRefreshToken.isEmpty) {
            debugPrint('❌ Backend did not return new refresh token');
            return null;
          }
          
          // Save both tokens (token rotation)
          await tokenStorageService.saveAccessToken(newAccessToken);
          await tokenStorageService.saveRefreshToken(newRefreshToken);
          
          debugPrint('✅ Token refresh successful, new tokens obtained');
          debugPrint('✅ New access token: ${newAccessToken.substring(0, 20)}...');
          debugPrint('✅ New refresh token: ${newRefreshToken.substring(0, 20)}...');
          return newAccessToken;
        } else {
          debugPrint('❌ Token refresh API returned error: ${response.data['message']}');
          return null;
        }
      } catch (apiError) {
        debugPrint('❌ Token refresh API call failed: $apiError');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error during token refresh: $e');
      return null;
    }
  }

  Future<void> connect({
    required String jwtToken,
    required String vehicleId,
    VoidCallback? onConnected,
    Function(String)? onError,
    Function(Map<String, dynamic>)? onLocationBroadcast,
  }) async {
    // Store callbacks for reconnection BEFORE disconnect
    _storedJwtToken = jwtToken;
    _storedOnConnected = onConnected;
    _storedOnError = onError;
    _storedOnLocationBroadcast = onLocationBroadcast;

    // Update connection status
    _connectionStatus = WebSocketConnectionStatus.connecting;
    _connectionStatusController.add(_connectionStatus);
    _lastError = null;

    final cleanToken = _cleanToken(jwtToken);
    _currentVehicleId = vehicleId;

    // Disconnect existing client (but keep stored callbacks)
    await _disconnectClient();
    
    // Set connection timeout
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = Timer(Duration(seconds: _connectionTimeoutSeconds), () {
      if (_connectionStatus == WebSocketConnectionStatus.connecting) {
        debugPrint('⏱️ Connection timeout after ${_connectionTimeoutSeconds}s');
        
        final errorMsg = 'Connection timeout';
        _lastError = errorMsg;
        _connectionStatus = WebSocketConnectionStatus.error;
        _connectionStatusController.add(_connectionStatus);
        
        // Disconnect and trigger reconnection
        _disconnectClient();
        _storedOnError?.call(errorMsg);
        
        if (_storedJwtToken != null && _currentVehicleId != null) {
          _scheduleReconnect(
            _storedJwtToken!,
            _currentVehicleId!,
            _storedOnConnected,
            _storedOnError,
            _storedOnLocationBroadcast,
          );
        }
      }
    });

    // Sử dụng endpoint mới /vehicle-tracking
    final wsUrl = '$baseUrl/vehicle-tracking';
    debugPrint('Connecting to WebSocket URL: $wsUrl');

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        webSocketConnectHeaders: {'Authorization': 'Bearer $cleanToken'},
        onConnect: (frame) {
          debugPrint('✅ WebSocket connected for vehicle: $vehicleId');

          // CRITICAL: Cancel ALL pending timers to prevent reconnect loop
          _connectionTimeoutTimer?.cancel();
          _connectionTimeoutTimer = null;
          _reconnectTimer?.cancel();
          _reconnectTimer = null;

          // Reset reconnect attempts on successful connection
          _reconnectAttempts = 0;

          // Update connection status
          _connectionStatus = WebSocketConnectionStatus.connected;
          _connectionStatusController.add(_connectionStatus);

          // Subscribe ONLY to this vehicle-specific broadcasts
          // CRITICAL: Do NOT subscribe to all vehicles to prevent camera focus issues
          // in multi-trip orders where each driver should only see their own vehicle
          _subscribeToVehicleUpdates(vehicleId, onLocationBroadcast);

          onConnected?.call();
        },
        onStompError: (frame) {
          final errorMsg = 'STOMP Error: ${frame.body}';
          debugPrint('❌ $errorMsg');

          _lastError = errorMsg;
          _connectionStatus = WebSocketConnectionStatus.error;
          _connectionStatusController.add(_connectionStatus);

          _storedOnError?.call(errorMsg);

          // CRITICAL: Check for 401 Unauthorized error
          if (errorMsg.contains('401') || errorMsg.contains('Unauthorized')) {
            debugPrint('🔐 401 Unauthorized detected - attempting token refresh...');
            _handleUnauthorizedError();
          } else {
            // CRITICAL: Always try to reconnect on STOMP errors
            if (_storedJwtToken != null && _currentVehicleId != null) {
              debugPrint('🔄 STOMP error - scheduling reconnect...');
              _scheduleReconnect(
                _storedJwtToken!,
                _currentVehicleId!,
                _storedOnConnected,
                _storedOnError,
                _storedOnLocationBroadcast,
              );
            } else {
              debugPrint('❌ Cannot reconnect after STOMP error: missing credentials');
              debugPrint('   Token: ${_storedJwtToken != null ? "present" : "missing"}');
              debugPrint('   VehicleId: ${_currentVehicleId ?? "missing"}');
            }
          }
        },
        onWebSocketError: (error) {
          final errorMsg = 'WebSocket Error: $error';
          debugPrint('❌ $errorMsg');

          _lastError = errorMsg;
          _connectionStatus = WebSocketConnectionStatus.error;
          _connectionStatusController.add(_connectionStatus);

          _storedOnError?.call(errorMsg);

          // CRITICAL: Check for 401 Unauthorized error
          if (errorMsg.contains('401') || errorMsg.contains('Unauthorized')) {
            debugPrint('🔐 401 Unauthorized detected - attempting token refresh...');
            _handleUnauthorizedError();
          } else {
            // CRITICAL: Always try to reconnect on WebSocket errors
            if (_storedJwtToken != null && _currentVehicleId != null) {
              debugPrint('🔄 WebSocket error - scheduling reconnect...');
              _scheduleReconnect(
                _storedJwtToken!,
                _currentVehicleId!,
                _storedOnConnected,
                _storedOnError,
                _storedOnLocationBroadcast,
              );
            } else {
              debugPrint('❌ Cannot reconnect after WebSocket error: missing credentials');
              debugPrint('   Token: ${_storedJwtToken != null ? "present" : "missing"}');
              debugPrint('   VehicleId: ${_currentVehicleId ?? "missing"}');
            }
          }
        },
        onDisconnect: (frame) {
          debugPrint('🔌 WebSocket disconnected');

          _connectionStatus = WebSocketConnectionStatus.disconnected;
          _connectionStatusController.add(_connectionStatus);
          
          // Notify error callback about disconnection
          final errorMsg = 'WebSocket disconnected';
          _storedOnError?.call(errorMsg);
          
          // Try to reconnect automatically using stored credentials
          if (_storedJwtToken != null && _currentVehicleId != null) {
            debugPrint('🔄 Scheduling auto-reconnect after disconnect...');
            _scheduleReconnect(
              _storedJwtToken!,
              _currentVehicleId!,
              _storedOnConnected,
              _storedOnError,
              _storedOnLocationBroadcast,
            );
          } else {
            debugPrint('⚠️ Cannot auto-reconnect: missing stored credentials');
          }
        },
        reconnectDelay: const Duration(seconds: 0), // Disable auto-reconnect, use manual reconnect
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

      _storedOnError?.call(errorMsg);

      // CRITICAL: Always try to reconnect on connection failure
      if (_storedJwtToken != null && _currentVehicleId != null) {
        debugPrint('🔄 Connection failed - scheduling reconnect...');
        _scheduleReconnect(
          _storedJwtToken!,
          _currentVehicleId!,
          _storedOnConnected,
          _storedOnError,
          _storedOnLocationBroadcast,
        );
      } else {
        debugPrint('❌ Cannot reconnect after connection failure: missing credentials');
        debugPrint('   Token: ${_storedJwtToken != null ? "present" : "missing"}');
        debugPrint('   VehicleId: ${_currentVehicleId ?? "missing"}');
      }
    }
  }

  /// Handle 401 Unauthorized error by attempting token refresh
  void _handleUnauthorizedError() {
    debugPrint('🔐 Handling 401 Unauthorized error...');
    
    // Disconnect current client
    _disconnectClient();
    
    // Try to refresh token
    _tryRefreshToken().then((newToken) {
      if (newToken != null && _storedJwtToken != null && _currentVehicleId != null) {
        debugPrint('✅ Token refreshed, attempting reconnect with new token...');
        
        // Update stored token with new one
        _storedJwtToken = newToken;
        
        // Schedule immediate reconnect with new token
        _scheduleReconnect(
          newToken,
          _currentVehicleId!,
          _storedOnConnected,
          _storedOnError,
          _storedOnLocationBroadcast,
        );
      } else {
        debugPrint('❌ Token refresh failed, scheduling regular reconnect...');
        
        // Fall back to regular reconnect with exponential backoff
        if (_storedJwtToken != null && _currentVehicleId != null) {
          _scheduleReconnect(
            _storedJwtToken!,
            _currentVehicleId!,
            _storedOnConnected,
            _storedOnError,
            _storedOnLocationBroadcast,
          );
        }
      }
    }).catchError((e) {
      debugPrint('❌ Error during token refresh: $e');
      
      // Fall back to regular reconnect
      if (_storedJwtToken != null && _currentVehicleId != null) {
        _scheduleReconnect(
          _storedJwtToken!,
          _currentVehicleId!,
          _storedOnConnected,
          _storedOnError,
          _storedOnLocationBroadcast,
        );
      }
    });
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
        '📅 Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delay.inSeconds}s',
      );

      _reconnectTimer = Timer(delay, () {
        debugPrint(
          '🔄 Attempting to reconnect (attempt $_reconnectAttempts/$_maxReconnectAttempts)...',
        );
        
        // Use stored callbacks to ensure they persist across reconnects
        connect(
          jwtToken: _storedJwtToken ?? jwtToken,
          vehicleId: vehicleId,
          onConnected: _storedOnConnected ?? onConnected,
          onError: _storedOnError ?? onError,
          onLocationBroadcast: _storedOnLocationBroadcast ?? onLocationBroadcast,
        );
      });
    } else {
      debugPrint('❌ Maximum reconnect attempts ($_maxReconnectAttempts) reached');
      debugPrint('   Please restart the app or manually reconnect');
      
      // Notify error callback
      final errorMsg = 'Maximum reconnect attempts reached';
      _storedOnError?.call(errorMsg);
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
          
          // CRITICAL: Verify this location update is for the correct vehicle
          // This prevents camera focus issues if backend sends wrong vehicle data
          final receivedVehicleId = data['vehicleId']?.toString();
          if (receivedVehicleId != null && receivedVehicleId != vehicleId) {
            debugPrint('⚠️ WARNING: Received location for wrong vehicle!');
            debugPrint('   Expected: $vehicleId, Got: $receivedVehicleId');
            debugPrint('   Ignoring this location update to prevent focus issues');
            return;
          }
          
          debugPrint('📍 Vehicle $vehicleId location update: $data');
          onMessage?.call(data);
        } catch (e) {
          debugPrint('Error parsing vehicle update: $e');
        }
      },
    );
  }

  /// DEPRECATED: Do NOT use this method in driver app
  /// This subscribes to ALL vehicles' locations which causes camera focus issues
  /// in multi-trip orders. Each driver should ONLY see their own vehicle.
  /// This method is kept for reference only (e.g., admin dashboard feature in future).
  void _subscribeToAllVehicles(Function(Map<String, dynamic>)? onMessage) {
    if (_client?.connected != true) return;

    debugPrint('⚠️ WARNING: Subscribing to ALL vehicles - this should NOT be used in driver app!');
    
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
      
      // Trigger reconnection if we have stored connection info
      if (_storedJwtToken != null && _currentVehicleId != null) {
        debugPrint('🔄 Attempting to reconnect WebSocket...');
        _triggerReconnection();
      }
      
      return;
    }

    final message = {
      'latitude': latitude,
      'longitude': longitude,
      'licensePlateNumber': licensePlateNumber,
    };

    try {
      _client!.send(
        destination: '/app/vehicle/$vehicleId/location',
        body: jsonEncode(message),
      );

      debugPrint(
        '📤 Sent location update for vehicle $vehicleId: lat=$latitude, lng=$longitude',
      );
    } catch (e) {
      debugPrint('❌ Failed to send location update: $e');
      
      // Trigger reconnection on send failure
      if (_storedJwtToken != null && _currentVehicleId != null) {
        debugPrint('🔄 Send failed, attempting to reconnect WebSocket...');
        _triggerReconnection();
      }
    }
  }

  // Send location update with rate limiting (5 seconds server-side)
  void sendLocationUpdateRateLimited({
    required String vehicleId,
    required double latitude,
    required double longitude,
    required String licensePlateNumber,
    double? bearing,
    double? speed,
  }) {
    if (_client?.connected != true) {
      debugPrint('❌ Cannot send location: WebSocket not connected');
      
      // Trigger reconnection if we have stored connection info
      if (_storedJwtToken != null && _currentVehicleId != null) {
        debugPrint('🔄 Attempting to reconnect WebSocket...');
        _triggerReconnection();
      }
      
      return;
    }

    final message = {
      'latitude': latitude,
      'longitude': longitude,
      'licensePlateNumber': licensePlateNumber,
      if (bearing != null) 'bearing': bearing,
      if (speed != null) 'speed': speed,
    };

    final destination = '/app/vehicle/$vehicleId/location-rate-limited';
    
    debugPrint('📤 Sending STOMP message:');
    debugPrint('   - Destination: $destination');
    debugPrint('   - VehicleId: $vehicleId');
    debugPrint('   - Location: ($latitude, $longitude)');
    debugPrint('   - License Plate: $licensePlateNumber');
    if (bearing != null) debugPrint('   - Bearing: $bearing°');
    if (speed != null) debugPrint('   - Speed: ${speed.toStringAsFixed(1)} km/h');
    debugPrint('   - Body: ${jsonEncode(message)}');

    try {
      _client!.send(
        destination: destination,
        body: jsonEncode(message),
      );
      debugPrint('✅ STOMP message sent successfully');
    } catch (e) {
      debugPrint('❌ Failed to send STOMP message: $e');
      
      // Trigger reconnection on send failure
      if (_storedJwtToken != null && _currentVehicleId != null) {
        debugPrint('🔄 Send failed, attempting to reconnect WebSocket...');
        _triggerReconnection();
      }
    }
  }

  /// Trigger immediate reconnection (bypasses exponential backoff for first attempt)
  void _triggerReconnection() {
    // Check if we have the necessary info to reconnect
    if (_storedJwtToken == null || _currentVehicleId == null) {
      debugPrint('❌ Cannot trigger reconnection: missing stored credentials');
      return;
    }
    
    // Don't trigger if already scheduled
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      debugPrint('⚠️ Reconnection already scheduled, skipping trigger');
      return;
    }
    
    debugPrint('🔄 Triggering immediate reconnection...');
    debugPrint('   Current status: $_connectionStatus');
    debugPrint('   Reconnect attempts: $_reconnectAttempts/$_maxReconnectAttempts');
    
    // Schedule immediate reconnection (no delay for first attempt)
    _scheduleReconnect(
      _storedJwtToken!,
      _currentVehicleId!,
      _storedOnConnected,
      _storedOnError,
      _storedOnLocationBroadcast,
    );
  }

  /// Internal method to disconnect client without clearing callbacks
  Future<void> _disconnectClient() async {
    if (_client != null) {
      _client!.deactivate();
      _client = null;
    }
  }

  /// Public disconnect method - clears callbacks and stops reconnection
  Future<void> disconnect() async {
    // Cancel any pending reconnect attempts
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionTimeoutTimer?.cancel();
    _connectionTimeoutTimer = null;
    _reconnectAttempts = 0; // Reset attempts

    await _disconnectClient();

    _connectionStatus = WebSocketConnectionStatus.disconnected;
    _connectionStatusController.add(_connectionStatus);
    
    // Clear stored callbacks when explicitly disconnecting
    _storedJwtToken = null;
    _storedOnConnected = null;
    _storedOnError = null;
    _storedOnLocationBroadcast = null;
    
    debugPrint('🔌 WebSocket explicitly disconnected and callbacks cleared');
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
