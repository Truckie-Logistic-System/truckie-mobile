import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
// import '../../presentation/common_widgets/vietmap/vietmap_widget_temp.dart';

class VietMapConfig {
  final CameraPosition initialCameraPosition;
  final String styleString;
  final bool myLocationEnabled;
  final MyLocationTrackingMode myLocationTrackingMode;
  final MyLocationRenderMode myLocationRenderMode;
  final bool trackCameraPosition;

  VietMapConfig({
    required this.initialCameraPosition,
    required this.styleString,
    this.myLocationEnabled = true,
    required this.myLocationTrackingMode,
    required this.myLocationRenderMode,
    this.trackCameraPosition = true,
  });

  factory VietMapConfig.defaultConfig(String styleString) {
    return VietMapConfig(
      initialCameraPosition: const CameraPosition(
        target: LatLng(10.762317, 106.654551), // Mặc định ở TP.HCM
        zoom: 14.0,
      ),
      styleString: styleString,
      myLocationTrackingMode: MyLocationTrackingMode.values[0],
      myLocationRenderMode: MyLocationRenderMode.values[0],
    );
  }
}
