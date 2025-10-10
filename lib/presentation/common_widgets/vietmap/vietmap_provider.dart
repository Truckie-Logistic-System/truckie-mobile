import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../core/services/vietmap_service.dart';
import 'vietmap_viewmodel.dart';
import 'vietmap_widget.dart';

/// A provider widget for the VietMap component.
/// This widget provides the necessary dependencies for the VietMap component.
class VietMapProvider extends StatelessWidget {
  /// Child widget
  final Widget child;

  /// Base URL for API calls
  final String baseUrl;

  const VietMapProvider({Key? key, required this.child, required this.baseUrl})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(
            baseUrl: baseUrl,
            client: http.Client(),
            tokenStorageService: getIt<TokenStorageService>(),
          ),
        ),
        ProxyProvider<ApiService, VietMapService>(
          update: (_, apiService, __) => VietMapService(apiService: apiService),
        ),
        ChangeNotifierProxyProvider<VietMapService, VietMapViewModel>(
          create: (context) => VietMapViewModel(
            vietMapService: Provider.of<VietMapService>(context, listen: false),
          ),
          update: (_, vietMapService, previousViewModel) =>
              previousViewModel ??
              VietMapViewModel(vietMapService: vietMapService),
        ),
      ],
      child: child,
    );
  }
}

/// A convenience widget that combines the VietMapProvider and VietMapWidget.
class VietMap extends StatelessWidget {
  /// Callback when map is created
  final void Function(VietmapController)? onMapCreated;

  /// Callback when map is clicked
  final OnMapClickCallback? onMapClick;

  /// Callback when map is long pressed
  final OnMapLongClickCallback? onMapLongClick;

  /// Callback when map is fully rendered
  final VoidCallback? onMapRenderedCallback;

  /// Height of the map, if null it will take the available height
  final double? height;

  /// Width of the map, if null it will take the available width
  final double? width;

  /// Custom loading widget
  final Widget? loadingWidget;

  /// Custom error widget
  final Widget? errorWidget;

  /// Whether to show user location
  final bool? showUserLocation;

  /// Custom user location icon
  final Widget? userLocationIcon;

  /// Custom bearing icon
  final Widget? bearingIcon;

  /// List of markers to display on the map
  final List<Marker>? markers;

  /// List of static markers to display on the map
  final List<StaticMarker>? staticMarkers;

  /// Base URL for API calls
  final String baseUrl;

  const VietMap({
    Key? key,
    required this.baseUrl,
    this.onMapCreated,
    this.onMapClick,
    this.onMapLongClick,
    this.onMapRenderedCallback,
    this.height,
    this.width,
    this.loadingWidget,
    this.errorWidget,
    this.showUserLocation,
    this.userLocationIcon,
    this.bearingIcon,
    this.markers,
    this.staticMarkers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return VietMapProvider(
      baseUrl: baseUrl,
      child: VietMapWidget(
        onMapCreated: onMapCreated,
        onMapClick: onMapClick,
        onMapLongClick: onMapLongClick,
        onMapRenderedCallback: onMapRenderedCallback,
        height: height,
        width: width,
        loadingWidget: loadingWidget,
        errorWidget: errorWidget,
        showUserLocation: showUserLocation,
        userLocationIcon: userLocationIcon,
        bearingIcon: bearingIcon,
        markers: markers,
        staticMarkers: staticMarkers,
      ),
    );
  }
}
