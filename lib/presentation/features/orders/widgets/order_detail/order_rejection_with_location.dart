import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../app/di/service_locator.dart';
import '../../../../../core/services/global_location_manager.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../domain/repositories/issue_repository.dart';
import '../../viewmodels/order_list_viewmodel.dart';
import '../../../../widgets/driver/order_rejection_button.dart';

/// Widget wrapper to get current location and pass to OrderRejectionButton
/// Uses GlobalLocationManager to get simulated location during simulation mode
class OrderRejectionWithLocation extends StatefulWidget {
  final OrderWithDetails order;
  final VoidCallback onReported;

  const OrderRejectionWithLocation({
    super.key,
    required this.order,
    required this.onReported,
  });

  @override
  State<OrderRejectionWithLocation> createState() => _OrderRejectionWithLocationState();
}

class _OrderRejectionWithLocationState extends State<OrderRejectionWithLocation> {
  late final GlobalLocationManager _globalLocationManager;
  double? _currentLatitude;
  double? _currentLongitude;

  @override
  void initState() {
    super.initState();
    _globalLocationManager = getIt<GlobalLocationManager>();
    _getCurrentLocation();
  }

  void _getCurrentLocation() {
    // Get location from GlobalLocationManager
    // This will return simulated location if simulation mode is active
    _currentLatitude = _globalLocationManager.currentLatitude;
    _currentLongitude = _globalLocationManager.currentLongitude;

    if (_currentLatitude == null || _currentLongitude == null) {

    } else {

    }
  }

  @override
  Widget build(BuildContext context) {
    // Get issue repository from service locator instead of context to avoid Provider errors
    final issueRepository = getIt<IssueRepository>();
    // Get OrderListViewModel from context (it's provided in OrderDetailScreen)
    final orderListViewModel = context.read<OrderListViewModel>();

    return OrderRejectionButton(
      order: widget.order,
      onReported: widget.onReported,
      currentLatitude: _currentLatitude,
      currentLongitude: _currentLongitude,
      issueRepository: issueRepository,
      orderListViewModel: orderListViewModel,
    );
  }
}
