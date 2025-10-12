import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_locator.dart';
import 'enhanced_location_tracking_service.dart';
import 'background_location_service.dart';
import 'token_storage_service.dart';

/// Service để khôi phục tracking state sau khi app restart
/// Supports both real-time tracking and simulation mode
class AppRestartRecoveryService {
  static const String _trackingStateKey = 'location_tracking_state';
  static const String _lastLocationKey = 'last_known_location';
  static const String _trackingStatsKey = 'tracking_statistics';
  static const String _simulationStateKey = 'simulation_state';
  
  static SharedPreferences? _prefs;
  static bool _isInitialized = false;
  
  /// Initialize recovery service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      debugPrint('✅ AppRestartRecoveryService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize AppRestartRecoveryService: $e');
      rethrow;
    }
  }

  /// Save current tracking state
  static Future<void> saveTrackingState({
    required String vehicleId,
    required String licensePlateNumber,
    required bool isTracking,
    required bool isBackgroundTracking,
    String? jwtToken,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isInitialized || _prefs == null) {
      debugPrint('❌ AppRestartRecoveryService not initialized');
      return;
    }

    try {
      final state = {
        'vehicleId': vehicleId,
        'licensePlateNumber': licensePlateNumber,
        'isTracking': isTracking,
        'isBackgroundTracking': isBackgroundTracking,
        'jwtToken': jwtToken,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'additionalData': additionalData ?? {},
      };

      await _prefs!.setString(_trackingStateKey, jsonEncode(state));
      debugPrint('💾 Tracking state saved');
      
    } catch (e) {
      debugPrint('❌ Failed to save tracking state: $e');
    }
  }

  /// Get saved tracking state
  static Future<Map<String, dynamic>?> getSavedTrackingState() async {
    if (!_isInitialized || _prefs == null) {
      debugPrint('❌ AppRestartRecoveryService not initialized');
      return null;
    }

    try {
      final stateJson = _prefs!.getString(_trackingStateKey);
      if (stateJson == null) {
        debugPrint('ℹ️ No saved tracking state found');
        return null;
      }

      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      
      // Check if state is not too old (max 24 hours)
      final savedAt = DateTime.fromMillisecondsSinceEpoch(state['savedAt'] ?? 0);
      final now = DateTime.now();
      final age = now.difference(savedAt);
      
      if (age.inHours > 24) {
        debugPrint('⚠️ Saved tracking state is too old (${age.inHours} hours), ignoring');
        await clearTrackingState();
        return null;
      }

      debugPrint('📂 Retrieved saved tracking state (age: ${age.inMinutes} minutes)');
      return state;
      
    } catch (e) {
      debugPrint('❌ Failed to get saved tracking state: $e');
      return null;
    }
  }

  /// Clear saved tracking state
  static Future<void> clearTrackingState() async {
    if (!_isInitialized || _prefs == null) {
      return;
    }

    try {
      await _prefs!.remove(_trackingStateKey);
      debugPrint('🗑️ Tracking state cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear tracking state: $e');
    }
  }

  /// Save last known location
  static Future<void> saveLastKnownLocation({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double? bearing,
    double? accuracy,
  }) async {
    if (!_isInitialized || _prefs == null) {
      return;
    }

    try {
      final location = {
        'latitude': latitude,
        'longitude': longitude,
        'bearing': bearing,
        'accuracy': accuracy,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

      await _prefs!.setString(_lastLocationKey, jsonEncode(location));
      
    } catch (e) {
      debugPrint('❌ Failed to save last known location: $e');
    }
  }

  /// Get last known location
  static Future<Map<String, dynamic>?> getLastKnownLocation() async {
    if (!_isInitialized || _prefs == null) {
      return null;
    }

    try {
      final locationJson = _prefs!.getString(_lastLocationKey);
      if (locationJson == null) {
        return null;
      }

      final location = jsonDecode(locationJson) as Map<String, dynamic>;
      
      // Check if location is not too old (max 1 hour)
      final timestamp = DateTime.fromMillisecondsSinceEpoch(location['timestamp'] ?? 0);
      final age = DateTime.now().difference(timestamp);
      
      if (age.inHours > 1) {
        debugPrint('⚠️ Last known location is too old (${age.inMinutes} minutes)');
        return null;
      }

      return location;
      
    } catch (e) {
      debugPrint('❌ Failed to get last known location: $e');
      return null;
    }
  }

  /// Save tracking statistics
  static Future<void> saveTrackingStats(Map<String, dynamic> stats) async {
    if (!_isInitialized || _prefs == null) {
      return;
    }

    try {
      await _prefs!.setString(_trackingStatsKey, jsonEncode(stats));
    } catch (e) {
      debugPrint('❌ Failed to save tracking stats: $e');
    }
  }

  /// Get saved tracking statistics
  static Future<Map<String, dynamic>?> getSavedTrackingStats() async {
    if (!_isInitialized || _prefs == null) {
      return null;
    }

    try {
      final statsJson = _prefs!.getString(_trackingStatsKey);
      if (statsJson == null) {
        return null;
      }

      return jsonDecode(statsJson) as Map<String, dynamic>;
      
    } catch (e) {
      debugPrint('❌ Failed to get saved tracking stats: $e');
      return null;
    }
  }

  /// Attempt to recover and restart tracking after app restart
  static Future<bool> attemptTrackingRecovery() async {
    if (!_isInitialized) {
      debugPrint('❌ AppRestartRecoveryService not initialized');
      return false;
    }

    try {
      debugPrint('🔄 Attempting tracking recovery...');
      
      // Get saved tracking state
      final savedState = await getSavedTrackingState();
      if (savedState == null) {
        debugPrint('ℹ️ No tracking state to recover');
        return false;
      }

      final vehicleId = savedState['vehicleId'] as String?;
      final licensePlateNumber = savedState['licensePlateNumber'] as String?;
      final isTracking = savedState['isTracking'] as bool? ?? false;
      final isBackgroundTracking = savedState['isBackgroundTracking'] as bool? ?? false;
      final jwtToken = savedState['jwtToken'] as String?;

      if (!isTracking || vehicleId == null || licensePlateNumber == null) {
        debugPrint('ℹ️ No active tracking to recover');
        await clearTrackingState();
        return false;
      }

      debugPrint('🔄 Recovering tracking for vehicle: $vehicleId');

      // Get fresh token if needed
      String? currentToken = jwtToken;
      if (currentToken == null) {
        final tokenService = getIt<TokenStorageService>();
        currentToken = tokenService.getAccessToken();
      }

      if (currentToken == null) {
        debugPrint('❌ No valid token for recovery');
        await clearTrackingState();
        return false;
      }

      // Restart enhanced location tracking
      final trackingService = getIt<EnhancedLocationTrackingService>();
      final trackingSuccess = await trackingService.startTracking(
        vehicleId: vehicleId,
        licensePlateNumber: licensePlateNumber,
        jwtToken: currentToken,
        onError: (error) {
          debugPrint('❌ Tracking recovery error: $error');
        },
      );

      if (!trackingSuccess) {
        debugPrint('❌ Failed to restart location tracking');
        return false;
      }

      // Restart background tracking if it was active
      if (isBackgroundTracking) {
        final backgroundSuccess = await BackgroundLocationService.startBackgroundTracking(
          vehicleId: vehicleId,
          licensePlateNumber: licensePlateNumber,
          jwtToken: currentToken,
        );

        if (!backgroundSuccess) {
          debugPrint('⚠️ Failed to restart background tracking, but foreground tracking is active');
        }
      }

      // Update saved state with current time
      await saveTrackingState(
        vehicleId: vehicleId,
        licensePlateNumber: licensePlateNumber,
        isTracking: true,
        isBackgroundTracking: isBackgroundTracking,
        jwtToken: currentToken,
        additionalData: savedState['additionalData'],
      );

      debugPrint('✅ Tracking recovery successful');
      return true;
      
    } catch (e) {
      debugPrint('❌ Tracking recovery failed: $e');
      await clearTrackingState();
      return false;
    }
  }

  /// Check if app was killed during active tracking
  static Future<bool> wasTrackingActiveBeforeKill() async {
    final savedState = await getSavedTrackingState();
    return savedState != null && (savedState['isTracking'] as bool? ?? false);
  }

  /// Get recovery status info
  static Future<Map<String, dynamic>> getRecoveryStatus() async {
    if (!_isInitialized) {
      return {'initialized': false};
    }

    final savedState = await getSavedTrackingState();
    final lastLocation = await getLastKnownLocation();
    final savedStats = await getSavedTrackingStats();

    return {
      'initialized': true,
      'hasSavedState': savedState != null,
      'hasLastLocation': lastLocation != null,
      'hasSavedStats': savedStats != null,
      'savedState': savedState,
      'lastLocation': lastLocation,
      'savedStats': savedStats,
    };
  }

  /// Periodic state saving (call this periodically during active tracking)
  static Future<void> periodicStateSave({
    required String vehicleId,
    required String licensePlateNumber,
    required bool isTracking,
    required bool isBackgroundTracking,
    String? jwtToken,
    Map<String, dynamic>? trackingStats,
    double? latitude,
    double? longitude,
    double? bearing,
    double? accuracy,
  }) async {
    // Save tracking state
    await saveTrackingState(
      vehicleId: vehicleId,
      licensePlateNumber: licensePlateNumber,
      isTracking: isTracking,
      isBackgroundTracking: isBackgroundTracking,
      jwtToken: jwtToken,
    );

    // Save last location if provided
    if (latitude != null && longitude != null) {
      await saveLastKnownLocation(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        bearing: bearing,
        accuracy: accuracy,
      );
    }

    // Save tracking stats if provided
    if (trackingStats != null) {
      await saveTrackingStats(trackingStats);
    }
  }

  /// Clear all recovery data
  static Future<void> clearAllRecoveryData() async {
    if (!_isInitialized || _prefs == null) {
      return;
    }

    try {
      await Future.wait([
        _prefs!.remove(_trackingStateKey),
        _prefs!.remove(_lastLocationKey),
        _prefs!.remove(_trackingStatsKey),
        _prefs!.remove(_simulationStateKey),
      ]);
      
      debugPrint('🗑️ All recovery data cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear recovery data: $e');
    }
  }

  // ==================== SIMULATION MODE RECOVERY ====================

  /// Save simulation state for recovery
  static Future<void> saveSimulationState({
    required String orderId,
    required int currentSegmentIndex,
    required List<int> currentPointIndices,
    required double simulationSpeed,
    required bool isPaused,
    String? vehicleId,
    String? licensePlateNumber,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isInitialized || _prefs == null) {
      debugPrint('❌ AppRestartRecoveryService not initialized');
      return;
    }

    try {
      final state = {
        'orderId': orderId,
        'currentSegmentIndex': currentSegmentIndex,
        'currentPointIndices': currentPointIndices,
        'simulationSpeed': simulationSpeed,
        'isPaused': isPaused,
        'vehicleId': vehicleId,
        'licensePlateNumber': licensePlateNumber,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'additionalData': additionalData ?? {},
      };

      await _prefs!.setString(_simulationStateKey, jsonEncode(state));
      debugPrint('💾 Simulation state saved');
      
    } catch (e) {
      debugPrint('❌ Failed to save simulation state: $e');
    }
  }

  /// Get saved simulation state
  static Future<Map<String, dynamic>?> getSavedSimulationState() async {
    if (!_isInitialized || _prefs == null) {
      debugPrint('❌ AppRestartRecoveryService not initialized');
      return null;
    }

    try {
      final stateJson = _prefs!.getString(_simulationStateKey);
      if (stateJson == null) {
        debugPrint('ℹ️ No saved simulation state found');
        return null;
      }

      final state = jsonDecode(stateJson) as Map<String, dynamic>;
      
      // Check if state is not too old (max 1 hour for simulation)
      final savedAt = DateTime.fromMillisecondsSinceEpoch(state['savedAt'] ?? 0);
      final now = DateTime.now();
      final age = now.difference(savedAt);
      
      if (age.inHours > 1) {
        debugPrint('⚠️ Saved simulation state is too old (${age.inMinutes} minutes), ignoring');
        await clearSimulationState();
        return null;
      }

      debugPrint('📂 Retrieved saved simulation state (age: ${age.inMinutes} minutes)');
      return state;
      
    } catch (e) {
      debugPrint('❌ Failed to get saved simulation state: $e');
      return null;
    }
  }

  /// Clear simulation state
  static Future<void> clearSimulationState() async {
    if (!_isInitialized || _prefs == null) {
      return;
    }

    try {
      await _prefs!.remove(_simulationStateKey);
      debugPrint('🗑️ Simulation state cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear simulation state: $e');
    }
  }

  /// Check if simulation was active before app kill
  static Future<bool> wasSimulationActiveBeforeKill() async {
    final state = await getSavedSimulationState();
    return state != null && state['orderId'] != null;
  }
}
