import '../../domain/entities/order.dart';

class OrderModel extends Order {
  const OrderModel({
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
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
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
    };
  }
}
