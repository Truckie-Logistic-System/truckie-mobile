import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../domain/entities/order_detail.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../core/services/location_tracking_service.dart';

class NavigationTestViewModel extends ChangeNotifier {
  // Location tracking service
  final LocationTrackingService _locationTrackingService =
      getIt<LocationTrackingService>();
  bool _isTrackingActive = false;

  // WebSocket service không còn cần thiết vì đã sử dụng LocationTrackingService
  bool _isWebSocketConnected = false;
  String? _currentVehicleId;
  String? _currentLicensePlateNumber;
  String? _jwtToken;

  // Sử dụng Map thay vì OrderWithDetails để tránh lỗi
  Map<String, dynamic>? _orderData;

  // Sample order data
  final Map<String, dynamic> _sampleOrderData = {
    "success": true,
    "message": "Success",
    "statusCode": 200,
    "data": {
      "order": {
        "id": "384b8d82-10fa-423a-8fc8-9ef56397b8e7",
        "notes": "Không có ghi chú",
        "totalQuantity": 1,
        "orderCode": "ORD20251001163622-D992",
        "receiverName": "Son",
        "receiverPhone": "0123456789",
        "receiverIdentity": "0123456789",
        "packageDescription": "a",
        "createdAt": "2025-10-01T16:36:23.013867",
        "status": "FULLY_PAID",
        "deliveryAddress":
            "34/2 Nguyễn Thị Thập, Phường Tân Thuận, Thành Phố Hồ Chí Minh",
        "pickupAddress":
            "128 Cống Quỳnh, Phường Bến Thành, Thành Phố Hồ Chí Minh",
        "senderName": "Representer",
        "senderPhone": "0358696560",
        "senderCompanyName": "TEST COMPANY",
        "categoryName": "NORMAL",
        "orderDetails": [
          {
            "id": "ORD_D_20251001163623-C8AB",
            "weightBaseUnit": 20,
            "unit": "Kí",
            "description": "a",
            "status": "ASSIGNED_TO_DRIVER",
            "startTime": null,
            "estimatedStartTime": "2025-10-03T16:45:00",
            "endTime": "2025-10-08T09:20:00",
            "estimatedEndTime": "2025-10-08T09:34:09.281193",
            "createdAt": "2025-10-01T16:36:23.061175",
            "trackingCode": "ORD_D_20251001163623-C8AB",
            "orderSize": {
              "id": "7ad7d6d3-5813-4dd0-b5fa-5dcd624a4755",
              "description": "TRUCK_1_25_TON",
              "minLength": 3.17,
              "maxLength": 4.4,
              "minHeight": 1.11,
              "maxHeight": 1.84,
              "minWidth": 1.67,
              "maxWidth": 1.92,
            },
            "vehicleAssignment": {
              "id": "ff3534f0-43ed-4027-8ada-d974a4dd44df",
              "vehicle": {
                "id": "a2222222-2222-2222-2222-222222222222",
                "manufacturer": "Isuzu",
                "model": "Model B",
                "licensePlateNumber": "51B-00005",
                "vehicleType": "TRUCK_1_25_TON",
              },
              "primaryDriver": {
                "id": "d7abde3e-879d-4ebc-93e0-434adb7bc5d7",
                "fullName": "Driver 2 Tran",
                "phoneNumber": "0901000002",
              },
              "secondaryDriver": {
                "id": "daf741ae-56a7-4ef7-bd66-760748ec8a8c",
                "fullName": "Driver 4 Pham",
                "phoneNumber": "0901000004",
              },
              "status": "ACTIVE",
              "trackingCode": "TRIP_20251003000050-26BA",
              "issues": [],
              "photoCompletions": [],
              "orderSeals": [],
              "journeyHistories": [
                {
                  "id": "59443c05-558c-4ed3-93fd-6eae529a31a9",
                  "journeyName": "Journey for TRIP_20251003000050-26BA",
                  "journeyType": "INITIAL",
                  "status": "ACTIVE",
                  "totalTollFee": 0,
                  "totalTollCount": 0,
                  "totalDistance": 22,
                  "reasonForReroute": null,
                  "vehicleAssignmentId": "ff3534f0-43ed-4027-8ada-d974a4dd44df",
                  "journeySegments": [
                    {
                      "id": "1ca0ca47-f83e-4701-ab32-0c163378fca0",
                      "segmentOrder": 1,
                      "startPointName": "Carrier",
                      "endPointName": "Pickup",
                      "startLatitude": 10.762534,
                      "startLongitude": 106.660191,
                      "endLatitude": 10.765377,
                      "endLongitude": 106.690095,
                      "distanceMeters": 4,
                      "pathCoordinatesJson":
                          "[[106.660191,10.762534],[106.660352,10.762567],[106.660091,10.763543],[106.660094,10.763612],[106.660034,10.763824],[106.664035,10.765976],[106.665144,10.766589],[106.665262,10.766613],[106.667073,10.767635],[106.667388,10.7678],[106.667833,10.767987],[106.66791,10.767968],[106.66797,10.767993],[106.66814,10.767958],[106.668456,10.767926],[106.674123,10.767692],[106.674143,10.767607],[106.674216,10.767505],[106.674277,10.767464],[106.674402,10.767428],[106.674514,10.76744],[106.674613,10.767488],[106.674696,10.767583],[106.676382,10.767023],[106.680924,10.765588],[106.681366,10.765464],[106.681372,10.765391],[106.681415,10.765288],[106.68149,10.765211],[106.681566,10.765171],[106.681646,10.765156],[106.681716,10.76516],[106.681837,10.765211],[106.681911,10.765287],[106.681946,10.76536],[106.681961,10.765467],[106.681934,10.765577],[106.682619,10.766044],[106.683265,10.766453],[106.684706,10.767408],[106.68511,10.76768],[106.685434,10.767928],[106.685856,10.767737],[106.685943,10.767664],[106.686442,10.767438],[106.686549,10.767393],[106.686669,10.767379],[106.687359,10.767046],[106.688043,10.766781],[106.688225,10.766724],[106.68823,10.766677],[106.688254,10.766641],[106.688292,10.766617],[106.688339,10.766613],[106.688382,10.766631],[106.688411,10.766664],[106.688663,10.766526],[106.689374,10.766221],[106.689518,10.766136],[106.689648,10.766008],[106.690095,10.765377]]",
                      "status": "PENDING",
                      "createdAt": "2025-10-03T00:00:50.972867",
                      "modifiedAt": "2025-10-03T00:00:50.972867",
                    },
                    {
                      "id": "0ad5cac1-f77f-4ef2-a8e1-224a8ac5af4d",
                      "segmentOrder": 1,
                      "startPointName": "Pickup",
                      "endPointName": "Delivery",
                      "startLatitude": 10.765377,
                      "startLongitude": 106.690095,
                      "endLatitude": 10.737708,
                      "endLongitude": 106.727986,
                      "distanceMeters": 7,
                      "pathCoordinatesJson":
                          "[[106.690095,10.765377],[106.690596,10.764692],[106.690748,10.764304],[106.690693,10.764262],[106.690684,10.764188],[106.690722,10.764137],[106.690783,10.764123],[106.690833,10.764144],[106.690862,10.764193],[106.692114,10.76469],[106.692174,10.764738],[106.692232,10.764761],[106.692533,10.764877],[106.692787,10.76495],[106.693763,10.766061],[106.694711,10.767175],[106.695395,10.767932],[106.695789,10.767288],[106.696386,10.766221],[106.696985,10.765222],[106.697011,10.765076],[106.697595,10.764078],[106.697769,10.76384],[106.697925,10.763698],[106.698095,10.763852],[106.698491,10.764146],[106.698914,10.764399],[106.699188,10.764476],[106.700224,10.765093],[106.700461,10.765248],[106.700975,10.765624],[106.701314,10.765251],[106.701519,10.765066],[106.702019,10.764659],[106.703361,10.763685],[106.703697,10.763395],[106.703739,10.763344],[106.70435,10.763828],[106.704662,10.764042],[106.705297,10.764332],[106.707178,10.765083],[106.708256,10.762686],[106.708356,10.762508],[106.708455,10.76241],[106.7097,10.761668],[106.712708,10.759927],[106.716371,10.757778],[106.717962,10.757014],[106.718183,10.756853],[106.718623,10.756479],[106.724319,10.752257],[106.724722,10.751966],[106.724823,10.751872],[106.725836,10.752334],[106.726406,10.752484],[106.727122,10.752593],[106.727692,10.752639],[106.728448,10.752656],[106.728839,10.747802],[106.729132,10.745933],[106.729286,10.744838],[106.730324,10.737943],[106.730262,10.737782],[106.730219,10.737732],[106.729976,10.737602],[106.72896,10.737618],[106.727993,10.737665],[106.727986,10.737708]]",
                      "status": "PENDING",
                      "createdAt": "2025-10-03T00:00:50.973903",
                      "modifiedAt": "2025-10-03T00:00:50.973903",
                    },
                    {
                      "id": "1494e72a-e941-49e3-842e-d70bf3a71688",
                      "segmentOrder": 2,
                      "startPointName": "Delivery",
                      "endPointName": "Carrier",
                      "startLatitude": 10.737708,
                      "startLongitude": 106.727986,
                      "endLatitude": 10.762709,
                      "endLongitude": 106.660146,
                      "distanceMeters": 11,
                      "pathCoordinatesJson":
                          "[[106.727986,10.737708],[106.727993,10.737665],[106.726109,10.73778],[106.724432,10.737901],[106.723585,10.737934],[106.722858,10.738003],[106.721726,10.738044],[106.721548,10.73805],[106.721548,10.737995],[106.721546,10.737403],[106.721487,10.736088],[106.72143,10.735332],[106.72126,10.734411],[106.721014,10.733647],[106.720807,10.73315],[106.720739,10.733082],[106.720454,10.732567],[106.719925,10.73182],[106.719472,10.731332],[106.719058,10.730952],[106.718331,10.730408],[106.717769,10.730083],[106.71736,10.729889],[106.716914,10.729708],[106.716235,10.729495],[106.715702,10.729374],[106.715339,10.729324],[106.714892,10.729284],[106.714314,10.729259],[106.709263,10.729134],[106.7086,10.7291],[106.704277,10.729012],[106.703269,10.729004],[106.697548,10.728867],[106.696092,10.728787],[106.695402,10.728723],[106.69389,10.728646],[106.69368,10.728576],[106.693185,10.728528],[106.688445,10.728404],[106.684863,10.728345],[106.683726,10.728336],[106.682313,10.728346],[106.677607,10.728238],[106.6775,10.728395],[106.677312,10.72853],[106.676765,10.729327],[106.675884,10.730453],[106.67536,10.731175],[106.675086,10.731583],[106.673651,10.733558],[106.672208,10.735601],[106.671363,10.736747],[106.671098,10.737136],[106.671085,10.737224],[106.67046,10.737993],[106.669527,10.739253],[106.669344,10.739546],[106.669136,10.739926],[106.669048,10.740191],[106.668944,10.740673],[106.668932,10.741032],[106.668919,10.744652],[106.668959,10.745737],[106.66909,10.747456],[106.669171,10.748272],[106.669226,10.749496],[106.669335,10.750483],[106.669413,10.751375],[106.669461,10.752308],[106.669496,10.752676],[106.669463,10.75286],[106.669488,10.753446],[106.668344,10.752814],[106.668075,10.752626],[106.667315,10.752522],[106.666735,10.752463],[106.66657,10.754038],[106.666403,10.755267],[106.666304,10.756234],[106.665626,10.75604],[106.665232,10.75595],[106.663388,10.755596],[106.662399,10.755392],[106.661717,10.757816],[106.661289,10.759288],[106.661127,10.759787],[106.660604,10.761702],[106.660299,10.762755],[106.660146,10.762709]]",
                      "status": "PENDING",
                      "createdAt": "2025-10-03T00:00:50.973903",
                      "modifiedAt": "2025-10-03T00:00:50.973903",
                    },
                  ],
                  "createdAt": "2025-10-03T00:00:50.965815",
                  "modifiedAt": "2025-10-03T00:00:50.965815",
                },
              ],
            },
          },
        ],
      },
    },
  };

