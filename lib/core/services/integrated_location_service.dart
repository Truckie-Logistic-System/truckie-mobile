import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'service_locator.dart';
import 'enhanced_location_tracking_service.dart';
import 'background_location_service.dart';
import 'app_restart_recovery_service.dart';

/// Integrated Location Service - Main interface cho location tracking
/// Kết hợp tất cả các enhanced features
class IntegratedLocationService {
  static IntegratedLocationService? _instance;
  static IntegratedLocationService get instance => _instance ??= IntegratedLocationService._();
  
  IntegratedLocationService._();

  final EnhancedLocationTrackingService _enhancedService = getIt<EnhancedLocationTrackingService>();
  
  StreamSubscription<Position>? _positionStream;
  Timer? _periodicSaveTimer;
  
  bool _isActive = false;
  String? _currentVehicleId;
  String? _currentLicensePlate;
  bool _isBackgroundTrackingEnabled = false;

  // Getters
  bool get isActive => _isActive;
  String? get currentVehicleId => _currentVehicleId;
  String? get currentLicensePlate => _currentLicensePlate;
  bool get isBackgroundTrackingEnabled => _isBackgroundTrackingEnabled;
  
  // Streams
  Stream<Map<String, dynamic>> get locationUpdates => _enhancedService.locationUpdates;
  Stream<LocationTrackingStats> get statsStream => _enhancedService.statsStream;

  /// Start comprehensive location tracking
  Future<bool> startTracking({
    required String vehicleId,
    required String licensePlateNumber,
    String? jwtToken,
    bool enableBackgroundTracking = true,
    Function(Map<String, dynamic>)? onLocationUpdate,
    Function(String)? onError,
  }) async {
    if (_isActive) {
      debugPrint('⚠️ Integrated location tracking already active');
      return true;
    }

    try {
      debugPrint('🚀 Starting integrated location tracking...');
      
      // 1. Check and request permissions
      final hasPermissions = await _checkAndRequestPermissions();
      if (!hasPermissions) {
        onError?.call('Location permissions denied');
        return false;
      }

      // 2. Start enhanced location tracking
      final trackingSuccess = await _enhancedService.startTracking(
        vehicleId: vehicleId,
        licensePlateNumber: licensePlateNumber,
        jwtToken: jwtToken,
        onLocationUpdate: onLocationUpdate,
        onError: onError,
      );

      if (!trackingSuccess) {
        debugPrint('❌ Failed to start enhanced location tracking');
        return false;
      }

      // 3. Start background tracking if enabled
      if (enableBackgroundTracking) {
        final backgroundSuccess = await BackgroundLocationService.startBackgroundTracking(
          vehicleId: vehicleId,
          licensePlateNumber: licensePlateNumber,
          jwtToken: jwtToken,
        );
        
        if (backgroundSuccess) {
          _isBackgroundTrackingEnabled = true;
          debugPrint('✅ Background tracking enabled');
        } else {
          debugPrint('⚠️ Background tracking failed, continuing with foreground only');
        }
      }

      // 4. Start GPS position stream
      await _startPositionStream();

      // 5. Start periodic state saving
      _startPeriodicStateSaving();

      // 6. Save initial tracking state
      await AppRestartRecoveryService.saveTrackingState(
        vehicleId: vehicleId,
        licensePlateNumber: licensePlateNumber,
        isTracking: true,
        isBackgroundTracking: _isBackgroundTrackingEnabled,
        jwtToken: jwtToken,
      );

      _isActive = true;
      _currentVehicleId = vehicleId;
      _currentLicensePlate = licensePlateNumber;

      debugPrint('✅ Integrated location tracking started successfully');
      return true;

    } catch (e) {
      debugPrint('❌ Failed to start integrated location tracking: $e');
      onError?.call('Failed to start tracking: $e');
      return false;
    }
  }

  /// Stop all location tracking
  Future<void> stopTracking() async {
    if (!_isActive) {
      debugPrint('⚠️ Integrated location tracking not active');
      return;
    }

    try {
      debugPrint('🛑 Stopping integrated location tracking...');

      // 1. Stop position stream
      await _positionStream?.cancel();
      _positionStream = null;

      // 2. Stop periodic saving
      _periodicSaveTimer?.cancel();
      _periodicSaveTimer = null;

      // 3. Stop background tracking
      if (_isBackgroundTrackingEnabled) {
        await BackgroundLocationService.stopBackgroundTracking();
        _isBackgroundTrackingEnabled = false;
      }

      // 4. Stop enhanced tracking
      await _enhancedService.stopTracking();

      // 5. Clear tracking state
      await AppRestartRecoveryService.clearTrackingState();

      _isActive = false;
      _currentVehicleId = null;
      _currentLicensePlate = null;

      debugPrint('✅ Integrated location tracking stopped');

    } catch (e) {
      debugPrint('❌ Error stopping integrated location tracking: $e');
    }
  }

