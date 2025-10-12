import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/service_locator.dart';
import '../viewmodels/location_tracking_viewmodel.dart';
import '../widgets/location_map_widget.dart';

class DriverLocationScreen extends StatefulWidget {
  final String vehicleId;
  final String licensePlateNumber;
  final String jwtToken;

  const DriverLocationScreen({
    Key? key,
    required this.vehicleId,
    required this.licensePlateNumber,
    required this.jwtToken,
  }) : super(key: key);

  @override
  State<DriverLocationScreen> createState() => _DriverLocationScreenState();
}

class _DriverLocationScreenState extends State<DriverLocationScreen> {
  late final LocationTrackingViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = serviceLocator<LocationTrackingViewModel>();
    _viewModel.initialize(
      vehicleId: widget.vehicleId,
      licensePlateNumber: widget.licensePlateNumber,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Theo dõi vị trí xe'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<LocationTrackingViewModel>(
      builder: (context, viewModel, _) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(viewModel),
                const SizedBox(height: 20),
                const LocationMapWidget(),
                const SizedBox(height: 20),
                _buildTrackingButton(viewModel),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(LocationTrackingViewModel viewModel) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin xe',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('ID xe: ${widget.vehicleId}'),
            const SizedBox(height: 4),
            Text('Biển số xe: ${widget.licensePlateNumber}'),
            const SizedBox(height: 16),
            Text('Trạng thái: ${viewModel.status}'),
            const SizedBox(height: 4),
            Text('Cập nhật cuối: ${viewModel.lastUpdate}'),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingButton(LocationTrackingViewModel viewModel) {
    return ElevatedButton(
      onPressed: () {
        if (viewModel.isTracking) {
          viewModel.stopTracking();
        } else {
          viewModel.startTracking(widget.jwtToken);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: viewModel.isTracking ? Colors.red : Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
        viewModel.isTracking ? 'Dừng theo dõi' : 'Bắt đầu theo dõi',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
