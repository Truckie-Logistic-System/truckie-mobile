import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import 'vietmap_viewmodel.dart';

/// A reusable VietMap widget component that can be used across multiple screens.
/// This component follows MVVM architecture and provides a responsive map display
/// with various customization options.
class VietMapWidget extends StatefulWidget {
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

  const VietMapWidget({
    Key? key,
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
  State<VietMapWidget> createState() => _VietMapWidgetState();
}

class _VietMapWidgetState extends State<VietMapWidget>
    with AutomaticKeepAliveClientMixin {
  VietmapController? _controller;
  bool _disposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _disposed = true;
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<VietMapViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return SizedBox(
            height: widget.height,
            width: widget.width,
            child:
                widget.loadingWidget ??
                const Center(child: CircularProgressIndicator()),
          );
        }

        if (viewModel.hasError) {
          return SizedBox(
            height: widget.height,
            width: widget.width,
            child:
                widget.errorWidget ??
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Không thể tải bản đồ',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        viewModel.errorMessage,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (!_disposed) {
                            viewModel.retryInitialization();
                          }
                        },
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
          );
        }

        if (viewModel.mapConfig == null || viewModel.mapStyle == null) {
          return SizedBox(
            height: widget.height ?? double.infinity,
            width: widget.width ?? double.infinity,
            child: const Center(child: Text('Không thể tải cấu hình bản đồ')),
          );
        }

        return SizedBox(
          height: widget.height,
          width: widget.width,
          child: Stack(
            children: [
              // Main map widget
              VietmapGL(
                styleString: viewModel.mapConfig!.styleString,
                initialCameraPosition:
                    viewModel.mapConfig!.initialCameraPosition,
                trackCameraPosition: viewModel.mapConfig!.trackCameraPosition,
                myLocationEnabled:
                    widget.showUserLocation ??
                    viewModel.mapConfig!.myLocationEnabled,
                myLocationTrackingMode:
                    viewModel.mapConfig!.myLocationTrackingMode,
                myLocationRenderMode: viewModel.mapConfig!.myLocationRenderMode,
                onMapCreated: (controller) {
                  if (_disposed) return;

                  _controller = controller;
                  viewModel.setMapController(controller);

                  if (widget.onMapCreated != null) {
                    widget.onMapCreated!(controller);
                  }

                  // Add a post-frame callback to ensure the controller is set after the widget is fully built
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_disposed) return;

                    if (viewModel.mapController == null) {
                      viewModel.setMapController(controller);
                    }
                  });
                },
                onMapClick: widget.onMapClick,
                onMapLongClick: widget.onMapLongClick,
                onMapRenderedCallback: widget.onMapRenderedCallback,
              ),

              // Markers layer
              if (!_disposed &&
                  widget.markers != null &&
                  widget.markers!.isNotEmpty &&
                  viewModel.mapController != null)
                MarkerLayer(
                  mapController: viewModel.mapController!,
                  markers: widget.markers!,
                  ignorePointer: true,
                ),

              // Static markers layer
              if (!_disposed &&
                  widget.staticMarkers != null &&
                  widget.staticMarkers!.isNotEmpty &&
                  viewModel.mapController != null)
                StaticMarkerLayer(
                  mapController: viewModel.mapController!,
                  markers: widget.staticMarkers!,
                  ignorePointer: true,
                ),

              // User location layer
              if (!_disposed &&
                  (widget.showUserLocation ??
                      viewModel.mapConfig!.myLocationEnabled) &&
                  viewModel.mapController != null)
                UserLocationLayer(
                  mapController: viewModel.mapController!,
                  locationIcon:
                      widget.userLocationIcon ??
                      const Icon(Icons.circle, color: Colors.blue, size: 20),
                  bearingIcon:
                      widget.bearingIcon ??
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: Colors.red,
                          size: 15,
                        ),
                      ),
                  ignorePointer: true,
                ),
            ],
          ),
        );
      },
    );
  }
}
