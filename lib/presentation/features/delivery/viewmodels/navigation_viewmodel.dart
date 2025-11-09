import 'dart:async';
import 'dart:math';
import 'dart:convert'; // Added for json.decode
import 'package:flutter/foundation.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/entities/order_detail.dart';
import '../../../../domain/entities/order_detail_status.dart';
import '../../../../domain/usecases/orders/get_order_details_usecase.dart';
import '../../../../domain/usecases/orders/update_order_to_ongoing_delivered_usecase.dart';
import '../../../../domain/usecases/orders/update_order_to_delivered_usecase.dart';
import '../../../../domain/usecases/orders/update_order_to_successful_usecase.dart';
import '../../../../domain/usecases/orders/update_order_detail_status_usecase.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class RouteSegment {
  final String name;
  final List<LatLng> points;

  RouteSegment({required this.name, required this.points});
}

class NavigationViewModel extends ChangeNotifier {
  final GetOrderDetailsUseCase _getOrderDetailsUseCase =
      getIt<GetOrderDetailsUseCase>();
  final UpdateOrderToOngoingDeliveredUseCase _updateToOngoingDeliveredUseCase =
      getIt<UpdateOrderToOngoingDeliveredUseCase>();
  final UpdateOrderToSuccessfulUseCase _updateToSuccessfulUseCase =
      getIt<UpdateOrderToSuccessfulUseCase>();
  final UpdateOrderDetailStatusUseCase _updateOrderDetailStatusUseCase =
      getIt<UpdateOrderDetailStatusUseCase>();
  final AuthViewModel _authViewModel = getIt<AuthViewModel>();

  OrderWithDetails? orderWithDetails;
  List<RouteSegment> routeSegments = [];
  int currentSegmentIndex = 0;

  LatLng? currentLocation;
  double? currentBearing;
  double currentSpeed = 0.0;

  String _currentVehicleId = '';
  String _currentLicensePlateNumber = '';
  String? _vehicleAssignmentId; // NEW: Store vehicle assignment ID

  String get currentVehicleId => _currentVehicleId;
  String get currentLicensePlateNumber => _currentLicensePlateNumber;
  String? get vehicleAssignmentId => _vehicleAssignmentId; // NEW: Getter

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

  /// Get current user's vehicle assignment (for multi-trip orders)
  VehicleAssignment? _getCurrentUserVehicleAssignment(OrderWithDetails order) {
    if (order.vehicleAssignments.isEmpty) {
      debugPrint('❌ No vehicle assignments in order');
      return null;
    }

    // Get current user phone number
    debugPrint('🔍 _authViewModel.driver: ${_authViewModel.driver}');
    debugPrint('🔍 _authViewModel.driver?.userResponse: ${_authViewModel.driver?.userResponse}');
    final currentUserPhone = _authViewModel.driver?.userResponse.phoneNumber;
    debugPrint('🔍 currentUserPhone: $currentUserPhone');
    if (currentUserPhone == null || currentUserPhone.isEmpty) {
      debugPrint('❌ Could not get current user phone number');
      return null;
    }

    debugPrint('🔍 Looking for vehicle assignment for phone: $currentUserPhone');
    debugPrint('   Total vehicle assignments: ${order.vehicleAssignments.length}');

    // Find vehicle assignment where current user is primary driver
    try {
      final result = order.vehicleAssignments.firstWhere(
        (va) {
          if (va.primaryDriver == null) {
            debugPrint('   - VA ${va.id}: no primary driver');
            return false;
          }
          final match = currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
          debugPrint('   - VA ${va.id}: primary=${va.primaryDriver!.phoneNumber}, match=$match');
          return match;
        },
      );
      debugPrint('✅ Found vehicle assignment: ${result.id}');
      return result;
    } catch (e) {
      debugPrint('❌ Could not find vehicle assignment for current user: $e');
      // Fallback to first vehicle assignment if not found
      if (order.vehicleAssignments.isNotEmpty) {
        debugPrint('⚠️ Using fallback: first vehicle assignment');
        return order.vehicleAssignments.first;
      }
      return null;
    }
  }

