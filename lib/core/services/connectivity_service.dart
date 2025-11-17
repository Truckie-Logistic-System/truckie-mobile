import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity and provide connection status
/// Uses connectivity_plus package for cross-platform support
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Current connection status
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  // Stream controller for broadcasting connectivity changes
  final _connectionStreamController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStreamController.stream;
  
  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    debugPrint('🌐 [ConnectivityService] Initializing...');
    
    // Check initial connectivity
    await _updateConnectionStatus();
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
      onError: (error) {
        debugPrint('❌ [ConnectivityService] Error: $error');
      },
    );
    
    debugPrint('✅ [ConnectivityService] Initialized, connected: $_isConnected');
  }
  
  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    
    // Check if any result indicates connection
    _isConnected = results.any((result) =>
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet
    );
    
    // Log change
    if (wasConnected != _isConnected) {
      if (_isConnected) {
        debugPrint('✅ [ConnectivityService] Connected - ${results.join(', ')}');
      } else {
        debugPrint('❌ [ConnectivityService] Disconnected');
      }
      
      // Broadcast change
      _connectionStreamController.add(_isConnected);
    }
  }
  
  /// Update connection status
  Future<void> _updateConnectionStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
    } catch (e) {
      debugPrint('❌ [ConnectivityService] Error checking connectivity: $e');
      _isConnected = false;
    }
  }
  
  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    await _updateConnectionStatus();
    return _isConnected;
  }
  
  /// Get connection type
  Future<String> getConnectionType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return 'Không có kết nối';
      }
      
      if (results.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      }
      
      if (results.contains(ConnectivityResult.mobile)) {
        return 'Di động';
      }
      
      if (results.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      }
      
      return 'Khác';
    } catch (e) {
      debugPrint('❌ [ConnectivityService] Error getting connection type: $e');
      return 'Không xác định';
    }
  }
  
  /// Wait for connection with timeout
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    debugPrint('⏳ [ConnectivityService] Waiting for connection (max ${timeout.inSeconds}s)...');
    
    if (_isConnected) {
      debugPrint('✅ [ConnectivityService] Already connected');
      return true;
    }
    
    final completer = Completer<bool>();
    StreamSubscription<bool>? subscription;
    Timer? timeoutTimer;
    
    // Listen for connection
    subscription = connectionStream.listen((isConnected) {
      if (isConnected && !completer.isCompleted) {
        debugPrint('✅ [ConnectivityService] Connection restored');
        timeoutTimer?.cancel();
        subscription?.cancel();
        completer.complete(true);
      }
    });
    
    // Set timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint('⏰ [ConnectivityService] Wait timeout');
        subscription?.cancel();
        completer.complete(false);
      }
    });
    
    return completer.future;
  }
  
  /// Execute operation only if connected
  Future<T?> executeIfConnected<T>({
    required Future<T> Function() operation,
    VoidCallback? onDisconnected,
  }) async {
    if (!_isConnected) {
      debugPrint('⚠️ [ConnectivityService] Operation blocked - no connection');
      onDisconnected?.call();
      return null;
    }
    
    try {
      return await operation();
    } catch (e) {
      debugPrint('❌ [ConnectivityService] Operation failed: $e');
      rethrow;
    }
  }
  
  /// Execute with auto-retry on connection restore
  Future<T> executeWithRetryOnReconnect<T>({
    required Future<T> Function() operation,
    required T Function() onTimeout,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Try immediately if connected
    if (_isConnected) {
      try {
        return await operation();
      } catch (e) {
        debugPrint('⚠️ [ConnectivityService] Initial attempt failed: $e');
      }
    }
    
    // Wait for connection
    debugPrint('⏳ [ConnectivityService] Waiting for connection to retry...');
    final connected = await waitForConnection(timeout: timeout);
    
    if (connected) {
      debugPrint('🔄 [ConnectivityService] Retrying operation...');
      try {
        return await operation();
      } catch (e) {
        debugPrint('❌ [ConnectivityService] Retry failed: $e');
        return onTimeout();
      }
    }
    
    debugPrint('❌ [ConnectivityService] Connection timeout, using fallback');
    return onTimeout();
  }
  
  /// Dispose service
  void dispose() {
    debugPrint('🗑️ [ConnectivityService] Disposing...');
    _connectivitySubscription?.cancel();
    _connectionStreamController.close();
  }
}