  /// Attempt to recover tracking after app restart
  Future<bool> attemptRecovery() async {
    debugPrint('🔄 Attempting integrated location tracking recovery...');
    
    try {
      // Use recovery service to restore state
      final recovered = await AppRestartRecoveryService.attemptTrackingRecovery();
      
      if (recovered) {
        // Get recovered state
        final savedState = await AppRestartRecoveryService.getSavedTrackingState();
        if (savedState != null) {
          _isActive = true;
          _currentVehicleId = savedState['vehicleId'];
          _currentLicensePlate = savedState['licensePlateNumber'];
          _isBackgroundTrackingEnabled = savedState['isBackgroundTracking'] ?? false;
          
          // Restart position stream and periodic saving
          await _startPositionStream();
          _startPeriodicStateSaving();
          
          debugPrint('✅ Integrated location tracking recovered successfully');
          return true;
        }
      }
      
      debugPrint('ℹ️ No tracking state to recover');
      return false;
      
    } catch (e) {
      debugPrint('❌ Recovery failed: $e');
      return false;
    }
  }

  /// Check and request location permissions
  Future<bool> _checkAndRequestPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permissions permanently denied');
        return false;
      }
      
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permissions denied');
        return false;
      }
      
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services disabled');
        return false;
      }
      
      debugPrint('✅ Location permissions granted');
      return true;
      
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Start GPS position stream
  Future<void> _startPositionStream() async {
    try {
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Minimum 5 meters movement
        // Remove timeLimit to prevent timeout errors
        // GPS will continue streaming indefinitely
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          // Send position through enhanced service (with throttling and validation)
          _enhancedService.sendPosition(position);
        },
        onError: (error) {
          debugPrint('❌ Position stream error: $error');
          // Don't stop tracking on error, just log it
        },
        cancelOnError: false, // Continue stream even if there's an error
      );

      debugPrint('✅ GPS position stream started');
      
    } catch (e) {
      debugPrint('❌ Failed to start position stream: $e');
    }
  }

  /// Start periodic state saving
  void _startPeriodicStateSaving() {
    _periodicSaveTimer?.cancel();
    
    _periodicSaveTimer = Timer.periodic(
      const Duration(minutes: 1), // Save state every minute
      (_) => _saveCurrentState(),
    );
    
    debugPrint('✅ Periodic state saving started');
  }

  /// Save current tracking state
  Future<void> _saveCurrentState() async {
    if (!_isActive || _currentVehicleId == null || _currentLicensePlate == null) {
      return;
    }

    try {
      // Get current stats
      final stats = _enhancedService.getTrackingStats();
      
      // Get last known location (if available)
      // This would typically come from the last position received
      
      await AppRestartRecoveryService.periodicStateSave(
        vehicleId: _currentVehicleId!,
        licensePlateNumber: _currentLicensePlate!,
        isTracking: _isActive,
        isBackgroundTracking: _isBackgroundTrackingEnabled,
        trackingStats: stats,
      );
      
    } catch (e) {
      debugPrint('❌ Failed to save current state: $e');
    }
  }

  /// Get comprehensive tracking status
  Map<String, dynamic> getTrackingStatus() {
    final enhancedStats = _enhancedService.getTrackingStats();
    final backgroundStatus = BackgroundLocationService.getTrackingStatus();
    
    return {
      'isActive': _isActive,
      'vehicleId': _currentVehicleId,
      'licensePlate': _currentLicensePlate,
      'isBackgroundEnabled': _isBackgroundTrackingEnabled,
      'hasPositionStream': _positionStream != null,
      'hasPeriodicSaving': _periodicSaveTimer != null,
      'enhancedStats': enhancedStats,
      'backgroundStatus': backgroundStatus,
    };
  }

  /// Send manual location update
  Future<void> sendLocationUpdate(LatLng location, {double? bearing}) async {
    if (!_isActive) {
      debugPrint('⚠️ Cannot send location: tracking not active');
      return;
    }

    await _enhancedService.sendLocationUpdate(
      latitude: location.latitude,
      longitude: location.longitude,
      bearing: bearing,
    );
  }

  /// Get tracking statistics
  Map<String, dynamic> getTrackingStats() {
    return _enhancedService.getTrackingStats();
  }

  /// Check if tracking was active before app kill
  Future<bool> wasTrackingActiveBeforeKill() async {
    return await AppRestartRecoveryService.wasTrackingActiveBeforeKill();
  }

  /// Get recovery status
  Future<Map<String, dynamic>> getRecoveryStatus() async {
    return await AppRestartRecoveryService.getRecoveryStatus();
  }

  /// Process background location queue
  /// Call this when app comes to foreground
  Future<void> processBackgroundLocationQueue() async {
    try {
      debugPrint('🔄 Processing background location queue...');
      
      // Open background queue box
      if (!Hive.isBoxOpen('background_location_queue')) {
        await Hive.openBox('background_location_queue');
      }

      final box = Hive.box('background_location_queue');
      
      if (box.isEmpty) {
        debugPrint('ℹ️ Background queue is empty');
        return;
      }

      debugPrint('📦 Found ${box.length} background locations to process');
      
      int processed = 0;
      int failed = 0;

      // Process each queued location
      for (int i = 0; i < box.length; i++) {
        try {
          final locationData = box.getAt(i) as Map<dynamic, dynamic>;
          
          // Send location through enhanced service
          await _enhancedService.sendLocationUpdate(
            latitude: locationData['latitude'] as double,
            longitude: locationData['longitude'] as double,
            bearing: locationData['bearing'] as double?,
          );
          
          processed++;
          
        } catch (e) {
          debugPrint('❌ Failed to process background location: $e');
          failed++;
        }
      }

      // Clear processed locations
      await box.clear();
      
      debugPrint('✅ Background queue processed: $processed sent, $failed failed');
      
    } catch (e) {
      debugPrint('❌ Failed to process background queue: $e');
    }
  }
}
