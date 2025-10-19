import 'dart:async';
import 'dart:math';
import 'dart:convert'; // Added for json.decode
import 'package:flutter/foundation.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/usecases/orders/get_order_details_usecase.dart';

class RouteSegment {
  final String name;
  final List<LatLng> points;

  RouteSegment({required this.name, required this.points});
}

class NavigationViewModel extends ChangeNotifier {
  final GetOrderDetailsUseCase _getOrderDetailsUseCase =
      getIt<GetOrderDetailsUseCase>();

  OrderWithDetails? orderWithDetails;
  List<RouteSegment> routeSegments = [];
  int currentSegmentIndex = 0;

  LatLng? currentLocation;
  double? currentBearing;
  double currentSpeed = 0.0;

  String _currentVehicleId = '';
  String _currentLicensePlateNumber = '';

  String get currentVehicleId => _currentVehicleId;
  String get currentLicensePlateNumber => _currentLicensePlateNumber;

  // Simulation variables
  Timer? _simulationTimer;
  List<List<int>> _pointIndices = [];
  List<int> _currentPointIndices = [];
  final double _simulationInterval = 1000; // milliseconds - Consistent 1Hz updates for smooth interpolation
  double _currentSimulationSpeed = 1.0; // Lưu tốc độ simulation hiện tại
  bool _isSimulating = false;
  
  // Interpolation variables for smooth animation
  LatLng? _startPoint;
  LatLng? _endPoint;
  double _interpolationProgress = 0.0; // 0.0 to 1.0
  final int _interpolationSteps = 10; // Number of steps between route points