  void parseRouteFromOrder(OrderWithDetails order) {
    debugPrint('🔄 parseRouteFromOrder called');
    debugPrint('   - orderDetails.length: ${order.orderDetails.length}');
    debugPrint('   - vehicleAssignments.length: ${order.vehicleAssignments.length}');
    
    try {
      routeSegments = [];
      _pointIndices = [];
      currentSegmentIndex = 0;

      // Parse route data from order
      if (order.orderDetails.isEmpty || order.vehicleAssignments.isEmpty) {
        debugPrint('❌ Không có dữ liệu order');
        return;
      }

      // Get current user's vehicle assignment (for multi-trip orders) - ONLY ONCE
      final vehicleAssignment = _getCurrentUserVehicleAssignment(order);
      if (vehicleAssignment == null) {
        debugPrint('❌ Không có vehicle assignment cho driver hiện tại');
        return;
      }

      // Store vehicle assignment ID and vehicle info
      _vehicleAssignmentId = vehicleAssignment.id;
      debugPrint('📌 Stored vehicle assignment ID: $_vehicleAssignmentId');
      
      if (vehicleAssignment.vehicle != null) {
        _currentVehicleId = vehicleAssignment.vehicle!.id ?? '';
        _currentLicensePlateNumber = vehicleAssignment.vehicle!.licensePlateNumber;
        debugPrint('📌 Vehicle: $_currentLicensePlateNumber (ID: $_currentVehicleId)');
      }

      if (vehicleAssignment.journeyHistories.isEmpty) {
        debugPrint('❌ Không có dữ liệu journeyHistories');
        return;
      }

      // Select the active journey (prefer ACTIVE status, fallback to first)
      JourneyHistory journeyHistory;
      try {
        journeyHistory = vehicleAssignment.journeyHistories.firstWhere(
          (j) => j.status == 'ACTIVE',
        );
      } catch (e) {
        journeyHistory = vehicleAssignment.journeyHistories.first;
      }
      final segments = journeyHistory.journeySegments;

      if (segments.isEmpty) {
        debugPrint('❌ Không có dữ liệu journeySegments');
        return;
      }

      debugPrint('✅ Found ${segments.length} journey segments to parse');

      // Clear waypoints
      List<LatLng> waypoints = [];
      List<String> waypointNames = [];

      bool hasValidRoute = false;

      for (final segment in segments) {
        debugPrint('📍 Parsing segment: ${segment.startPointName} → ${segment.endPointName}');
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
        _currentPointIndices = List.generate(routeSegments.length, (_) => 0);
        debugPrint('✅ Route parsed successfully: ${routeSegments.length} segments');
        debugPrint('   - Initial location: ${currentLocation!.latitude}, ${currentLocation!.longitude}');
        debugPrint('   - First segment has ${routeSegments[0].points.length} points');
      } else {
        debugPrint('❌ Route segments empty or no points in first segment');
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
    debugPrint('   - currentLocation: $currentLocation');
    debugPrint('   - currentSegmentIndex: $currentSegmentIndex');
    
    if (routeSegments.isNotEmpty) {
      debugPrint('   - routeSegments[0].points.length: ${routeSegments[0].points.length}');
      if (routeSegments[0].points.isNotEmpty) {
        debugPrint('   - First point: ${routeSegments[0].points.first}');
      }
    }

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

    // Set initial location and bearing ONLY if not already restored
    if (currentLocation == null && routeSegments.isNotEmpty && routeSegments[0].points.isNotEmpty) {
      debugPrint('📍 No restored position - starting from beginning');
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
    } else if (currentLocation != null) {
      debugPrint('📍 Using restored position - continuing from segment $currentSegmentIndex');
      // Position already restored, just ensure point indices are initialized
      if (_currentPointIndices.isEmpty) {
        _currentPointIndices = List.generate(routeSegments.length, (_) => 0);
      }
    }

    // Notify immediately with current position (restored or initial)
    if (currentLocation != null) {
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

  Future<void> _updateLocation(
    Function(LatLng, double?) onLocationUpdate,
    Function(int, bool) onSegmentComplete,
  ) async {
    if (routeSegments.isEmpty || currentSegmentIndex >= routeSegments.length) {
      _simulationTimer?.cancel();
      _isSimulating = false;
      notifyListeners();
      return;
    }

    final currentSegment = routeSegments[currentSegmentIndex];
    final points = currentSegment.points;

    if (points.isEmpty) {
      await _moveToNextSegment(onSegmentComplete);
      return;
    }

    // Get current point index
    final currentPointIndex = _currentPointIndices[currentSegmentIndex];

    // If we've reached PAST the end of this segment (no more points to interpolate to)
    // Note: points.length - 1 is the last point index
    // We need currentPointIndex + 1 to exist for interpolation
    if (currentPointIndex >= points.length) {
      debugPrint('🏁 Reached PAST end of segment $currentSegmentIndex');
      debugPrint('   - currentPointIndex: $currentPointIndex, points.length: ${points.length}');
      debugPrint('   - Calling _moveToNextSegment()');
      await _moveToNextSegment(onSegmentComplete);
      return;
    }
    
    // Special case: if at last point, set location and complete segment
    if (currentPointIndex == points.length - 1) {
      debugPrint('🎯 At LAST point of segment $currentSegmentIndex');
      debugPrint('   - currentPointIndex: $currentPointIndex, points.length: ${points.length}');
      currentLocation = points[currentPointIndex];
      currentSpeed = 0.0; // Stop at waypoint
      debugPrint('   - Location: ${currentLocation!.latitude}, ${currentLocation!.longitude}');
      debugPrint('   - Calling _moveToNextSegment()');
      await _moveToNextSegment(onSegmentComplete);
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

  Future<void> _moveToNextSegment(Function(int, bool) onSegmentComplete) async {
    debugPrint('📍 _moveToNextSegment() called');
    debugPrint('   - currentSegmentIndex: $currentSegmentIndex');
    debugPrint('   - routeSegments.length: ${routeSegments.length}');
    
    // Notify that current segment is complete
    final isLastSegment = currentSegmentIndex >= routeSegments.length - 1;
    debugPrint('   - isLastSegment: $isLastSegment');
    
    // Note: Order status update is now handled by backend when photo is uploaded
    // No need to update status here anymore
    
    debugPrint('   - Calling onSegmentComplete($currentSegmentIndex, $isLastSegment)');
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

  // Manually move to next segment (for after action confirmation)
  void moveToNextSegmentManually() {
    debugPrint('⏭️ Manually moving to next segment...');
    debugPrint('   - Current segment: $currentSegmentIndex');
    
    final isLastSegment = currentSegmentIndex >= routeSegments.length - 1;
    if (isLastSegment) {
      debugPrint('⚠️ Already at last segment, cannot move forward');
      return;
    }
    
    // Move to next segment
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
      debugPrint('✅ Moved to segment $currentSegmentIndex');
      debugPrint('   - New location: ${currentLocation!.latitude}, ${currentLocation!.longitude}');
    }
    
    // Reset interpolation
    _startPoint = null;
    _endPoint = null;
    _interpolationProgress = 0.0;
    
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
    debugPrint('   - currentLocation: $currentLocation');
    debugPrint('   - currentSegmentIndex: $currentSegmentIndex');
    debugPrint('   - _locationUpdateCallback: ${_locationUpdateCallback != null ? "SET" : "NULL"}');
    debugPrint('   - _segmentCompleteCallback: ${_segmentCompleteCallback != null ? "SET" : "NULL"}');

    if (_isSimulating && _simulationTimer == null) {
      debugPrint('✅ Resuming simulation timer...');
      
      // CRITICAL: Check if callbacks are set
      if (_locationUpdateCallback == null || _segmentCompleteCallback == null) {
        debugPrint('❌ ERROR: Callbacks are NULL! Cannot resume simulation properly.');
        debugPrint('   This means NavigationScreen was recreated and callbacks were lost.');
        debugPrint('   Need to call startSimulation() instead of resumeSimulation().');
        return;
      }
      
      // CRITICAL: Check if we're at the end of a segment (just completed an action)
      // If so, move to next segment before resuming
      if (currentLocation != null && 
          currentSegmentIndex < routeSegments.length &&
          routeSegments[currentSegmentIndex].points.isNotEmpty) {
        final currentSegment = routeSegments[currentSegmentIndex];
        final lastPoint = currentSegment.points.last;
        
        // Check if current location is at the end of segment (within 10 meters)
        final distanceToEnd = _calculateDistance(currentLocation!, lastPoint);
        if (distanceToEnd < 10) {
          debugPrint('📍 At end of segment $currentSegmentIndex, moving to next segment');
          
          // Move to next segment
          if (currentSegmentIndex < routeSegments.length - 1) {
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
              debugPrint('✅ Moved to segment $currentSegmentIndex');
              debugPrint('   - New location: ${currentLocation!.latitude}, ${currentLocation!.longitude}');
            }
            
            // Reset interpolation
            _startPoint = null;
            _endPoint = null;
            _interpolationProgress = 0.0;
          }
        }
      }
      
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
  
  // Simulation state getter for persistence
  Map<String, dynamic> getSimulationState() {
    return {
      'isSimulating': _isSimulating,
      'currentSegmentIndex': currentSegmentIndex,
      'currentLocation': currentLocation != null ? {
        'latitude': currentLocation!.latitude,
        'longitude': currentLocation!.longitude,
      } : null,
      'currentBearing': currentBearing,
      'currentSpeed': currentSpeed,
      'simulationSpeed': _currentSimulationSpeed,
    };
  }

  void updateSimulationSpeed(double speed) {
    _currentSimulationSpeed = speed; // Cập nhật tốc độ simulation
    debugPrint('🎚️ Updating simulation speed to ${speed}x');
    
    if (_simulationTimer != null && _isSimulating) {
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
      debugPrint('✅ Simulation speed updated, new interval: ${interval}ms');
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

  // Getter for current simulation speed
  double get currentSimulationSpeed => _currentSimulationSpeed;

  /// Reset simulation flag to allow restarting simulation
  /// Used when NavigationScreen is recreated and needs to restart simulation with new callbacks
  void resetSimulationFlag() {
    debugPrint('🔄 Resetting _isSimulating flag to false');
    _isSimulating = false;
    notifyListeners();
  }

  /// Restore simulation position from saved state
  void restoreSimulationPosition({
    required int segmentIndex,
    required double latitude,
    required double longitude,
    double? bearing,
  }) {
    debugPrint('🔄 Restoring simulation position:');
    debugPrint('   - Segment index: $segmentIndex');
    debugPrint('   - Position: ($latitude, $longitude)');
    debugPrint('   - Bearing: $bearing');
    
    if (routeSegments.isEmpty) {
      debugPrint('❌ Cannot restore: no route segments');
      return;
    }
    
    if (segmentIndex >= routeSegments.length) {
      debugPrint('❌ Cannot restore: invalid segment index');
      return;
    }
    
    // Set current segment
    currentSegmentIndex = segmentIndex;
    
    // Find closest point in the segment to the saved position
    final segment = routeSegments[segmentIndex];
    int closestPointIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < segment.points.length; i++) {
      final point = segment.points[i];
      final distance = _calculateDistance(
        LatLng(latitude, longitude),
        point,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }
    
    debugPrint('   - Closest point index: $closestPointIndex');
    debugPrint('   - Distance to closest point: ${minDistance.toStringAsFixed(2)}m');
    
    // Initialize point indices if not already done
    if (_currentPointIndices.isEmpty) {
      _currentPointIndices = List.generate(routeSegments.length, (_) => 0);
    }
    
    // Set current point index for this segment
    _currentPointIndices[segmentIndex] = closestPointIndex;
    
    // Use exact saved location for better continuity
    currentLocation = LatLng(latitude, longitude);
    
    // Use saved bearing if available
    if (bearing != null) {
      currentBearing = bearing;
    } else if (closestPointIndex < segment.points.length - 1) {
      // Calculate bearing to next point
      final nextPoint = segment.points[closestPointIndex + 1];
      currentBearing = _calculateBearing(currentLocation!, nextPoint);
    } else {
      currentBearing = 0;
    }
    
    // Set up interpolation for smooth continuation
    if (closestPointIndex < segment.points.length - 1) {
      _startPoint = currentLocation;
      _endPoint = segment.points[closestPointIndex + 1];
      _interpolationProgress = 0.0;
    }
    
    debugPrint('✅ Position restored successfully');
    debugPrint('   - Current location: ${currentLocation!.latitude}, ${currentLocation!.longitude}');
    debugPrint('   - Current bearing: $currentBearing');
    notifyListeners();
  }

  // Jump to end of current segment (skip to destination of current route)
  Future<void> jumpToNextSegment() async {
    if (routeSegments.isEmpty) {
      debugPrint('⚠️ Cannot jump: no segments');
      return;
    }

    if (currentSegmentIndex >= routeSegments.length) {
      debugPrint('⚠️ Cannot jump: invalid segment index');
      return;
    }

    debugPrint('⏩ Skipping to end of current segment...');
    debugPrint('   - Current segment: $currentSegmentIndex');
    
    final currentSegment = routeSegments[currentSegmentIndex];
    
    // Jump to END of current segment only
    if (currentSegment.points.isNotEmpty) {
      currentLocation = currentSegment.points.last;
      currentSpeed = 0.0; // Stop at waypoint
      
      // CRITICAL: Update order status when jumping to delivery point (segment 1)
      // This ensures user can see the delivery confirmation button in OrderDetailScreen
      if (currentSegmentIndex == 1 && orderWithDetails != null) {
        debugPrint('🎯 Jumped to delivery point! Auto-updating order status to ONGOING_DELIVERED...');
        // Note: This will be called from NavigationScreen context to trigger OrderDetailViewModel
        // For now, just log - the actual update happens in NavigationScreen._jumpToNextSegment()
      }
      
      // Calculate bearing to next segment if available
      if (currentSegmentIndex + 1 < routeSegments.length) {
        final nextSegment = routeSegments[currentSegmentIndex + 1];
        if (nextSegment.points.isNotEmpty) {
          currentBearing = _calculateBearing(currentLocation!, nextSegment.points.first);
        }
      } else {
        currentBearing = 0.0;
      }
      
      // Update point index to last point
      // The next simulation tick will detect this and trigger completion
      final lastPointIndex = currentSegment.points.length - 1;
      
      // Ensure array has enough elements
      while (_currentPointIndices.length <= currentSegmentIndex) {
        _currentPointIndices.add(0);
      }
      _currentPointIndices[currentSegmentIndex] = lastPointIndex;
      
      debugPrint('✅ Skipped to END of segment $currentSegmentIndex');
      debugPrint('   - Location: ${currentLocation!.latitude}, ${currentLocation!.longitude}');
      debugPrint('   - Set currentPointIndex to: $lastPointIndex');
      debugPrint('   - Next tick will detect end and trigger completion');
    }
    
    // Reset interpolation to force re-check on next tick
    _startPoint = null;
    _endPoint = null;
    _interpolationProgress = 0.0;
    
    // CRITICAL: Ensure simulation is running to detect completion
    debugPrint('🔍 Checking simulation state after jump:');
    debugPrint('   - _isSimulating: $_isSimulating');
    debugPrint('   - _simulationTimer?.isActive: ${_simulationTimer?.isActive}');
    
    if (!_isSimulating || _simulationTimer?.isActive != true) {
      debugPrint('⚠️ WARNING: Simulation not running after jump!');
      debugPrint('   - This will prevent automatic detection of segment completion');
      debugPrint('   - Make sure simulation is started before jumping');
    }
    
    notifyListeners();
  }

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

  /// Update OrderDetail status to ONGOING_DELIVERED when reaching delivery point
  /// NEW: Uses vehicle assignment ID for multi-trip support
  Future<void> updateToOngoingDelivered() async {
    if (_vehicleAssignmentId == null) {
      debugPrint('❌ Cannot update status: no vehicle assignment ID');
      return;
    }

    debugPrint('🎯 Updating OrderDetail status to ONGOING_DELIVERED...');
    debugPrint('   - Vehicle Assignment ID: $_vehicleAssignmentId');
    
    final result = await _updateOrderDetailStatusUseCase(
      assignmentId: _vehicleAssignmentId!,
      status: OrderDetailStatus.ongoingDelivered,
    );
    
    result.fold(
      (failure) {
        debugPrint('❌ Failed to update OrderDetail status: ${failure.message}');
      },
      (success) {
        debugPrint('✅ Successfully updated OrderDetail status to ONGOING_DELIVERED');
      },
    );
  }

  /// Complete trip - update order status to SUCCESSFUL
  /// Called when driver confirms delivery completion
  Future<bool> completeTrip() async {
    if (orderWithDetails == null) {
      debugPrint('❌ Cannot complete trip: no order details');
      return false;
    }
    
    debugPrint('🏁 Completing trip for order ${orderWithDetails!.id}...');
    final result = await _updateToSuccessfulUseCase(orderWithDetails!.id);
    
    return result.fold(
      (failure) {
        debugPrint('❌ Failed to complete trip: ${failure.message}');
        return false;
      },
      (success) {
        debugPrint('✅ Successfully completed trip - order status updated to SUCCESSFUL');
        return true;
      },
    );
  }
}
