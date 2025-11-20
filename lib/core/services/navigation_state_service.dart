import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to persist navigation state across app restarts
/// This allows resuming delivery tracking after app crash or restart
class NavigationStateService {
  static const String _keyActiveOrderId = 'active_order_id';
  static const String _keyVehicleId = 'active_vehicle_id';
  static const String _keyLicensePlate = 'active_license_plate';
  static const String _keyIsSimulationMode = 'is_simulation_mode';
  static const String _keyCurrentSegmentIndex = 'current_segment_index';
  static const String _keyCurrentLatitude = 'current_latitude';
  static const String _keyCurrentLongitude = 'current_longitude';
  static const String _keyCurrentBearing = 'current_bearing';
  static const String _keyTrackingStartTime = 'tracking_start_time';

  final SharedPreferences _prefs;

  NavigationStateService(this._prefs);

  /// Save active navigation state
  Future<void> saveNavigationState({
    required String orderId,
    required String vehicleId,
    required String licensePlate,
    required bool isSimulationMode,
    int? currentSegmentIndex,
    double? currentLatitude,
    double? currentLongitude,
    double? currentBearing,
  }) async {
    try {
      await _prefs.setString(_keyActiveOrderId, orderId);
      await _prefs.setString(_keyVehicleId, vehicleId);
      await _prefs.setString(_keyLicensePlate, licensePlate);
      await _prefs.setBool(_keyIsSimulationMode, isSimulationMode);
      await _prefs.setString(
        _keyTrackingStartTime,
        DateTime.now().toIso8601String(),
      );

      if (currentSegmentIndex != null) {
        await _prefs.setInt(_keyCurrentSegmentIndex, currentSegmentIndex);
      }
      if (currentLatitude != null) {
        await _prefs.setDouble(_keyCurrentLatitude, currentLatitude);
      }
      if (currentLongitude != null) {
        await _prefs.setDouble(_keyCurrentLongitude, currentLongitude);
      }
      if (currentBearing != null) {
        await _prefs.setDouble(_keyCurrentBearing, currentBearing);
      }

    } catch (e) {

    }
  }

  /// Update current position (called frequently during tracking)
  Future<void> updateCurrentPosition({
    required double latitude,
    required double longitude,
    double? bearing,
    int? segmentIndex,
  }) async {
    try {
      await _prefs.setDouble(_keyCurrentLatitude, latitude);
      await _prefs.setDouble(_keyCurrentLongitude, longitude);
      if (bearing != null) {
        await _prefs.setDouble(_keyCurrentBearing, bearing);
      }
      if (segmentIndex != null) {
        await _prefs.setInt(_keyCurrentSegmentIndex, segmentIndex);
      }
    } catch (e) {

    }
  }

  /// Get saved navigation state
  NavigationState? getSavedNavigationState() {
    try {
      final orderId = _prefs.getString(_keyActiveOrderId);
      if (orderId == null) {
        return null;
      }

      final vehicleId = _prefs.getString(_keyVehicleId);
      final licensePlate = _prefs.getString(_keyLicensePlate);
      final isSimulationMode = _prefs.getBool(_keyIsSimulationMode) ?? false;
      final currentSegmentIndex = _prefs.getInt(_keyCurrentSegmentIndex);
      final currentLatitude = _prefs.getDouble(_keyCurrentLatitude);
      final currentLongitude = _prefs.getDouble(_keyCurrentLongitude);
      final currentBearing = _prefs.getDouble(_keyCurrentBearing);
      final trackingStartTimeStr = _prefs.getString(_keyTrackingStartTime);

      DateTime? trackingStartTime;
      if (trackingStartTimeStr != null) {
        try {
          trackingStartTime = DateTime.parse(trackingStartTimeStr);
        } catch (e) {

        }
      }

      return NavigationState(
        orderId: orderId,
        vehicleId: vehicleId,
        licensePlate: licensePlate,
        isSimulationMode: isSimulationMode,
        currentSegmentIndex: currentSegmentIndex,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        currentBearing: currentBearing,
        trackingStartTime: trackingStartTime,
      );
    } catch (e) {

      return null;
    }
  }

  /// Clear saved navigation state (when delivery is completed or cancelled)
  Future<void> clearNavigationState() async {
    try {
      await _prefs.remove(_keyActiveOrderId);
      await _prefs.remove(_keyVehicleId);
      await _prefs.remove(_keyLicensePlate);
      await _prefs.remove(_keyIsSimulationMode);
      await _prefs.remove(_keyCurrentSegmentIndex);
      await _prefs.remove(_keyCurrentLatitude);
      await _prefs.remove(_keyCurrentLongitude);
      await _prefs.remove(_keyCurrentBearing);
      await _prefs.remove(_keyTrackingStartTime);

    } catch (e) {

    }
  }

  /// Check if there's an active navigation session
  bool hasActiveNavigation() {
    return _prefs.getString(_keyActiveOrderId) != null;
  }

  /// Get active order ID if exists
  String? getActiveOrderId() {
    return _prefs.getString(_keyActiveOrderId);
  }
  
  /// Save just the active order ID (lightweight alternative to saveNavigationState)
  /// Used when we only need to persist orderId without full navigation state
  Future<void> saveActiveOrderId(String orderId) async {
    try {
      await _prefs.setString(_keyActiveOrderId, orderId);
    } catch (e) {
      // Silent fail - non-critical operation
    }
  }
}

/// Data class to hold navigation state
class NavigationState {
  final String orderId;
  final String? vehicleId;
  final String? licensePlate;
  final bool isSimulationMode;
  final int? currentSegmentIndex;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? currentBearing;
  final DateTime? trackingStartTime;

  NavigationState({
    required this.orderId,
    this.vehicleId,
    this.licensePlate,
    required this.isSimulationMode,
    this.currentSegmentIndex,
    this.currentLatitude,
    this.currentLongitude,
    this.currentBearing,
    this.trackingStartTime,
  });

  bool get hasPosition =>
      currentLatitude != null && currentLongitude != null;

  @override
  String toString() {
    return 'NavigationState(orderId: $orderId, vehicleId: $vehicleId, '
        'isSimulation: $isSimulationMode, segment: $currentSegmentIndex, '
        'position: ${hasPosition ? "($currentLatitude, $currentLongitude)" : "none"})';
  }
}
