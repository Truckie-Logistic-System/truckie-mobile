import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'token_storage_service.dart';
import 'vehicle_websocket_service.dart';
import 'location_queue_service.dart';

/// Enhanced Location Tracking Service với GPS throttling, quality validation, và offline support
class EnhancedLocationTrackingService {
  // Core services
  final VehicleWebSocketService _webSocketService;
  final LocationQueueService _queueService;

  // Connection state
  bool _isConnected = false;
  String? _vehicleId;
  String? _licensePlateNumber;
  bool _isSimulationMode = false; // CRITICAL: Block GPS location trong simulation

  // GPS throttling state
  DateTime? _lastSendTime;
  LatLng? _lastSendLocation;
  Position? _lastValidPosition;

  // Configuration
  static const Duration _minTimeBetweenSends = Duration(seconds: 5);
  static const double _minDistanceBetweenSends = 20.0; // meters
  static const double _maxAccuracyThreshold =
      1000.0; // meters (relaxed for emulator testing)
  static const double _maxSpeedThreshold = 200.0; // km/h
  static const double _dedupeRadius = 5.0; // meters

  // Stream controllers
  final StreamController<Map<String, dynamic>> _locationUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<LocationTrackingStats> _statsController =
      StreamController<LocationTrackingStats>.broadcast();

  // Stats tracking
  final LocationTrackingStats _stats = LocationTrackingStats();

  // Getters
  Stream<Map<String, dynamic>> get locationUpdates =>
      _locationUpdatesController.stream;
  Stream<LocationTrackingStats> get statsStream => _statsController.stream;
  bool get isConnected => _isConnected;
  String? get vehicleId => _vehicleId;
  String? get licensePlateNumber => _licensePlateNumber;
  LocationTrackingStats get currentStats => _stats;
  bool get isSimulationMode => _isSimulationMode; // Expose simulation mode flag

  EnhancedLocationTrackingService({
    required VehicleWebSocketService webSocketService,
    required LocationQueueService queueService,
  }) : _webSocketService = webSocketService,
       _queueService = queueService;

  /// Start enhanced location tracking
  Future<bool> startTracking({
    String? vehicleId,
    String? licensePlateNumber,
    String? jwtToken,
    bool isSimulationMode = false, // CRITICAL: Block GPS trong simulation
    Function(Map<String, dynamic>)? onLocationUpdate,
    Function(String)? onError,
  }) async {
    if (_isConnected) return true;

    try {
      // Token must be provided
      String? token = jwtToken;

      if (token == null) {
        final errorMsg = 'Không thể kết nối: Không có token';
        debugPrint('❌ $errorMsg');
        onError?.call(errorMsg);
        return false;
      }

      // Validate vehicle info
      if (vehicleId == null || licensePlateNumber == null) {
        final errorMsg = 'Không thể kết nối: Thiếu thông tin xe';
        debugPrint('❌ $errorMsg');
        onError?.call(errorMsg);
        return false;
      }

      _vehicleId = vehicleId;
      _licensePlateNumber = licensePlateNumber;
      _isSimulationMode = isSimulationMode; // Set simulation mode flag
      
      if (_isSimulationMode) {
        debugPrint('⚠️ SIMULATION MODE: GPS location sending will be BLOCKED');
      }

      // Initialize queue service
      await _queueService.initialize();

      // Connect WebSocket
      final connected = await _connectWebSocket(
        token: token,
        vehicleId: vehicleId,
        onLocationUpdate: onLocationUpdate,
        onError: onError,
      );

      if (connected) {
        _isConnected = true;
        _stats.connectionTime = DateTime.now();
        _updateStats();

        // CRITICAL: Send initial location immediately after connecting
        // This ensures database has GPS data before any broadcasts
        if (!isSimulationMode) {
          // For real GPS mode, get and send current location
          await _sendInitialLocation();
        }
        // For simulation mode, initial location will be sent when simulation starts

        // Process any queued locations
        await _processQueuedLocations();

        debugPrint('✅ Enhanced location tracking started');
      }

      return connected;
    } catch (e) {
      final errorMsg = 'Lỗi khi khởi động tracking: $e';
      debugPrint('❌ $errorMsg');
      onError?.call(errorMsg);
      return false;
    }
  }

