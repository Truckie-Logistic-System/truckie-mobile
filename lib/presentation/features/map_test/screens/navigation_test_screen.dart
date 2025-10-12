import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../core/models/vietmap_config.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/vietmap_service.dart';
import '../../../../domain/entities/order_detail.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../viewmodels/navigation_test_viewmodel.dart';

class NavigationTestScreen extends StatefulWidget {
  const NavigationTestScreen({Key? key}) : super(key: key);

  @override
  State<NavigationTestScreen> createState() => _NavigationTestScreenState();
}

class _NavigationTestScreenState extends State<NavigationTestScreen> {
  late NavigationTestViewModel _viewModel;
  VietmapController? _mapController;
  Line? _completedRouteLine;
  Line? _pendingRouteLine;
  Line? _currentSegmentLine;
  bool _isMapReady = false;
  bool _isMapInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _locationUpdateTimer;
  double _simulationSpeed = 1.0;
  bool _isPaused = true;
  bool _isDisposed = false;
  bool _is3DMode = true; // Default to 3D mode
  bool _isFollowingUser = true; // Default to following user
  String? _mapStyle; // Lưu trữ style string từ API
  bool _isLoadingMapStyle = true; // Trạng thái đang tải map style
  bool _hasResetBeenCalled = false; // Flag để đánh dấu đã gọi reset chưa

  // Dịch vụ theo dõi vị trí
  late LocationTrackingService _locationTrackingService;
  bool _isLocationTrackingActive = false;
  String _locationTrackingStatus = 'Chưa kết nối';

  // Màu sắc cho các đoạn đường
  final List<Color> _routeColors = [
    AppColors.primary, // Màu xanh dương cho đoạn 1
    AppColors.success, // Màu xanh lá cho đoạn 2
    Colors.orange, // Màu cam cho đoạn 3
  ];

  // Tên các đoạn đường
  final List<String> _routeNames = [
    'Kho → Lấy hàng',
    'Lấy hàng → Giao hàng',
    'Giao hàng → Kho',
  ];

  // Chú thích ngắn gọn
  final List<String> _shortRouteNames = [
    'Kho → Lấy',
    'Lấy → Giao',
    'Giao → Kho',
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = NavigationTestViewModel();
    _viewModel.loadSampleOrder();
    _loadMapStyle();

    // Khởi tạo dịch vụ theo dõi vị trí
    _locationTrackingService = getIt<LocationTrackingService>();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _locationUpdateTimer?.cancel();

    // Dừng theo dõi vị trí
    _stopLocationTracking();

    // Giải phóng tài nguyên map trước khi dispose
    _mapController = null;
    _viewModel.dispose();
    super.dispose();
  }

