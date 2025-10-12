# VietMap Component

Một component bản đồ tái sử dụng được xây dựng trên nền tảng VietMap SDK cho ứng dụng Flutter. Component này tuân theo kiến trúc MVVM và có thể dễ dàng tích hợp vào nhiều màn hình khác nhau.

## Cài đặt

1. Đảm bảo đã thêm thư viện `vietmap_flutter_gl` vào file `pubspec.yaml`:
   ```yaml
   dependencies:
     vietmap_flutter_gl: ^4.0.1
   ```

2. Cấu hình Android:
   - Thêm JitPack repository vào file `android/build.gradle`:
     ```gradle
     allprojects {
         repositories {
             google()
             mavenCentral()
             maven { url "https://jitpack.io" }
         }
     }
     ```
   - Cập nhật minSdkVersion lên 24 trong file `android/app/build.gradle`:
     ```gradle
     minSdkVersion 24
     ```

3. Cấu hình iOS:
   - Thêm các mô tả quyền vị trí vào file `ios/Runner/Info.plist`:
     ```xml
     <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
     <string>Ứng dụng cần quyền truy cập vị trí để hiển thị vị trí của bạn trên bản đồ</string>
     <key>NSLocationAlwaysUsageDescription</key>
     <string>Ứng dụng cần quyền truy cập vị trí để hiển thị vị trí của bạn trên bản đồ</string>
     <key>NSLocationWhenInUseUsageDescription</key>
     <string>Ứng dụng cần quyền truy cập vị trí để hiển thị vị trí của bạn trên bản đồ</string>
     ```
   - Cập nhật phiên bản iOS tối thiểu lên 12.0 trong file `ios/Podfile`:
     ```ruby
     platform :ios, '12.0'
     ```

## Sử dụng

### Sử dụng cơ bản

```dart
import 'package:flutter/material.dart';
import 'package:your_app/presentation/common_widgets/vietmap/index.dart';

class MapScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bản đồ')),
      body: VietMap(
        baseUrl: 'https://your-api-base-url.com/api',
        showUserLocation: true,
        onMapCreated: (controller) {
          // Lưu controller để sử dụng sau này
        },
      ),
    );
  }
}
```

### Sử dụng nâng cao

```dart
import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'package:your_app/presentation/common_widgets/vietmap/index.dart';

class AdvancedMapScreen extends StatefulWidget {
  @override
  _AdvancedMapScreenState createState() => _AdvancedMapScreenState();
}

class _AdvancedMapScreenState extends State<AdvancedMapScreen> {
  VietmapController? _mapController;
  List<Marker> _markers = [];
  Line? _routeLine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bản đồ nâng cao')),
      body: Column(
        children: [
          Expanded(
            child: VietMap(
              baseUrl: 'https://your-api-base-url.com/api',
              showUserLocation: true,
              onMapCreated: (controller) {
                setState(() {
                  _mapController = controller;
                });
              },
              onMapClick: (point, latLng) {
                // Thêm marker khi người dùng nhấp vào bản đồ
                setState(() {
                  _markers.add(
                    Marker(
                      child: Icon(Icons.location_on, color: Colors.red),
                      latLng: latLng,
                    ),
                  );
                });
              },
              markers: _markers,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _markers.length >= 2 ? _drawRoute : null,
              child: Text('Vẽ tuyến đường'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _drawRoute() async {
    if (_markers.length < 2) return;
    
    final List<LatLng> points = _markers.map((marker) => marker.latLng).toList();
    
    if (_routeLine != null) {
      await _mapController?.removePolyline(_routeLine!);
    }
    
    _routeLine = await _mapController?.addPolyline(
      PolylineOptions(
        geometry: points,
        polylineColor: Colors.blue,
        polylineWidth: 4.0,
      ),
    );
  }
}
```

## Tùy chỉnh

Component VietMap hỗ trợ nhiều tùy chọn tùy chỉnh:

- `height` và `width`: Kích thước của bản đồ
- `showUserLocation`: Hiển thị vị trí người dùng
- `userLocationIcon`: Biểu tượng vị trí người dùng
- `bearingIcon`: Biểu tượng hướng di chuyển
- `markers`: Danh sách các điểm đánh dấu
- `staticMarkers`: Danh sách các điểm đánh dấu tĩnh (xoay theo bản đồ)
- `loadingWidget`: Widget hiển thị khi đang tải bản đồ
- `errorWidget`: Widget hiển thị khi có lỗi

## API

Component VietMap cung cấp các API sau:

### VietMapViewModel

- `mapController`: Controller của bản đồ
- `mapConfig`: Cấu hình bản đồ
- `isLoading`: Trạng thái đang tải
- `hasError`: Trạng thái có lỗi
- `errorMessage`: Thông báo lỗi
- `moveCameraToPosition(LatLng position, {double zoom})`: Di chuyển camera đến vị trí
- `addPolyline(List<LatLng> points, {...})`: Thêm đường polyline
- `updatePolyline(Line line, List<LatLng> points, {...})`: Cập nhật đường polyline
- `removePolyline(Line line)`: Xóa đường polyline
- `clearPolylines()`: Xóa tất cả đường polyline

### VietMapWidget

- `onMapCreated`: Callback khi bản đồ được tạo
- `onMapClick`: Callback khi bản đồ được nhấp
- `onMapLongClick`: Callback khi bản đồ được nhấn giữ
- `onMapRenderedCallback`: Callback khi bản đồ được hiển thị hoàn toàn

## Lưu ý

- Đảm bảo thêm `key` cho tất cả các widget trong màn hình sử dụng SDK bản đồ để tránh các vấn đề về hiệu suất.
- Sử dụng `trackCameraPosition: true` để đảm bảo MarkerLayer hiển thị bình thường.
- Tối ưu hóa việc sử dụng bản đồ bằng cách tránh tạo lại các đối tượng không cần thiết. 