  /// Connect WebSocket with enhanced error handling
  Future<bool> _connectWebSocket({
    required String token,
    required String vehicleId,
    Function(Map<String, dynamic>)? onLocationUpdate,
    Function(String)? onError,
  }) async {
    final Completer<bool> connectionCompleter = Completer<bool>();

    await _webSocketService.connect(
      jwtToken: token,
      vehicleId: vehicleId,
      onConnected: () {
        debugPrint('✅ WebSocket connected for enhanced tracking');
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete(true);
        }
      },
      onError: (error) {
        debugPrint('❌ WebSocket error: $error');
        _stats.lastError = error;
        _stats.errorCount++;
        _updateStats();
        onError?.call(error);
        if (!connectionCompleter.isCompleted) {
          connectionCompleter.complete(false);
        }
      },
      onLocationBroadcast: (data) {
        // CRITICAL: Verify this location update is for OUR vehicle only
        // This prevents camera focus issues in multi-trip orders
        final broadcastVehicleId = data['vehicleId']?.toString();
        
        if (broadcastVehicleId != null && broadcastVehicleId != vehicleId) {
          debugPrint('⚠️ IGNORED: Location broadcast for different vehicle');
          debugPrint('   Expected: $vehicleId, Got: $broadcastVehicleId');
          debugPrint('   This prevents auto-focus issues in multi-trip orders');
          return; // Ignore locations from other vehicles
        }
        
        debugPrint('📍 Enhanced location broadcast (vehicleId: $vehicleId): $data');
        _locationUpdatesController.add(data);
        onLocationUpdate?.call(data);
      },
    );

    // Timeout
    Timer(const Duration(seconds: 10), () {
      if (!connectionCompleter.isCompleted) {
        debugPrint('⏱️ WebSocket connection timeout');
        connectionCompleter.complete(false);
      }
    });