  // Map controller
  VietmapController? _mapController;

  // Route data
  List<List<LatLng>> _routeSegments = [];
  int _currentSegmentIndex = 0;
  int _currentPointIndex = 0;
  List<LatLng> _completedRoute = [];
  List<LatLng> _activeSegmentPoints = []; // Points of the active segment

  // Current location
  LatLng? _currentLocation;
  double? _currentBearing;

  // Simulation control
  Timer? _simulationTimer;
  bool _isPaused = true;
  double _simulationSpeed = 1.0;
  Duration _simulationInterval = const Duration(milliseconds: 500);
  bool _isSimulating = false;

  // Waypoints
  List<LatLng> _waypoints = []; // Carrier, Pickup, Delivery, Carrier
  List<String> _waypointNames = []; // Names of waypoints

  // Callbacks
  Function(LatLng, double, List<LatLng>)? _onLocationUpdate;
  Function(int)? _onSegmentComplete;
  Function(String, String, int)?
  _onWaypointReached; // Callback for when a waypoint is reached

  // Vehicle information
  String? _vehicleId;

  // Waypoint reached status
  bool _isAtWaypoint = false;
  String _currentWaypointName = '';
  String _nextWaypointName = '';

  // Getters
  List<List<LatLng>> get routeSegments => _routeSegments;
  int get currentSegmentIndex => _currentSegmentIndex;
  LatLng? get currentLocation => _currentLocation;
  double? get currentBearing => _currentBearing;
  List<LatLng> get completedRoute => _completedRoute;
  List<LatLng> get activeSegmentPoints => _activeSegmentPoints;
  bool get isAtWaypoint => _isAtWaypoint;
  String get currentWaypointName => _currentWaypointName;
  String get nextWaypointName => _nextWaypointName;

