import 'package:flutter/material.dart';
// import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../common_widgets/vietmap/index.dart';

class ExampleMapScreen extends StatefulWidget {
  const ExampleMapScreen({Key? key}) : super(key: key);

  @override
  State<ExampleMapScreen> createState() => _ExampleMapScreenState();
}

class _ExampleMapScreenState extends State<ExampleMapScreen> {
  VietmapController? _mapController;
  List<Marker> _markers = [];
  Line? _routeLine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bản đồ giao hàng')),
      body: Column(
        children: [
          Expanded(
            child: VietMap(
              baseUrl:
                  'https://your-api-base-url.com/api', // Thay thế bằng URL thực tế của bạn
              height: double.infinity,
              width: double.infinity,
              showUserLocation: true,
              onMapCreated: (controller) {
                setState(() {
                  _mapController = controller;
                });
              },
              onMapRenderedCallback: () {
                // Di chuyển camera đến vị trí mặc định khi bản đồ đã được tải hoàn toàn
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    const CameraPosition(
                      target: LatLng(10.762317, 106.654551),
                      zoom: 14.0,
                      tilt: 0,
                    ),
                  ),
                );
              },
              onMapClick: (point, latLng) {
                // Thêm marker khi người dùng nhấp vào bản đồ
                _addMarker(latLng);
              },
              markers: _markers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _clearMarkers,
                  child: const Text('Xóa markers'),
                ),
                ElevatedButton(
                  onPressed: _markers.length >= 2 ? _drawRoute : null,
                  child: const Text('Vẽ tuyến đường'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addMarker(LatLng position) {
    setState(() {
      _markers.add(
        Marker(
          child: const Icon(Icons.location_on, color: Colors.red, size: 30),
          latLng: position,
        ),
      );
    });
  }

  void _clearMarkers() {
    setState(() {
      _markers.clear();
      if (_routeLine != null) {
        _mapController?.removePolyline(_routeLine!);
        _routeLine = null;
      }
    });
  }

  Future<void> _drawRoute() async {
    if (_markers.length < 2) return;

    // Lấy danh sách các điểm từ markers
    final List<LatLng> points = _markers
        .map((marker) => marker.latLng)
        .toList();

    // Nếu đã có tuyến đường, xóa nó trước
    if (_routeLine != null) {
      await _mapController?.removePolyline(_routeLine!);
    }

    // Vẽ tuyến đường mới
    _routeLine = await _mapController?.addPolyline(
      PolylineOptions(
        geometry: points,
        polylineColor: Colors.blue,
        polylineWidth: 4.0,
        polylineOpacity: 0.8,
      ),
    );
  }
}