    return await connectionCompleter.future;
  }

  /// Get and send current location immediately after connecting
  /// This ensures database has GPS data before any broadcasts
  Future<void> _sendInitialLocation() async {
    if (!_isConnected || _vehicleId == null) {
      return;
    }

    try {
      debugPrint('📍 Getting initial location...');
      
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission denied - cannot send initial location');
        return;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ Initial location timeout - will send when GPS ready');
          throw Exception('Getting initial location timed out');
        },
      );

      // Validate position
      if (position.latitude == 0 && position.longitude == 0) {
        debugPrint('❌ Invalid initial position (0,0) - skipping');
        return;
      }

      // Check for California GPS (emulator default)
      final isCaliforniaGPS = (position.latitude >= 32.0 && position.latitude <= 42.0) && 
                             (position.longitude >= -125.0 && position.longitude <= -114.0);
      
      if (isCaliforniaGPS && _isSimulationMode) {
        debugPrint('⚠️ California GPS detected in simulation mode - waiting for simulation location');
        return;
      }

      debugPrint('✅ Got initial location: ${position.latitude}, ${position.longitude}');
      
      // Send initial location
      // Use isManualUpdate=false for real GPS, true for simulation
      await sendPosition(position, isManualUpdate: false);
      
      debugPrint('📤 Initial location sent successfully');
    } catch (e) {
      debugPrint('⚠️ Could not get initial location: $e');
      // Don't fail - location will be sent when GPS updates arrive
    }
  }

  /// Enhanced location sending with throttling and validation
  Future<void> sendLocationUpdate({
    required double latitude,
    required double longitude,
    double? bearing,
    double? speed,
    double? accuracy,
  }) async {
    final position = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: accuracy ?? 999.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: bearing ?? 0.0,
      headingAccuracy: 0.0,
      speed: speed ?? 0.0,
      speedAccuracy: 0.0,
    );

    await sendPosition(position, isManualUpdate: true); // Manual update - always allow
  }

  /// Send Position object with full validation
  Future<void> sendPosition(Position position, {bool isManualUpdate = false}) async {
    // Check for California GPS
    final lat = position.latitude;
    final lng = position.longitude;
    final isCaliforniaGPS = (lat >= 32.0 && lat <= 42.0) && (lng >= -125.0 && lng <= -114.0);
    
    // CRITICAL: Block GPS location trong simulation mode
    // NHƯNG CHO PHÉP manual updates (simulation location)
    if (_isSimulationMode && !isManualUpdate) {
      if (isCaliforniaGPS) {
        debugPrint('🚫🚫🚫 CALIFORNIA GPS DETECTED IN SIMULATION MODE! 🚫🚫🚫');
        debugPrint('   - GPS Location: ${position.latitude}, ${position.longitude}');
        debugPrint('   - Source: GPS Stream (SHOULD BE STOPPED!)');
        debugPrint('   - ⚠️⚠️⚠️ CRITICAL: GPS stream is LEAKING in simulation mode!');
      } else {
        debugPrint('🚫 BLOCKED: GPS location ignored in simulation mode');
        debugPrint('   - GPS Location: ${position.latitude}, ${position.longitude}');
      }
      return;
    }
    
    if (isManualUpdate && _isSimulationMode) {
      if (isCaliforniaGPS) {
        debugPrint('❌❌❌ ERROR: Manual update with California GPS in simulation!');
        debugPrint('   - This should NEVER happen!');
        debugPrint('   - Location: ${position.latitude}, ${position.longitude}');
        return; // Don't send California GPS even if manual
      }
      debugPrint('✅ ALLOWED: Manual location update in simulation mode');
      debugPrint('   - Simulation Location: ${position.latitude}, ${position.longitude}');
      debugPrint('   - Source: Manual sendLocationUpdate()');
    }
    
    if (!_isSimulationMode && !isManualUpdate) {
      debugPrint('📍 GPS: Real GPS location in normal mode');
      debugPrint('   - GPS Location: ${position.latitude}, ${position.longitude}');
    }
    
    _stats.totalUpdatesReceived++;

    // CRITICAL: Skip validation and throttling for simulation mode
    // Simulation locations are always valid and should be sent immediately
    if (!isManualUpdate || !_isSimulationMode) {
      // 1. GPS Quality Validation (only for real GPS)
      if (!_isValidGPSQuality(position)) {
        _stats.rejectedByQuality++;
        _updateStats();
        debugPrint('❌ GPS quality too poor: accuracy=${position.accuracy}m');
        return;
      }

      // 2. Speed Validation (only for real GPS)
      if (!_isValidSpeed(position)) {
        _stats.rejectedBySpeed++;
        _updateStats();
        debugPrint('❌ Speed too high: ${position.speed * 3.6} km/h');
        return;
      }

      // 3. Throttling Check (only for real GPS)
      if (!_shouldSendUpdate(position)) {
        _stats.throttledUpdates++;
        _updateStats();
        debugPrint('🔄 Update throttled');
        return;
      }
    } else {
      debugPrint('⚡ FAST-TRACK: Simulation location - skipping validation & throttling');
    }

    final location = LatLng(position.latitude, position.longitude);

    // 4. Try to send immediately
    if (_isConnected && await _isOnline()) {
      // Convert speed from m/s to km/h
      final speedKmh = position.speed * 3.6;
      final success = await _sendLocationNow(location, position.heading, speed: speedKmh);
      if (success) {
        _updateLastSendState(location);
        _stats.successfulSends++;
        _stats.lastSuccessfulSend = DateTime.now();
        _updateStats();
        return;
      }
    }

    // 5. Queue for later if failed or offline
    await _queueLocation(location, position.heading, position.accuracy);
    _stats.queuedUpdates++;
    _updateStats();
    debugPrint('📦 Location queued for later');
  }

  /// Validate GPS quality
  bool _isValidGPSQuality(Position position) {
    // Reject if accuracy is worse than threshold
    if (position.accuracy > _maxAccuracyThreshold) {
      return false;
    }

    // Additional quality checks
    if (position.latitude.abs() < 0.001 && position.longitude.abs() < 0.001) {
      return false; // Likely invalid (0,0) coordinate
    }

    return true;
  }

  /// Validate speed to filter GPS spikes
  bool _isValidSpeed(Position position) {
    final speedKmh = position.speed * 3.6; // Convert m/s to km/h
    return speedKmh <= _maxSpeedThreshold;
  }

  /// Check if we should send this update based on time and distance throttling
  bool _shouldSendUpdate(Position position) {
    final now = DateTime.now();
    final location = LatLng(position.latitude, position.longitude);

    // Always send first update
    if (_lastSendTime == null || _lastSendLocation == null) {
      return true;
    }

    // Check time threshold
    final timeSinceLastSend = now.difference(_lastSendTime!);
    final timeThresholdMet = timeSinceLastSend >= _minTimeBetweenSends;

    // Check distance threshold
    final distanceMoved = _calculateDistance(_lastSendLocation!, location);
    final distanceThresholdMet = distanceMoved >= _minDistanceBetweenSends;

    // Check dedupe (too close to last position)
    final tooClose = distanceMoved < _dedupeRadius;
    if (tooClose && timeSinceLastSend < _minTimeBetweenSends) {
      return false; // Skip jitter
    }

    // Send if either threshold is met
    return timeThresholdMet || distanceThresholdMet;
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Send location immediately via WebSocket
  Future<bool> _sendLocationNow(LatLng location, double bearing, {double? speed}) async {
    if (!_isConnected || _vehicleId == null || _licensePlateNumber == null) {
      return false;
    }

    try {
      _webSocketService.sendLocationUpdateRateLimited(
        vehicleId: _vehicleId!,
        latitude: location.latitude,
        longitude: location.longitude,
        licensePlateNumber: _licensePlateNumber!,
        bearing: bearing,
        speed: speed,
      );

      debugPrint(
        '📤 Enhanced location sent: ${location.latitude}, ${location.longitude}, speed: ${speed ?? 0}km/h',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send location: $e');
      _stats.failedSends++;
      _stats.lastError = e.toString();
      _updateStats();
      return false;
    }
  }

  /// Queue location for offline sending
  Future<void> _queueLocation(
    LatLng location,
    double bearing,
    double accuracy,
  ) async {
    await _queueService.queueLocation(
      vehicleId: _vehicleId!,
      latitude: location.latitude,
      longitude: location.longitude,
      bearing: bearing,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    );
  }

  /// Process queued locations when connection is restored
  Future<void> _processQueuedLocations() async {
    if (!_isConnected) return;

    final queuedLocations = await _queueService.getQueuedLocations();
    debugPrint('📦 Processing ${queuedLocations.length} queued locations');

    for (final location in queuedLocations) {
      final success = await _sendLocationNow(
        LatLng(location['latitude'], location['longitude']),
        location['bearing'] ?? 0.0,
      );

      if (success) {
        await _queueService.removeLocation(location['id']);
        _stats.queueProcessed++;
      } else {
        break; // Stop processing if send fails
      }
    }

    _updateStats();
  }

  /// Check if device is online
  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Update last send state
  void _updateLastSendState(LatLng location) {
    _lastSendTime = DateTime.now();
    _lastSendLocation = location;
  }

  /// Update stats and notify listeners
  void _updateStats() {
    _stats.queueSize = _queueService.queueSize;
    _statsController.add(_stats);
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    if (!_isConnected) {
      debugPrint('⚠️ Enhanced tracking already stopped or not connected');
      return;
    }

    try {
      debugPrint('🔌 Stopping enhanced location tracking...');
      debugPrint('   - Vehicle ID: $_vehicleId');
      debugPrint('   - Was simulation mode: $_isSimulationMode');
      
      await _webSocketService.disconnect();
      _isConnected = false;
      _vehicleId = null;
      _licensePlateNumber = null;
      _isSimulationMode = false; // CRITICAL: Reset simulation mode flag
      _lastSendTime = null;
      _lastSendLocation = null;
      _lastValidPosition = null;
      
      _stats.disconnectionTime = DateTime.now();
      _updateStats();
      
      debugPrint('✅ Enhanced location tracking stopped');
      debugPrint('   - Simulation mode reset to: false');
      debugPrint('   - All state cleared');
    } catch (e) {
      debugPrint('❌ Error stopping tracking: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _locationUpdatesController.close();
    _statsController.close();
    _queueService.dispose();
  }

  /// Get current tracking statistics
  Map<String, dynamic> getTrackingStats() {
    return {
      'totalReceived': _stats.totalUpdatesReceived,
      'successfulSends': _stats.successfulSends,
      'failedSends': _stats.failedSends,
      'throttledUpdates': _stats.throttledUpdates,
      'queuedUpdates': _stats.queuedUpdates,
      'queueProcessed': _stats.queueProcessed,
      'rejectedByQuality': _stats.rejectedByQuality,
      'rejectedBySpeed': _stats.rejectedBySpeed,
      'errorCount': _stats.errorCount,
      'queueSize': _stats.queueSize,
      'lastSuccessfulSend': _stats.lastSuccessfulSend?.toIso8601String(),
      'connectionTime': _stats.connectionTime?.toIso8601String(),
      'lastError': _stats.lastError,
    };
  }
}

/// Statistics tracking class
class LocationTrackingStats {
  int totalUpdatesReceived = 0;
  int successfulSends = 0;
  int failedSends = 0;
  int throttledUpdates = 0;
  int queuedUpdates = 0;
  int queueProcessed = 0;
  int rejectedByQuality = 0;
  int rejectedBySpeed = 0;
  int errorCount = 0;
  int queueSize = 0;
  DateTime? lastSuccessfulSend;
  DateTime? connectionTime;
  DateTime? disconnectionTime;
  String? lastError;

  double get successRate {
    final total = successfulSends + failedSends;
    return total > 0 ? successfulSends / total : 0.0;
  }

  Duration? get connectionDuration {
    if (connectionTime == null) return null;
    final endTime = disconnectionTime ?? DateTime.now();
    return endTime.difference(connectionTime!);
  }
}