  // Getter để truy cập sample order data từ bên ngoài
  Map<String, dynamic> get sampleOrderData => _sampleOrderData;

  // Kiểm tra nếu đây là điểm cuối cùng và là Carrier
  bool get isLastWaypoint =>
      _currentSegmentIndex == _routeSegments.length - 1 &&
      _currentPointIndex >= _routeSegments[_currentSegmentIndex].length - 2;

  bool get isLastCarrierPoint =>
      isLastWaypoint && _currentWaypointName == 'Carrier';

  // Load sample order data
  void loadSampleOrder() {
    try {
      final orderData = _sampleOrderData;
      if (orderData['success'] == true && orderData['data'] != null) {
        final orderJson = orderData['data']['order'];
        _orderData = orderJson;
        _parseRouteFromOrder();
      }
    } catch (e) {
      debugPrint('Error loading sample order: $e');
    }
  }

  // Set map controller
  void setMapController(VietmapController controller) {
    _mapController = controller;
  }

  // Bắt đầu mô phỏng
  void startSimulation({
    required Function(LatLng, double, List<LatLng>) onLocationUpdate,
    Function(int)? onSegmentComplete,
    Function(String, String, int)? onWaypointReached,
    double simulationSpeed = 1.0,
  }) {
    if (_isSimulating) return;

    _isSimulating = true;
    _isPaused = false;
    _simulationSpeed = simulationSpeed;

    // Lưu lại callbacks
    _onLocationUpdate = onLocationUpdate;
    _onSegmentComplete = onSegmentComplete;
    _onWaypointReached = onWaypointReached;

    // Đảm bảo có dữ liệu tuyến đường
    if (_routeSegments.isEmpty) {
      debugPrint('Không có dữ liệu tuyến đường để mô phỏng');
      return;
    }

    // Đặt vị trí ban đầu ở điểm đầu tiên của đoạn đường hiện tại
    if (_currentSegmentIndex < _routeSegments.length &&
        _routeSegments[_currentSegmentIndex].isNotEmpty) {
      _currentLocation = _routeSegments[_currentSegmentIndex][0];
      _currentPointIndex = 0;
      _currentBearing = 0.0;

      // Gọi callback với vị trí ban đầu ngay lập tức
      onLocationUpdate(
        _currentLocation!,
        _currentBearing ?? 0.0,
        _completedRoute,
      );
    }

    // Tính toán khoảng thời gian cập nhật dựa trên tốc độ mô phỏng
    // Tăng khoảng thời gian cơ bản để mô phỏng mượt mà hơn
    final baseInterval = 800; // Tăng từ 500ms lên 800ms
    final interval = (baseInterval / _simulationSpeed).round();
    _simulationInterval = Duration(milliseconds: interval);

    // Khởi tạo timer để cập nhật vị trí
    _simulationTimer = Timer.periodic(_simulationInterval, (timer) {
      if (_isPaused) return;

      _updateLocation(
        onLocationUpdate: onLocationUpdate,
        onSegmentComplete: onSegmentComplete,
        onWaypointReached: onWaypointReached,
      );
    });
  }

