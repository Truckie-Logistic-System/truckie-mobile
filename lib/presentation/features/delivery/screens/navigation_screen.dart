import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/entities/order_detail.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/global_location_manager.dart';
import '../../../../core/services/navigation_state_service.dart';
import '../../../../app/di/service_locator.dart';
import '../../../../data/datasources/api_client.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../presentation/features/orders/viewmodels/order_detail_viewmodel.dart';
import '../../../../presentation/utils/driver_role_checker.dart';
import '../viewmodels/navigation_viewmodel.dart';
import '../widgets/map/image_based_3d_truck_marker.dart';

class NavigationScreen extends StatefulWidget {
  final String orderId;
  final bool isSimulationMode;

  const NavigationScreen({
    super.key,
    required this.orderId,
    this.isSimulationMode = false,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> with WidgetsBindingObserver, RouteAware {
  late final NavigationViewModel _viewModel;
  late final GlobalLocationManager _globalLocationManager;
  late final AuthViewModel _authViewModel;

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

  // Custom marker for current location
  Symbol? _currentLocationMarker;
  
  // Waypoint markers list
  List<Marker> _waypointMarkers = [];

  // Throttle _drawRoutes to prevent buffer overflow
  DateTime? _lastDrawRoutesTime;
  static const _drawRoutesThrottleDuration = Duration(milliseconds: 500);

  // Removed didChangeDependencies - using Navigator result pattern instead

  @override
  void initState() {
    super.initState();
    debugPrint('🔧 NavigationScreen.initState()');
    debugPrint('   - orderId: ${widget.orderId}');
    debugPrint('   - isSimulationMode: ${widget.isSimulationMode}');

    _viewModel = getIt<NavigationViewModel>();
    _globalLocationManager = getIt<GlobalLocationManager>();
    _authViewModel = getIt<AuthViewModel>();

    // Register observers
    WidgetsBinding.instance.addObserver(this);

    // Register this screen with GlobalLocationManager
    _globalLocationManager.registerScreen('NavigationScreen');

    debugPrint(
      '   - Global tracking active: ${_globalLocationManager.isGlobalTrackingActive}',
    );
    debugPrint(
      '   - Global tracking active for order ${widget.orderId}: ${_globalLocationManager.isTrackingOrder(widget.orderId)}',
    );
    debugPrint('   - Route segments: ${_viewModel.routeSegments.length}');

    _loadMapStyle();

    // Check if viewModel is already simulating (returning to active simulation)
    // Only set _isSimulating if viewModel confirms it's running
    if (_viewModel.isSimulating && widget.isSimulationMode) {
      debugPrint('   - ViewModel is simulating, setting _isSimulating = true');
      _isSimulating = true;
      
      // CRITICAL: Check and resume immediately if already have route segments
      // Don't wait for _loadOrderDetails() which might be slow or fail
      if (_viewModel.routeSegments.isNotEmpty) {
        debugPrint('   - Route segments already loaded, checking resume immediately');
        _checkAndResumeAfterAction();
      }
    } else {
      debugPrint('   - ViewModel not simulating, _isSimulating = false');
    }

    // Load order details to ensure we have latest vehicle assignment info
    // This is important for determining isPrimaryDriver status
    debugPrint('   - Loading order details...');
    _loadOrderDetails().then((_) {
      // After loading, check if we need to auto-resume (in case segments weren't loaded before)
      if (_viewModel.routeSegments.isNotEmpty && _viewModel.isSimulating && !_isSimulating) {
        debugPrint('   - Route segments loaded after init, checking resume');
        _checkAndResumeAfterAction();
      }
    }).catchError((e) {
      debugPrint('   - Error loading order details: $e');
    });
  }
  
  // Check if we need to resume simulation after action confirmation
  void _checkAndResumeAfterAction() {
    debugPrint('🔍 Checking if need to resume after action...');
    debugPrint('   - _isSimulating: $_isSimulating');
    debugPrint('   - _isPaused: $_isPaused');
    debugPrint('   - ViewModel.isSimulating: ${_viewModel.isSimulating}');
    debugPrint('   - isSimulationMode: ${widget.isSimulationMode}');
    debugPrint('   - currentSegmentIndex: ${_viewModel.currentSegmentIndex}');
    debugPrint('   - currentLocation: ${_viewModel.currentLocation}');
    
    // CRITICAL: If ViewModel is simulating but screen state is not, sync immediately
    // This happens when NavigationScreen is recreated after action confirmation
    if (_viewModel.isSimulating && !_isSimulating) {
      debugPrint('⚠️ State mismatch: ViewModel is simulating but screen state is not');
      debugPrint('   🔄 Syncing screen state from ViewModel...');
      _isSimulating = true;
      _isPaused = false; // ViewModel is actively simulating, so NOT paused
      
      // IMPORTANT: Ensure timer is reset before resuming
      // This handles case where timer might still be active from previous session
      debugPrint('   🔄 Ensuring simulation timer is reset...');
      _viewModel.pauseSimulation(); // Cancel any existing timer
      
      // Reset _isSimulating flag so startSimulation can be called
      debugPrint('   🔄 Resetting _isSimulating flag...');
      _viewModel.resetSimulationFlag();
      
      // CRITICAL: Re-register callbacks since NavigationScreen was recreated
      // This ensures location updates and segment completion are handled properly
      debugPrint('   🔄 Re-registering simulation callbacks...');
      _viewModel.startSimulation(
        onLocationUpdate: (location, bearing) {
          debugPrint(
            '📍 Location update (resume): ${location.latitude}, ${location.longitude}, bearing: $bearing',
          );

          // Update custom location marker
          _updateLocationMarker(location, bearing);

          // Update camera to follow vehicle
          if (_isFollowingUser) {
            _setCameraToNavigationMode(location);
          }

          // Send location update via GlobalLocationManager with speed and segment
          _globalLocationManager.sendLocationUpdate(
            location.latitude,
            location.longitude,
            bearing: bearing,
            speed: _viewModel.currentSpeed,
            segmentIndex: _viewModel.currentSegmentIndex,
          );

          // Rebuild UI to update speed display
          if (mounted) {
            setState(() {});
          }
        },
        onSegmentComplete: (segmentIndex, isLastSegment) {
          debugPrint('✅ Segment $segmentIndex complete (resume), isLast: $isLastSegment');

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
        simulationSpeed: _viewModel.currentSimulationSpeed,
      );
      
      debugPrint('   ▶️ Simulation restarted with callbacks');
      return; // Exit early since we've already handled the resume
    }
    
    // If in simulation mode and paused (user manually paused), auto-resume
    if (widget.isSimulationMode && _isSimulating && _isPaused) {
      debugPrint('✅ Auto-resuming simulation after action confirmation (was paused)');
      
      // Check if we're at the end of a segment (just completed an action)
      final currentSegment = _viewModel.routeSegments.isNotEmpty && 
                            _viewModel.currentSegmentIndex < _viewModel.routeSegments.length
          ? _viewModel.routeSegments[_viewModel.currentSegmentIndex]
          : null;
      
      if (currentSegment != null && 
          _viewModel.currentLocation != null &&
          currentSegment.points.isNotEmpty) {
        final lastPoint = currentSegment.points.last;
        final isAtEndOfSegment = _viewModel.currentLocation == lastPoint;
        
        if (isAtEndOfSegment) {
          debugPrint('📍 At end of segment, moving to next segment before resume');
          _viewModel.moveToNextSegmentManually();
        }
      }
      
      // Delay to ensure UI is ready and map is loaded
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (mounted && _isPaused) {
          // Focus camera first
          if (_viewModel.currentLocation != null && _mapController != null) {
            debugPrint('📍 Pre-focusing camera before resume');
            await _setCameraToNavigationMode(_viewModel.currentLocation!);
            await Future.delayed(const Duration(milliseconds: 300));
          }
          
          // Then resume
          _resumeSimulation();
        }
      });
    }
  }

  @override
  VehicleAssignment? _getVehicleAssignmentFromOrderDetail(OrderWithDetails order) {
    if (order.orderDetails.isEmpty || order.vehicleAssignments.isEmpty) {
      return null;
    }

    // Get current user phone number
    final currentUserPhone = _authViewModel.driver?.userResponse.phoneNumber;
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

  void dispose() {
    // Clean up map resources to prevent buffer overflow
    try {
      if (_mapController != null) {
        _mapController!.clearPolylines();
        _mapController!.clearCircles();
        if (_currentLocationMarker != null) {
          _mapController!.removeSymbol(_currentLocationMarker!);
          _currentLocationMarker = null;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning up map resources: $e');
    }

    // Remove observers
    WidgetsBinding.instance.removeObserver(this);

    // Unregister this screen from GlobalLocationManager
    _globalLocationManager.unregisterScreen('NavigationScreen');

    // IMPORTANT: Don't stop tracking when just navigating away
    // Only stop when explicitly requested (trip complete, cancel, etc.)
    // This allows user to go back to order detail and return to navigation

    // Only stop if trip is complete
    if (_isTripComplete) {
      debugPrint('🏁 Trip complete, stopping global tracking');
      _globalLocationManager.stopGlobalTracking(reason: 'Trip completed');
      _viewModel.resetNavigation();
    } else {
      debugPrint(
        '🔄 Navigation screen disposed but global tracking continues in background',
      );
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
    debugPrint(
      '   - Route segments empty: ${_viewModel.routeSegments.isEmpty}',
    );
    if (_viewModel.routeSegments.isEmpty) {
      debugPrint('⚠️ Chưa có dữ liệu route, đang tải lại...');
      _loadOrderDetails().then((_) {
        if (_viewModel.routeSegments.isNotEmpty) {
          // Delay thêm để đảm bảo style đã load xong
          Future.delayed(const Duration(milliseconds: 500), () {
            _drawRoutes(clearFirst: true); // Clear on initial load
          });

          // Đặt camera vào vị trí thích hợp
          if (_viewModel.routeSegments[0].points.isNotEmpty) {
            _setCameraToNavigationMode(
              _viewModel.routeSegments[0].points.first,
            );
          }

          // Check if we should auto-restore simulation from saved state
          final stateService = getIt<NavigationStateService>();
          final savedState = stateService.getSavedNavigationState();
          final shouldAutoRestore = savedState != null && 
                                   savedState.orderId == widget.orderId &&
                                   savedState.isSimulationMode &&
                                   widget.isSimulationMode;

          // Start real tracking or simulation based on mode
          // Priority: Check simulation mode first
          if (widget.isSimulationMode && !_isSimulating) {
            if (shouldAutoRestore) {
              debugPrint('🔄 Auto-restoring simulation from saved state');
              // Auto-start simulation WITH restore
              _startSimulation(shouldRestore: true);
            } else {
              debugPrint('🎬 Starting simulation mode (after loading order)');
              // Show dialog for new simulation
              _showSimulationDialog();
            }
          } else if (!widget.isSimulationMode &&
              !_globalLocationManager.isGlobalTrackingActive) {
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
      // Delay to ensure map is fully ready before drawing routes
      Future.delayed(const Duration(milliseconds: 300), () {
        _drawRoutes(clearFirst: true); // Clear on initial load
      });

      // Đặt camera vào vị trí thích hợp
      // Use current location if available, otherwise use first point
      if (_viewModel.currentLocation != null) {
        debugPrint('📍 Setting camera to current location');
        _setCameraToNavigationMode(_viewModel.currentLocation!);
      } else if (_viewModel.routeSegments[0].points.isNotEmpty) {
        debugPrint('📍 Setting camera to first point');
        _setCameraToNavigationMode(_viewModel.routeSegments[0].points.first);
      }

      // Check if we should auto-restore simulation from saved state
      final stateService = getIt<NavigationStateService>();
      final savedState = stateService.getSavedNavigationState();
      final shouldAutoRestore = savedState != null && 
                               savedState.orderId == widget.orderId &&
                               savedState.isSimulationMode &&
                               widget.isSimulationMode;

      // Start real tracking or simulation based on mode
      // Priority: Check simulation mode first, then check existing connections
      debugPrint('🔍 Checking navigation mode:');
      debugPrint('   - widget.isSimulationMode: ${widget.isSimulationMode}');
      debugPrint('   - _isSimulating: $_isSimulating');
      debugPrint('   - _isPaused: $_isPaused');
      debugPrint('   - shouldAutoRestore: $shouldAutoRestore');
      debugPrint(
        '   - Global tracking active: ${_globalLocationManager.isGlobalTrackingActive}',
      );

      if (widget.isSimulationMode && !_isSimulating) {
        if (shouldAutoRestore) {
          debugPrint('🔄 Auto-restoring simulation from saved state');
          // Auto-start simulation WITH restore
          _startSimulation(shouldRestore: true);
        } else {
          debugPrint(
            '🎬 Starting simulation mode (isSimulationMode=true, _isSimulating=false)',
          );
          // Show dialog for new simulation
          _showSimulationDialog();
        }
      } else if (!widget.isSimulationMode &&
          !_globalLocationManager.isGlobalTrackingActive) {
        debugPrint('🚗 Starting real-time navigation');
        _startRealTimeNavigation();
      } else if (_isSimulating && _isPaused) {
        debugPrint('⏸️ Simulation paused, auto-resuming...');
        // Auto-resume simulation after action (no dialog needed)
        _resumeSimulation();
      } else if (_isSimulating) {
        debugPrint('▶️ Resuming existing simulation');
        // Resume existing simulation
        _resumeSimulation();
      } else if (_globalLocationManager.isGlobalTrackingActive) {
        debugPrint('🔗 Integrated tracking already active, continuing...');
        debugPrint('   - This should only happen for real GPS tracking, not simulation');
        debugPrint('   - If you see this during simulation restore, there is a bug');
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
            Text('Đang khởi động location tracking...'),
          ],
        ),
      ),
    );

    try {
      debugPrint('🚀 Starting global location tracking...');

      // CRITICAL: Nếu là simulation mode và tracking đã active
      // KHÔNG stop WebSocket, chỉ switch sang simulation mode
      if (widget.isSimulationMode && _globalLocationManager.isGlobalTrackingActive) {
        debugPrint('⚠️ Simulation mode with active tracking detected');
        debugPrint('   - Keeping WebSocket alive, just switching to simulation mode');
        debugPrint('   - Current tracking order: ${_globalLocationManager.currentOrderId}');
        
        // Check if it's the same order
        if (_globalLocationManager.currentOrderId == widget.orderId) {
          debugPrint('✅ Same order - WebSocket stays connected, simulation will override GPS');
          // Just register this screen, don't restart tracking
          // CRITICAL: Only register if this is the primary driver
          if (_globalLocationManager.isPrimaryDriver) {
            _globalLocationManager.registerScreen(
              'NavigationScreen',
              onLocationUpdate: (data) {
                final isPrimary = _globalLocationManager.isPrimaryDriver;
                
                debugPrint(
                  '📍 Global location update (${isPrimary ? "Primary" : "Secondary"} Driver): $data',
                );

                final lat = data['latitude'] as double?;
                final lng = data['longitude'] as double?;

                if (lat != null && lng != null) {
                  final location = LatLng(lat, lng);

                  // Update viewModel's current location
                  _viewModel.currentLocation = location;

                  if (_isFollowingUser && mounted) {
                    _setCameraToNavigationMode(location);
                  }
                }
              },
              onError: (error) {
                debugPrint('❌ Global tracking error: $error');
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
          } else {
            debugPrint('⚠️ Secondary driver - not registering for location updates');
          }
          
          // Close loading dialog and return success
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            setState(() {
              _isConnectingWebSocket = false;
            });
          }
          return true;
        }
      }

      // Xác định driver role từ vehicle assignment hiện tại (không phải từ order chung)
      // CRITICAL: Với multi-trip orders, cần check xem user có phải là primary driver của CHUYẾN HIỆN TẠI
      bool isPrimaryDriver = true; // Default
      if (_viewModel.orderWithDetails != null && _viewModel.vehicleAssignmentId != null) {
        // Find the vehicle assignment for current trip
        final currentVehicleAssignment = _viewModel.orderWithDetails!.vehicleAssignments
            .cast<VehicleAssignment?>()
            .firstWhere(
              (va) => va?.id == _viewModel.vehicleAssignmentId,
              orElse: () => null,
            );
        
        if (currentVehicleAssignment != null) {
          // Check if current user is primary driver of THIS vehicle assignment
          final currentUserPhone = _authViewModel.driver?.userResponse.phoneNumber;
          if (currentUserPhone != null && currentVehicleAssignment.primaryDriver != null) {
            isPrimaryDriver = currentUserPhone.trim() == 
                currentVehicleAssignment.primaryDriver!.phoneNumber.trim();
            debugPrint('🔍 Primary driver check for trip ${_viewModel.vehicleAssignmentId}:');
            debugPrint('   - Current user: $currentUserPhone');
            debugPrint('   - Primary driver: ${currentVehicleAssignment.primaryDriver!.phoneNumber}');
            debugPrint('   - Is primary: $isPrimaryDriver');
          }
        }
      }

      // Use GlobalLocationManager instead of direct IntegratedLocationService
      // Get JWT token from auth view model
      final jwtToken = _authViewModel.user?.authToken;
      
      final success = await _globalLocationManager.startGlobalTracking(
        orderId: widget.orderId,
        vehicleId: _viewModel.currentVehicleId,
        licensePlateNumber: _viewModel.currentLicensePlateNumber,
        jwtToken: jwtToken,
        initiatingScreen: 'NavigationScreen',
        isPrimaryDriver: isPrimaryDriver,
        isSimulationMode:
            widget.isSimulationMode, // CRITICAL: Tắt GPS thật trong simulation
      );

      if (success) {
        // Register callbacks for location updates
        // CRITICAL: Only register if this is the primary driver
        // This prevents secondary drivers from receiving location updates
        // which would cause camera to focus on wrong vehicle in multi-trip orders
        if (isPrimaryDriver) {
          _globalLocationManager.registerScreen(
            'NavigationScreen',
            onLocationUpdate: (data) {
              final isPrimary = _globalLocationManager.isPrimaryDriver;
              debugPrint(
                '📍 Global location update (${isPrimary ? "Primary" : "Secondary"} Driver): $data',
              );

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
              debugPrint('❌ Global tracking error: $error');

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
        } else {
          debugPrint('⚠️ Secondary driver - not registering for location updates');
        }
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (success) {
        debugPrint('✅ Global location tracking started successfully');

        // Listen to tracking statistics from GlobalLocationManager
        // _globalLocationManager.globalStatsStream.listen((stats) {
        //   debugPrint('📊 Global Tracking Stats:');
        //   debugPrint(
        //     '   - Success rate: ${(stats.successRate * 100).toStringAsFixed(1)}%',
        //   );
        //   debugPrint('   - Queue size: ${stats.queueSize}');
        //   debugPrint('   - Total sent: ${stats.successfulSends}');
        //   debugPrint('   - Throttled: ${stats.throttledUpdates}');
        //   debugPrint('   - Rejected (quality): ${stats.rejectedByQuality}');
        // });

        if (mounted) {
          final isPrimary = _globalLocationManager.isPrimaryDriver;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPrimary
                    ? '✅ Location tracking started (Primary Driver)'
                    : '✅ Tracking initialized (Secondary Driver - No WebSocket)',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        debugPrint('❌ Failed to start global location tracking');

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
    debugPrint('🛑 Stopping global location tracking...');
    debugPrint('⚠️ This should ONLY be called when trip is complete!');

    // Stop global location tracking
    await _globalLocationManager.stopGlobalTracking(
      reason: 'Trip completed from NavigationScreen',
    );
    debugPrint('✅ GlobalLocationManager stopped');
  }

  void _drawRoutes({bool clearFirst = false}) {
    if (_mapController == null || _viewModel.routeSegments.isEmpty) return;

    // Throttle to prevent excessive redrawing and buffer overflow
    final now = DateTime.now();
    if (_lastDrawRoutesTime != null &&
        now.difference(_lastDrawRoutesTime!) < _drawRoutesThrottleDuration) {
      debugPrint('⏱️ Throttling _drawRoutes call');
      return;
    }
    _lastDrawRoutesTime = now;

    // If need to clear first, wait for clear to complete before drawing
    if (clearFirst) {
      _clearMapElementsWithDelay();
      // Wait for clear to complete (300ms) + extra buffer (200ms)
      Future.delayed(const Duration(milliseconds: 500), () {
        _drawRoutesInternal();
      });
    } else {
      // Draw immediately without clearing
      _drawRoutesInternal();
    }
  }

  void _drawRoutesInternal() {
    if (_mapController == null || _viewModel.routeSegments.isEmpty) return;

    // Clear previous waypoint markers
    _waypointMarkers.clear();

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
          polylineColor: AppColors.primary, // Luôn dùng màu xanh dương
          polylineWidth: 8.0, // Tăng độ dày để dễ nhìn
          polylineOpacity: 1.0, // Đầy đủ opacity
        ),
      );

      // Draw waypoint markers with icons
      if (optimizedPoints.isNotEmpty) {
        // Start point - only for first segment (Carrier)
        if (i == 0) {
          _waypointMarkers.add(
            Marker(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.warehouse,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              latLng: optimizedPoints.first,
            ),
          );
        }

        // End point markers with different colors and icons based on segment
        Color endPointColor;
        IconData endPointIcon;
        String label;
        
        if (i == 0) {
          endPointColor = Colors.green; // Pickup point
          endPointIcon = Icons.inventory_2; // Goods box icon
          label = 'Lấy hàng';
        } else if (i == _viewModel.routeSegments.length - 1) {
          endPointColor = Colors.orange; // Back to Carrier
          endPointIcon = Icons.warehouse; // Warehouse icon
          label = 'Kho';
        } else {
          endPointColor = Colors.red; // Delivery point
          endPointIcon = Icons.local_shipping; // Delivery icon
          label = 'Giao hàng';
        }

        _waypointMarkers.add(
          Marker(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: endPointColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    endPointIcon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: endPointColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            latLng: optimizedPoints.last,
          ),
        );
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
    // Use moveCamera instead of animateCamera to avoid "chasing" effect
    // Camera moves instantly with marker, creating smooth tracking
    if (_cameraUpdateCounter % _cameraUpdateFrequency == 0) {
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location,
            zoom: 16.0,
            bearing: bearing ?? 0.0,
            tilt: 45.0, // Góc nghiêng 3D
          ),
        ),
      );
    }
  }

  /// Clear map elements with delay to avoid VietmapGL style loading issues
  /// Error: "Calling getSourceAs when a newer style is loading/has loaded"
  void _clearMapElementsWithDelay() {
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (_mapController == null) return;
      
      try {
        await _mapController!.clearPolylines();
        debugPrint('✅ Cleared polylines');
      } catch (e) {
        debugPrint('⚠️ Error clearing polylines: $e');
      }
      
      try {
        await _mapController!.clearCircles();
        debugPrint('✅ Cleared circles');
      } catch (e) {
        debugPrint('⚠️ Error clearing circles: $e');
      }
    });
  }

  Future<void> _updateLocationMarker(LatLng location, double? bearing) async {
    if (_mapController == null) return;

    try {
      // Update existing marker instead of remove/add to avoid buffer issues
      if (_currentLocationMarker != null) {
        await _mapController!.updateSymbol(
          _currentLocationMarker!,
          SymbolOptions(
            geometry: location,
            textRotate: bearing ?? 0.0,
          ),
        );
      } else {
        // Create marker for the first time
        _currentLocationMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: location,
            textField: '🚛', // Truck emoji
            textSize: 32.0,
            textRotate: bearing ?? 0.0,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating location marker: $e');
      // If update fails, try to recreate
      try {
        if (_currentLocationMarker != null) {
          await _mapController!.removeSymbol(_currentLocationMarker!);
          _currentLocationMarker = null;
        }
        _currentLocationMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: location,
            textField: '🚛',
            textSize: 32.0,
            textRotate: bearing ?? 0.0,
          ),
        );
      } catch (e2) {
        debugPrint('❌ Error recreating marker: $e2');
      }
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

  Future<void> _startSimulation({bool shouldRestore = false}) async {
    if (_isSimulating) {
      debugPrint('⚠️ Simulation already running');
      return;
    }

    debugPrint('🎬 Starting simulation...');
    debugPrint('   - isSimulationMode: ${widget.isSimulationMode}');
    debugPrint('   - shouldRestore: $shouldRestore');
    debugPrint('   - Route segments: ${_viewModel.routeSegments.length}');

    // Validate route data
    if (_viewModel.routeSegments.isEmpty) {
      debugPrint('❌ Cannot start simulation: No route data');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có dữ liệu lộ trình để mô phỏng'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Reset any existing simulation in viewModel
    _viewModel.pauseSimulation();
    
    // If NOT restoring (manual start), clear old saved state to start fresh
    if (!shouldRestore) {
      final stateService = getIt<NavigationStateService>();
      stateService.clearNavigationState();
      debugPrint('🗑️ Cleared old saved state (manual start from beginning)');
    }

    // CRITICAL: Update simulation mode in GlobalLocationManager
    // This ensures saved state has correct simulation mode
    debugPrint('🔄 Updating GlobalLocationManager simulation mode to TRUE');
    _globalLocationManager.updateSimulationMode(true);
    
    // Save updated state with simulation mode
    await _globalLocationManager.saveNavigationState();
    debugPrint('✅ Saved state updated with simulation mode: true');

    // Connect to WebSocket first (with simulation mode enabled)
    final connected = await _startLocationTracking();
    if (!connected) {
      debugPrint('❌ Failed to connect WebSocket for simulation');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể kết nối WebSocket cho mô phỏng'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    debugPrint('✅ WebSocket connected, waiting for stabilization...');
    // Wait longer for WebSocket connection to stabilize and GPS stream to be fully stopped
    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      _isSimulating = true;
      _isPaused = false;
    });

    debugPrint('▶️ Starting actual simulation...');
    // Start the simulation
    _startActualSimulation(shouldRestore: shouldRestore);
  }

  void _startActualSimulation({required bool shouldRestore}) {
    debugPrint('🚀 _startActualSimulation called');
    debugPrint('   - shouldRestore: $shouldRestore');

    // Only restore saved position if shouldRestore is true
    if (shouldRestore) {
      final stateService = getIt<NavigationStateService>();
      final savedState = stateService.getSavedNavigationState();
      
      if (savedState != null && 
          savedState.orderId == widget.orderId && 
          savedState.hasPosition) {
        debugPrint('📍 Restoring saved simulation position:');
        debugPrint('   - Lat: ${savedState.currentLatitude}');
        debugPrint('   - Lng: ${savedState.currentLongitude}');
        debugPrint('   - Segment: ${savedState.currentSegmentIndex}');
        
        // Restore position in viewModel
        if (savedState.currentSegmentIndex != null) {
          _viewModel.restoreSimulationPosition(
            segmentIndex: savedState.currentSegmentIndex!,
            latitude: savedState.currentLatitude!,
            longitude: savedState.currentLongitude!,
          );
        }
      } else {
        debugPrint('ℹ️ No saved position found to restore');
      }
    } else {
      debugPrint('ℹ️ Manual start - NOT restoring saved position, starting from beginning');
    }

    // Ensure we're following the vehicle
    setState(() {
      _isFollowingUser = true;
    });

    // Start the simulation with callbacks
    _viewModel.startSimulation(
      onLocationUpdate: (location, bearing) {
        debugPrint(
          '📍 Location update: ${location.latitude}, ${location.longitude}, bearing: $bearing',
        );

        // Update custom location marker
        _updateLocationMarker(location, bearing);

        // Update camera to follow vehicle
        if (_isFollowingUser) {
          _setCameraToNavigationMode(location);
        }

        // Send location update via GlobalLocationManager with speed and segment
        _globalLocationManager.sendLocationUpdate(
          location.latitude,
          location.longitude,
          bearing: bearing,
          speed: _viewModel.currentSpeed, // Add current speed
          segmentIndex: _viewModel.currentSegmentIndex, // Add segment for position restore
        );

        // Check if near delivery point (3km) and update status
        _checkAndUpdateNearDelivery(location).ignore();

        // Rebuild UI to update speed display
        if (mounted) {
          setState(() {});
        }
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
          _simulationSpeed * 0.5, // Giảm xuống 0.5 để đạt 30-60 km/h
    );

    debugPrint('✅ Simulation started with speed: ${_simulationSpeed * 0.5}x');
  }

  void _pauseSimulation() {
    debugPrint('⏸️ _pauseSimulation called');
    debugPrint('   - _isSimulating: $_isSimulating');
    debugPrint('   - _isPaused: $_isPaused');

    if (!_isSimulating || _isPaused) {
      debugPrint(
        '❌ Cannot pause: _isSimulating=$_isSimulating, _isPaused=$_isPaused',
      );
      return;
    }

    setState(() {
      _isPaused = true;
    });

    debugPrint('✅ State updated: _isPaused=true');

    _viewModel.pauseSimulation();

    debugPrint('✅ ViewModel.pauseSimulation() called');

    // Rebuild UI to show speed = 0
    if (mounted) {
      setState(() {});
    }
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
      debugPrint(
        '❌ Cannot resume: _isSimulating=$_isSimulating, _isPaused=$_isPaused',
      );
      return;
    }

    debugPrint('▶️ Resuming simulation...');

    // Ensure global tracking is active
    if (!_globalLocationManager.isGlobalTrackingActive) {
      debugPrint('⚠️ Global tracking not active, starting...');
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

    debugPrint('✅ State updated: _isPaused=false, _isFollowingUser=true');

    _viewModel.resumeSimulation();

    debugPrint('✅ ViewModel.resumeSimulation() called');

    // Wait a bit for map to be ready, then refocus camera
    await Future.delayed(const Duration(milliseconds: 300));

    // Refocus camera on current position with retry
    if (_viewModel.currentLocation != null && mounted) {
      debugPrint('📍 Refocusing camera to: ${_viewModel.currentLocation}');
      
      // Try multiple times to ensure camera focuses
      for (int i = 0; i < 3; i++) {
        if (!mounted) break;
        
        await _setCameraToNavigationMode(_viewModel.currentLocation!);
        debugPrint('   - Camera focus attempt ${i + 1}/3');
        
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      debugPrint('✅ Camera refocused successfully');
    }

    // Rebuild UI to show updated speed
    if (mounted) {
      setState(() {});
    }

    debugPrint('✅ Resume complete');
  }

  void _resetSimulation() {
    debugPrint('🔄 Resetting simulation...');

    // Reset UI state
    setState(() {
      _isSimulating = false;
      _isPaused = false;
    });

    // Reset viewModel (cancels timer, clears route data)
    _viewModel.resetNavigation();

    // Clear all polylines and symbols (including current position marker)
    _mapController?.clearLines();
    _mapController?.clearSymbols();

    // CRITICAL: Clear saved navigation state to start fresh
    final stateService = getIt<NavigationStateService>();
    stateService.clearNavigationState();
    debugPrint('🗑️ Cleared saved navigation state');

    // Update simulation mode to false in GlobalLocationManager
    debugPrint('🔄 Updating GlobalLocationManager simulation mode to FALSE');
    _globalLocationManager.updateSimulationMode(false);

    // Re-parse route and redraw
    if (_viewModel.orderWithDetails != null) {
      _viewModel.parseRouteFromOrder(_viewModel.orderWithDetails!);
      _drawRoutes();

      // Focus camera back to starting position
      if (_viewModel.routeSegments.isNotEmpty &&
          _viewModel.routeSegments[0].points.isNotEmpty) {
        final startPoint = _viewModel.routeSegments[0].points.first;
        debugPrint(
          '📍 Focusing camera to start position: ${startPoint.latitude}, ${startPoint.longitude}',
        );
        _setCameraToNavigationMode(startPoint);

        // Send location update to reset position on server
        debugPrint('📤 Sending reset location to server...');
        _globalLocationManager.sendLocationUpdate(
          startPoint.latitude,
          startPoint.longitude,
          bearing: 0.0,
        );
      }
    }

    debugPrint('✅ Simulation reset complete');
  }

  void _jumpToNextSegment() async {
    debugPrint('⏩ Jump to next segment button pressed');
    debugPrint('   - _isSimulating: $_isSimulating');
    debugPrint('   - _isPaused: $_isPaused');
    debugPrint('   - Current segment: ${_viewModel.currentSegmentIndex}');

    // CRITICAL: Ensure simulation is running
    // If paused, resume it so next tick can detect completion
    if (_isSimulating && _isPaused) {
      debugPrint('⚠️ Simulation is paused, resuming before jump...');
      _resumeSimulation();
      // Wait a bit for simulation to start
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Check if jumping to delivery point (segment 1) and update status
    final isJumpingToDelivery = _viewModel.currentSegmentIndex == 1;
    debugPrint('📊 isJumpingToDelivery: $isJumpingToDelivery (currentSegmentIndex: ${_viewModel.currentSegmentIndex})');
    debugPrint('📊 orderWithDetails: ${_viewModel.orderWithDetails != null}');
    
    // Jump to next segment in viewModel (await for status updates)
    await _viewModel.jumpToNextSegment();
    
    // CRITICAL: Update order status to ONGOING_DELIVERED when jumping to delivery
    if (isJumpingToDelivery && _viewModel.orderWithDetails != null) {
      debugPrint('🎯 Jumped to delivery point! Updating order status to ONGOING_DELIVERED...');
      final orderDetailViewModel = Provider.of<OrderDetailViewModel>(
        context,
        listen: false,
      );
      await orderDetailViewModel.updateOrderStatusToOngoingDelivered();
      _hasNotifiedNearDelivery = true; // Mark as notified to avoid duplicate updates
    } else {
      debugPrint('⏭️ Skipping status update: isJumpingToDelivery=$isJumpingToDelivery, hasOrderDetails=${_viewModel.orderWithDetails != null}');
    }
    
    // Update camera to new location
    if (_viewModel.currentLocation != null) {
      _updateLocationMarker(
        _viewModel.currentLocation!,
        _viewModel.currentBearing,
      );
      
      if (_isFollowingUser) {
        _setCameraToNavigationMode(_viewModel.currentLocation!);
      }
      
      // Send location update to server
      _globalLocationManager.sendLocationUpdate(
        _viewModel.currentLocation!.latitude,
        _viewModel.currentLocation!.longitude,
        bearing: _viewModel.currentBearing,
        speed: _viewModel.currentSpeed,
      );
    }
    
    // Redraw routes to update current segment
    _drawRoutes();
    
    debugPrint('✅ Jump complete, waiting for next tick to detect completion...');
    // Note: We don't manually trigger completion here.
    // The next simulation tick (or GPS check) will detect that we're at
    // the end of the segment and trigger onSegmentComplete naturally.
    // This ensures consistent behavior between simulation, GPS, and skip.
  }

  Widget _buildSpeedButton(String label, double speed) {
    final isSelected = _simulationSpeed == speed;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _simulationSpeed = speed;
        });
        if (_isSimulating && !_isPaused) {
          _viewModel.updateSimulationSpeed(_simulationSpeed * 0.5);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(60, 36),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
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
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              
              // Navigate to order detail and wait for result
              final result = await Navigator.of(context).pushNamed(
                AppRoutes.orderDetail,
                arguments: widget.orderId,
              );
              
              // If result is true, seal was confirmed - resume simulation
              if (result == true && mounted) {
                debugPrint('✅ Seal confirmed, resuming simulation');
                if (_isPaused && _isSimulating) {
                  _resumeSimulation();
                }
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _showDeliveryMessage() {
    debugPrint('📍 _showDeliveryMessage() called');
    
    // CRITICAL: Update order status to ONGOING_DELIVERED when showing delivery dialog
    // Fire and forget - don't wait for it to complete
    debugPrint('🔄 Calling _updateOrderStatusOnDeliveryReached()...');
    _updateOrderStatusOnDeliveryReached().then((_) {
      debugPrint('✅ Order status update completed');
    }).catchError((e) {
      debugPrint('❌ Order status update error: $e');
    });
    
    debugPrint('📋 Showing delivery dialog...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Đã đến điểm giao hàng'),
        content: const Text(
          'Bạn đã đến điểm giao hàng. Vui lòng chụp ảnh xác nhận giao hàng.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              
              // Navigate to order detail and wait for result
              final result = await Navigator.of(context).pushNamed(
                AppRoutes.orderDetail,
                arguments: widget.orderId,
              );
              
              // If result is true, delivery was confirmed - resume simulation
              if (result == true && mounted) {
                debugPrint('✅ Delivery confirmed, resuming simulation');
                if (_isPaused && _isSimulating) {
                  _resumeSimulation();
                }
              }
            },
            child: const Text('Chụp ảnh xác nhận'),
          ),
        ],
      ),
    );
  }

  /// Update order status to ONGOING_DELIVERED when reaching delivery point
  Future<void> _updateOrderStatusOnDeliveryReached() async {
    debugPrint('🎯 Delivery point reached! Updating order status to ONGOING_DELIVERED...');
    
    try {
      // Call ViewModel method to update status (respects MVVM architecture)
      await _viewModel.updateToOngoingDelivered();
      _hasNotifiedNearDelivery = true; // Mark as notified
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
    }
  }

  Future<bool?> _showCompleteTripConfirmation() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hoàn thành'),
        content: const Text(
          'Bạn có chắc chắn đã giao hàng thành công?\n\n'
          'Sau khi xác nhận, chuyến xe sẽ được đánh dấu là hoàn thành.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _showCompletionMessage() {
    // Pause simulation but don't mark as complete yet
    // Driver needs to upload odometer end reading first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Đã về đến kho'),
        content: const Text(
          'Bạn đã về đến kho. Vui lòng chụp ảnh đồng hồ công tơ mét cuối để hoàn thành chuyến xe.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Navigate to order detail to upload odometer
              // Backend will update order status to SUCCESSFUL after upload
              Navigator.of(context).pushNamed(
                AppRoutes.orderDetail,
                arguments: widget.orderId,
              );
            },
            child: const Text('Chụp ảnh đồng hồ'),
          ),
        ],
      ),
    );
  }


  // Track if we've already notified about near delivery
  bool _hasNotifiedNearDelivery = false;
  static const double _nearDeliveryThresholdKm = 3.0;

  /// Check if vehicle is near delivery point (within 3km) and update order status
  Future<void> _checkAndUpdateNearDelivery(LatLng currentLocation) async {
    // Only check if:
    // 1. Currently in segment 1 (going to delivery point)
    // 2. Haven't notified yet
    // 3. Have order details
    if (_viewModel.currentSegmentIndex != 1 || 
        _hasNotifiedNearDelivery || 
        _viewModel.orderWithDetails == null) {
      return;
    }

    // Get delivery point (last point of segment 1)
    if (_viewModel.routeSegments.length <= 1 || 
        _viewModel.routeSegments[1].points.isEmpty) {
      return;
    }

    final deliveryPoint = _viewModel.routeSegments[1].points.last;
    final distanceMeters = _calculateDistance(currentLocation, deliveryPoint);
    final distanceKm = distanceMeters / 1000;

    debugPrint('📍 Distance to delivery: ${distanceKm.toStringAsFixed(2)} km');

    // If within 3km threshold, update order status
    if (distanceKm <= _nearDeliveryThresholdKm) {
      debugPrint('🎯 Within 3km of delivery point! Updating order status to ONGOING_DELIVERED...');
      _hasNotifiedNearDelivery = true;
      
      // Call OrderDetailViewModel to update status
      final orderDetailViewModel = Provider.of<OrderDetailViewModel>(
        context,
        listen: false,
      );
      await orderDetailViewModel.updateOrderStatusToOngoingDelivered();
      debugPrint('✅ Order status updated to ONGOING_DELIVERED');
    }
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(LatLng start, LatLng end) {
    const earthRadius = 6371000; // meters
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLat = (end.latitude - start.latitude) * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // distance in meters
  }

  void _toggle3DMode() {
    setState(() {
      _is3DMode = !_is3DMode;
    });

    if (_viewModel.currentLocation != null) {
      _setCameraToNavigationMode(_viewModel.currentLocation!);
    }
  }

  Future<void> _setCameraToNavigationMode(LatLng position) async {
    if (_mapController == null) return;

    // Giảm tốc độ chuyển camera để tránh tải quá nhiều tile
    final duration = const Duration(milliseconds: 1000);

    if (_is3DMode) {
      // Chế độ 3D: tilt cao (45 độ), zoom gần hơn và bearing theo hướng di chuyển
      await _mapController!.animateCamera(
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
      await _mapController!.animateCamera(
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
        // When back button is pressed, try to pop, if not possible go to order detail
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.orderDetail,
            arguments: widget.orderId,
          );
        }
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
              // Try to pop, if not possible go to order detail
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed(
                  AppRoutes.orderDetail,
                  arguments: widget.orderId,
                );
              }
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

                    // Vehicle marker with Image-Based 3D model (8 PNG sprites)
                    // + Waypoint markers with icons
                    if (_mapController != null &&
                        _viewModel.currentLocation != null &&
                        _isMapReady &&
                        _isMapInitialized)
                      MarkerLayer(
                        mapController: _mapController!,
                        markers: [
                          // Waypoint markers
                          ..._waypointMarkers,
                          // Vehicle marker
                          Marker(
                            child: ImageBased3DTruckMarker(
                              bearing: _viewModel.currentBearing ?? 0,
                              size: 50, // Smaller size for better accuracy
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
                                              i ==
                                                  _viewModel.currentSegmentIndex
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
                                              i ==
                                                  _viewModel.currentSegmentIndex
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color:
                                              i ==
                                                  _viewModel.currentSegmentIndex
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
                        const Text(
                          'Tốc độ:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildSpeedButton('x1', 1.0),
                              _buildSpeedButton('x2', 2.0),
                              _buildSpeedButton('x3', 3.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: !_isSimulating
                                ? _startSimulation
                                : (_isPaused
                                      ? _resumeSimulation
                                      : _pauseSimulation),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
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
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    !_isSimulating
                                        ? 'Bắt đầu'
                                        : (_isPaused ? 'Tiếp tục' : 'Tạm dừng'),
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isSimulating) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _jumpToNextSegment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.skip_next, size: 20),
                                  SizedBox(width: 4),
                                  Text(
                                    'Skip',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _resetSimulation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, size: 20),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Đặt lại',
                                    style: TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
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
