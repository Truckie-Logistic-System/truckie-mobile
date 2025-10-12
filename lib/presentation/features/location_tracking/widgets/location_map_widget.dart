import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../viewmodels/location_tracking_viewmodel.dart';

class LocationMapWidget extends StatefulWidget {
  const LocationMapWidget({Key? key}) : super(key: key);

  @override
  State<LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<LocationMapWidget> {
  GoogleMapController? _mapController;
  final Map<String, Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationTrackingViewModel>(
      builder: (context, viewModel, _) {
        _updateMarkerFromViewModel(viewModel);

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 300,
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(10.762622, 106.660172), // Ho Chi Minh City
                  zoom: 15,
                ),
                markers: Set<Marker>.of(_markers.values),
                mapType: MapType.normal,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                compassEnabled: true,
                zoomControlsEnabled: true,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateMarkerFromViewModel(LocationTrackingViewModel viewModel) {
    final locationData = viewModel.lastLocationData;
    if (locationData != null &&
        locationData['latitude'] != null &&
        locationData['longitude'] != null) {
      final vehicleId = locationData['vehicleId'] ?? 'vehicle';
      final licensePlate =
          locationData['licensePlateNumber'] ?? 'Không có biển số';
      final latLng = LatLng(
        double.parse(locationData['latitude'].toString()),
        double.parse(locationData['longitude'].toString()),
      );

      final marker = Marker(
        markerId: MarkerId(vehicleId),
        position: latLng,
        infoWindow: InfoWindow(
          title: 'Xe: $licensePlate',
          snippet: 'Vị trí hiện tại',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      setState(() {
        _markers[vehicleId] = marker;
      });

      _animateToPosition(latLng);
    }
  }

  void _animateToPosition(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15));
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
