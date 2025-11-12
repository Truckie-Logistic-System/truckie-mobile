import '../../domain/entities/order_rejection_issue.dart';

class OrderRejectionDetailResponse {
  final OrderRejectionIssue issue;

  OrderRejectionDetailResponse({required this.issue});

  factory OrderRejectionDetailResponse.fromJson(Map<String, dynamic> json) {
    return OrderRejectionDetailResponse(
      issue: OrderRejectionIssue.fromJson(json),
    );
  }
}
