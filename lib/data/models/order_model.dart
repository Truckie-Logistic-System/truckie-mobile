import '../../domain/entities/order.dart';

class OrderModel extends Order {
  const OrderModel({
    required String id,
    required String notes,
    required int totalQuantity,
    required String orderCode,
    required String receiverName,
    required String receiverPhone,
    required String receiverIdentity,
    required String packageDescription,
    required DateTime createdAt,
    required String status,
  }) : super(
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
