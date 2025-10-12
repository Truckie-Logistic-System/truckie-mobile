import '../../domain/entities/order_with_details.dart';
import 'order_detail_model.dart';

class OrderWithDetailsModel extends OrderWithDetails {
  const OrderWithDetailsModel({
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
    required String deliveryAddress,
    required String pickupAddress,
    required String senderName,
    required String senderPhone,
    required String senderCompanyName,
    required String categoryName,
    required List<OrderDetailModel> orderDetails,
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
         deliveryAddress: deliveryAddress,
         pickupAddress: pickupAddress,
         senderName: senderName,
         senderPhone: senderPhone,
         senderCompanyName: senderCompanyName,
         categoryName: categoryName,
         orderDetails: orderDetails,
       );

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
