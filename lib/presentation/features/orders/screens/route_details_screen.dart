import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';
import '../../orders/viewmodels/order_detail_viewmodel.dart';
import '../../../../domain/entities/order_detail.dart';

class RouteDetailsScreen extends StatefulWidget {
  final OrderDetailViewModel viewModel;

  const RouteDetailsScreen({Key? key, required this.viewModel})
    : super(key: key);

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  VietmapController? _mapController;
  bool _isMapReady = false;
  bool _isMapInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _selectedSegmentIndex = 0;

  // ScrollController for the segment selector
  final ScrollController _scrollController = ScrollController();

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

  @override
  void initState() {
    super.initState();
    _selectedSegmentIndex = widget.viewModel.selectedSegmentIndex;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goToNextSegment() {
    if (widget.viewModel.routeSegments.length > 1) {
      setState(() {
        // Circular navigation: if at last segment, go to first
        if (_selectedSegmentIndex >=
            widget.viewModel.routeSegments.length - 1) {
          _selectedSegmentIndex = 0;
        } else {
          _selectedSegmentIndex++;
        }
      });
      widget.viewModel.selectSegment(_selectedSegmentIndex);
      _drawAllRoutes();
      _scrollToSelectedSegment();
    }
  }

  void _goToPreviousSegment() {
    if (widget.viewModel.routeSegments.length > 1) {
      setState(() {
        // Circular navigation: if at first segment, go to last
        if (_selectedSegmentIndex <= 0) {
          _selectedSegmentIndex = widget.viewModel.routeSegments.length - 1;
        } else {
          _selectedSegmentIndex--;
        }
      });
      widget.viewModel.selectSegment(_selectedSegmentIndex);
      _drawAllRoutes();
      _scrollToSelectedSegment();
    }
  }

  // Scroll to make the selected segment visible
  void _scrollToSelectedSegment() {
    // Use a small delay to ensure the UI has updated
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        // Calculate the approximate position of the selected segment
        // Each chip is about 100-120 pixels wide with padding
        final double itemWidth = 120.0;
        final double scrollOffset = _selectedSegmentIndex * itemWidth;

        // Scroll to the position with some padding
        _scrollController.animateTo(
          scrollOffset,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Nếu không có dữ liệu route, hiển thị thông báo lỗi
    if (widget.viewModel.routeSegments.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết lộ trình'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Không có dữ liệu lộ trình')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết lộ trình'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (widget.viewModel.routeSegments.length > 1) {
            if (details.primaryVelocity! > 0) {
              // Swipe right - go to previous segment
              _goToPreviousSegment();
            } else if (details.primaryVelocity! < 0) {
              // Swipe left - go to next segment
              _goToNextSegment();
            }
          }
        },
        child: Stack(
          children: [
            // VietMap widget
            VietmapGL(
              styleString: _getMapStyleString(),
              initialCameraPosition: _getInitialCameraPosition(),
              myLocationEnabled: true,
              onMapCreated: _onMapCreated,
              onMapRenderedCallback: () {
                setState(() {
                  _isMapReady = true;
                });
                _drawAllRoutes();
              },
              onStyleLoadedCallback: () {
                setState(() {
                  _isMapInitialized = true;
                });
                _drawAllRoutes();
              },
            ),

            // Segment selector
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn đoạn lộ trình',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      widget.viewModel.routeSegments.length > 1
                          ? SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  SizedBox(width: 8),
                                  ...List.generate(
                                    widget.viewModel.routeSegments.length,
                                    (index) => Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(_routeNames[index]),
                                        selected:
                                            _selectedSegmentIndex == index,
                                        selectedColor: _routeColors[index],
                                        labelStyle: TextStyle(
                                          color: _selectedSegmentIndex == index
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        onSelected: (selected) {
                                          if (selected &&
                                              _selectedSegmentIndex != index) {
                                            setState(() {
                                              _selectedSegmentIndex = index;
                                            });
                                            widget.viewModel.selectSegment(
                                              index,
                                            );
                                            _drawAllRoutes();
                                            _scrollToSelectedSegment();
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              _routeNames[0],
                              style: TextStyle(
                                color: _routeColors[0],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),

            // Swipe indicators (only visible when there are multiple segments)
            if (widget.viewModel.routeSegments.length > 1) ...[
              // Left swipe indicator (always visible)
              Positioned(
                left: 0,
                top: MediaQuery.of(context).size.height / 2 - 40,
                child: Container(
                  height: 80,
                  width: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

              // Right swipe indicator (always visible)
              Positioned(
                right: 0,
                top: MediaQuery.of(context).size.height / 2 - 40,
                child: Container(
                  height: 80,
                  width: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],

            // Route info card
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildRouteInfo(),
                ),
              ),
            ),

            // Loading indicator
            if (!_isMapReady)
              Container(
                color: Colors.white.withOpacity(0.7),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
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
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Không thể hiển thị bản đồ',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: AppTextStyles.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _isMapReady = false;
                          });
                          // Bản đồ sẽ tự động được tải lại
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
    );
  }

  Widget _buildRouteInfo() {
    if (!_shouldShowRouteInfo()) {
      return const SizedBox.shrink();
    }

    final journeySegments = widget
        .viewModel
        .orderWithDetails!
        .orderDetails
        .first
        .vehicleAssignment!
        .journeyHistories
        .first
        .journeySegments;

    // Get current segment
    final currentSegment = journeySegments[_selectedSegmentIndex];

    // Format distance in km
    final distanceKm = (currentSegment.distanceMeters).toStringAsFixed(2);

    // Chuyển đổi tên điểm đầu/cuối sang tiếng Việt
    String startPointName = currentSegment.startPointName;
    String endPointName = currentSegment.endPointName;

    if (startPointName == "Carrier") startPointName = "Kho";
    if (startPointName == "Pickup") startPointName = "Lấy hàng";
    if (startPointName == "Delivery") startPointName = "Giao hàng";

    if (endPointName == "Carrier") endPointName = "Kho";
    if (endPointName == "Pickup") endPointName = "Lấy hàng";
    if (endPointName == "Delivery") endPointName = "Giao hàng";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Đoạn ${_selectedSegmentIndex + 1}: $startPointName → $endPointName',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _routeColors[_selectedSegmentIndex],
                ),
              ),
            ),
            if (widget.viewModel.routeSegments.length > 1)
              Row(
                children: [
                  // Previous segment button
                  IconButton(
                    onPressed: () => _goToPreviousSegment(),
                    icon: Icon(
                      Icons.arrow_back_ios,
                      size: 18,
                      color: _selectedSegmentIndex > 0
                          ? _routeColors[_selectedSegmentIndex > 0
                                ? _selectedSegmentIndex - 1
                                : widget.viewModel.routeSegments.length - 1]
                          : _routeColors[widget.viewModel.routeSegments.length -
                                1],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                    splashRadius: 20,
                  ),

                  // Next segment button
                  IconButton(
                    onPressed: () => _goToNextSegment(),
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color:
                          _selectedSegmentIndex <
                              widget.viewModel.routeSegments.length - 1
                          ? _routeColors[_selectedSegmentIndex <
                                    widget.viewModel.routeSegments.length - 1
                                ? _selectedSegmentIndex + 1
                                : 0]
                          : _routeColors[0],
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                    splashRadius: 20,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.straighten, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Khoảng cách: $distanceKm km',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours giờ ${minutes > 0 ? '$minutes phút' : ''}';
    } else {
      return '$minutes phút';
    }
  }

  bool _shouldShowRouteInfo() {
    return widget.viewModel.routeSegments.isNotEmpty &&
        widget.viewModel.orderWithDetails != null &&
        widget.viewModel.orderWithDetails!.orderDetails.isNotEmpty &&
        widget
                .viewModel
                .orderWithDetails!
                .orderDetails
                .first
                .vehicleAssignment !=
            null &&
        widget
            .viewModel
            .orderWithDetails!
            .orderDetails
            .first
            .vehicleAssignment!
            .journeyHistories
            .isNotEmpty &&
        widget
            .viewModel
            .orderWithDetails!
            .orderDetails
            .first
            .vehicleAssignment!
            .journeyHistories
            .first
            .journeySegments
            .isNotEmpty;
  }

  String _getMapStyleString() {
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
          "id": "layer_raster_vm",
          "type": "raster",
          "source": "raster_vm",
          "minzoom": 0,
          "maxzoom": 20
        }
      ]
    }
    ''';
  }

  CameraPosition _getInitialCameraPosition() {
    // Lấy tất cả các điểm từ tất cả các đoạn đường
    List<LatLng> allPoints = [];
    for (var segment in widget.viewModel.routeSegments) {
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

      return CameraPosition(target: LatLng(centerLat, centerLng), zoom: 13.0);
    }

    // Mặc định ở TP.HCM
    return const CameraPosition(
      target: LatLng(10.762317, 106.654551),
      zoom: 13.0,
    );
  }

  void _onMapCreated(VietmapController controller) {
    setState(() {
      _mapController = controller;
    });
  }

  void _drawAllRoutes() async {
    if (_mapController == null || !_isMapReady || !_isMapInitialized) {
      return;
    }

    try {
      // Xóa các polyline và symbol cũ
      await _mapController!.clearLines();
      await _mapController!.clearSymbols();
      await _mapController!.clearCircles();

      // Danh sách tất cả các điểm để tính toán bounds
      List<LatLng> allPoints = [];

      // Vẽ tất cả các đoạn đường
      for (int i = 0; i < widget.viewModel.routeSegments.length; i++) {
        final route = widget.viewModel.routeSegments[i];
        if (route.isEmpty) continue;

        allPoints.addAll(route);

        // Lấy màu cho đoạn đường này
        final color = i < _routeColors.length
            ? _routeColors[i]
            : AppColors.primary;

        // Độ đậm của đường phụ thuộc vào việc có đang được chọn hay không
        final isSelected = i == _selectedSegmentIndex;
        final lineWidth = isSelected ? 5.0 : 3.0;
        final opacity = isSelected ? 1.0 : 0.6;

        // Vẽ polyline cho tuyến đường
        await _mapController!.addPolyline(
          PolylineOptions(
            geometry: route,
            polylineColor: color,
            polylineWidth: lineWidth,
            polylineOpacity: opacity,
          ),
        );

        // Thêm marker cho điểm đầu và điểm cuối của mỗi đoạn
        final startPoint = route.first;
        final endPoint = route.last;

        // Thêm circle marker cho điểm đầu
        await _mapController!.addCircle(
          CircleOptions(
            geometry: startPoint,
            circleRadius: isSelected ? 10.0 : 8.0,
            circleColor: color,
            circleStrokeWidth: 2.0,
            circleStrokeColor: Colors.white,
            circleOpacity: opacity,
          ),
        );

        // Thêm circle marker cho điểm cuối
        await _mapController!.addCircle(
          CircleOptions(
            geometry: endPoint,
            circleRadius: isSelected ? 10.0 : 8.0,
            circleColor: color,
            circleStrokeWidth: 2.0,
            circleStrokeColor: Colors.white,
            circleOpacity: opacity,
          ),
        );
      }

      // Di chuyển camera để hiển thị toàn bộ tuyến đường hoặc đoạn đường đang chọn
      if (_selectedSegmentIndex >= 0 &&
          _selectedSegmentIndex < widget.viewModel.routeSegments.length) {
        final selectedRoute =
            widget.viewModel.routeSegments[_selectedSegmentIndex];
        if (selectedRoute.isNotEmpty) {
          double minLat = selectedRoute.map((p) => p.latitude).reduce(min);
          double maxLat = selectedRoute.map((p) => p.latitude).reduce(max);
          double minLng = selectedRoute.map((p) => p.longitude).reduce(min);
          double maxLng = selectedRoute.map((p) => p.longitude).reduce(max);

          // Thêm padding để đảm bảo hiển thị đầy đủ
          const double padding = 0.01;

          // Cập nhật camera để hiển thị đoạn đường đang chọn
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat - padding, minLng - padding),
                northeast: LatLng(maxLat + padding, maxLng + padding),
              ),
            ),
          );
        }
      } else if (allPoints.length > 1) {
        // Hiển thị tất cả các đoạn đường nếu không có đoạn nào được chọn
        double minLat = allPoints.map((p) => p.latitude).reduce(min);
        double maxLat = allPoints.map((p) => p.latitude).reduce(max);
        double minLng = allPoints.map((p) => p.longitude).reduce(min);
        double maxLng = allPoints.map((p) => p.longitude).reduce(max);

        // Cập nhật camera để hiển thị toàn bộ tuyến đường
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat - 0.005, minLng - 0.005),
              northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Không thể vẽ tuyến đường: ${e.toString()}';
      });
    }
  }
}
