import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'enhanced_location_tracking_service.dart';
import 'navigation_state_service.dart';
import 'token_storage_service.dart';

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

  // Simulation state persistence
  Timer? _stateSaveTimer;
  final Duration _stateSaveInterval = const Duration(seconds: 2); // Save every 2 seconds

  // Track latest location
  double? _lastLatitude;
  double? _lastLongitude;
  double? _lastBearing;

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
  
  // Get current location (for damage reports, etc)
  double? get currentLatitude => _lastLatitude;
  double? get currentLongitude => _lastLongitude;
  double? get currentBearing => _lastBearing;
  
  // Setter for resume flag
  void setShouldResumeSimulation(bool value) {
    
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
      
      
      // If same order, just register the screen
      if (_currentOrderId == orderId) {
        if (initiatingScreen != null) {
          _registerScreen(initiatingScreen);
        }
        return true;
      } else {
        
        return false;
      }
    }

    try {
      
      
      
      
      
      
      

      // Store simulation mode for reconnection (before checking primary driver)
      _isSimulationMode = isSimulationMode;
      
      // Chỉ kết nối WebSocket nếu là tài xế chính
      if (!isPrimaryDriver) {
        
        
        
        
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
        
        await _positionStream?.cancel();
        _positionStream = null;
        await Future.delayed(const Duration(milliseconds: 500)); // Longer delay
        
      }
      
      // Start GPS position stream if NOT in simulation mode
      if (success && !isSimulationMode) {
        await _startPositionStream();
        
      } else if (isSimulationMode) {
        
        
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
        
        // Start periodic state saving (especially for simulation mode)
        _startPeriodicStateSaving();
        
        
        return true;
      } else {
        
        return false;
      }
    } catch (e) {
      
      return false;
    }
  }

  /// Schedule auto-reconnect with exponential backoff
  void _scheduleAutoReconnect() {
    if (_isReconnecting) {
      
      
      
      return;
    }
    
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      
      _trackingStateController.add('MAX_RECONNECT_ATTEMPTS_REACHED');
      _isReconnecting = false; // Reset flag
      return;
    }
    
    _reconnectAttempts++;
    
    // Exponential backoff: 2^n seconds (2s, 4s, 8s, 16s, 32s...)
    final delaySeconds = (2 << (_reconnectAttempts - 1)).clamp(2, 60);
    
    
    _trackingStateController.add('RECONNECTING_IN_${delaySeconds}S');
    
    _reconnectTimer?.cancel();
    _isReconnecting = true; // Set AFTER checks, BEFORE timer
    
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      
      
      final success = await forceReconnect();
      
      if (success) {
        
        _reconnectAttempts = 0; // Reset on success
        _isReconnecting = false;
        _trackingStateController.add('AUTO_RECONNECTED');
      } else {
        
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
    
    // Stop periodic state saving
    _stopPeriodicStateSaving();
    
    if (!_isGlobalTrackingActive) {
      
      return;
    }

    try {
      
      
      
      

      // Stop GPS stream first
      if (_positionStream != null) {
        
        await _positionStream?.cancel();
        _positionStream = null;
        await Future.delayed(const Duration(milliseconds: 100));
        
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
      
      
    } catch (e) {
      
    }
  }

  /// Register a screen as active (for tracking which screens are using the service)
  void registerScreen(String screenName, {
    Function(Map<String, dynamic>)? onLocationUpdate,
    Function(String)? onError,
  }) {
    
    
    _registerScreen(screenName);
    
    // Store callbacks for this screen
    if (onLocationUpdate != null) {
      _locationCallbacks[screenName] = onLocationUpdate;
    }
    if (onError != null) {
      _errorCallbacks[screenName] = onError;
    }
    
    _currentScreen = screenName;
    
    
  }

  /// Unregister a screen (when screen is disposed or navigated away)
  void unregisterScreen(String screenName) {
    
    
    _activeScreens.remove(screenName);
    _locationCallbacks.remove(screenName);
    _errorCallbacks.remove(screenName);
    
    // Update current screen to the most recent active screen
    if (_activeScreens.isNotEmpty) {
      _currentScreen = _activeScreens.last;
    } else {
      _currentScreen = null;
    }
    
    
    
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
    // CRITICAL: Final defense layer - verify this location is for OUR vehicle
    // This prevents camera focus issues in multi-trip orders
    final locationVehicleId = data['vehicleId']?.toString();
    
    if (locationVehicleId != null && _currentVehicleId != null && locationVehicleId != _currentVehicleId) {
      
      
      
      
      
      return; // IGNORE locations from other vehicles
    }
    
    // 
    
    // Store last known location
    _lastLatitude = data['latitude'] as double?;
    _lastLongitude = data['longitude'] as double?;
    _lastBearing = data['bearing'] as double?;
    
    // Broadcast to global stream
    _globalLocationController.add(data);
    
    // Send to all registered screen callbacks
    for (final callback in _locationCallbacks.values) {
      try {
        callback(data);
      } catch (e) {
        
      }
    }
  }

  /// Handle global errors and distribute to registered screens
  void _handleGlobalError(String error) {
    
    
    // Send to all registered screen error callbacks
    for (final callback in _errorCallbacks.values) {
      try {
        callback(error);
      } catch (e) {
        
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
      
      return;
    }

    if (!_isPrimaryDriver) {
      
      return;
    }

    // Store last known location
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    _lastBearing = bearing;

    await _enhancedService.sendLocationUpdate(
      latitude: latitude,
      longitude: longitude,
      bearing: bearing,
      speed: speed,
    );
    
    // Save position to persistent storage (ALWAYS, for both GPS and simulation)
    // This ensures state is saved even when app goes to background
    await saveNavigationState(
      latitude: latitude,
      longitude: longitude,
      bearing: bearing,
      segmentIndex: segmentIndex,
    );
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
      
      return false;
    }

    if (!_isPrimaryDriver) {
      
      return false;
    }

    
    
    try {
      // Stop GPS stream
      await _positionStream?.cancel();
      _positionStream = null;
      
      // Stop current tracking
      await _enhancedService.stopTracking();
      
      // Wait a moment
      await Future.delayed(const Duration(seconds: 1));
      
      // Get latest token from TokenStorageService
      final tokenStorage = GetIt.instance<TokenStorageService>();
      final jwtToken = tokenStorage.getAccessToken();
      
      if (jwtToken == null) {
        
        _trackingStateController.add('RECONNECT_FAILED');
        return false;
      }
      
      // Restart tracking with SAME simulation mode
      final success = await _enhancedService.startTracking(
        vehicleId: _currentVehicleId!,
        licensePlateNumber: _currentLicensePlate!,
        jwtToken: jwtToken,
        isSimulationMode: _isSimulationMode, // ✅ Restore simulation mode!
        onLocationUpdate: _handleGlobalLocationUpdate,
        onError: _handleGlobalError,
      );
      
      // Restart GPS stream ONLY if NOT in simulation mode
      if (success && !_isSimulationMode) {
        await _startPositionStream();
        
      } else if (success && _isSimulationMode) {
        
      }
      
      if (success) {
        
        _trackingStateController.add('RECONNECTED');
      } else {
        
        _trackingStateController.add('RECONNECT_FAILED');
      }
      
      return success;
    } catch (e) {
      
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
          
        },
        cancelOnError: false,
      );

      
      
    } catch (e) {
      
    }
  }

  /// Update simulation mode (called when user starts simulation manually)
  void updateSimulationMode(bool isSimulationMode) {
    
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
      
    }
  }

  /// Try to restore navigation state from persistent storage
  /// Returns true if state was restored and tracking was resumed
  Future<bool> tryRestoreNavigationState() async {
    try {
      
      
      final stateService = _navigationStateService;
      
      
      final savedState = stateService.getSavedNavigationState();
      

      if (savedState == null) {
        
        return false;
      }

      
      
      
      
      
      

      // Check if state is still valid (not too old)
      if (savedState.trackingStartTime != null) {
        final age = DateTime.now().difference(savedState.trackingStartTime!);
        
        if (age.inHours > 24) {
          
          await stateService.clearNavigationState();
          return false;
        }
      }

      // Try to reconnect with saved state
      
      
      // Get latest token from TokenStorageService
      final tokenStorage = GetIt.instance<TokenStorageService>();
      final jwtToken = tokenStorage.getAccessToken();
      
      if (jwtToken == null) {
        
        return false;
      }
      
      final success = await startGlobalTracking(
        orderId: savedState.orderId,
        vehicleId: savedState.vehicleId ?? '',
        licensePlateNumber: savedState.licensePlate ?? '',
        jwtToken: jwtToken,
        isSimulationMode: savedState.isSimulationMode,
        initiatingScreen: 'AutoRestore',
      );

      if (success) {
        
        
        
        
        
        
        // Double check that simulation mode was set correctly
        if (_isSimulationMode != savedState.isSimulationMode) {
          
          
        }
        
        return true;
      } else {
        
        return false;
      }
    } catch (e, stackTrace) {
      
      
      return false;
    }
  }

  /// Clear saved navigation state (call when trip is completed)
  Future<void> clearSavedNavigationState() async {
    try {
      final stateService = _navigationStateService;
      await stateService.clearNavigationState();
      
    } catch (e) {
      
    }
  }

  /// Start periodic state saving for simulation mode
  void _startPeriodicStateSaving() {
    if (!_isSimulationMode) {
      
      return;
    }
    
    _stopPeriodicStateSaving(); // Ensure no duplicate timers
    
    
    _stateSaveTimer = Timer.periodic(_stateSaveInterval, (timer) {
      if (_isGlobalTrackingActive && _isSimulationMode) {
        // 
        // State will be saved via sendLocationUpdate calls
        // This timer is a backup to ensure state is always current
      }
    });
  }
  
  /// Stop periodic state saving
  void _stopPeriodicStateSaving() {
    _stateSaveTimer?.cancel();
    _stateSaveTimer = null;
    
  }

  /// Dispose resources
  void dispose() {
    _positionStream?.cancel();
    _stateSaveTimer?.cancel();
    _reconnectTimer?.cancel();
    _globalLocationController.close();
    _globalStatsController.close();
    _trackingStateController.close();
  }
}
