import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../../app/app_routes.dart';
import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';
import '../../viewmodels/order_detail_viewmodel.dart';

/// Widget hiển thị bản đồ lộ trình
class RouteMapSection extends StatefulWidget {
  /// ViewModel chứa thông tin lộ trình
  final OrderDetailViewModel viewModel;

  const RouteMapSection({super.key, required this.viewModel});

  @override
  State<RouteMapSection> createState() => _RouteMapSectionState();
}

class _RouteMapSectionState extends State<RouteMapSection>
    with AutomaticKeepAliveClientMixin {
  VietmapController? _mapController;
  final bool _isMapReady = false;
  bool _isDisposed = false;
  final bool _isMapInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Waypoint markers list
  List<Marker> _waypointMarkers = [];

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
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _isDisposed = true;
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Nếu không có dữ liệu route, ẩn phần bản đồ
    if (widget.viewModel.routeSegments.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.routeDetails,
          arguments: widget.viewModel,
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lộ trình vận chuyển', style: AppTextStyles.titleMedium),
                  Row(
                    children: [
                      Text(
                        'Xem trên bản đồ',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12.r,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Thông tin tổng quát về lộ trình
            if (_shouldShowRouteInfo())
              Padding(padding: EdgeInsets.all(16.r), child: _buildRouteInfo()),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          Container(width: 16.w, height: 4.h, color: color),
          SizedBox(width: 8.w),
          Text(text, style: AppTextStyles.bodySmall),
        ],
      ),
    );
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

  bool _shouldShowRouteInfo() {
    if (widget.viewModel.routeSegments.isEmpty ||
        widget.viewModel.orderWithDetails == null ||
        widget.viewModel.orderWithDetails!.orderDetails.isEmpty ||
        widget.viewModel.orderWithDetails!.vehicleAssignments.isEmpty) {
      return false;
    }
    
    final vehicleAssignmentId = widget.viewModel.orderWithDetails!.orderDetails.first.vehicleAssignmentId;
    if (vehicleAssignmentId == null) {
      return false;
    }
    
    final vehicleAssignment = widget.viewModel.orderWithDetails!.vehicleAssignments.firstWhere(
      (va) => va.id == vehicleAssignmentId,
      orElse: () => null,
    );
    
    return vehicleAssignment != null &&
        vehicleAssignment.journeyHistories.isNotEmpty &&
        vehicleAssignment.journeyHistories.first.journeySegments.isNotEmpty;
  }

  Widget _buildRouteInfo() {
    if (!_shouldShowRouteInfo()) {
      return const SizedBox.shrink();
    }

    final vehicleAssignmentId = widget.viewModel.orderWithDetails!.orderDetails.first.vehicleAssignmentId;
    final vehicleAssignment = widget.viewModel.orderWithDetails!.vehicleAssignments.firstWhere(
      (va) => va.id == vehicleAssignmentId,
      orElse: () => null,
    );
    
    if (vehicleAssignment == null) {
      return const SizedBox.shrink();
    }

    final journeySegments = vehicleAssignment.journeyHistories.first.journeySegments;

    // Tính tổng khoảng cách
    double totalDistanceKm = journeySegments.fold(
      0.0,
      (sum, segment) => sum + segment.distanceMeters,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin lộ trình',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Icon(Icons.straighten, size: 16.r, color: AppColors.textSecondary),
            SizedBox(width: 8.w),
            Text(
              'Tổng khoảng cách: ${totalDistanceKm.toStringAsFixed(2)} km',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ...List.generate(
          journeySegments.length,
          (index) => _buildSegmentInfoItem(
            journeySegments[index],
            _routeColors[index],
            index,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentInfoItem(JourneySegment segment, Color color, int index) {
    // Format distance in km
    final distanceKm = (segment.distanceMeters).toStringAsFixed(2);

    // Chuyển đổi tên điểm đầu/cuối sang tiếng Việt
    String startPointName = segment.startPointName;
    String endPointName = segment.endPointName;

    if (startPointName == "Carrier") startPointName = "Kho";
    if (startPointName == "Pickup") startPointName = "Lấy hàng";
    if (startPointName == "Delivery") startPointName = "Giao hàng";

    if (endPointName == "Carrier") endPointName = "Kho";
    if (endPointName == "Pickup") endPointName = "Lấy hàng";
    if (endPointName == "Delivery") endPointName = "Giao hàng";

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16.w,
            height: 16.h,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$startPointName → $endPointName',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Khoảng cách: $distanceKm km',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    if (!_isDisposed) {
      setState(() {
        _mapController = controller;
      });

      // Debug thông tin
      debugPrint('VietMap controller created');
    }
  }

  void _drawAllRoutes() async {
    if (_mapController == null ||
        !_isMapReady ||
        _isDisposed ||
        !_isMapInitialized) {
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
      
      // Clear previous waypoint markers
      _waypointMarkers.clear();

      // Danh sách tất cả các điểm để tính toán bounds
      List<LatLng> allPoints = [];

      // Vẽ tất cả các đoạn đường
      for (int i = 0; i < widget.viewModel.routeSegments.length; i++) {
        final route = widget.viewModel.routeSegments[i];
        if (route.isEmpty) continue;

        debugPrint('Drawing route $i with ${route.length} points');
        allPoints.addAll(route);

        // Lấy màu cho đoạn đường này
        final color = i < _routeColors.length
            ? _routeColors[i]
            : AppColors.primary;

        // Vẽ polyline cho tuyến đường
        await _mapController!.addPolyline(
          PolylineOptions(
            geometry: route,
            polylineColor: color,
            polylineWidth: 4.0,
            polylineOpacity: 1.0,
          ),
        );

        // Thêm marker cho điểm đầu và điểm cuối của mỗi đoạn
        final startPoint = route.first;
        final endPoint = route.last;

        // Thêm marker cho điểm đầu (Carrier - Kho)
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
              latLng: startPoint,
            ),
          );
        }

        // Thêm marker cho điểm cuối
        Color endMarkerColor;
        IconData endMarkerIcon;
        String endMarkerLabel;
        
        if (i == 0) {
          endMarkerColor = Colors.green; // Pickup
          endMarkerIcon = Icons.inventory_2;
          endMarkerLabel = 'Lấy hàng';
        } else if (i == widget.viewModel.routeSegments.length - 1) {
          endMarkerColor = Colors.orange; // Back to Carrier
          endMarkerIcon = Icons.warehouse;
          endMarkerLabel = 'Kho';
        } else {
          endMarkerColor = Colors.red; // Delivery
          endMarkerIcon = Icons.local_shipping;
          endMarkerLabel = 'Giao hàng';
        }

        _waypointMarkers.add(
          Marker(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: endMarkerColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    endMarkerIcon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: endMarkerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    endMarkerLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            latLng: endPoint,
          ),
        );
      }

      // Di chuyển camera để hiển thị toàn bộ tuyến đường
      if (allPoints.length > 1) {
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

        debugPrint('Camera moved to show all routes');
      }
    } catch (e) {
      debugPrint('Error drawing routes: $e');
      if (!_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Không thể vẽ tuyến đường: ${e.toString()}';
        });
      }
    }
  }
}
