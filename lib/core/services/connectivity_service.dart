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
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Current connection status
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  // Stream controller for broadcasting connectivity changes
  final _connectionStreamController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStreamController.stream;
  
  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    
    
    // Check initial connectivity
    await _updateConnectionStatus();
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _handleConnectivityChange(result);
      },
      onError: (error) {
        
      },
    );
    
    
  }
  
  /// Handle connectivity changes
  void _handleConnectivityChange(ConnectivityResult result) {
    final wasConnected = _isConnected;
    
    // Check if any result indicates connection
    _isConnected = result != ConnectivityResult.none;
    
    // Log change
    if (wasConnected != _isConnected) {
      if (_isConnected) {
        
      } else {
        
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
      final result = await _connectivity.checkConnectivity();
      
      if (result == ConnectivityResult.none) {
        return 'Không có kết nối';
      }
      
      if (result == ConnectivityResult.wifi) {
        return 'WiFi';
      }
      
      if (result == ConnectivityResult.mobile) {
        return 'Di động';
      }
      
      if (result == ConnectivityResult.ethernet) {
        return 'Ethernet';
      }
      
      return 'Khác';
    } catch (e) {
      
      return 'Không xác định';
    }
  }
  
  /// Wait for connection with timeout
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    
    
    if (_isConnected) {
      
      return true;
    }
    
    final completer = Completer<bool>();
    StreamSubscription<bool>? subscription;
    Timer? timeoutTimer;
    
    // Listen for connection
    subscription = connectionStream.listen((isConnected) {
      if (isConnected && !completer.isCompleted) {
        
        timeoutTimer?.cancel();
        subscription?.cancel();
        completer.complete(true);
      }
    });
    
    // Set timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        
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
      
      onDisconnected?.call();
      return null;
    }
    
    try {
      return await operation();
    } catch (e) {
      
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
        
      }
    }
    
    // Wait for connection
    
    final connected = await waitForConnection(timeout: timeout);
    
    if (connected) {
      
      try {
        return await operation();
      } catch (e) {
        
        return onTimeout();
      }
    }
    
    
    return onTimeout();
  }
  
  /// Dispose service
  void dispose() {
    
    _connectivitySubscription?.cancel();
    _connectionStreamController.close();
  }
}