  // Update location during simulation
  void _updateLocation({
    Function(LatLng, double, List<LatLng>)? onLocationUpdate,
    Function(int)? onSegmentComplete,
    Function(String, String, int)? onWaypointReached,
  }) {
    if (_isPaused) return;

    // Check if we've reached the end of all segments
    if (_currentSegmentIndex >= _routeSegments.length) {
      _simulationTimer?.cancel();
      return;
    }

    // Get current segment
    final currentSegment = _routeSegments[_currentSegmentIndex];

    // Check if we've reached the end of the current segment
    if (_currentPointIndex >= currentSegment.length - 1) {
      // We've reached a waypoint (end of segment)
      final waypointIndex =
          _currentSegmentIndex + 1; // +1 because first waypoint is at index 0

      if (waypointIndex < _waypointNames.length) {
        // Update current and next waypoint names
        _isAtWaypoint = true;
        _currentWaypointName = _waypointNames[waypointIndex];
        _nextWaypointName = waypointIndex + 1 < _waypointNames.length
            ? _waypointNames[waypointIndex + 1]
            : '';

        // Notify that we've reached a waypoint
        if (onWaypointReached != null) {
          onWaypointReached(
            _currentWaypointName,
            _nextWaypointName,
            _currentSegmentIndex,
          );
        }

        // Pause simulation at waypoint
        _isPaused = true;

        // Wait for user to resume or move to next segment
        return;
      }

      // Move to next segment
      _currentSegmentIndex++;
      _currentPointIndex = 0;

      // Update active segment points
      if (_currentSegmentIndex < _routeSegments.length) {
        _activeSegmentPoints = List.from(_routeSegments[_currentSegmentIndex]);
      }

      // Notify segment completion
      if (onSegmentComplete != null) {
        onSegmentComplete(_currentSegmentIndex - 1);
      }

      // Check if we've completed all segments
      if (_currentSegmentIndex >= _routeSegments.length) {
        _simulationTimer?.cancel();
        return;
      }

      // Start next segment
      return;
    }

    // Move to next point
    final previousPoint = currentSegment[_currentPointIndex];
    _currentPointIndex++;
    final currentPoint = currentSegment[_currentPointIndex];

    // Update current location
    _currentLocation = currentPoint;

    // Calculate bearing
    _currentBearing = _calculateBearing(previousPoint, currentPoint);

    // Add to completed route
    _completedRoute.add(currentPoint);

    // Update vehicle location on server (simulated)
    _updateVehicleLocation();

    // Notify location update
    if (onLocationUpdate != null) {
      onLocationUpdate(_currentLocation!, _currentBearing!, _completedRoute);
    }

    notifyListeners();
  }

