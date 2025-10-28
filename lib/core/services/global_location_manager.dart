import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'enhanced_location_tracking_service.dart';
import 'navigation_state_service.dart';

/// Global Location Manager - Quản lý location tracking xuyên suốt app lifecycle
/// Đảm bảo WebSocket connection không bị ngắt khi navigate giữa các màn hình
class GlobalLocationManager {
  static GlobalLocationManager? _instance;
  static GlobalLocationManager get instance {
    if (_instance == null) {
      throw StateError('GlobalLocationManager not initialized. Call initialize() first.');
    }
    return _instance!;
  }
  
  final EnhancedLocationTrackingService _enhancedService;
  final NavigationStateService _navigationStateService;
  
  GlobalLocationManager._(
    this._enhancedService,
    this._navigationStateService,
  );
  
  static void initialize(
    EnhancedLocationTrackingService enhancedService,
    NavigationStateService navigationStateService,
  ) {
    _instance = GlobalLocationManager._(enhancedService, navigationStateService);
  }
  
  // GPS tracking
  StreamSubscription<Position>? _positionStream;
  
  // Tracking state
  bool _isGlobalTrackingActive = false;
  String? _currentOrderId;
  String? _currentVehicleId;
  String? _currentLicensePlate;
  DateTime? _trackingStartTime;
  bool _isPrimaryDriver = true;
  bool _isSimulationMode = false; // Track simulation mode for reconnection
  bool _shouldResumeSimulation = false; // Flag to resume simulation after action confirmation
  
  // Screen tracking để biết màn hình nào đang active
  String? _currentScreen;
  final Set<String> _activeScreens = {};
  
  // Callbacks for different screens
  final Map<String, Function(Map<String, dynamic>)> _locationCallbacks = {};
  final Map<String, Function(String)> _errorCallbacks = {};
  
  // Stream controllers for global events
  final StreamController<Map<String, dynamic>> _globalLocationController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<LocationTrackingStats> _globalStatsController = 
      StreamController<LocationTrackingStats>.broadcast();
  final StreamController<String> _trackingStateController = 
      StreamController<String>.broadcast();
  
  // Auto-reconnect mechanism
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10; // More attempts for long-running trips
  bool _isReconnecting = false;

  // Getters
  bool get isGlobalTrackingActive => _isGlobalTrackingActive;
  String? get currentOrderId => _currentOrderId;
  String? get currentVehicleId => _currentVehicleId;
  String? get currentLicensePlate => _currentLicensePlate;
  DateTime? get trackingStartTime => _trackingStartTime;
  bool get isPrimaryDriver => _isPrimaryDriver;
  bool get isSimulationMode => _isSimulationMode;
  bool get shouldResumeSimulation => _shouldResumeSimulation;
  String? get currentScreen => _currentScreen;
  Set<String> get activeScreens => Set.unmodifiable(_activeScreens);
  
  // Setter for resume flag
  void setShouldResumeSimulation(bool value) {
    debugPrint('🔄 GlobalLocationManager: setShouldResumeSimulation = $value');
    _shouldResumeSimulation = value;
  }
  
  // Streams
  Stream<Map<String, dynamic>> get globalLocationStream => _globalLocationController.stream;
  Stream<LocationTrackingStats> get globalStatsStream => _globalStatsController.stream;
  Stream<String> get trackingStateStream => _trackingStateController.stream;

