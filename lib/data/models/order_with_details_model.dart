import '../../domain/entities/order_with_details.dart';
import '../../domain/entities/order_detail.dart';
import '../../domain/entities/order_rejection_issue.dart';
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
    super.categoryDescription, // Optional category description
    required List<OrderDetailModel> super.orderDetails,
    super.vehicleAssignments = const [],
    super.orderRejectionIssue,
  });

  factory OrderWithDetailsModel.fromJson(Map<String, dynamic> json) {
    // Parse vehicle assignments first
    final vehicleAssignments = (json['vehicleAssignments'] as List<dynamic>?)
            ?.map((e) => VehicleAssignmentModel.fromJson(e))
            .toList() ??
        [];
    
    // Extract ORDER_REJECTION issue from vehicle assignments issues
    OrderRejectionIssue? orderRejectionIssue;
    for (var va in vehicleAssignments) {
      try {
        final rejectionIssue = va.issues.firstWhere(
          (issue) => issue.issueCategory == 'ORDER_REJECTION',
        );
        orderRejectionIssue = _convertVehicleIssueToOrderRejectionIssue(rejectionIssue);
        break; // Only one ORDER_REJECTION issue per order
      } catch (e) {
        // No ORDER_REJECTION issue found in this vehicle assignment, continue
        continue;
      }
    }
    
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
      categoryDescription: json['categoryDescription'] ?? json['category']?['description'], // Handle both flat and nested structures
      orderDetails:
          (json['orderDetails'] as List<dynamic>?)
              ?.map((e) => OrderDetailModel.fromJson(e))
              .toList() ??
          [],
      vehicleAssignments: vehicleAssignments,
      orderRejectionIssue: orderRejectionIssue,
    );
  }
  
  /// Convert VehicleIssue with ORDER_REJECTION category to OrderRejectionIssue
  static OrderRejectionIssue _convertVehicleIssueToOrderRejectionIssue(VehicleIssue issue) {
    // Parse affected order details
    List<AffectedOrderDetail> affectedOrderDetails = [];
    if (issue.affectedOrderDetails != null) {
      if (issue.affectedOrderDetails is List) {
        affectedOrderDetails = (issue.affectedOrderDetails as List)
            .map((e) => AffectedOrderDetail.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    
    return OrderRejectionIssue(
      issueId: issue.id,
      issueCode: issue.id, // Use ID as code since backend doesn't provide separate code
      description: issue.description,
      status: issue.status,
      reportedAt: issue.reportedAt ?? DateTime.now(),
      resolvedAt: null, // Not provided in VehicleIssue
      customerInfo: null, // Not provided in VehicleIssue
      calculatedFee: issue.calculatedFee,
      adjustedFee: issue.adjustedFee,
      finalFee: issue.finalFee,
      returnTransaction: null, // Transaction is separate, not included in simple issue response
      paymentDeadline: issue.paymentDeadline,
      returnJourney: null, // Journey info is separate
      affectedOrderDetails: affectedOrderDetails,
      returnDeliveryImages: [], // Not available in VehicleIssue
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
      'vehicleAssignments': vehicleAssignments
          .map((e) => (e as VehicleAssignmentModel).toJson())
          .toList(),
    };
  }
}