  // Calculate bearing between two points
  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitude * (pi / 180);
    final startLng = start.longitude * (pi / 180);
    final endLat = end.latitude * (pi / 180);
    final endLng = end.longitude * (pi / 180);

    final y = sin(endLng - startLng) * cos(endLat);
    final x =
        cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(endLng - startLng);

    final bearing = atan2(y, x) * (180 / pi);
    return (bearing + 360) % 360;
  }

  // Update vehicle location on server
  void _updateVehicleLocation() {
    if (_currentVehicleId == null || _currentLocation == null) return;

    // In a real implementation, this would make an API call
    // For this simulation, we'll just log the update
    debugPrint(
      'Updating vehicle location: Vehicle ID: $_currentVehicleId, '
      'Lat: ${_currentLocation!.latitude}, Lng: ${_currentLocation!.longitude}',
    );

    // Example API call (commented out)
    /*
    final apiService = ApiService();
    apiService.put(
      '/vehicles/$_vehicleId/location/rate-limited',
      data: {
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
      },
      queryParameters: {'seconds': 5},
    );
    */
  }

  // Pause simulation
  void pauseSimulation() {
    _isPaused = true;
    notifyListeners();
  }

  // Resume simulation
  void resumeSimulation() {
    if (_isPaused) {
      _isPaused = false;
      _isAtWaypoint = false;
      notifyListeners();
    }
  }

  // Continue to next segment (when at waypoint)
  void continueToNextSegment() {
    if (_isAtWaypoint) {
      _isAtWaypoint = false;
      _isPaused = false;

      // Move to next segment if we're at the end of the current segment
      if (_currentPointIndex >=
          _routeSegments[_currentSegmentIndex].length - 1) {
        _currentSegmentIndex++;
        _currentPointIndex = 0;

        // Update active segment points
        if (_currentSegmentIndex < _routeSegments.length) {
          _activeSegmentPoints = List.from(
            _routeSegments[_currentSegmentIndex],
          );
        }

        // Notify segment completion
        if (_onSegmentComplete != null) {
          _onSegmentComplete!(_currentSegmentIndex - 1);
        }
      }

      notifyListeners();
    }
  }

  /// Reset simulation state
  void resetSimulation() {
    // Cancel any ongoing timers
    _simulationTimer?.cancel();
    _simulationTimer = null;

    // Reset state
    _isPaused = true;
    _isSimulating = false;
    _currentSegmentIndex = 0;
    _currentPointIndex = 0;
    _currentLocation = null;
    _currentBearing = 0.0;
    _simulationSpeed = 1.0;
    _isAtWaypoint = false;
    _currentWaypointName = '';
    _nextWaypointName = '';

    // Clear completed route
    _completedRoute.clear();

    // Reset callbacks
    _onLocationUpdate = null;
    _onSegmentComplete = null;
    _onWaypointReached = null;

    // Re-parse route from order data to ensure fresh state
    if (_orderData != null) {
      _parseRouteFromOrder();
    }

    // Initialize active segment points
    if (_routeSegments.isNotEmpty && _routeSegments[0].isNotEmpty) {
      _activeSegmentPoints = List.from(_routeSegments[0]);
    } else {
      _activeSegmentPoints = [];
    }

    debugPrint('Navigation simulation reset');

    notifyListeners();
  }

  // Update simulation speed
  void updateSimulationSpeed(double speed) {
    _simulationSpeed = speed;

    // Tăng khoảng thời gian cơ bản để mô phỏng mượt mà hơn
    final baseInterval = 800; // Tăng từ 500ms lên 800ms
    final interval = (baseInterval / _simulationSpeed).round();
    _simulationInterval = Duration(milliseconds: interval);

    // Restart timer with new interval if running
    if (!_isPaused && _simulationTimer != null) {
      _simulationTimer!.cancel();
      _simulationTimer = Timer.periodic(_simulationInterval, (timer) {
        _updateLocation(
          onLocationUpdate: _onLocationUpdate,
          onSegmentComplete: _onSegmentComplete,
          onWaypointReached: _onWaypointReached,
        );
      });
    }

    notifyListeners();
  }

  @override
  void dispose() {
    // Dừng theo dõi vị trí khi dispose
    if (_isTrackingActive) {
      _locationTrackingService.stopTracking();
    }
    _simulationTimer?.cancel();
    super.dispose();
  }

  // Bắt đầu theo dõi vị trí
  Future<bool> _startLocationTracking() async {
    if (_isTrackingActive) return true;

    try {
      // Lấy thông tin xe từ order data
      if (_currentVehicleId == null || _currentLicensePlateNumber == null) {
        debugPrint('❌ Không thể bắt đầu theo dõi: Không có thông tin xe');
        return false;
      }

      final success = await _locationTrackingService.startTracking(
        vehicleId: _currentVehicleId!,
        licensePlateNumber: _currentLicensePlateNumber!,
        onLocationUpdate: (data) {
          debugPrint('📍 Nhận vị trí từ server: $data');
        },
        onError: (error) {
          debugPrint('❌ Lỗi theo dõi vị trí: $error');
        },
      );

      _isTrackingActive = success;
      return success;
    } catch (e) {
      debugPrint('❌ Lỗi khi bắt đầu theo dõi vị trí: $e');
      return false;
    }
  }

  // Dừng theo dõi vị trí
  Future<void> _stopLocationTracking() async {
    if (!_isTrackingActive) return;

    try {
      await _locationTrackingService.stopTracking();
      _isTrackingActive = false;
    } catch (e) {
      debugPrint('❌ Lỗi khi dừng theo dõi vị trí: $e');
    }
  }

  // Xóa phương thức _sendLocationUpdate vì đã sử dụng LocationTrackingService

  // Parse route segments from order details
  void _parseRouteFromOrder() {
    if (_orderData == null) {
      debugPrint('No order data available.');
      return;
    }

    try {
      final orderDetails = _orderData!['orderDetails'][0];
      final vehicleAssignment = orderDetails['vehicleAssignment'];
      final journeyHistories = vehicleAssignment['journeyHistories'];

      if (journeyHistories == null || journeyHistories.isEmpty) {
        debugPrint('No journey histories found.');
        return;
      }

      final journeyHistory = journeyHistories[0];
      final journeySegments = journeyHistory['journeySegments'];

      _routeSegments = [];
      _waypoints = [];
      _waypointNames = [];

      for (var segment in journeySegments) {
        try {
          final List<LatLng> points = [];
          final List<dynamic> coordinates = json.decode(
            segment['pathCoordinatesJson'],
          );

          for (var coordinate in coordinates) {
            if (coordinate is List && coordinate.length >= 2) {
              // Note: In JSON, coordinates are stored as [longitude, latitude]
              final double lng = coordinate[0].toDouble();
              final double lat = coordinate[1].toDouble();
              points.add(LatLng(lat, lng));
            }
          }

          if (points.isNotEmpty) {
            _routeSegments.add(points);

            // Add start point to waypoints
            if (_waypoints.isEmpty) {
              _waypoints.add(points.first);
              _waypointNames.add(segment['startPointName']);
            }

            // Add end point to waypoints
            _waypoints.add(points.last);
            _waypointNames.add(segment['endPointName']);
          }
        } catch (e) {
          debugPrint('Error parsing route segment: $e');
        }
      }

      // Set initial location to the start of the first segment
      if (_routeSegments.isNotEmpty && _routeSegments[0].isNotEmpty) {
        _currentLocation = _routeSegments[0][0];
        _activeSegmentPoints = List.from(_routeSegments[0]);
      }

      // Set initial waypoint information
      if (_waypointNames.isNotEmpty) {
        _currentWaypointName = _waypointNames[0];
        _nextWaypointName = _waypointNames.length > 1 ? _waypointNames[1] : '';
      }

      // Lấy thông tin xe
      final vehicle = vehicleAssignment['vehicle'];
      if (vehicle != null) {
        _currentVehicleId = vehicle['id'];
        _currentLicensePlateNumber = vehicle['licensePlateNumber'];
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing order data: $e');
    }
  }
}