  // Error handling
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // State management
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> getOrderDetails(String orderId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _getOrderDetailsUseCase(orderId);
      result.fold(
        (failure) {
          _errorMessage = failure.message;
          orderWithDetails = null;
        },
        (order) {
          orderWithDetails = order;
          _errorMessage = '';
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      orderWithDetails = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void parseRouteFromOrder(OrderWithDetails order) {
    try {
      routeSegments = [];
      _pointIndices = [];
      currentSegmentIndex = 0;

      // Extract vehicle ID and license plate number
      if (order.orderDetails.isNotEmpty &&
          order.orderDetails.first.vehicleAssignment != null &&
          order.orderDetails.first.vehicleAssignment!.vehicle != null) {
        _currentVehicleId =
            order.orderDetails.first.vehicleAssignment!.vehicle!.id ?? '';
        _currentLicensePlateNumber = order
            .orderDetails
            .first
            .vehicleAssignment!
            .vehicle!
            .licensePlateNumber;
      }

      // Parse route data from order
      if (order.orderDetails.isEmpty ||
          order.orderDetails.first.vehicleAssignment == null ||
          order
              .orderDetails
              .first
              .vehicleAssignment!
              .journeyHistories
              .isEmpty) {
        debugPrint('❌ Không có dữ liệu journeyHistories');
        return;
      }

      final journeyHistory =
          order.orderDetails.first.vehicleAssignment!.journeyHistories.first;
      final segments = journeyHistory.journeySegments;

      if (segments.isEmpty) {
        debugPrint('❌ Không có dữ liệu journeySegments');
        return;
      }

      // Clear waypoints
      List<LatLng> waypoints = [];
      List<String> waypointNames = [];

      bool hasValidRoute = false;

      for (final segment in segments) {
        // Translate point names to Vietnamese
        final startName = _translatePointName(segment.startPointName);
        final endName = _translatePointName(segment.endPointName);
        final name = '$startName → $endName';
        final points = <LatLng>[];
        final indices = <int>[];

        // Parse route points from JSON if available
        try {
          if (segment.pathCoordinatesJson.isNotEmpty) {
            // Parse JSON string to get coordinates
            final List<dynamic> coordinates = json.decode(
              segment.pathCoordinatesJson,
            );

            // Add all points from the path
            int index = 0;
            for (var coordinate in coordinates) {
              if (coordinate is List && coordinate.length >= 2) {
                // Coordinates in format [longitude, latitude]
                final double lng = coordinate[0].toDouble();
                final double lat = coordinate[1].toDouble();
                points.add(LatLng(lat, lng));
                indices.add(index++);
              }
            }

            // Add waypoints
            if (points.isNotEmpty) {
              // Add start point to waypoints if this is the first segment
              if (waypoints.isEmpty) {
                waypoints.add(points.first);
                waypointNames.add(segment.startPointName);
              }

              // Add end point to waypoints
              waypoints.add(points.last);
              waypointNames.add(segment.endPointName);

              hasValidRoute = true;
            }
          } else {
            // If no path coordinates, just use start and end points
            points.add(LatLng(segment.startLatitude, segment.startLongitude));
            indices.add(0);

            points.add(LatLng(segment.endLatitude, segment.endLongitude));
            indices.add(1);

            // Add waypoints
            if (waypoints.isEmpty) {
              waypoints.add(
                LatLng(segment.startLatitude, segment.startLongitude),
              );
              waypointNames.add(segment.startPointName);
            }
            waypoints.add(LatLng(segment.endLatitude, segment.endLongitude));
            waypointNames.add(segment.endPointName);

            hasValidRoute = true;
          }
        } catch (e) {
          debugPrint('❌ Lỗi khi parse tọa độ segment: $e');
          // Fallback to start and end points
          points.add(LatLng(segment.startLatitude, segment.startLongitude));
          indices.add(0);

          points.add(LatLng(segment.endLatitude, segment.endLongitude));
          indices.add(1);

          // Add waypoints
          if (waypoints.isEmpty) {
            waypoints.add(
              LatLng(segment.startLatitude, segment.startLongitude),
            );
            waypointNames.add(segment.startPointName);
          }
          waypoints.add(LatLng(segment.endLatitude, segment.endLongitude));
          waypointNames.add(segment.endPointName);

          hasValidRoute = true;
        }

        if (points.isNotEmpty) {
          routeSegments.add(RouteSegment(name: name, points: points));
          _pointIndices.add(indices);
        }
      }

      // Set initial location to first point of first segment
      if (routeSegments.isNotEmpty && routeSegments[0].points.isNotEmpty) {
        currentLocation = routeSegments[0].points.first;
        currentBearing = 0;
        _currentPointIndices = [0];
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Lỗi khi parse route: $e');
    }
  }

  // NOTE: useSampleRouteData() method removed - no longer needed
  // All route data now comes from backend API via parseRouteFromOrder()

  void startSimulation({
    required Function(LatLng, double?) onLocationUpdate,
    required Function(int, bool) onSegmentComplete,
    double simulationSpeed = 1.0,
  }) {
    debugPrint('🎬 NavigationViewModel.startSimulation called');
    debugPrint('   - routeSegments.length: ${routeSegments.length}');
    debugPrint('   - _isSimulating: $_isSimulating');

    if (routeSegments.isEmpty) {
      debugPrint('❌ Cannot start simulation: no route segments');
      return;
    }

    if (_isSimulating) {
      debugPrint('⚠️ Simulation already running');
      return;
    }

    _isSimulating = true;
    _currentSimulationSpeed = simulationSpeed; // Lưu tốc độ simulation
    debugPrint('✅ Simulation state set to true');

    // Lưu trữ callback để có thể sử dụng lại khi resume
    _locationUpdateCallback = onLocationUpdate;
    _segmentCompleteCallback = onSegmentComplete;

    // Set initial location and bearing
    if (routeSegments.isNotEmpty && routeSegments[0].points.isNotEmpty) {
      currentSegmentIndex = 0;
      // Initialize point indices for all segments
      _currentPointIndices = List.generate(routeSegments.length, (_) => 0);
      currentLocation = routeSegments[0].points.first;

      // Calculate initial bearing and speed if we have at least 2 points
      if (routeSegments[0].points.length > 1) {
        final nextPoint = routeSegments[0].points[1];
        currentBearing = _calculateBearing(currentLocation!, nextPoint);
        
        // Calculate initial speed based on first segment
        final distance = _calculateDistance(currentLocation!, nextPoint);
        final totalTimeInSeconds = (_simulationInterval * _interpolationSteps / simulationSpeed) / 1000.0;
        currentSpeed = (distance / totalTimeInSeconds) * 3.6;
        debugPrint('🚗 Initial speed calculated: ${currentSpeed.toStringAsFixed(1)} km/h');
      } else {
        currentBearing = 0;
        currentSpeed = 0.0;
      }

      // Notify immediately with initial position
      onLocationUpdate(currentLocation!, currentBearing);
    }

    // Calculate base interval based on simulation speed
    final baseInterval = _simulationInterval;
    final interval = (baseInterval / simulationSpeed).round();

    debugPrint(
      '⏱️ Starting timer with interval: ${interval}ms (speed: ${simulationSpeed}x)',
    );

    // Start simulation timer
    _simulationTimer = Timer.periodic(Duration(milliseconds: interval), (
      timer,
    ) {
      _updateLocation(onLocationUpdate, onSegmentComplete);
    });

    debugPrint('✅ Timer started successfully');
    notifyListeners();
  }

  void _updateLocation(
    Function(LatLng, double?) onLocationUpdate,
    Function(int, bool) onSegmentComplete,
  ) {
    if (routeSegments.isEmpty || currentSegmentIndex >= routeSegments.length) {
      _simulationTimer?.cancel();
      _isSimulating = false;
      notifyListeners();
      return;
    }

    final currentSegment = routeSegments[currentSegmentIndex];
    final points = currentSegment.points;

    if (points.isEmpty) {
      _moveToNextSegment(onSegmentComplete);
      return;
    }

    // Get current point index
    final currentPointIndex = _currentPointIndices[currentSegmentIndex];

    // If we've reached the end of this segment
    if (currentPointIndex >= points.length - 1) {
      _moveToNextSegment(onSegmentComplete);
      return;
    }

    // Get current and next route points
    final currentRoutePoint = points[currentPointIndex];
    final nextRoutePoint = points[currentPointIndex + 1];

    // Initialize interpolation if starting new segment
    if (_startPoint == null || _endPoint == null || 
        _startPoint != currentRoutePoint || _endPoint != nextRoutePoint) {
      _startPoint = currentRoutePoint;
      _endPoint = nextRoutePoint;
      _interpolationProgress = 0.0;
      
      // Calculate bearing between route points
      currentBearing = _calculateBearing(_startPoint!, _endPoint!);
      
      // Calculate speed based on segment distance and total time to traverse it
      // Total time = _simulationInterval * _interpolationSteps / _currentSimulationSpeed
      final segmentDistance = _calculateDistance(_startPoint!, _endPoint!);
      final totalTimeInSeconds = (_simulationInterval * _interpolationSteps / _currentSimulationSpeed) / 1000.0;
      currentSpeed = (segmentDistance / totalTimeInSeconds) * 3.6; // km/h
    }

    // Interpolate between start and end points
    final lat = _startPoint!.latitude + 
        (_endPoint!.latitude - _startPoint!.latitude) * _interpolationProgress;
    final lng = _startPoint!.longitude + 
        (_endPoint!.longitude - _startPoint!.longitude) * _interpolationProgress;
    
    currentLocation = LatLng(lat, lng);
    
    // Advance interpolation
    _interpolationProgress += 1.0 / _interpolationSteps;
    
    // If interpolation complete, move to next route point
    if (_interpolationProgress >= 1.0) {
      _currentPointIndices[currentSegmentIndex]++;
      _startPoint = null; // Reset for next segment
      _endPoint = null;
    }

    // Notify listeners with interpolated location
    onLocationUpdate(currentLocation!, currentBearing);
    notifyListeners();
  }

  void _moveToNextSegment(Function(int, bool) onSegmentComplete) {
    // Notify that current segment is complete
    final isLastSegment = currentSegmentIndex >= routeSegments.length - 1;
    onSegmentComplete(currentSegmentIndex, isLastSegment);

    // Move to next segment if available
    if (!isLastSegment) {
      currentSegmentIndex++;
      if (_currentPointIndices.length <= currentSegmentIndex) {
        _currentPointIndices.add(0);
      } else {
        _currentPointIndices[currentSegmentIndex] = 0;
      }

      // Set location to first point of new segment
      final newSegment = routeSegments[currentSegmentIndex];
      if (newSegment.points.isNotEmpty) {
        currentLocation = newSegment.points.first;
      }
    } else {
      // End of simulation
      _simulationTimer?.cancel();
      _isSimulating = false;
      currentSpeed = 0.0; // Reset tốc độ khi kết thúc
    }

    notifyListeners();
  }

  void pauseSimulation() {
    debugPrint('⏸️ NavigationViewModel.pauseSimulation called');
    debugPrint(
      '   - Timer before cancel: ${_simulationTimer != null ? "active" : "null"}',
    );

    _simulationTimer?.cancel();
    _simulationTimer = null; // ✅ IMPORTANT: Set to null after cancel
    currentSpeed = 0.0; // Reset tốc độ khi pause

    debugPrint('✅ Timer cancelled and set to null');
    notifyListeners();
  }

  void resumeSimulation() {
    debugPrint('▶️ NavigationViewModel.resumeSimulation called');
    debugPrint('   - _isSimulating: $_isSimulating');
    debugPrint(
      '   - _simulationTimer: ${_simulationTimer != null ? "active" : "null"}',
    );

    if (_isSimulating && _simulationTimer == null) {
      debugPrint('✅ Resuming simulation timer...');
      
      // Recalculate speed based on current position
      if (currentLocation != null && 
          currentSegmentIndex < routeSegments.length &&
          routeSegments[currentSegmentIndex].points.isNotEmpty) {
        final currentSegment = routeSegments[currentSegmentIndex];
        final currentPointIndex = _currentPointIndices[currentSegmentIndex];
        
        if (currentPointIndex < currentSegment.points.length - 1) {
          final nextPoint = currentSegment.points[currentPointIndex + 1];
          final distance = _calculateDistance(currentLocation!, nextPoint);
          final totalTimeInSeconds = (_simulationInterval * _interpolationSteps / _currentSimulationSpeed) / 1000.0;
          currentSpeed = (distance / totalTimeInSeconds) * 3.6;
          debugPrint('🚗 Speed recalculated on resume: ${currentSpeed.toStringAsFixed(1)} km/h');
        }
      }
      
      final interval = (_simulationInterval / _currentSimulationSpeed).round();
      _simulationTimer = Timer.periodic(
        Duration(milliseconds: interval),
        (timer) {
          if (_locationUpdateCallback != null &&
              _segmentCompleteCallback != null) {
            _updateLocation(
              _locationUpdateCallback!,
              _segmentCompleteCallback!,
            );
          }
        },
      );
      debugPrint('✅ Simulation timer resumed with interval: ${interval}ms');
      notifyListeners();
    } else {
      debugPrint(
        '⚠️ Cannot resume: _isSimulating=$_isSimulating, timer=${_simulationTimer != null}',
      );
    }
  }

  // Lưu trữ callback để có thể sử dụng lại khi resume
  Function(LatLng, double?)? _locationUpdateCallback;
  Function(int, bool)? _segmentCompleteCallback;

  void updateSimulationSpeed(double speed) {
    _currentSimulationSpeed = speed; // Cập nhật tốc độ simulation
    
    if (_simulationTimer != null) {
      _simulationTimer!.cancel();

      final interval = (_simulationInterval / speed).round();
      _simulationTimer = Timer.periodic(Duration(milliseconds: interval), (
        timer,
      ) {
        if (_locationUpdateCallback != null &&
            _segmentCompleteCallback != null) {
          _updateLocation(_locationUpdateCallback!, _segmentCompleteCallback!);
        }
      });
    }
  }

  void resetNavigation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isSimulating = false;
    _currentSimulationSpeed = 1.0; // Reset về default

    routeSegments = [];
    _pointIndices = [];
    currentSegmentIndex = 0;
    _currentPointIndices = [];
    
    // Reset interpolation variables
    _startPoint = null;
    _endPoint = null;
    _interpolationProgress = 0.0;

    currentLocation = null;
    currentBearing = null;
    currentSpeed = 0.0;

    _currentVehicleId = '';
    _currentLicensePlateNumber = '';

    notifyListeners();
  }

  String getCurrentSegmentName() {
    if (routeSegments.isEmpty || currentSegmentIndex >= routeSegments.length) {
      return 'Không có dữ liệu';
    }
    return routeSegments[currentSegmentIndex].name;
  }

  // Getter to check if simulation is running
  bool get isSimulating => _isSimulating;

  // Helper method to translate point names to Vietnamese
  String _translatePointName(String name) {
    // Common translations
    final translations = {
      'Carrier': 'Kho vận chuyển',
      'Pickup': 'Điểm lấy hàng',
      'Delivery': 'Điểm giao hàng',
      'Warehouse': 'Kho',
      'Origin': 'Điểm đi',
      'Destination': 'Điểm đến',
    };

    // Return translated name if exists, otherwise return original
    return translations[name] ?? name;
  }

  // Helper methods
  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * pi / 180;
    final startLng = start.longitude * pi / 180;
    final endLat = end.latitude * pi / 180;
    final endLng = end.longitude * pi / 180;

    final dLng = endLng - startLng;

    final y = sin(dLng) * cos(endLat);
    final x =
        cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng);

    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const earthRadius = 6371000; // meters

    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLat = (end.latitude - start.latitude) * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // distance in meters
  }
}