  // Tải map style từ API
  Future<void> _loadMapStyle() async {
    try {
      setState(() {
        _isLoadingMapStyle = true;
      });

      final vietMapService = getIt<VietMapService>();
      final styleString = await vietMapService.getMobileStyles();

      if (!_isDisposed) {
        // Xử lý style trước khi đặt vào state
        try {
          final styleJson = json.decode(styleString);

          // Thêm background layer để tránh mảng đen
          if (styleJson is Map && styleJson.containsKey('layers')) {
            final layers = styleJson['layers'];
            if (layers is List) {
              bool hasBackgroundLayer = false;
              for (var layer in layers) {
                if (layer is Map && layer['id'] == 'background') {
                  hasBackgroundLayer = true;
                  if (layer.containsKey('paint') && layer['paint'] is Map) {
                    layer['paint']['background-color'] = '#ffffff';
                  }
                  break;
                }
              }

              if (!hasBackgroundLayer) {
                layers.insert(0, {
                  'id': 'background',
                  'type': 'background',
                  'paint': {'background-color': '#ffffff'},
                });
              }
            }
          }

          setState(() {
            _mapStyle = json.encode(styleJson);
            _isLoadingMapStyle = false;
          });
        } catch (e) {
          debugPrint('Error processing map style: $e');
          setState(() {
            _mapStyle = styleString;
            _isLoadingMapStyle = false;
          });
        }

        // Sau khi tải xong map style, đợi map được khởi tạo
        _waitForMapInitialization();
      }
    } catch (e) {
      debugPrint('Error loading map style: $e');
      if (!_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Không thể tải style bản đồ: ${e.toString()}';
          _isLoadingMapStyle = false;
        });
      }
    }
  }

  // Đợi map được khởi tạo đầy đủ rồi mới reset
  void _waitForMapInitialization() {
    debugPrint('Waiting for map initialization...');

    // Thay vì kiểm tra liên tục, chỉ đặt một timer duy nhất
    Future.delayed(const Duration(seconds: 2), () {
      if (_isDisposed) return;

      debugPrint(
        'Checking map status once: ready=$_isMapReady, initialized=$_isMapInitialized, hasReset=$_hasResetBeenCalled',
      );

      if (_isMapReady && _isMapInitialized && !_hasResetBeenCalled) {
        debugPrint(
          'Map is ready and initialized, performing reset from delayed check',
        );
        _resetSimulation();
      } else if (!_hasResetBeenCalled) {
        // Nếu map chưa sẵn sàng sau 2 giây, thử lại một lần nữa sau 3 giây
        Future.delayed(const Duration(seconds: 3), () {
          if (_isDisposed) return;

          debugPrint(
            'Final map status check: ready=$_isMapReady, initialized=$_isMapInitialized, hasReset=$_hasResetBeenCalled',
          );

          if (!_hasResetBeenCalled) {
            debugPrint('Forcing reset after delay');
            // Cưỡng chế reset bất kể trạng thái map
            _resetSimulation();
          }
        });
      }
    });
  }

  void _onMapCreated(VietmapController controller) {
    debugPrint('_onMapCreated called');
    if (!_isDisposed) {
      setState(() {
        _mapController = controller;
      });
      _viewModel.setMapController(controller);
      debugPrint('VietMap controller created successfully');
    }
  }

  void _onMapRendered() {
    debugPrint('_onMapRendered called');
    if (!_isDisposed) {
      setState(() {
        _isMapReady = true;
      });
      debugPrint('Map is rendered successfully, _isMapReady=$_isMapReady');

      // Kiểm tra nếu cả hai điều kiện đã sẵn sàng và chưa gọi reset thì reset
      if (_isMapReady && _isMapInitialized && !_hasResetBeenCalled) {
        debugPrint(
          'Both map and style are ready, calling reset from _onMapRendered',
        );
        _resetSimulation();
      }
    }
  }

  void _onStyleLoaded() {
    debugPrint('_onStyleLoaded called');
    if (!_isDisposed) {
      setState(() {
        _isMapInitialized = true;
      });
      debugPrint(
        'Style is loaded successfully, _isMapInitialized=$_isMapInitialized',
      );

      // Kiểm tra nếu cả hai điều kiện đã sẵn sàng và chưa gọi reset thì reset
      if (_isMapReady && _isMapInitialized && !_hasResetBeenCalled) {
        debugPrint(
          'Both map and style are ready, calling reset from _onStyleLoaded',
        );
        _resetSimulation();
      }
    }
  }

  void _setNavigationCamera() {
    if (_mapController == null || !_isMapReady || !_isMapInitialized) return;

    // Nếu có vị trí hiện tại, focus vào đó
    if (_viewModel.currentLocation != null) {
      _setCameraToNavigationMode(_viewModel.currentLocation!);
    }
    // Nếu không, focus vào điểm đầu tiên của route
    else if (_viewModel.routeSegments.isNotEmpty &&
        _viewModel.routeSegments[0].isNotEmpty) {
      _setCameraToNavigationMode(_viewModel.routeSegments[0][0]);
    }
  }

  void _setCameraToNavigationMode(LatLng position) {
    if (_mapController == null) return;

    // Giảm tốc độ chuyển camera để tránh tải quá nhiều tile
    final duration = const Duration(milliseconds: 1000);

    if (_is3DMode) {
      // Chế độ 3D: tilt cao (45-60 độ), zoom gần hơn và bearing theo hướng di chuyển
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 16.0, // Giảm mức zoom để giảm tải tile
            bearing: _viewModel.currentBearing ?? 0.0,
            tilt: 45.0, // Giảm góc nghiêng để giảm tải tài nguyên
          ),
        ),
        duration: duration,
      );
    } else {
      // Chế độ 2D: không có tilt, zoom xa hơn một chút
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 15.0, bearing: 0.0, tilt: 0.0),
        ),
        duration: duration,
      );
    }
  }

  void _toggle3DMode() {
    setState(() {
      _is3DMode = !_is3DMode;
    });

    if (_viewModel.currentLocation != null) {
      _setCameraToNavigationMode(_viewModel.currentLocation!);
    }
  }

  void _toggleFollowUser() {
    setState(() {
      _isFollowingUser = !_isFollowingUser;
    });

    if (_isFollowingUser && _viewModel.currentLocation != null) {
      _setCameraToNavigationMode(_viewModel.currentLocation!);
    }
  }

  void _startSimulation() {
    setState(() {
      _isPaused = false;
      _isFollowingUser = true; // Tự động bật chế độ theo dõi khi bắt đầu
    });

    // Hiển thị dialog đang kết nối
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Đang kết nối'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang kết nối WebSocket...'),
          ],
        ),
      ),
    );

    // Đảm bảo đã kết nối WebSocket trước khi bắt đầu mô phỏng
    _startLocationTracking().then((success) {
      // Đóng dialog
      Navigator.of(context).pop();

      if (!success) {
        // Hiển thị thông báo lỗi nếu kết nối thất bại
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể kết nối WebSocket. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isPaused = true;
        });
        return;
      }

      if (_viewModel.currentLocation != null) {
        // Đợi thêm một chút để đảm bảo kết nối đã hoàn toàn thiết lập
        Future.delayed(Duration(milliseconds: 500), () {
          // Gửi vị trí ban đầu sau khi kết nối thành công
          _locationTrackingService.sendLocation(
            _viewModel.currentLocation!,
            bearing: _viewModel.currentBearing ?? 0.0,
          );
          debugPrint('📤 Gửi vị trí ban đầu qua WebSocket sau khi kết nối');
        });
      }

      // Bắt đầu mô phỏng chỉ khi kết nối thành công
      _startActualSimulation();
    });
  }

  // Hàm thực hiện việc bắt đầu mô phỏng sau khi đã kết nối WebSocket
  void _startActualSimulation() {
    // Biến để theo dõi thời gian cập nhật camera
    int _cameraUpdateCounter = 0;

    _viewModel.startSimulation(
      onLocationUpdate: (location, bearing, completedRoute) {
        if (_mapController != null && _isMapReady && _isMapInitialized) {
          // Tăng bộ đếm
          _cameraUpdateCounter++;

          // Update camera position to follow vehicle - luôn theo dõi xe
          if (_isFollowingUser) {
            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: location,
                  zoom: _is3DMode ? 16.0 : 15.0,
                  bearing: _is3DMode ? bearing : 0.0,
                  tilt: _is3DMode ? 45.0 : 0.0,
                ),
              ),
              duration: const Duration(
                milliseconds: 500,
              ), // Tăng thời gian để mượt hơn
            );
          }

          // Update completed route line
          if (_completedRouteLine != null && completedRoute.length >= 2) {
            // Tối ưu hóa: chỉ cập nhật polyline sau mỗi vài lần cập nhật vị trí
            if (_cameraUpdateCounter % 5 == 0) {
              // Tăng tần suất cập nhật để giảm tải
              // Đơn giản hóa route trước khi cập nhật để giảm tải
              List<LatLng> optimizedRoute = _simplifyRoute(completedRoute);

              _mapController!.updatePolyline(
                _completedRouteLine!,
                PolylineOptions(
                  geometry: optimizedRoute,
                  polylineColor: Colors.blue,
                  polylineWidth: 6.0,
                  polylineOpacity: 1.0,
                ),
              );
            }
          }

          // Luôn gửi vị trí hiện tại qua WebSocket mỗi khi có cập nhật vị trí
          if (_isLocationTrackingActive) {
            _locationTrackingService.sendLocation(location, bearing: bearing);
          }
        }
      },
      onSegmentComplete: (segmentIndex) {
        _drawRoutes();
      },
      onWaypointReached: _onWaypointReached,
      simulationSpeed: _simulationSpeed * 0.7, // Giảm tốc độ mô phỏng xuống 70%
    );
  }

  // Xử lý khi đến điểm waypoint
  void _onWaypointReached(
    String currentWaypoint,
    String nextWaypoint,
    int segmentIndex,
  ) {
    debugPrint(
      'Reached waypoint: $currentWaypoint, next: $nextWaypoint, segment: $segmentIndex',
    );

    // Kiểm tra nếu đây là điểm cuối cùng và là Carrier
    bool isLastCarrier =
        _viewModel.isLastCarrierPoint ||
        (currentWaypoint == 'Carrier' &&
            (nextWaypoint.isEmpty ||
                segmentIndex == _viewModel.routeSegments.length - 1));

    if (isLastCarrier) {
      debugPrint('Reached final Carrier waypoint - end of trip');
    }

    // Hiển thị thông báo khi đến điểm waypoint
    String waypointName = _getVietnameseName(currentWaypoint);

    // Hiển thị thông báo
    _showWaypointDialog(
      waypointName,
      nextWaypoint.isNotEmpty ? _getVietnameseName(nextWaypoint) : null,
    );
  }

  // Hiển thị dialog khi đến điểm waypoint
  void _showWaypointDialog(String waypointName, String? nextWaypointName) {
    // Kiểm tra nếu đây là điểm Carrier cuối cùng (kết thúc chuyến xe)
    bool isLastCarrierPoint =
        waypointName == 'Kho' &&
            (nextWaypointName == null || nextWaypointName.isEmpty) ||
        _viewModel.isLastCarrierPoint;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          isLastCarrierPoint ? 'Kết thúc chuyến xe' : 'Đã đến $waypointName',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLastCarrierPoint
                  ? 'Bạn đã hoàn thành chuyến xe và quay về kho.'
                  : 'Bạn đã đến điểm $waypointName.',
            ),
            if (!isLastCarrierPoint && nextWaypointName != null) ...[
              SizedBox(height: 8.h),
              Text('Điểm tiếp theo: $nextWaypointName'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();

              if (isLastCarrierPoint) {
                // Nếu là điểm Carrier cuối cùng, hiển thị thông báo hoàn thành
                _showCompletionMessage();
              } else {
                // Nếu không, tiếp tục như bình thường
                _viewModel.continueToNextSegment();

                // Đảm bảo cập nhật UI sau khi tiếp tục
                setState(() {
                  // Cập nhật lại state để hiển thị đúng
                });

                // Vẽ lại routes và cập nhật camera
                _drawRoutes();
                _setNavigationCamera();
              }
            },
            child: Text(isLastCarrierPoint ? 'Hoàn thành' : 'Tiếp tục'),
          ),
        ],
      ),
    );
  }

  // Hiển thị thông báo hoàn thành chuyến xe
  void _showCompletionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chuyến xe đã hoàn thành thành công!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
      ),
    );

    // Dừng theo dõi vị trí khi hoàn thành chuyến xe
    _stopLocationTracking().then((_) {
      debugPrint('📍 Đã ngắt kết nối WebSocket sau khi hoàn thành chuyến xe');
    });

    // Reset simulation sau khi hoàn thành
    setState(() {
      _hasResetBeenCalled = false;
    });
    _resetSimulation();
  }

  // Chuyển đổi tên điểm từ tiếng Anh sang tiếng Việt
  String _getVietnameseName(String name) {
    switch (name) {
      case 'Carrier':
        return 'Kho';
      case 'Pickup':
        return 'Điểm lấy hàng';
      case 'Delivery':
        return 'Điểm giao hàng';
      default:
        return name;
    }
  }

  void _drawRoutes() async {
    if (_mapController == null ||
        !_isMapReady ||
        !_isMapInitialized ||
        _isDisposed) {
      debugPrint(
        'Cannot draw routes: controller=${_mapController != null}, ready=$_isMapReady, initialized=$_isMapInitialized',
      );
      return;
    }

    try {
      // Xóa các polyline và symbol cũ
      await _mapController!.clearLines();
      await _mapController!.clearSymbols();
      await _mapController!.clearCircles();

      // Danh sách tất cả các điểm để tính toán bounds
      List<LatLng> allPoints = [];

      // Tối ưu hóa: chỉ vẽ các đoạn đường cần thiết
      int routesToDraw = 0;

      // Vẽ tất cả các đoạn đường
      for (int i = 0; i < _viewModel.routeSegments.length; i++) {
        final segment = _viewModel.routeSegments[i];
        if (segment.isEmpty) continue;

        // Giới hạn số lượng đoạn đường cần vẽ để tối ưu hiệu suất
        if (i >= _viewModel.currentSegmentIndex && routesToDraw < 3) {
          routesToDraw++;
          debugPrint('Drawing route $i with ${segment.length} points');

          // Tối ưu hóa: giảm số điểm cần vẽ nếu quá nhiều
          List<LatLng> optimizedSegment = segment;
          if (segment.length > 100) {
            optimizedSegment = _simplifyRoute(segment);
            debugPrint(
              'Optimized route $i from ${segment.length} to ${optimizedSegment.length} points',
            );
          }

          // Chỉ thêm điểm vào allPoints nếu đoạn đường này sẽ được vẽ
          allPoints.addAll(optimizedSegment);

          // Lấy màu cho đoạn đường này
          final color = i < _routeColors.length
              ? _routeColors[i]
              : AppColors.primary;

          // Vẽ polyline cho tuyến đường
          if (i == _viewModel.currentSegmentIndex) {
            // Đoạn đường hiện tại
            _pendingRouteLine = await _mapController!.addPolyline(
              PolylineOptions(
                geometry: optimizedSegment,
                polylineColor: color,
                polylineWidth: 5.0,
                polylineOpacity: 0.7,
              ),
            );

            // Thêm marker cho điểm đầu và điểm cuối của đoạn hiện tại
            final startPoint = optimizedSegment.first;
            final endPoint = optimizedSegment.last;

            // Thêm circle marker cho điểm đầu với màu nổi bật
            await _mapController!.addCircle(
              CircleOptions(
                geometry: startPoint,
                circleRadius: 6.0,
                circleColor: Colors.red,
                circleStrokeWidth: 1.0,
                circleStrokeColor: Colors.white,
              ),
            );

            // Thêm circle marker cho điểm cuối với màu nổi bật
            await _mapController!.addCircle(
              CircleOptions(
                geometry: endPoint,
                circleRadius: 6.0,
                circleColor: Colors.green,
                circleStrokeWidth: 1.0,
                circleStrokeColor: Colors.white,
              ),
            );
          } else if (i < _viewModel.currentSegmentIndex) {
            // Đoạn đường đã hoàn thành - không vẽ nữa
            continue;
          } else {
            // Đoạn đường sắp tới
            await _mapController!.addPolyline(
              PolylineOptions(
                geometry: optimizedSegment,
                polylineColor: color,
                polylineWidth: 3.0,
                polylineOpacity: 0.5,
              ),
            );

            // Thêm marker cho điểm đầu và điểm cuối của mỗi đoạn
            final startPoint = optimizedSegment.first;
            final endPoint = optimizedSegment.last;

            // Thêm circle marker cho điểm đầu
            await _mapController!.addCircle(
              CircleOptions(
                geometry: startPoint,
                circleRadius: 5.0,
                circleColor: color,
                circleStrokeWidth: 1.0,
                circleStrokeColor: Colors.white,
              ),
            );

            // Thêm circle marker cho điểm cuối
            await _mapController!.addCircle(
              CircleOptions(
                geometry: endPoint,
                circleRadius: 5.0,
                circleColor: color,
                circleStrokeWidth: 1.0,
                circleStrokeColor: Colors.white,
              ),
            );
          }
        }
      }

      // Initialize completed route line
      if (_viewModel.completedRoute.isNotEmpty) {
        // Tối ưu hóa: giảm số điểm của completed route nếu quá nhiều
        List<LatLng> optimizedCompletedRoute = _viewModel.completedRoute;
        if (_viewModel.completedRoute.length > 100) {
          optimizedCompletedRoute = _simplifyRoute(_viewModel.completedRoute);
          debugPrint(
            'Optimized completed route from ${_viewModel.completedRoute.length} to ${optimizedCompletedRoute.length} points',
          );
        }

        _completedRouteLine = await _mapController!.addPolyline(
          PolylineOptions(
            geometry: optimizedCompletedRoute,
            polylineColor: Colors.blue,
            polylineWidth: 6.0,
            polylineOpacity: 1.0,
          ),
        );
      }

      // Nếu đang ở chế độ theo dõi người dùng, focus vào vị trí hiện tại
      if (_isFollowingUser) {
        if (_viewModel.currentLocation != null) {
          _setCameraToNavigationMode(_viewModel.currentLocation!);
        } else if (_viewModel.routeSegments.isNotEmpty &&
            _viewModel.routeSegments[0].isNotEmpty) {
          _setCameraToNavigationMode(_viewModel.routeSegments[0][0]);
        }
      } else {
        // Nếu không theo dõi, hiển thị toàn bộ tuyến đường mà không có vùng xanh
        if (allPoints.length > 1) {
          double minLat = allPoints.map((p) => p.latitude).reduce(min);
          double maxLat = allPoints.map((p) => p.latitude).reduce(max);
          double minLng = allPoints.map((p) => p.longitude).reduce(min);
          double maxLng = allPoints.map((p) => p.longitude).reduce(max);

          // Cập nhật camera để hiển thị toàn bộ tuyến đường không có padding
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error drawing routes: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  // Hàm đơn giản hóa route để giảm số điểm cần vẽ
  List<LatLng> _simplifyRoute(List<LatLng> points) {
    if (points.length <= 2) return points;

    // Thuật toán Douglas-Peucker đơn giản hóa
    // Chỉ giữ lại khoảng 1/3 số điểm
    List<LatLng> result = [];
    int step = (points.length / 30).ceil(); // Giữ khoảng 30 điểm
    step = max(1, step); // Đảm bảo step ít nhất là 1

    // Luôn giữ điểm đầu và điểm cuối
    result.add(points.first);

    // Thêm các điểm ở giữa theo step
    for (int i = step; i < points.length - 1; i += step) {
      result.add(points[i]);
    }

    // Thêm điểm cuối
    if (points.length > 1) {
      result.add(points.last);
    }

    return result;
  }

  void _pauseSimulation() {
    setState(() {
      _isPaused = true;
    });
    _viewModel.pauseSimulation();

    // Không dừng theo dõi vị trí khi tạm dừng
  }

  void _resumeSimulation() {
    setState(() {
      _isPaused = false;
      _isFollowingUser = true; // Đảm bảo theo dõi xe khi tiếp tục
    });

    // Đảm bảo theo dõi vị trí vẫn hoạt động
    if (!_isLocationTrackingActive) {
      _startLocationTracking().then((success) {
        if (success) {
          // Tiếp tục mô phỏng sau khi kết nối WebSocket thành công
          _viewModel.resumeSimulation();

          // Focus camera vào vị trí hiện tại
          if (_viewModel.currentLocation != null) {
            _setCameraToNavigationMode(_viewModel.currentLocation!);
          }
        } else {
          // Hiển thị thông báo lỗi nếu kết nối thất bại
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể kết nối WebSocket. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isPaused = true;
          });
        }
      });
    } else {
      // WebSocket đã kết nối, chỉ cần tiếp tục mô phỏng
      _viewModel.resumeSimulation();

      // Focus camera vào vị trí hiện tại
      if (_viewModel.currentLocation != null) {
        _setCameraToNavigationMode(_viewModel.currentLocation!);
      }
    }
  }

  void _resetSimulation() {
    // Nếu đã gọi reset rồi thì không gọi nữa
    if (_hasResetBeenCalled) {
      debugPrint('Reset has already been called, skipping');
      return;
    }

    // Đánh dấu đã gọi reset
    _hasResetBeenCalled = true;

    debugPrint('Resetting simulation');
    setState(() {
      _isPaused = true;
      _isFollowingUser = true; // Đảm bảo chế độ theo dõi được bật khi reset
    });

    // Dừng mô phỏng hiện tại
    _viewModel.pauseSimulation();

    // Reset viewModel
    _viewModel.resetSimulation();

    // Đợi một chút để đảm bảo viewModel đã được reset hoàn toàn
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isDisposed) {
        debugPrint('Drawing routes after reset');
        // Vẽ lại routes
        _drawRoutes();

        debugPrint('Setting camera after reset');
        // Đặt camera vào vị trí thích hợp
        _setNavigationCamera();
      }
    });

    // Không dừng theo dõi vị trí khi reset, chỉ dừng khi hoàn thành chuyến xe
  }

  void _updateSimulationSpeed(double speed) {
    setState(() {
      _simulationSpeed = speed;
    });
    if (!_isPaused) {
      _viewModel.updateSimulationSpeed(speed);
    }
  }

  void _reportIssue() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tính năng báo cáo sự cố sẽ được triển khai sau'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getMapStyleString() {
    // Sử dụng style từ API nếu đã tải xong
    if (_mapStyle != null) {
      try {
        // Thử parse và chỉnh sửa style để tránh lỗi text-font
        final dynamic styleJson = json.decode(_mapStyle!);

        // Kiểm tra và đảm bảo cấu hình font chính xác
        if (styleJson is Map && styleJson.containsKey('layers')) {
          final layers = styleJson['layers'];
          if (layers is List) {
            for (var i = 0; i < layers.length; i++) {
              final layer = layers[i];
              // Xử lý các lớp có text-font
              if (layer is Map) {
                // Kiểm tra layout nếu có
                if (layer.containsKey('layout') && layer['layout'] is Map) {
                  final layout = layer['layout'];
                  if (layout.containsKey('text-font')) {
                    // Đảm bảo text-font là một mảng literal
                    layout['text-font'] = [
                      'Roboto Regular',
                      'Arial Unicode MS Regular',
                    ];
                  }
                }

                // Xử lý paint nếu có
                if (layer.containsKey('paint') && layer['paint'] is Map) {
                  final paint = layer['paint'];
                  if (paint.containsKey('text-font')) {
                    // Đảm bảo text-font là một mảng literal
                    paint['text-font'] = [
                      'Roboto Regular',
                      'Arial Unicode MS Regular',
                    ];
                  }
                }

                // Xử lý trực tiếp nếu có
                if (layer.containsKey('text-font')) {
                  layer['text-font'] = [
                    'Roboto Regular',
                    'Arial Unicode MS Regular',
                  ];
                }
              }
            }
          }

          // Thêm font vào style nếu chưa có
          if (!styleJson.containsKey('glyphs')) {
            styleJson['glyphs'] =
                'https://maps.vietmap.vn/api/fonts/{fontstack}/{range}.pbf';
          }

          // Thêm background layer để tránh mảng đen
          if (layers is List) {
            bool hasBackgroundLayer = false;
            for (var layer in layers) {
              if (layer is Map && layer['id'] == 'background') {
                hasBackgroundLayer = true;
                if (layer.containsKey('paint') && layer['paint'] is Map) {
                  layer['paint']['background-color'] = '#ffffff';
                }
                break;
              }
            }

            if (!hasBackgroundLayer) {
              layers.insert(0, {
                'id': 'background',
                'type': 'background',
                'paint': {'background-color': '#ffffff'},
              });
            }
          }
        }

        // Trả về style đã được chỉnh sửa
        return json.encode(styleJson);
      } catch (e) {
        debugPrint('Error parsing map style: $e');
        return _mapStyle!; // Trả về style gốc nếu có lỗi khi parse
      }
    }

    // Fallback style nếu chưa tải được từ API - sử dụng style raster đơn giản
    return '''
    {
      "version": 8,
      "sources": {
        "raster_vm": {
          "type": "raster",
          "tiles": [
            "https://maps.vietmap.vn/tm/{z}/{x}/{y}@2x.png?apikey=df5d9a3fffec4d07c7e3710bd0caf8181945d446509a3d42"
          ],
          "tileSize": 256,
          "attribution": "Vietmap@copyright"
        }
      },
      "layers": [
        {
          "id": "background",
          "type": "background",
          "paint": {
            "background-color": "#ffffff"
          }
        },
        {
          "id": "layer_raster_vm",
          "type": "raster",
          "source": "raster_vm",
          "minzoom": 0,
          "maxzoom": 17
        }
      ]
    }
    ''';
  }

  CameraPosition _getInitialCameraPosition() {
    // Lấy tất cả các điểm từ tất cả các đoạn đường
    List<LatLng> allPoints = [];
    for (var segment in _viewModel.routeSegments) {
      allPoints.addAll(segment);
    }

    if (allPoints.isNotEmpty) {
      // Tính toán trung tâm của tất cả các điểm
      double sumLat = 0;
      double sumLng = 0;
      for (var point in allPoints) {
        sumLat += point.latitude;
        sumLng += point.longitude;
      }
      final centerLat = sumLat / allPoints.length;
      final centerLng = sumLng / allPoints.length;

      // Trả về vị trí camera
      return CameraPosition(target: LatLng(centerLat, centerLng), zoom: 13.0);
    }

    // Mặc định ở TP.HCM
    return const CameraPosition(
      target: LatLng(10.762317, 106.654551),
      zoom: 13.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mô phỏng dẫn đường'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white, // Nền trắng cho toàn bộ container
              child: Stack(
                fit: StackFit.expand, // Đảm bảo các widget con mở rộng đầy đủ
                children: [
                  // Map
                  if (!_isLoadingMapStyle)
                    SizedBox.expand(
                      // Sử dụng SizedBox.expand để bao phủ toàn màn hình
                      child: VietmapGL(
                        styleString: _getMapStyleString(),
                        initialCameraPosition: _getInitialCameraPosition(),
                        myLocationEnabled:
                            false, // Tắt vị trí hiện tại mặc định
                        myLocationTrackingMode:
                            MyLocationTrackingMode.values[0],
                        myLocationRenderMode: MyLocationRenderMode.values[0],
                        trackCameraPosition: true,
                        onMapCreated: _onMapCreated,
                        onMapRenderedCallback: _onMapRendered,
                        onStyleLoadedCallback: _onStyleLoaded,
                        rotateGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        zoomGesturesEnabled: true,
                        doubleClickZoomEnabled: true,
                        cameraTargetBounds: CameraTargetBounds.unbounded,
                      ),
                    ),

                  // Bỏ UserLocationLayer - Không hiển thị vòng tròn xanh

                  // Vehicle marker
                  if (_mapController != null &&
                      _viewModel.currentLocation != null &&
                      _isMapReady &&
                      _isMapInitialized)
                    MarkerLayer(
                      mapController: _mapController!,
                      markers: [
                        Marker(
                          child: Transform.rotate(
                            angle:
                                (_viewModel.currentBearing ?? 0) *
                                (3.14159265359 / 180),
                            child: const Icon(
                              Icons.local_shipping,
                              color: AppColors.primary,
                              size: 30,
                            ),
                          ),
                          latLng: _viewModel.currentLocation!,
                        ),
                      ],
                      ignorePointer: true,
                    ),

                  // Action buttons
                  Positioned(
                    top: 16.h,
                    right: 16.w,
                    child: Column(
                      children: [
                        // Report issue button
                        FloatingActionButton(
                          onPressed: _reportIssue,
                          backgroundColor: Colors.white,
                          mini: true,
                          heroTag: 'report',
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: 8.h),

                        // Toggle 3D mode button
                        FloatingActionButton(
                          onPressed: _toggle3DMode,
                          backgroundColor: Colors.white,
                          mini: true,
                          heroTag: '3d',
                          child: Icon(
                            _is3DMode ? Icons.view_in_ar : Icons.map,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 8.h),

                        // Toggle follow user button
                        FloatingActionButton(
                          onPressed: _toggleFollowUser,
                          backgroundColor: Colors.white,
                          mini: true,
                          heroTag: 'follow',
                          child: Icon(
                            _isFollowingUser
                                ? Icons.gps_fixed
                                : Icons.gps_not_fixed,
                            color: _isFollowingUser
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Waypoint info
                  if (_viewModel.isAtWaypoint)
                    Positioned(
                      top: 16.h,
                      left: 16.w,
                      child: Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã đến ${_getVietnameseName(_viewModel.currentWaypointName)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_viewModel.nextWaypointName.isNotEmpty) ...[
                              SizedBox(height: 4.h),
                              Text(
                                'Tiếp theo: ${_getVietnameseName(_viewModel.nextWaypointName)}',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                            SizedBox(height: 8.h),
                            ElevatedButton(
                              onPressed: () {
                                _viewModel.continueToNextSegment();
                                _drawRoutes();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 6.h,
                                ),
                                minimumSize: Size(100.w, 30.h),
                              ),
                              child: const Text('Tiếp tục'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Chú thích
                  Positioned(
                    bottom: 8.r,
                    right: 8.r,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.r,
                        vertical: 4.r,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _routeColors.length,
                          (index) => Padding(
                            padding: EdgeInsets.only(
                              right: index < _routeColors.length - 1 ? 8.w : 0,
                            ),
                            child: _buildLegendItemHorizontal(
                              _routeColors[index],
                              _shortRouteNames[index],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Loading indicator for map style
                  if (_isLoadingMapStyle)
                    Container(
                      color: Colors.white,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 16),
                            Text('Đang tải bản đồ...'),
                          ],
                        ),
                      ),
                    ),

                  // Loading indicator for map initialization
                  if (!_isLoadingMapStyle &&
                      (!_isMapReady || !_isMapInitialized))
                    Container(
                      color: Colors.white.withOpacity(0.7),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                  // Error message
                  if (_hasError)
                    Container(
                      color: Colors.white.withOpacity(0.9),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 48.r,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Không thể hiển thị bản đồ',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _errorMessage,
                              style: AppTextStyles.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16.h),
                            ElevatedButton(
                              onPressed: () {
                                if (!_isDisposed) {
                                  setState(() {
                                    _hasError = false;
                                    _isMapReady = false;
                                    _isMapInitialized = false;
                                    _isLoadingMapStyle = true;
                                  });
                                  _loadMapStyle();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Controls
          Container(
            padding: EdgeInsets.all(16.r),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current segment info
                Text(
                  'Đoạn đường hiện tại: ${_getSegmentName(_viewModel.currentSegmentIndex)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),

                // Speed control
                Row(
                  children: [
                    const Text('Tốc độ:'),
                    Expanded(
                      child: Slider(
                        value: _simulationSpeed,
                        min: 0.5,
                        max: 5.0,
                        divisions: 9,
                        label: '${_simulationSpeed.toStringAsFixed(1)}x',
                        onChanged: _updateSimulationSpeed,
                      ),
                    ),
                    Text('${_simulationSpeed.toStringAsFixed(1)}x'),
                  ],
                ),

                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isPaused
                          ? _startSimulation
                          : _pauseSimulation,
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      label: Text(_isPaused ? 'Bắt đầu' : 'Tạm dừng'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isPaused ? null : _resumeSimulation,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Tiếp tục'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Reset flag trước khi gọi _resetSimulation
                        setState(() {
                          _hasResetBeenCalled = false;
                        });
                        _resetSimulation();
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('Đặt lại'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSegmentName(int index) {
    switch (index) {
      case 0:
        return 'Kho → Lấy hàng';
      case 1:
        return 'Lấy hàng → Giao hàng';
      case 2:
        return 'Giao hàng → Kho';
      default:
        return 'Không xác định';
    }
  }

  Widget _buildLegendItemHorizontal(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 3.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5.r),
          ),
        ),
        SizedBox(width: 4.w),
        Text(text, style: AppTextStyles.bodySmall.copyWith(fontSize: 10.sp)),
      ],
    );
  }

  // Bắt đầu theo dõi vị trí
  Future<bool> _startLocationTracking() async {
    if (_isLocationTrackingActive) return true;

    setState(() {
      _locationTrackingStatus = 'Đang kết nối...';
    });

    try {
      // Lấy thông tin xe từ sample order data
      final orderJson = _viewModel.sampleOrderData['data']['order'];
      final orderDetails = orderJson['orderDetails'][0];
      final vehicleAssignment = orderDetails['vehicleAssignment'];
      final vehicle = vehicleAssignment['vehicle'];

      if (vehicle == null) {
        setState(() {
          _locationTrackingStatus = 'Lỗi: Không có thông tin xe';
        });
        return false;
      }

      final vehicleId = vehicle['id'];
      final licensePlate = vehicle['licensePlateNumber'];

      // Đảm bảo kết nối WebSocket thành công trước khi tiếp tục
      final success = await _locationTrackingService.startTracking(
        vehicleId: vehicleId,
        licensePlateNumber: licensePlate,
        onLocationUpdate: (data) {
          // Xử lý dữ liệu vị trí nhận được
          debugPrint('📍 Nhận vị trí từ server: $data');
        },
        onError: (error) {
          setState(() {
            _locationTrackingStatus = 'Lỗi: $error';
            _isLocationTrackingActive = false;
          });
        },
      );

      setState(() {
        _isLocationTrackingActive = success;
        _locationTrackingStatus = success
            ? 'Đã kết nối và đang theo dõi'
            : 'Kết nối thất bại';
      });

      return success;
    } catch (e) {
      setState(() {
        _locationTrackingStatus = 'Lỗi: $e';
        _isLocationTrackingActive = false;
      });
      return false;
    }
  }

  // Dừng theo dõi vị trí
  Future<void> _stopLocationTracking() async {
    if (!_isLocationTrackingActive) return;

    try {
      await _locationTrackingService.stopTracking();

      if (!_isDisposed) {
        setState(() {
          _isLocationTrackingActive = false;
          _locationTrackingStatus = 'Đã ngắt kết nối';
        });
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _locationTrackingStatus = 'Lỗi khi ngắt kết nối: $e';
        });
      }
    }
  }

  // Gửi vị trí hiện tại
  void _sendCurrentLocation() {
    if (!_isLocationTrackingActive || _viewModel.currentLocation == null)
      return;

    _locationTrackingService.sendLocation(
      _viewModel.currentLocation!,
      bearing: _viewModel.currentBearing,
    );
  }
}
