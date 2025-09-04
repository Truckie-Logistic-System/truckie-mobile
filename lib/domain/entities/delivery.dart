import 'package:equatable/equatable.dart';

import 'location.dart';
import 'order.dart';

class Delivery extends Equatable {
  final String id;
  final Order order;
  final String driverId;
  final String status;
  final DateTime startTime;
  final DateTime? endTime;
  final LocationEntity currentLocation;
  final List<LocationEntity> route;

  const Delivery({
    required this.id,
    required this.order,
    required this.driverId,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.currentLocation,
    required this.route,
  });

  @override
  List<Object?> get props => [
    id,
    order,
    driverId,
    status,
    startTime,
    endTime,
    currentLocation,
    route,
  ];
}
