import 'package:equatable/equatable.dart';

class Order extends Equatable {
  final String id;
  final String code;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final DateTime pickupTime;
  final DateTime estimatedDeliveryTime;
  final String customerName;
  final String customerPhone;
  final double distance;
  final List<String> items;
  final String notes;

  const Order({
    required this.id,
    required this.code,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.pickupTime,
    required this.estimatedDeliveryTime,
    required this.customerName,
    required this.customerPhone,
    required this.distance,
    required this.items,
    this.notes = '',
  });

  @override
  List<Object?> get props => [
    id,
    code,
    status,
    pickupAddress,
    deliveryAddress,
    pickupTime,
    estimatedDeliveryTime,
    customerName,
    customerPhone,
    distance,
    items,
    notes,
  ];
}
