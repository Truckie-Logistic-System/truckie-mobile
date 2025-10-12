import 'package:equatable/equatable.dart';

class Order extends Equatable {
  final String id;
  final String notes;
  final int totalQuantity;
  final String orderCode;
  final String receiverName;
  final String receiverPhone;
  final String receiverIdentity;
  final String packageDescription;
  final DateTime createdAt;
  final String status;

  const Order({
    required this.id,
    required this.notes,
    required this.totalQuantity,
    required this.orderCode,
    required this.receiverName,
    required this.receiverPhone,
    required this.receiverIdentity,
    required this.packageDescription,
    required this.createdAt,
    required this.status,
  });

  @override
  List<Object?> get props => [
    id,
    notes,
    totalQuantity,
    orderCode,
    receiverName,
    receiverPhone,
    receiverIdentity,
    packageDescription,
    createdAt,
    status,
  ];
}
