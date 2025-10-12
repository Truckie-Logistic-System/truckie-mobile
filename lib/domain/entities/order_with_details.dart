import 'package:equatable/equatable.dart';

import 'order.dart';
import 'order_detail.dart';

class OrderWithDetails extends Equatable {
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
  final String deliveryAddress;
  final String pickupAddress;
  final String senderName;
  final String senderPhone;
  final String senderCompanyName;
  final String categoryName;
  final List<OrderDetail> orderDetails;

  const OrderWithDetails({
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
    required this.deliveryAddress,
    required this.pickupAddress,
    required this.senderName,
    required this.senderPhone,
    required this.senderCompanyName,
    required this.categoryName,
    required this.orderDetails,
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
    deliveryAddress,
    pickupAddress,
    senderName,
    senderPhone,
    senderCompanyName,
    categoryName,
    orderDetails,
  ];

  // Chuyển đổi từ OrderWithDetails sang Order
  Order toOrder() {
    return Order(
      id: id,
      notes: notes,
      totalQuantity: totalQuantity,
      orderCode: orderCode,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      receiverIdentity: receiverIdentity,
      packageDescription: packageDescription,
      createdAt: createdAt,
      status: status,
    );
  }
}