  /// Start global location tracking for an order
  /// This should be called ONCE when starting a trip and maintained until trip completion
  /// Only primary drivers will have WebSocket connection for location tracking
  Future<bool> startGlobalTracking({
    required String orderId,
    required String vehicleId,
    required String licensePlateNumber,
    String? jwtToken,
    String? initiatingScreen,
    bool isPrimaryDriver = true, // Mặc định là tài xế chính
    bool isSimulationMode = false, // Chế độ mô phỏng - không dùng GPS thật
  }) async {
    if (_isGlobalTrackingActive) {
      debugPrint('⚠️ Global tracking already active for order: $_currentOrderId');
      
      // If same order, just register the screen
      if (_currentOrderId == orderId) {
        if (initiatingScreen != null) {
          _registerScreen(initiatingScreen);
        }
        return true;
      } else {
        debugPrint('❌ Different order detected. Current: $_currentOrderId, New: $orderId');
        return false;
      }
    }

    try {
      debugPrint('🚀 Starting global location tracking...');
      debugPrint('   - Order ID: $orderId');
      debugPrint('   - Vehicle ID: $vehicleId');
      debugPrint('   - License Plate: $licensePlateNumber');
      debugPrint('   - Initiating Screen: $initiatingScreen');
      debugPrint('   - Is Primary Driver: $isPrimaryDriver');
      debugPrint('   - Is Simulation Mode: $isSimulationMode');

      // Store simulation mode for reconnection (before checking primary driver)
      _isSimulationMode = isSimulationMode;
      
      // Chỉ kết nối WebSocket nếu là tài xế chính
      if (!isPrimaryDriver) {
        debugPrint('⚠️ Secondary driver detected - WebSocket connection will not be established');
        debugPrint('   Secondary driver will use polling for location updates');
        debugPrint('   - Simulation mode: $isSimulationMode');
        
        // Vẫn set trạng thái tracking để UI có thể hoạt động
        _isGlobalTrackingActive = true;
        _currentOrderId = orderId;
        _currentVehicleId = vehicleId;
        _currentLicensePlate = licensePlateNumber;
        _trackingStartTime = DateTime.now();
        _isPrimaryDriver = false;
        
        if (initiatingScreen != null) {
          _registerScreen(initiatingScreen);
        }

        // Secondary driver sẽ lắng nghe location updates từ global stream
        // Không cần WebSocket riêng, chỉ cần register để nhận updates từ primary driver

        _trackingStateController.add('TRACKING_STARTED_SECONDARY_DRIVER');
        debugPrint('✅ Global location manager initialized for secondary driver (listening mode)');
        return true;
      }
      
      // Start enhanced location tracking service chỉ cho tài xế chính
      // CRITICAL: Disable GPS trong simulation mode
      final success = await _enhancedService.startTracking(
        vehicleId: vehicleId,
        licensePlateNumber: licensePlateNumber,
        jwtToken: jwtToken,
        isSimulationMode: isSimulationMode, // Pass simulation mode flag
        onLocationUpdate: _handleGlobalLocationUpdate,
        onError: _handleGlobalError,
      );
      
      // CRITICAL: Force stop any existing GPS stream before simulation
      if (isSimulationMode && _positionStream != null) {
        debugPrint('🛑 FORCE STOPPING existing GPS stream for simulation mode...');
        await _positionStream?.cancel();
        _positionStream = null;
        await Future.delayed(const Duration(milliseconds: 500)); // Longer delay
        debugPrint('   ✅ GPS stream force stopped');
      }
      
      // Start GPS position stream if NOT in simulation mode
      if (success && !isSimulationMode) {
        await _startPositionStream();
        debugPrint('✅ GPS position stream started');
      } else if (isSimulationMode) {
        debugPrint('⚠️ GPS position stream SKIPPED (simulation mode)');
        debugPrint('   - Simulation mode active: GPS will be blocked');
      }

      if (success) {
        _isGlobalTrackingActive = true;
        _currentOrderId = orderId;
        _currentVehicleId = vehicleId;
        _currentLicensePlate = licensePlateNumber;
        _trackingStartTime = DateTime.now();
        _isPrimaryDriver = true;
        
        if (initiatingScreen != null) {
          _registerScreen(initiatingScreen);
        }

        // Listen to stats
        _enhancedService.statsStream.listen(_handleGlobalStats);

        _trackingStateController.add('TRACKING_STARTED');
        
        // Save navigation state to persistent storage
        await saveNavigationState();
        
        debugPrint('✅ Global location tracking started successfully');
        return true;
      } else {
        debugPrint('❌ Failed to start global location tracking');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Exception starting global tracking: $e');
      return false;
    }
  }

  /// Schedule auto-reconnect with exponential backoff
  void _scheduleAutoReconnect() {
    if (_isReconnecting) {
      debugPrint('⚠️ Already reconnecting, skipping...');
      debugPrint('   Reconnect attempts: $_reconnectAttempts/$_maxReconnectAttempts');
      debugPrint('   Timer active: ${_reconnectTimer?.isActive ?? false}');
      return;
    }
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Max reconnect attempts reached ($_maxReconnectAttempts)');
      _trackingStateController.add('MAX_RECONNECT_ATTEMPTS_REACHED');
      _isReconnecting = false; // Reset flag
      return;
    }
    
    _reconnectAttempts++;
    
    // Exponential backoff: 2^n seconds (2s, 4s, 8s, 16s, 32s...)
    final delaySeconds = (2 << (_reconnectAttempts - 1)).clamp(2, 60);
    
    debugPrint('📍 Scheduling auto-reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts in ${delaySeconds}s');
    _trackingStateController.add('RECONNECTING_IN_${delaySeconds}S');
    
    _reconnectTimer?.cancel();
    _isReconnecting = true; // Set AFTER checks, BEFORE timer
    
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      debugPrint('🔄 Auto-reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts...');
      
      final success = await forceReconnect();
      
      if (success) {
        debugPrint('✅ Auto-reconnect successful!');
        _reconnectAttempts = 0; // Reset on success
        _isReconnecting = false;
        _trackingStateController.add('AUTO_RECONNECTED');
      } else {
        debugPrint('❌ Auto-reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts failed');
        _isReconnecting = false;
        // Will trigger another reconnect via error handler if needed
      }
    });
  }
  
  /// Stop global location tracking
  /// This should ONLY be called when trip is COMPLETE or CANCELLED
  Future<void> stopGlobalTracking({String? reason}) async {
    // Cancel any pending reconnect attempts
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _isReconnecting = false;
    
    if (!_isGlobalTrackingActive) {
      debugPrint('⚠️ Global tracking not active');
      return;
    }

    try {
      debugPrint('🛑 Stopping global location tracking...');
      debugPrint('   - Reason: ${reason ?? "Not specified"}');
      debugPrint('   - Order ID: $_currentOrderId');
      debugPrint('   - Duration: ${_getTrackingDuration()}');

      // Stop GPS stream first
      if (_positionStream != null) {
        debugPrint('   - Cancelling GPS position stream...');
        await _positionStream?.cancel();
        _positionStream = null;
        await Future.delayed(const Duration(milliseconds: 100));
        debugPrint('   ✅ GPS position stream cancelled');
      }
      
      // Stop enhanced tracking service
      await _enhancedService.stopTracking();

      // Clear saved navigation state
      await clearSavedNavigationState();

      // Clear state
      _isGlobalTrackingActive = false;
      _currentOrderId = null;
      _currentVehicleId = null;
      _currentLicensePlate = null;
      _trackingStartTime = null;
      _isPrimaryDriver = true; // Reset về default
      _isSimulationMode = false; // Reset simulation mode
      _currentScreen = null;
      _activeScreens.clear();
      _locationCallbacks.clear();
      _errorCallbacks.clear();

      _trackingStateController.add('TRACKING_STOPPED');
      
      debugPrint('✅ Global location tracking stopped');
    } catch (e) {
      debugPrint('❌ Error stopping global tracking: $e');
    }
  }

  /// Register a screen as active (for tracking which screens are using the service)
  void registerScreen(String screenName, {
    Function(Map<String, dynamic>)? onLocationUpdate,
    Function(String)? onError,
  }) {
    debugPrint('📱 Registering screen: $screenName');
    
    _registerScreen(screenName);
    
    // Store callbacks for this screen
    if (onLocationUpdate != null) {
      _locationCallbacks[screenName] = onLocationUpdate;
    }
    if (onError != null) {
      _errorCallbacks[screenName] = onError;
    }
    
    _currentScreen = screenName;
    
    debugPrint('   - Active screens: ${_activeScreens.join(", ")}');
  }

  /// Unregister a screen (when screen is disposed or navigated away)
  void unregisterScreen(String screenName) {
    debugPrint('📱 Unregistering screen: $screenName');
    
    _activeScreens.remove(screenName);
    _locationCallbacks.remove(screenName);
    _errorCallbacks.remove(screenName);
    
    // Update current screen to the most recent active screen
    if (_activeScreens.isNotEmpty) {
      _currentScreen = _activeScreens.last;
    } else {
      _currentScreen = null;
    }
    
    debugPrint('   - Active screens: ${_activeScreens.join(", ")}');
    debugPrint('   - Current screen: $_currentScreen');
  }

  /// Internal method to register screen
  void _registerScreen(String screenName) {
    _activeScreens.add(screenName);
    // Keep only last 3 screens to avoid memory issues
    if (_activeScreens.length > 3) {
      final screensList = _activeScreens.toList();
      _activeScreens.clear();
      _activeScreens.addAll(screensList.skip(screensList.length - 3));
    }
  }

  /// Handle global location updates and distribute to registered screens
  void _handleGlobalLocationUpdate(Map<String, dynamic> data) {
    debugPrint('📍 Global location update: ${data['latitude']}, ${data['longitude']}');
    
    // Broadcast to global stream
    _globalLocationController.add(data);
    
    // Send to all registered screen callbacks
    for (final callback in _locationCallbacks.values) {
      try {
        callback(data);
      } catch (e) {
        debugPrint('❌ Error calling location callback: $e');
      }
    }
  }

  /// Handle global errors and distribute to registered screens
  void _handleGlobalError(String error) {
    debugPrint('❌ Global tracking error: $error');
    
    // Send to all registered screen error callbacks
    for (final callback in _errorCallbacks.values) {
      try {
        callback(error);
      } catch (e) {
        debugPrint('❌ Error calling error callback: $e');
      }
    }
    
    // DISABLED: Let VehicleWebSocketService handle reconnection automatically
    // GlobalLocationManager reconnection conflicts with VehicleWebSocketService
    // VehicleWebSocketService has built-in reconnection with exponential backoff
    // and preserves simulation mode state correctly
    
    // Only log the error, don't trigger reconnection here
    if (_isGlobalTrackingActive && _isPrimaryDriver) {
      if (error.toLowerCase().contains('websocket') || 
          error.toLowerCase().contains('connection') ||
          error.toLowerCase().contains('disconnect')) {
        debugPrint('⚠️ WebSocket error detected - VehicleWebSocketService will handle reconnection');
      }
    }
  }

  /// Handle global stats
  void _handleGlobalStats(LocationTrackingStats stats) {
    _globalStatsController.add(stats);
  }

  /// Send location update manually
  /// Only primary drivers can send location updates
  Future<void> sendLocationUpdate(
    double latitude, 
    double longitude, {
    double? bearing, 
    double? speed,
    int? segmentIndex,
  }) async {
    if (!_isGlobalTrackingActive) {
      debugPrint('⚠️ Cannot send location: global tracking not active');
      return;
    }

    if (!_isPrimaryDriver) {
      debugPrint('⚠️ Cannot send location: only primary drivers can send location updates');
      return;
    }

    await _enhancedService.sendLocationUpdate(
      latitude: latitude,
      longitude: longitude,
      bearing: bearing,
      speed: speed,
    );
    
    // Save position to persistent storage (especially important for simulation mode)
    if (_isSimulationMode) {
      await saveNavigationState(
        latitude: latitude,
        longitude: longitude,
        bearing: bearing,
        segmentIndex: segmentIndex,
      );
    }
  }

  /// Get comprehensive status
  Map<String, dynamic> getGlobalStatus() {
    return {
      'isGlobalTrackingActive': _isGlobalTrackingActive,
      'currentOrderId': _currentOrderId,
      'currentVehicleId': _currentVehicleId,
      'currentLicensePlate': _currentLicensePlate,
      'trackingStartTime': _trackingStartTime?.toIso8601String(),
      'trackingDuration': _getTrackingDuration(),
      'isPrimaryDriver': _isPrimaryDriver,
      'currentScreen': _currentScreen,
      'activeScreens': _activeScreens.toList(),
      'enhancedServiceConnected': _enhancedService.isConnected,
      'enhancedServiceStats': _enhancedService.getTrackingStats(),
    };
  }

  /// Get tracking duration
  String _getTrackingDuration() {
    if (_trackingStartTime == null) return 'N/A';
    
    final duration = DateTime.now().difference(_trackingStartTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Check if tracking is active for a specific order
  bool isTrackingOrder(String orderId) {
    return _isGlobalTrackingActive && _currentOrderId == orderId;
  }

  /// Force reconnect WebSocket (for recovery scenarios)
  /// Only available for primary drivers
  Future<bool> forceReconnect() async {
    if (!_isGlobalTrackingActive || _currentVehicleId == null || _currentLicensePlate == null) {
      debugPrint('⚠️ Cannot reconnect: tracking not active or missing data');
      return false;
    }

    if (!_isPrimaryDriver) {
      debugPrint('⚠️ Cannot reconnect: only primary drivers can reconnect WebSocket');
      return false;
    }

    debugPrint('🔄 Force reconnecting global tracking...');
    
    try {
      // Stop GPS stream
      await _positionStream?.cancel();
      _positionStream = null;
      
      // Stop current tracking
      await _enhancedService.stopTracking();
      
      // Wait a moment
      await Future.delayed(const Duration(seconds: 1));
      
      // Restart tracking with SAME simulation mode
      final success = await _enhancedService.startTracking(
        vehicleId: _currentVehicleId!,
        licensePlateNumber: _currentLicensePlate!,
        isSimulationMode: _isSimulationMode, // ✅ Restore simulation mode!
        onLocationUpdate: _handleGlobalLocationUpdate,
        onError: _handleGlobalError,
      );
      
      // Restart GPS stream ONLY if NOT in simulation mode
      if (success && !_isSimulationMode) {
        await _startPositionStream();
        debugPrint('✅ GPS stream restarted (normal mode)');
      } else if (success && _isSimulationMode) {
        debugPrint('✅ Reconnected in simulation mode (GPS stream not started)');
      }
      
      if (success) {
        debugPrint('✅ Global tracking reconnected successfully');
        _trackingStateController.add('RECONNECTED');
      } else {
        debugPrint('❌ Failed to reconnect global tracking');
        _trackingStateController.add('RECONNECT_FAILED');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Exception during reconnect: $e');
      _trackingStateController.add('RECONNECT_ERROR');
      return false;
    }
  }

  /// Start GPS position stream
  Future<void> _startPositionStream() async {
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Minimum 5 meters movement
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          // Send position through enhanced service
          _enhancedService.sendPosition(position); // isManualUpdate = false by default
        },
        onError: (error) {
          debugPrint('❌ Position stream error: $error');
        },
        cancelOnError: false,
      );

      debugPrint('✅ GPS position stream started in GlobalLocationManager');
      
    } catch (e) {
      debugPrint('❌ Failed to start position stream: $e');
    }
  }

  /// Update simulation mode (called when user starts simulation manually)
  void updateSimulationMode(bool isSimulationMode) {
    debugPrint('🔄 Updating simulation mode: $_isSimulationMode → $isSimulationMode');
    _isSimulationMode = isSimulationMode;
  }

  /// Save current navigation state to persistent storage
  Future<void> saveNavigationState({
    double? latitude,
    double? longitude,
    double? bearing,
    int? segmentIndex,
  }) async {
    if (!_isGlobalTrackingActive || _currentOrderId == null) {
      return;
    }

    try {
      final stateService = _navigationStateService;
      
      if (latitude != null && longitude != null) {
        // Update position
        await stateService.updateCurrentPosition(
          latitude: latitude,
          longitude: longitude,
          bearing: bearing,
          segmentIndex: segmentIndex,
        );
      } else {
        // Save initial state
        await stateService.saveNavigationState(
          orderId: _currentOrderId!,
          vehicleId: _currentVehicleId ?? '',
          licensePlate: _currentLicensePlate ?? '',
          isSimulationMode: _isSimulationMode,
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving navigation state: $e');
    }
  }

  /// Try to restore navigation state from persistent storage
  /// Returns true if state was restored and tracking was resumed
  Future<bool> tryRestoreNavigationState() async {
    try {
      debugPrint('🔍 tryRestoreNavigationState - Starting...');
      
      final stateService = _navigationStateService;
      debugPrint('   - NavigationStateService obtained');
      
      final savedState = stateService.getSavedNavigationState();
      debugPrint('   - Saved state: ${savedState?.toString() ?? "null"}');

      if (savedState == null) {
        debugPrint('ℹ️ No saved navigation state found in SharedPreferences');
        return false;
      }

      debugPrint('🔄 Found saved navigation state:');
      debugPrint('   - Order ID: ${savedState.orderId}');
      debugPrint('   - Vehicle ID: ${savedState.vehicleId}');
      debugPrint('   - License Plate: ${savedState.licensePlate}');
      debugPrint('   - Simulation Mode: ${savedState.isSimulationMode}');
      debugPrint('   - Tracking Start Time: ${savedState.trackingStartTime}');

      // Check if state is still valid (not too old)
      if (savedState.trackingStartTime != null) {
        final age = DateTime.now().difference(savedState.trackingStartTime!);
        debugPrint('   - State age: ${age.inHours} hours');
        if (age.inHours > 24) {
          debugPrint('⚠️ Saved state is too old (${age.inHours} hours), clearing...');
          await stateService.clearNavigationState();
          return false;
        }
      }

      // Try to reconnect with saved state
      debugPrint('🔄 Attempting to restore tracking for order: ${savedState.orderId}');
      
      final success = await startGlobalTracking(
        orderId: savedState.orderId,
        vehicleId: savedState.vehicleId ?? '',
        licensePlateNumber: savedState.licensePlate ?? '',
        isSimulationMode: savedState.isSimulationMode,
        initiatingScreen: 'AutoRestore',
      );

      if (success) {
        debugPrint('✅ Navigation state restored successfully');
        debugPrint('   - Current order ID: $_currentOrderId');
        debugPrint('   - Is tracking active: $_isGlobalTrackingActive');
        debugPrint('   - Simulation mode in manager: $_isSimulationMode');
        debugPrint('   - Simulation mode from saved state: ${savedState.isSimulationMode}');
        
        // Double check that simulation mode was set correctly
        if (_isSimulationMode != savedState.isSimulationMode) {
          debugPrint('⚠️ WARNING: Simulation mode mismatch!');
          debugPrint('   Expected: ${savedState.isSimulationMode}, Got: $_isSimulationMode');
        }
        
        return true;
      } else {
        debugPrint('❌ Failed to restore navigation state - startGlobalTracking returned false');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error restoring navigation state: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Clear saved navigation state (call when trip is completed)
  Future<void> clearSavedNavigationState() async {
    try {
      final stateService = _navigationStateService;
      await stateService.clearNavigationState();
      debugPrint('✅ Saved navigation state cleared');
    } catch (e) {
      debugPrint('❌ Error clearing saved navigation state: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _positionStream?.cancel();
    _globalLocationController.close();
    _globalStatsController.close();
    _trackingStateController.close();
  }
}
