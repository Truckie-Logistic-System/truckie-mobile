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
  final int _maxReconnectAttempts = 15; // Increased from 10 to 15
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

  /// Get latest access token from TokenStorageService
  /// This ensures we always use the most up-to-date token, even after refresh
  String? _getLatestToken() {
    try {
      final tokenStorage = GetIt.instance<TokenStorageService>();
      final token = tokenStorage.getAccessToken();
      
      if (token != null) {
        // Update stored token with latest one
        _storedJwtToken = token;
      }
      
      return token;
    } catch (e) {
      return null;
    }
  }

  /// Try to refresh token when 401 error occurs
  Future<String?> _tryRefreshToken() async {
    try {
      
      final tokenStorageService = GetIt.instance<TokenStorageService>();
      final refreshToken = await tokenStorageService.getRefreshToken();
      
      if (refreshToken == null || refreshToken.isEmpty) {
        return null;
      }
      
      
      // CRITICAL: Call actual refresh token API
      try {
        final apiClient = GetIt.instance<ApiClient>();
        // Mobile app sends refreshToken in request body (not in cookie like web)
        final requestData = {
          'refreshToken': refreshToken,
        };
        
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
            return null;
          }
          
          if (newRefreshToken == null || newRefreshToken.isEmpty) {
            return null;
          }
          
          // Save both tokens (token rotation)
          await tokenStorageService.saveAccessToken(newAccessToken);
          await tokenStorageService.saveRefreshToken(newRefreshToken);
          
          return newAccessToken;
        } else {
          return null;
        }
      } catch (apiError) {
        return null;
      }
    } catch (e) {
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
        
        final errorMsg = 'Connection timeout';
        _lastError = errorMsg;
        _connectionStatus = WebSocketConnectionStatus.error;
        _connectionStatusController.add(_connectionStatus);
        
        // Disconnect and trigger reconnection
        _disconnectClient();
        _storedOnError?.call(errorMsg);
        
        final latestToken = _getLatestToken();
        if (latestToken != null && _currentVehicleId != null) {
          _scheduleReconnect(
            latestToken,
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

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        webSocketConnectHeaders: {'Authorization': 'Bearer $cleanToken'},
        onConnect: (frame) {

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

          _lastError = errorMsg;
          _connectionStatus = WebSocketConnectionStatus.error;
          _connectionStatusController.add(_connectionStatus);

          _storedOnError?.call(errorMsg);

          // CRITICAL: Check for 401 Unauthorized error
          if (errorMsg.contains('401') || errorMsg.contains('Unauthorized')) {
            _handleUnauthorizedError();
          } else {
            // CRITICAL: Always try to reconnect on STOMP errors
            final latestToken = _getLatestToken();
            if (latestToken != null && _currentVehicleId != null) {
              _scheduleReconnect(
                latestToken,
                _currentVehicleId!,
                _storedOnConnected,
                _storedOnError,
                _storedOnLocationBroadcast,
              );
            } else {
            }
          }
        },
        onWebSocketError: (error) {
          final errorMsg = 'WebSocket Error: $error';

          _lastError = errorMsg;
          _connectionStatus = WebSocketConnectionStatus.error;
          _connectionStatusController.add(_connectionStatus);

          _storedOnError?.call(errorMsg);

          // CRITICAL: Check for 401 Unauthorized error
          if (errorMsg.contains('401') || errorMsg.contains('Unauthorized')) {
            _handleUnauthorizedError();
          } else {
            // CRITICAL: Always try to reconnect on WebSocket errors
            final latestToken = _getLatestToken();
            if (latestToken != null && _currentVehicleId != null) {
              _scheduleReconnect(
                latestToken,
                _currentVehicleId!,
                _storedOnConnected,
                _storedOnError,
                _storedOnLocationBroadcast,
              );
            } else {
            }
          }
        },
        onDisconnect: (frame) {

          _connectionStatus = WebSocketConnectionStatus.disconnected;
          _connectionStatusController.add(_connectionStatus);
          
          // Notify error callback about disconnection
          final errorMsg = 'WebSocket disconnected';
          _storedOnError?.call(errorMsg);
          
          // Try to reconnect automatically using stored credentials
          final latestToken = _getLatestToken();
          if (latestToken != null && _currentVehicleId != null) {
            _scheduleReconnect(
              latestToken,
              _currentVehicleId!,
              _storedOnConnected,
              _storedOnError,
              _storedOnLocationBroadcast,
            );
          } else {
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

      _lastError = errorMsg;
      _connectionStatus = WebSocketConnectionStatus.error;
      _connectionStatusController.add(_connectionStatus);

      _storedOnError?.call(errorMsg);

      // CRITICAL: Always try to reconnect on connection failure
      final latestToken = _getLatestToken();
      if (latestToken != null && _currentVehicleId != null) {
        _scheduleReconnect(
          latestToken,
          _currentVehicleId!,
          _storedOnConnected,
          _storedOnError,
          _storedOnLocationBroadcast,
        );
      } else {
      }
    }
  }

  /// Handle 401 Unauthorized error by attempting token refresh
  void _handleUnauthorizedError() {
    
    // Disconnect current client
    _disconnectClient();
    
    // Try to refresh token
    _tryRefreshToken().then((newToken) {
      if (newToken != null && _currentVehicleId != null) {
        
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
        
        // Try to get latest token from TokenStorageService
        final latestToken = _getLatestToken();
        
        if (latestToken != null && _currentVehicleId != null) {
          _scheduleReconnect(
            latestToken,
            _currentVehicleId!,
            _storedOnConnected,
            _storedOnError,
            _storedOnLocationBroadcast,
          );
        } else {
          _storedOnError?.call('No access token available');
        }
      }
    }).catchError((e) {
      
      // Try to get latest token from TokenStorageService
      final latestToken = _getLatestToken();
      
      if (latestToken != null && _currentVehicleId != null) {
        _scheduleReconnect(
          latestToken,
          _currentVehicleId!,
          _storedOnConnected,
          _storedOnError,
          _storedOnLocationBroadcast,
        );
      } else {
        _storedOnError?.call('No access token available');
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

    // Check if max attempts reached
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      
      // Even after max retries, schedule one more attempt after longer delay
      // This ensures GPS tracking keeps trying indefinitely
      _reconnectTimer = Timer(const Duration(seconds: 60), () {
        _reconnectAttempts = 0; // Reset counter for next round
        _scheduleReconnect(jwtToken, vehicleId, onConnected, onError, onLocationBroadcast);
      });
      return;
    }

    _reconnectAttempts++;

    // Exponential backoff: 2^n * 1000 ms, capped at 32 seconds
    final delayMs = (1000 * _pow(2, _reconnectAttempts - 1)).toInt().clamp(1000, 32000);
    final delay = Duration(milliseconds: delayMs);


    _reconnectTimer = Timer(delay, () {
      
      // CRITICAL: Always get latest token from TokenStorageService before reconnecting
      final latestToken = _getLatestToken();
      
      if (latestToken == null) {
        final errorMsg = 'No access token for reconnection';
        _storedOnError?.call(errorMsg);
        
        // Schedule retry even without token (token might become available later)
        _scheduleReconnect(jwtToken, vehicleId, onConnected, onError, onLocationBroadcast);
        return;
      }
      
      
      // Use stored callbacks to ensure they persist across reconnects
      connect(
        jwtToken: latestToken,
        vehicleId: vehicleId,
        onConnected: _storedOnConnected ?? onConnected,
        onError: _storedOnError ?? onError,
        onLocationBroadcast: _storedOnLocationBroadcast ?? onLocationBroadcast,
      );
    });
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
            return;
          }
          
          onMessage?.call(data);
        } catch (e) {
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

    
    _client!.subscribe(
      destination: '/topic/vehicles/locations',
      callback: (frame) {
        try {
          final data = jsonDecode(frame.body ?? '{}') as Map<String, dynamic>;
          onMessage?.call(data);
        } catch (e) {
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
      
      // Trigger reconnection if we have stored connection info
      if (_storedJwtToken != null && _currentVehicleId != null) {
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

    } catch (e) {
      
      // Trigger reconnection on send failure
      if (_storedJwtToken != null && _currentVehicleId != null) {
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
      
      // Trigger reconnection if we have stored connection info
      if (_storedJwtToken != null && _currentVehicleId != null) {
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
    

    try {
      _client!.send(
        destination: destination,
        body: jsonEncode(message),
      );
    } catch (e) {
      
      // Trigger reconnection on send failure
      if (_storedJwtToken != null && _currentVehicleId != null) {
        _triggerReconnection();
      }
    }
  }

  /// Trigger immediate reconnection (bypasses exponential backoff for first attempt)
  void _triggerReconnection() {
    // Check if we have the necessary info to reconnect
    if (_storedJwtToken == null || _currentVehicleId == null) {
      return;
    }
    
    // Don't trigger if already scheduled
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      return;
    }
    
    
    // Get latest token and schedule immediate reconnection
    final latestToken = _getLatestToken();
    if (latestToken == null) {
      _storedOnError?.call('No access token for reconnection');
      return;
    }
    
    _scheduleReconnect(
      latestToken,
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
