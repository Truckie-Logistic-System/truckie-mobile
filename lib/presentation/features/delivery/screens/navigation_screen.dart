import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/integrated_location_service.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../viewmodels/navigation_viewmodel.dart';

class NavigationScreen extends StatefulWidget {
  final String orderId;
  final bool isSimulationMode;

  const NavigationScreen({
    Key? key,
    required this.orderId,
    this.isSimulationMode = false,
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final NavigationViewModel _viewModel;
  late final IntegratedLocationService _integratedLocationService;

  VietmapController? _mapController;
  String? _mapStyle;
  bool _isMapReady = false;
  bool _isMapInitialized = false;
  bool _isLoadingMapStyle = true;
  bool _isFollowingUser = true;
  bool _isConnectingWebSocket = false;
  bool _isSimulating = false;
  bool _isTripComplete = false;

  // Simulation controls (only used in simulation mode)
  double _simulationSpeed = 1.0;
  bool _isPaused = false;

  int _cameraUpdateCounter = 0;
  final int _cameraUpdateFrequency = 1; // Update camera every frame

  // Biến để theo dõi chế độ 3D
  bool _is3DMode = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🔧 NavigationScreen.initState()');
    debugPrint('   - orderId: ${widget.orderId}');
    debugPrint('   - isSimulationMode: ${widget.isSimulationMode}');
    
    _viewModel = getIt<NavigationViewModel>();
    _integratedLocationService = IntegratedLocationService.instance;
    
    debugPrint('   - Integrated tracking active: ${_integratedLocationService.isActive}');
    debugPrint('   - Route segments: ${_viewModel.routeSegments.length}');

    _loadMapStyle();
    
    // Only load order details if we don't have route data yet
    if (_viewModel.routeSegments.isEmpty) {
      debugPrint('   - Loading order details...');
      _loadOrderDetails();
    } else {
      debugPrint('✅ Route data already loaded, skipping reload');
    }
    
    // Check if viewModel is already simulating (returning to active simulation)
    // Only set _isSimulating if viewModel confirms it's running
    if (_viewModel.isSimulating && widget.isSimulationMode) {
      debugPrint('   - ViewModel is simulating, setting _isSimulating = true');
      _isSimulating = true;
    } else {
      debugPrint('   - ViewModel not simulating, _isSimulating = false');
    }
  }

  @override
  void dispose() {
    // IMPORTANT: Don't stop tracking when just navigating away
    // Only stop when explicitly requested (trip complete, cancel, etc.)
    // This allows user to go back to order detail and return to navigation
    
    // Only stop if trip is complete
    if (_isTripComplete) {
      debugPrint('🏁 Trip complete, stopping tracking');
      _stopLocationTracking();
      _viewModel.resetNavigation();
    } else {
      debugPrint('🔄 Navigation screen disposed but tracking continues in background');
      // Keep tracking active for when user returns
    }
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    setState(() {
      _isLoadingMapStyle = true;
    });

    try {
      final style = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/map_style/vietmap_style.json');
      setState(() {
        _mapStyle = style;
        _isLoadingMapStyle = false;
      });
    } catch (e) {
      debugPrint('Error loading map style: $e');
      setState(() {
        _isLoadingMapStyle = false;
      });
    }
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

  Future<void> _loadOrderDetails() async {
    try {
      // Tải dữ liệu order từ API
      await _viewModel.getOrderDetails(widget.orderId);

      if (_viewModel.orderWithDetails != null) {
        debugPrint('✅ Tải thông tin order thành công: ${widget.orderId}');
        _viewModel.parseRouteFromOrder(_viewModel.orderWithDetails!);

        // Kiểm tra xem đã parse được route chưa
        if (_viewModel.routeSegments.isEmpty) {
          debugPrint('⚠️ Không thể parse được route từ order, thử tải lại');
          // Thử tải lại dữ liệu
          await Future.delayed(const Duration(seconds: 1));
          await _viewModel.getOrderDetails(widget.orderId);
          if (_viewModel.orderWithDetails != null) {
            _viewModel.parseRouteFromOrder(_viewModel.orderWithDetails!);
          }
        }
      } else {
        debugPrint('❌ Không thể tải thông tin order: ${widget.orderId}');
        // Hiển thị thông báo lỗi
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể tải thông tin lộ trình. Vui lòng thử lại sau.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi tải thông tin order: $e');
      // Hiển thị thông báo lỗi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onMapCreated(VietmapController controller) {
    _mapController = controller;
  }

  void _onMapRendered() {
    setState(() {
      _isMapReady = true;
    });
  }

  void _onStyleLoaded() {
    debugPrint('🗺️ _onStyleLoaded called');
    setState(() {
      _isMapInitialized = true;
    });

    // Đảm bảo đã tải xong dữ liệu order trước khi vẽ route
    debugPrint('   - Route segments empty: ${_viewModel.routeSegments.isEmpty}');
    if (_viewModel.routeSegments.isEmpty) {
      debugPrint('⚠️ Chưa có dữ liệu route, đang tải lại...');
      _loadOrderDetails().then((_) {
        if (_viewModel.routeSegments.isNotEmpty) {
          _drawRoutes();

          // Đặt camera vào vị trí thích hợp
          if (_viewModel.routeSegments[0].points.isNotEmpty) {
            _setCameraToNavigationMode(
              _viewModel.routeSegments[0].points.first,
            );
          }

          // Start real tracking or simulation based on mode
          // Priority: Check simulation mode first
          if (widget.isSimulationMode && !_isSimulating) {
            debugPrint('🎬 Starting simulation mode (after loading order)');
            // DON'T stop tracking - keep WebSocket alive for simulation
            // Simulation will use the same WebSocket connection
            _showSimulationDialog();
          } else if (!widget.isSimulationMode && !_integratedLocationService.isActive) {
            _startRealTimeNavigation();
          } else if (_isSimulating) {
            // Resume existing simulation
            _resumeSimulation();
          }
        } else {
          debugPrint('❌ Không thể tải dữ liệu route');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Không thể tải thông tin lộ trình. Vui lòng kiểm tra lại thông tin đơn hàng.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Quay lại',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          );

          // Quay lại màn hình trước sau 5 giây
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      });
    } else {
      debugPrint('✅ Route data available, drawing routes...');
      _drawRoutes();

      // Đặt camera vào vị trí thích hợp
      // Use current location if available, otherwise use first point
      if (_viewModel.currentLocation != null) {
        debugPrint('📍 Setting camera to current location');
        _setCameraToNavigationMode(_viewModel.currentLocation!);
      } else if (_viewModel.routeSegments[0].points.isNotEmpty) {
        debugPrint('📍 Setting camera to first point');
        _setCameraToNavigationMode(_viewModel.routeSegments[0].points.first);
      }

      // Start real tracking or simulation based on mode
      // Priority: Check simulation mode first, then check existing connections
      debugPrint('🔍 Checking navigation mode:');
      debugPrint('   - widget.isSimulationMode: ${widget.isSimulationMode}');
      debugPrint('   - _isSimulating: $_isSimulating');
      debugPrint('   - _isPaused: $_isPaused');
      debugPrint('   - Integrated tracking active: ${_integratedLocationService.isActive}');
      
      if (widget.isSimulationMode && !_isSimulating) {
        debugPrint('🎬 Starting simulation mode (isSimulationMode=true, _isSimulating=false)');
        // DON'T stop tracking - keep WebSocket alive for simulation
        // Simulation will use the same WebSocket connection
        _showSimulationDialog();
      } else if (!widget.isSimulationMode && !_integratedLocationService.isActive) {
        debugPrint('🚗 Starting real-time navigation');
        _startRealTimeNavigation();
      } else if (_isSimulating && _isPaused) {
        debugPrint('⏸️ Simulation paused, showing resume dialog');
        // Simulation is paused (returned from order detail), show dialog to continue
        _showResumeSimulationDialog();
      } else if (_isSimulating) {
        debugPrint('▶️ Resuming existing simulation');
        // Resume existing simulation
        _resumeSimulation();
      } else if (_integratedLocationService.isActive) {
        debugPrint('🔗 Integrated tracking already active, continuing...');
        // WebSocket is connected, just update camera
        if (_viewModel.currentLocation != null) {
          _setCameraToNavigationMode(_viewModel.currentLocation!);
        }
      } else {
        debugPrint('⚠️ No condition matched!');
      }
    }
  }

  CameraPosition _getInitialCameraPosition() {
    if (_viewModel.routeSegments.isNotEmpty &&
        _viewModel.routeSegments[0].points.isNotEmpty) {
      final firstPoint = _viewModel.routeSegments[0].points.first;
      return CameraPosition(target: firstPoint, zoom: 15.0);
    }

    // Default to Ho Chi Minh City
    return const CameraPosition(
      target: LatLng(10.762317, 106.654551),
      zoom: 13.0,
    );
  }

  Future<void> _startRealTimeNavigation() async {
    if (_viewModel.routeSegments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có dữ liệu lộ trình'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _startLocationTracking();
  }

  Future<bool> _startLocationTracking() async {
    if (_isConnectingWebSocket) return false;

    setState(() {
      _isConnectingWebSocket = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Đang kết nối'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Đang khởi động enhanced location tracking...'),
          ],
        ),
      ),
    );

    try {
      debugPrint('🚀 Starting enhanced location tracking...');
      
      // Use IntegratedLocationService for enhanced tracking
      final success = await _integratedLocationService.startTracking(
        vehicleId: _viewModel.currentVehicleId,
        licensePlateNumber: _viewModel.currentLicensePlateNumber,
        enableBackgroundTracking: true, // Enable background tracking
        onLocationUpdate: (data) {
          debugPrint('📍 Enhanced location update: $data');
          
          // Update current location in viewModel
          final lat = data['latitude'] as double?;
          final lng = data['longitude'] as double?;
          
          if (lat != null && lng != null) {
            final location = LatLng(lat, lng);
            
            // Update viewModel's current location
            _viewModel.currentLocation = location;
            
            // Update camera if following user
            if (_isFollowingUser && mounted) {
              _setCameraToNavigationMode(location);
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Enhanced tracking error: $error');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi tracking: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (success) {
        debugPrint('✅ Enhanced location tracking started successfully');
        
        // Listen to tracking statistics (optional)
        _integratedLocationService.statsStream.listen((stats) {
          debugPrint('📊 Tracking Stats:');
          debugPrint('   - Success rate: ${(stats.successRate * 100).toStringAsFixed(1)}%');
          debugPrint('   - Queue size: ${stats.queueSize}');
          debugPrint('   - Total sent: ${stats.successfulSends}');
          debugPrint('   - Throttled: ${stats.throttledUpdates}');
          debugPrint('   - Rejected (quality): ${stats.rejectedByQuality}');
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Enhanced tracking started with GPS throttling & offline support'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        debugPrint('❌ Failed to start enhanced location tracking');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể khởi động location tracking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _isConnectingWebSocket = false;
        });
      }

      return success;
    } catch (e) {
      debugPrint('❌ Exception starting enhanced tracking: $e');
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối: $e'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isConnectingWebSocket = false;
        });
      }

      return false;
    }
  }

  /// Stop location tracking
  /// ⚠️ CRITICAL: Only call this when trip is COMPLETE
  /// Do NOT call when:
  /// - Navigating back to order detail
  /// - Switching between real-time and simulation
  /// - Pausing navigation
  /// WebSocket must stay alive until trip is finished!
  Future<void> _stopLocationTracking() async {
    debugPrint('🛑 Stopping location tracking...');
    debugPrint('⚠️ This should ONLY be called when trip is complete!');
    
    // Stop integrated location service if active
    if (_integratedLocationService.isActive) {
      await _integratedLocationService.stopTracking();
      debugPrint('✅ IntegratedLocationService stopped');
    }
    
    // Note: Only IntegratedLocationService is used now
    debugPrint('✅ All location services stopped');
  }

  void _drawRoutes() {
    if (_mapController == null || _viewModel.routeSegments.isEmpty) return;

    // Clear existing routes
    _mapController!.clearPolylines();
    _mapController!.clearCircles();
    _mapController!.clearSymbols();

    // Danh sách tất cả các điểm để tính toán bounds
    List<LatLng> allPoints = [];

    // Draw all segments with different colors
    for (int i = 0; i < _viewModel.routeSegments.length; i++) {
      final segment = _viewModel.routeSegments[i];
      final isCurrentSegment = i == _viewModel.currentSegmentIndex;

      // Lấy màu cho đoạn đường này
      final Color color;
      switch (i) {
        case 0:
          color = AppColors.primary; // Màu xanh dương cho đoạn 1
          break;
        case 1:
          color = Colors.green; // Màu xanh lá cho đoạn 2
          break;
        case 2:
          color = Colors.orange; // Màu cam cho đoạn 3
          break;
        default:
          color = isCurrentSegment ? AppColors.primary : Colors.grey;
      }

      // Tối ưu hóa: giảm số điểm cần vẽ nếu quá nhiều
      List<LatLng> optimizedPoints = segment.points;
      if (segment.points.length > 100) {
        optimizedPoints = _simplifyRoute(segment.points);
      }

      // Thêm điểm vào danh sách tất cả các điểm
      allPoints.addAll(optimizedPoints);

      // Draw line for this segment
      _mapController!.addPolyline(
        PolylineOptions(
          geometry: optimizedPoints,
          polylineColor: color,
          polylineWidth: isCurrentSegment ? 5.0 : 3.0,
          polylineOpacity: isCurrentSegment ? 1.0 : 0.6,
        ),
      );

      // Draw circles for start and end points of each segment
      if (optimizedPoints.isNotEmpty) {
        // Start point
        _mapController!.addCircle(
          CircleOptions(
            geometry: optimizedPoints.first,
            circleRadius: isCurrentSegment ? 6.0 : 5.0,
            circleColor: color,
            circleStrokeWidth: 1.0,
            circleStrokeColor: Colors.white,
            circleOpacity: isCurrentSegment ? 1.0 : 0.7,
          ),
        );

        // End point
        _mapController!.addCircle(
          CircleOptions(
            geometry: optimizedPoints.last,
            circleRadius: isCurrentSegment ? 6.0 : 5.0,
            circleColor: color,
            circleStrokeWidth: 1.0,
            circleStrokeColor: Colors.white,
            circleOpacity: isCurrentSegment ? 1.0 : 0.7,
          ),
        );

        // Intermediate points (smaller circles) - chỉ vẽ cho đoạn đường hiện tại
        if (isCurrentSegment) {
          // Chỉ vẽ một số điểm trung gian để tránh quá nhiều điểm
          int step = (optimizedPoints.length / 10).ceil();
          step = step < 1 ? 1 : step;

          for (int j = step; j < optimizedPoints.length - step; j += step) {
            _mapController!.addCircle(
              CircleOptions(
                geometry: optimizedPoints[j],
                circleRadius: 4.0,
                circleColor: color,
                circleStrokeWidth: 1.0,
                circleStrokeColor: Colors.white,
                circleOpacity: 0.7,
              ),
            );
          }
        }
      }
    }

    // If not following user, fit map to show all route points
    if (!_isFollowingUser && allPoints.length > 1) {
      double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;

      for (final point in allPoints) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }

      // No padding to avoid green area
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          left: 0,
          top: 0,
          right: 0,
          bottom: 0,
        ),
      );
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

  void _updateCameraPosition(LatLng location, double? bearing) {
    if (_mapController == null || !_isFollowingUser) return;

    _cameraUpdateCounter++;

    // Update camera position to follow user's location
    if (_cameraUpdateCounter % _cameraUpdateFrequency == 0) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 16.0,
            bearing: bearing ?? 0.0,
            tilt: 45.0, // Thêm góc nghiêng để có trải nghiệm 3D tốt hơn
          ),
        ),
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  void _showSimulationDialog() {
    debugPrint('🎭 _showSimulationDialog called');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chế độ mô phỏng'),
        content: const Text('Bạn có muốn bắt đầu mô phỏng di chuyển xe không?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startSimulation();
            },
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }

  void _showResumeSimulationDialog() {
    debugPrint('🎭 _showResumeSimulationDialog called');
    
    // Get current segment name for context
    final currentSegment = _viewModel.getCurrentSegmentName();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tiếp tục mô phỏng'),
        content: Text(
          'Bạn đã hoàn thành xác nhận.\n\n'
          'Đoạn đường tiếp theo: $currentSegment\n\n'
          'Bạn có muốn tiếp tục mô phỏng di chuyển không?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Stay paused, user can manually resume later
            },
            child: const Text('Để sau'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resumeSimulation();
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  Future<void> _startSimulation() async {
    if (_isSimulating) {
      debugPrint('⚠️ Simulation already running');
      return;
    }

    debugPrint('🎬 Starting simulation...');
    
    // Reset any existing simulation in viewModel
    _viewModel.pauseSimulation();
    
    // Connect to WebSocket first
    final connected = await _startLocationTracking();
    if (!connected) {
      debugPrint('❌ Failed to connect WebSocket');
      return;
    }

    debugPrint('✅ WebSocket connected, waiting for stabilization...');
    // Wait a moment for WebSocket connection to stabilize
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _isSimulating = true;
      _isPaused = false;
    });

    debugPrint('▶️ Starting actual simulation...');
    // Start the simulation
    _startActualSimulation();
  }

  void _startActualSimulation() {
    debugPrint('🚀 _startActualSimulation called');
    
    // Ensure we're following the vehicle
    setState(() {
      _isFollowingUser = true;
    });

    // Start the simulation with callbacks
    _viewModel.startSimulation(
      onLocationUpdate: (location, bearing) {
        debugPrint('📍 Location update: ${location.latitude}, ${location.longitude}, bearing: $bearing');
        
        // Update camera to follow vehicle
        if (_isFollowingUser) {
          _setCameraToNavigationMode(location);
        }

        // Send location update via IntegratedLocationService
        _integratedLocationService.sendLocationUpdate(location, bearing: bearing);
      },
      onSegmentComplete: (segmentIndex, isLastSegment) {
        debugPrint('✅ Segment $segmentIndex complete, isLast: $isLastSegment');
        
        // Pause simulation when reaching any waypoint
        _pauseSimulation();
        _drawRoutes();

        if (isLastSegment) {
          // Reached final destination (Carrier)
          _showCompletionMessage();
        } else if (segmentIndex == 0) {
          // Completed segment 0: Reached Pickup location
          _showPickupMessage();
        } else if (segmentIndex == 1) {
          // Completed segment 1: Reached Delivery location
          _showDeliveryMessage();
        }
      },
      simulationSpeed:
          _simulationSpeed * 0.7, // Slow down for better experience
    );
    
    debugPrint('✅ Simulation started with speed: ${_simulationSpeed * 0.7}');
  }

  void _pauseSimulation() {
    debugPrint('⏸️ _pauseSimulation called');
    debugPrint('   - _isSimulating: $_isSimulating');
    debugPrint('   - _isPaused: $_isPaused');
    
    if (!_isSimulating || _isPaused) {
      debugPrint('❌ Cannot pause: _isSimulating=$_isSimulating, _isPaused=$_isPaused');
      return;
    }

    setState(() {
      _isPaused = true;
    });
    
    debugPrint('✅ State updated: _isPaused=true');

    _viewModel.pauseSimulation();
    
    debugPrint('✅ ViewModel.pauseSimulation() called');
  }

  void _resumeSimulation() async {
    debugPrint('🔄 _resumeSimulation called');
    debugPrint('   - _isSimulating: $_isSimulating');
    debugPrint('   - _isPaused: $_isPaused');
    debugPrint('   - ViewModel.isSimulating: ${_viewModel.isSimulating}');
    
    // If simulation is running and not paused, just continue
    if (_isSimulating && !_isPaused) {
      debugPrint('✅ Simulation already running, just refocusing camera');
      // Refocus camera on current position
      if (_viewModel.currentLocation != null) {
        _setCameraToNavigationMode(_viewModel.currentLocation!);
      }
      return;
    }

    if (!_isSimulating || !_isPaused) {
      debugPrint('❌ Cannot resume: _isSimulating=$_isSimulating, _isPaused=$_isPaused');
      return;
    }

    debugPrint('▶️ Resuming simulation...');

    // Ensure integrated tracking is active
    if (!_integratedLocationService.isActive) {
      debugPrint('⚠️ Integrated tracking not active, starting...');
      final connected = await _startLocationTracking();
      if (!connected) {
        debugPrint('❌ Failed to start tracking');
        return;
      }

      // Wait for WebSocket connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isPaused = false;
      _isFollowingUser = true;
    });
    
    debugPrint('✅ State updated: _isPaused=false');

    _viewModel.resumeSimulation();
    
    debugPrint('✅ ViewModel.resumeSimulation() called');

    // Refocus camera on current position
    if (_viewModel.currentLocation != null) {
      _setCameraToNavigationMode(_viewModel.currentLocation!);
      debugPrint('✅ Camera refocused');
    }
    
    debugPrint('✅ Resume complete');
  }

