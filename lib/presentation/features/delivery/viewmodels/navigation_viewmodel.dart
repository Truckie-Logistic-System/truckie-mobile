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
  String? currentJourneyType; // STANDARD, REROUTE, RETURN

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
  final int _interpolationSteps = 50; // High FPS for ultra-smooth movement (60fps optimized)
  
  // Bearing smoothing for natural rotation transitions
  double? _previousBearing;
  double? _targetBearing;
  static const double _bearingSmoothingFactor = 0.15; // Faster response, smoother rotation

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
      return null;
    }

    // Get current user phone number
    final currentUserPhone = _authViewModel.driver?.userResponse.phoneNumber;
    if (currentUserPhone == null || currentUserPhone.isEmpty) {
      return null;
    }
    // Find vehicle assignment where current user is primary driver
    try {
      final result = order.vehicleAssignments.firstWhere(
        (va) {
          if (va.primaryDriver == null) {
            return false;
          }
          final match = currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
          return match;
        },
      );
      return result;
    } catch (e) {
      // Fallback to first vehicle assignment if not found
      if (order.vehicleAssignments.isNotEmpty) {
        return order.vehicleAssignments.first;
      }
      return null;
    }
  }

  void parseRouteFromOrder(OrderWithDetails order) {
    try {
      routeSegments = [];
      _pointIndices = [];
      currentSegmentIndex = 0;

      // Parse route data from order
      if (order.orderDetails.isEmpty || order.vehicleAssignments.isEmpty) {
        _errorMessage = 'Đơn hàng không có thông tin chi tiết hoặc phương tiện';
        notifyListeners();
        return;
      }

      // Get current user's vehicle assignment (for multi-trip orders) - ONLY ONCE
      final vehicleAssignment = _getCurrentUserVehicleAssignment(order);
      if (vehicleAssignment == null) {
        _errorMessage = 'Không tìm thấy phân công xe cho tài xế này';
        notifyListeners();
        return;
      }

      // Store vehicle assignment ID and vehicle info
      _vehicleAssignmentId = vehicleAssignment.id;
      if (vehicleAssignment.vehicle != null) {
        _currentVehicleId = vehicleAssignment.vehicle!.id ?? '';
        _currentLicensePlateNumber = vehicleAssignment.vehicle!.licensePlateNumber;
        
      }

      if (vehicleAssignment.journeyHistories.isEmpty) {
        _errorMessage = 'Chuyến hàng chưa có lộ trình. Vui lòng liên hệ nhân viên kế hoạch.';
        notifyListeners();
        return;
      }

      // 🆕 Always use the LATEST ACTIVE journey history (sort by createdAt DESC)
      // Special handling for RETURN journeys: only use if ACTIVE (customer paid)
      final sortedJourneys = List<JourneyHistory>.from(vehicleAssignment.journeyHistories)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Find the latest journey that is usable
      JourneyHistory? journeyHistory;
      for (final journey in sortedJourneys) {
        // For RETURN journeys, only use if ACTIVE (customer paid)
        if (journey.journeyType == 'RETURN') {
          if (journey.status == 'ACTIVE') {
            journeyHistory = journey;
            break;
          } else {
            
            continue; // Skip INACTIVE return journey, check next one
          }
        } else {
          // For non-RETURN journeys, use regardless of status
          journeyHistory = journey;
          
          break;
        }
      }
      
      if (journeyHistory == null) {
        _errorMessage = 'Không tìm thấy hành trình khả dụng. Có thể chuyến trả hàng chưa được kích hoạt.';
        notifyListeners();
        return;
      }
      
      
      // Store journey type for later use
      currentJourneyType = journeyHistory.journeyType;
      final segments = journeyHistory.journeySegments;

      if (segments.isEmpty) {
        _errorMessage = 'Hành trình không có thông tin chặng đường. Vui lòng liên hệ nhân viên kế hoạch.';
        notifyListeners();
        return;
      }
      
      // 🚨 CRITICAL FIX: Sort segments by segmentOrder before parsing
      // Backend may return segments in wrong array order even if segmentOrder is correct
      // Example: REROUTE journey returns [segment3, segment2, segment1] instead of [segment1, segment2, segment3]
      final sortedSegments = List<JourneySegment>.from(segments)
        ..sort((a, b) => a.segmentOrder.compareTo(b.segmentOrder));
      
      print('📍 Parsing ${sortedSegments.length} segments (sorted by segmentOrder):');
      for (final seg in sortedSegments) {
        print('   Segment ${seg.segmentOrder}: ${seg.startPointName} → ${seg.endPointName}');
      }
      
      // Clear waypoints
      List<LatLng> waypoints = [];
      List<String> waypointNames = [];

      bool hasValidRoute = false;

      for (final segment in sortedSegments) {
        // Translate point names to Vietnamese
        final startName = _translatePointName(segment.startPointName);
        final endName = _translatePointName(segment.endPointName);
        final name = '$startName → $endName';
        final points = <LatLng>[];
        final indices = <int>[];

        // Parse route points from JSON if available
        try {
          if (segment.pathCoordinatesJson != null && segment.pathCoordinatesJson!.isNotEmpty) {
            // Parse JSON string to get coordinates
            final List<dynamic> coordinates = json.decode(
              segment.pathCoordinatesJson!,
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
                waypointNames.add(startName); // ✅ Use translated name
              }

              // Add end point to waypoints
              waypoints.add(points.last);
              waypointNames.add(endName); // ✅ Use translated name

              hasValidRoute = true;
            }
          } else if (segment.startLatitude != null && 
                     segment.startLongitude != null &&
                     segment.endLatitude != null && 
                     segment.endLongitude != null) {
            // If no path coordinates, just use start and end points (if available)
            points.add(LatLng(segment.startLatitude!, segment.startLongitude!));
            indices.add(0);

            points.add(LatLng(segment.endLatitude!, segment.endLongitude!));
            indices.add(1);

            // Add waypoints
            if (waypoints.isEmpty) {
              waypoints.add(
                LatLng(segment.startLatitude!, segment.startLongitude!),
              );
              waypointNames.add(startName); // ✅ Use translated name
            }
            waypoints.add(LatLng(segment.endLatitude!, segment.endLongitude!));
            waypointNames.add(endName); // ✅ Use translated name

            hasValidRoute = true;
          } else {
            // Skip segments with null coordinates (e.g., return journey placeholders)
          }
        } catch (e) {
          // Fallback to start and end points if available
          if (segment.startLatitude != null && 
              segment.startLongitude != null &&
              segment.endLatitude != null && 
              segment.endLongitude != null) {
            points.add(LatLng(segment.startLatitude!, segment.startLongitude!));
            indices.add(0);

            points.add(LatLng(segment.endLatitude!, segment.endLongitude!));
            indices.add(1);

            // Add waypoints
            if (waypoints.isEmpty) {
              waypoints.add(
                LatLng(segment.startLatitude!, segment.startLongitude!),
              );
              waypointNames.add(startName); // ✅ Use translated name
            }
            waypoints.add(LatLng(segment.endLatitude!, segment.endLongitude!));
            waypointNames.add(endName); // ✅ Use translated name

            hasValidRoute = true;
          }
        }

        if (points.isNotEmpty) {
          routeSegments.add(RouteSegment(name: name, points: points));
          _pointIndices.add(indices);
        }
      }

      // Set initial location to first point of first segment ONLY if not already set
      // This prevents resetting location when reloading route (e.g., after seal confirmation)
      if (currentLocation == null && routeSegments.isNotEmpty && routeSegments[0].points.isNotEmpty) {
        currentLocation = routeSegments[0].points.first;
        currentBearing = 0;
        print('📍 Initial location set to first point of first segment');
      }
      
      // Always ensure point indices are properly initialized
      if (_currentPointIndices.isEmpty || _currentPointIndices.length != routeSegments.length) {
        _currentPointIndices = List.generate(routeSegments.length, (_) => 0);
        print('📊 Point indices initialized for ${routeSegments.length} segments');
      }

      notifyListeners();
    } catch (e) {
    }
  }

  // NOTE: useSampleRouteData() method removed - no longer needed
  // All route data now comes from backend API via parseRouteFromOrder()

  void startSimulation({
    required Function(LatLng, double?) onLocationUpdate,
    required Function(int, bool) onSegmentComplete,
    double simulationSpeed = 1.0,
  }) {
    if (routeSegments.isNotEmpty) {
      if (routeSegments[0].points.isNotEmpty) {
      }
    }

    if (routeSegments.isEmpty) {
      return;
    }

    if (_isSimulating) {
      return;
    }

    _isSimulating = true;
    _currentSimulationSpeed = simulationSpeed; // Lưu tốc độ simulation
    // Lưu trữ callback để có thể sử dụng lại khi resume
    _locationUpdateCallback = onLocationUpdate;
    _segmentCompleteCallback = onSegmentComplete;

    // Set initial location and bearing ONLY if not already restored
    if (currentLocation == null && routeSegments.isNotEmpty && routeSegments[0].points.isNotEmpty) {
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
        
      } else {
        currentBearing = 0;
        currentSpeed = 0.0;
      }
    } else if (currentLocation != null) {
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

    

    // Start simulation timer
    _simulationTimer = Timer.periodic(Duration(milliseconds: interval), (
      timer,
    ) {
      _updateLocation(onLocationUpdate, onSegmentComplete);
    });
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
      
      await _moveToNextSegment(onSegmentComplete);
      return;
    }
    
    // Special case: if at last point, set location and complete segment
    if (currentPointIndex == points.length - 1) {
      currentLocation = points[currentPointIndex];
      currentSpeed = 0.0; // Stop at waypoint
      
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
      
      // Calculate target bearing for this segment
      _targetBearing = _calculateBearing(_startPoint!, _endPoint!);
      
      // If no previous bearing, set immediately
      if (_previousBearing == null) {
        currentBearing = _targetBearing;
        _previousBearing = currentBearing;
      }
      
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
    
    // SMOOTH bearing interpolation (critical for natural rotation)
    if (_targetBearing != null && _previousBearing != null) {
      double bearingDiff = _targetBearing! - _previousBearing!;
      
      // Handle 360° wrap-around (e.g., 350° → 10° should go +20°, not -340°)
      if (bearingDiff > 180) bearingDiff -= 360;
      if (bearingDiff < -180) bearingDiff += 360;
      
      // Smooth interpolation towards target bearing
      currentBearing = _previousBearing! + (bearingDiff * _bearingSmoothingFactor);
      currentBearing = (currentBearing! + 360) % 360; // Normalize to 0-360
      
      _previousBearing = currentBearing;
    }
    
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
    
    // Notify that current segment is complete
    final isLastSegment = currentSegmentIndex >= routeSegments.length - 1;
    // Note: Order status update is now handled by backend when photo is uploaded
    // No need to update status here anymore
    
    
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
    final isLastSegment = currentSegmentIndex >= routeSegments.length - 1;
    if (isLastSegment) {
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
    }
    
    // Reset interpolation
    _startPoint = null;
    _endPoint = null;
    _interpolationProgress = 0.0;
    
    notifyListeners();
  }

  // Set current segment index to a specific segment (e.g., return journey)
  void setCurrentSegmentIndex(int segmentIndex) {
    if (segmentIndex < 0 || segmentIndex >= routeSegments.length) {
      print('⚠️ Invalid segment index: $segmentIndex (max: ${routeSegments.length - 1})');
      return;
    }
    
    print('📍 Setting current segment to index $segmentIndex');
    
    // ✅ CRITICAL: Pause simulation first to clear pending timers and completion checks
    // This prevents old segment completion events from firing after segment change
    if (isSimulating) {
      print('⏸️ Pausing simulation to clear pending events...');
      pauseSimulation();
    }
    
    // Set segment index
    currentSegmentIndex = segmentIndex;
    
    // Ensure point indices array is properly sized
    if (_currentPointIndices.length <= segmentIndex) {
      _currentPointIndices = List.generate(routeSegments.length, (_) => 0);
    } else {
      _currentPointIndices[segmentIndex] = 0;
    }
    
    // Set location to first point of target segment
    final targetSegment = routeSegments[segmentIndex];
    if (targetSegment.points.isNotEmpty) {
      currentLocation = targetSegment.points.first;
      print('📍 Location set to first point of segment: ${currentLocation!.latitude}, ${currentLocation!.longitude}');
    }
    
    // Reset interpolation
    _startPoint = null;
    _endPoint = null;
    _interpolationProgress = 0.0;
    
    notifyListeners();
  }

  void pauseSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null; // ✅ IMPORTANT: Set to null after cancel
    currentSpeed = 0.0; // Reset tốc độ khi pause
    notifyListeners();
  }

  void resumeSimulation() {
    if (_isSimulating && _simulationTimer == null) {
      // CRITICAL: Check if callbacks are set
      if (_locationUpdateCallback == null || _segmentCompleteCallback == null) {
        
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
      notifyListeners();
    } else {
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
    _previousBearing = null;
    _targetBearing = null;

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
    
    if (routeSegments.isEmpty) {
      return;
    }
    
    if (segmentIndex >= routeSegments.length) {
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
    notifyListeners();
  }

  // Jump to end of current segment (skip to destination of current route)
  // IMPROVED: Skip to a point ~100m before destination to allow simulation 
  // to update location and send updates to FE before reaching waypoint (~6-7 seconds)
  Future<void> jumpToNextSegment() async {
    if (routeSegments.isEmpty) {
      return;
    }

    if (currentSegmentIndex >= routeSegments.length) {
      return;
    }
    final currentSegment = routeSegments[currentSegmentIndex];
    
    // Skip to a point NEAR the end (not exactly at the end)
    // This gives simulation time to update location and send to FE
    if (currentSegment.points.isNotEmpty) {
      final targetDistanceBeforeEnd = 100.0; // meters - distance before destination (reduced for faster skip)
      final lastPoint = currentSegment.points.last;
      
      // Find the point that is approximately targetDistanceBeforeEnd meters before the end
      int targetPointIndex = currentSegment.points.length - 1;
      double accumulatedDistance = 0.0;
      
      // Walk backwards from the end to find the point ~100m before
      for (int i = currentSegment.points.length - 1; i > 0; i--) {
        final point = currentSegment.points[i];
        final previousPoint = currentSegment.points[i - 1];
        final segmentDistance = _calculateDistance(previousPoint, point);
        
        accumulatedDistance += segmentDistance;
        
        if (accumulatedDistance >= targetDistanceBeforeEnd) {
          targetPointIndex = i;
          break;
        }
      }
      
      // Ensure we're not at the very first point (need some progress)
      if (targetPointIndex <= 0) {
        targetPointIndex = (currentSegment.points.length * 0.7).floor();
      }
      
      currentLocation = currentSegment.points[targetPointIndex];
      
      // Calculate speed for smooth continuation to destination
      final remainingDistance = _calculateDistance(currentLocation!, lastPoint);
      final estimatedTimeToDestination = 6.0; // seconds - allow ~6 seconds of simulation (faster but still safe for WebSocket)
      currentSpeed = (remainingDistance / estimatedTimeToDestination) * 3.6; // km/h
      
      
      
      
      
      // CRITICAL: Update order status when jumping to delivery point (segment 1)
      // This ensures user can see the delivery confirmation button in OrderDetailScreen
      if (currentSegmentIndex == 1 && orderWithDetails != null) {
        // Note: This will be called from NavigationScreen context to trigger OrderDetailViewModel
        // For now, just log - the actual update happens in NavigationScreen._jumpToNextSegment()
      }
      
      // Calculate bearing to next point
      if (targetPointIndex < currentSegment.points.length - 1) {
        final nextPoint = currentSegment.points[targetPointIndex + 1];
        currentBearing = _calculateBearing(currentLocation!, nextPoint);
      } else {
        // At last point, calculate bearing to next segment if available
        if (currentSegmentIndex + 1 < routeSegments.length) {
          final nextSegment = routeSegments[currentSegmentIndex + 1];
          if (nextSegment.points.isNotEmpty) {
            currentBearing = _calculateBearing(currentLocation!, nextSegment.points.first);
          }
        } else {
          currentBearing = 0.0;
        }
      }
      
      // Update point index to target point
      // The simulation will continue from here to the end naturally
      while (_currentPointIndices.length <= currentSegmentIndex) {
        _currentPointIndices.add(0);
      }
      _currentPointIndices[currentSegmentIndex] = targetPointIndex;
    }
    
    // Reset interpolation to start fresh from new position
    _startPoint = null;
    _endPoint = null;
    _interpolationProgress = 0.0;
    
    // CRITICAL: Ensure simulation is running to continue to destination
    if (!_isSimulating || _simulationTimer?.isActive != true) {
    }
    
    notifyListeners();
  }

  // Helper method to translate point names to Vietnamese
  String _translatePointName(String name) {
    // Common translations
    final translations = {
      'Carrier': 'Đơn vị vận chuyển',
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
      return;
    }
    final result = await _updateOrderDetailStatusUseCase(
      assignmentId: _vehicleAssignmentId!,
      status: OrderDetailStatus.ongoingDelivered,
    );
    
    result.fold(
      (failure) {
      },
      (success) {
      },
    );
  }

  /// Complete trip - update order status to SUCCESSFUL
  /// Called when driver confirms delivery completion
  Future<bool> completeTrip() async {
    if (orderWithDetails == null) {
      return false;
    }
    final result = await _updateToSuccessfulUseCase(orderWithDetails!.id);
    
    return result.fold(
      (failure) {
        return false;
      },
      (success) {
        return true;
      },
    );
  }
}
