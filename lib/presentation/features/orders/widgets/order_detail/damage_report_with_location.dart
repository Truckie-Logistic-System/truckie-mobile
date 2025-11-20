import 'package:flutter/material.dart';

import '../../../../../app/di/service_locator.dart';
import '../../../../../core/services/global_location_manager.dart';
import '../../../../../domain/entities/order_with_details.dart';
import 'damage_report_section.dart';

/// Widget wrapper to get current location and pass to DamageReportSection
/// UPDATED: Now uses GlobalLocationManager to get simulated location during simulation mode
/// instead of Geolocator.getCurrentPosition() which always returns real GPS
class DamageReportWithLocation extends StatefulWidget {
  final OrderWithDetails order;
  final VoidCallback onReported;

  const DamageReportWithLocation({
    super.key,
    required this.order,
    required this.onReported,
  });

  @override
  State<DamageReportWithLocation> createState() => _DamageReportWithLocationState();
}

class _DamageReportWithLocationState extends State<DamageReportWithLocation> {
  late final GlobalLocationManager _globalLocationManager;
  double? _currentLatitude;
  double? _currentLongitude;

  @override
  void initState() {
    super.initState();
    _globalLocationManager = getIt<GlobalLocationManager>();
    _getCurrentLocation();
  }

  void _getCurrentLocation() {
    // CRITICAL: Get location from GlobalLocationManager
    // This will return simulated location if simulation mode is active
    // Otherwise, it returns the last known GPS location
    _currentLatitude = _globalLocationManager.currentLatitude;
    _currentLongitude = _globalLocationManager.currentLongitude;

    if (_currentLatitude == null || _currentLongitude == null) {

    } else if (_currentLatitude == 37.4219983 && _currentLongitude == -122.084) {

    } else {

    }
  }

  @override
  Widget build(BuildContext context) {
    return DamageReportSection(
      order: widget.order,
      onReported: widget.onReported,
      currentLatitude: _currentLatitude,
      currentLongitude: _currentLongitude,
    );
  }
}