  void _resetSimulation() {
    debugPrint('🔄 Resetting simulation...');
    
    setState(() {
      _isSimulating = false;
      _isPaused = false;
    });

    _viewModel.resetNavigation();

    if (_viewModel.orderWithDetails != null) {
      _viewModel.parseRouteFromOrder(_viewModel.orderWithDetails!);
      _drawRoutes();
      
      // Focus camera back to starting position
      if (_viewModel.routeSegments.isNotEmpty && 
          _viewModel.routeSegments[0].points.isNotEmpty) {
        final startPoint = _viewModel.routeSegments[0].points.first;
        debugPrint('📍 Focusing camera to start position: ${startPoint.latitude}, ${startPoint.longitude}');
        _setCameraToNavigationMode(startPoint);
      }
    }
  }

  void _reportIncident() {
    // TODO: Implement incident reporting logic
    debugPrint('⚠️ Report incident button pressed');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Báo cáo sự cố'),
          ],
        ),
        content: const Text(
          'Chức năng báo cáo sự cố đang được phát triển.\n\n'
          'Bạn sẽ có thể báo cáo các vấn đề như:\n'
          '• Tai nạn giao thông\n'
          '• Hỏng xe\n'
          '• Thời tiết xấu\n'
          '• Vấn đề với hàng hóa\n'
          '• Khác',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showPickupMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Đã đến điểm lấy hàng'),
        content: const Text(
          'Bạn đã đến điểm lấy hàng. Vui lòng xác nhận hàng hóa và seal.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to order detail screen
              Navigator.of(context).pushNamed(
                AppRoutes.orderDetail,
                arguments: widget.orderId,
              );
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _showDeliveryMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Đã đến điểm giao hàng'),
        content: const Text(
          'Bạn đã đến điểm giao hàng. Vui lòng giao hàng và xác nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to order detail screen
              Navigator.of(context).pushNamed(
                AppRoutes.orderDetail,
                arguments: widget.orderId,
              );
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _showCompletionMessage() {
    // Mark trip as complete and stop WebSocket tracking
    setState(() {
      _isTripComplete = true;
    });
    _stopLocationTracking();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Hoàn thành chuyến xe'),
        content: const Text('Bạn đã hoàn thành chuyến xe thành công!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Pop back to order detail screen
              Navigator.of(context).pop();
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _toggle3DMode() {
    setState(() {
      _is3DMode = !_is3DMode;
    });

    if (_viewModel.currentLocation != null) {
      _setCameraToNavigationMode(_viewModel.currentLocation!);
    }
  }

  void _setCameraToNavigationMode(LatLng position) {
    if (_mapController == null) return;

    // Giảm tốc độ chuyển camera để tránh tải quá nhiều tile
    final duration = const Duration(milliseconds: 1000);

    if (_is3DMode) {
      // Chế độ 3D: tilt cao (45 độ), zoom gần hơn và bearing theo hướng di chuyển
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 16.0,
            bearing: _viewModel.currentBearing ?? 0.0,
            tilt: 45.0,
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // When back button is pressed, go to order detail instead of order list
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.orderDetail,
          arguments: widget.orderId,
        );
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dẫn đường'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Navigate to order detail when back button is pressed
              Navigator.of(context).pushReplacementNamed(
                AppRoutes.orderDetail,
                arguments: widget.orderId,
              );
            },
          ),
          actions: [
          // Button to toggle following mode
          IconButton(
            icon: Icon(
              _isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed,
            ),
            onPressed: () {
              setState(() {
                _isFollowingUser = !_isFollowingUser;
                if (_isFollowingUser && _viewModel.currentLocation != null) {
                  _updateCameraPosition(
                    _viewModel.currentLocation!,
                    _viewModel.currentBearing,
                  );
                }
              });
            },
            tooltip: _isFollowingUser ? 'Đang theo dõi' : 'Không theo dõi',
          ),
        ],
      ),
      body: Column(
        children: [
          // Route info panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đoạn đường: ${_viewModel.getCurrentSegmentName()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tốc độ: ${_viewModel.currentSpeed.toStringAsFixed(1)} km/h',
                      ),
                    ],
                  ),
                ),
                if (!widget.isSimulationMode)
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to simulation mode
                      Navigator.of(context).pushReplacementNamed(
                        AppRoutes.navigation,
                        arguments: {
                          'orderId': widget.orderId,
                          'isSimulationMode': true,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: const Text('Mô phỏng'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!_isLoadingMapStyle)
                    SizedBox.expand(
                      child: VietmapGL(
                        styleString: _getMapStyleString(),
                        initialCameraPosition: _getInitialCameraPosition(),
                        myLocationEnabled: false,
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

                  // Loading indicator
                  if (_isLoadingMapStyle)
                    const Center(child: CircularProgressIndicator()),

                  // Route info overlay
                  if (_viewModel.routeSegments.isNotEmpty)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
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
                            for (
                              int i = 0;
                              i < _viewModel.routeSegments.length;
                              i++
                            )
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color:
                                            i == _viewModel.currentSegmentIndex
                                            ? AppColors.primary
                                            : Colors.grey,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _viewModel.routeSegments[i].name,
                                      style: TextStyle(
                                        fontWeight:
                                            i == _viewModel.currentSegmentIndex
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color:
                                            i == _viewModel.currentSegmentIndex
                                            ? AppColors.primary
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Action buttons
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      children: [
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
                        const SizedBox(height: 8),

                        // Toggle follow user button
                        FloatingActionButton(
                          onPressed: () {
                            setState(() {
                              _isFollowingUser = !_isFollowingUser;
                              if (_isFollowingUser &&
                                  _viewModel.currentLocation != null) {
                                _setCameraToNavigationMode(
                                  _viewModel.currentLocation!,
                                );
                              }
                            });
                          },
                          backgroundColor: Colors.white,
                          mini: true,
                          heroTag: 'follow',
                          child: Icon(
                            _isFollowingUser
                                ? Icons.gps_fixed
                                : Icons.gps_not_fixed,
                            color: _isFollowingUser
                                ? AppColors.success
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Report incident button
                        FloatingActionButton(
                          onPressed: _reportIncident,
                          backgroundColor: Colors.red,
                          mini: true,
                          heroTag: 'incident',
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Simulation controls (only visible in simulation mode)
          if (widget.isSimulationMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đoạn đường hiện tại: ${_viewModel.getCurrentSegmentName()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Tốc độ:'),
                      Expanded(
                        child: Slider(
                          value: _simulationSpeed,
                          min: 0.5,
                          max: 3.0,
                          divisions: 5,
                          label: '${_simulationSpeed.toStringAsFixed(1)}x',
                          onChanged: (value) {
                            setState(() {
                              _simulationSpeed = value;
                            });
                            if (_isSimulating && !_isPaused) {
                              _viewModel.updateSimulationSpeed(
                                _simulationSpeed * 0.7,
                              );
                            }
                          },
                        ),
                      ),
                      Text('${_simulationSpeed.toStringAsFixed(1)}x'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: !_isSimulating
                            ? _startSimulation
                            : (_isPaused
                                  ? _resumeSimulation
                                  : _pauseSimulation),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              !_isSimulating
                                  ? Icons.play_arrow
                                  : (_isPaused
                                        ? Icons.play_arrow
                                        : Icons.pause),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              !_isSimulating
                                  ? 'Bắt đầu'
                                  : (_isPaused ? 'Tiếp tục' : 'Tạm dừng'),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _resetSimulation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh),
                            SizedBox(width: 8),
                            Text('Đặt lại'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }
}
