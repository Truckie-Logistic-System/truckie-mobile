import '../../domain/entities/order_with_details.dart';
import 'order_detail_model.dart';

class OrderWithDetailsModel extends OrderWithDetails {
  const OrderWithDetailsModel({
    required super.id,
    required super.notes,
    required super.totalQuantity,
    required super.orderCode,
    required super.receiverName,
    required super.receiverPhone,
    required super.receiverIdentity,
    required super.packageDescription,
    required super.createdAt,
    required super.status,
    required super.deliveryAddress,
    required super.pickupAddress,
    required super.senderName,
    required super.senderPhone,
    required super.senderCompanyName,
    required super.categoryName,
    required List<OrderDetailModel> super.orderDetails,
  });

  factory OrderWithDetailsModel.fromJson(Map<String, dynamic> json) {
    return OrderWithDetailsModel(
      id: json['id'] ?? '',
      notes: json['notes'] ?? 'Không có ghi chú',
      totalQuantity: json['totalQuantity'] ?? 0,
      orderCode: json['orderCode'] ?? '',
      receiverName: json['receiverName'] ?? '',
      receiverPhone: json['receiverPhone'] ?? '',
      receiverIdentity: json['receiverIdentity'] ?? '',
      packageDescription: json['packageDescription'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      status: json['status'] ?? '',
      deliveryAddress: json['deliveryAddress'] ?? '',
      pickupAddress: json['pickupAddress'] ?? '',
      senderName: json['senderName'] ?? '',
      senderPhone: json['senderPhone'] ?? '',
      senderCompanyName: json['senderCompanyName'] ?? '',
      categoryName: json['categoryName'] ?? '',
      orderDetails:
          (json['orderDetails'] as List<dynamic>?)
              ?.map((e) => OrderDetailModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notes': notes,
      'totalQuantity': totalQuantity,
      'orderCode': orderCode,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'receiverIdentity': receiverIdentity,
      'packageDescription': packageDescription,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'deliveryAddress': deliveryAddress,
      'pickupAddress': pickupAddress,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'senderCompanyName': senderCompanyName,
      'categoryName': categoryName,
      'orderDetails': orderDetails
          .map((e) => (e as OrderDetailModel).toJson())
          .toList(),
    };
  }
}
