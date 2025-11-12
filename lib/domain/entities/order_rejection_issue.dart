/// Entity for ORDER_REJECTION issue detail
class OrderRejectionIssue {
  final String issueId;
  final String issueCode;
  final String? description;
  final String status; // OPEN, IN_PROGRESS, RESOLVED
  final DateTime reportedAt;
  final DateTime? resolvedAt;
  
  // Customer information
  final CustomerInfo? customerInfo;
  
  // Return shipping fee
  final double? calculatedFee;
  final double? adjustedFee;
  final double? finalFee;
  
  // Transaction
  final ReturnTransaction? returnTransaction;
  
  // Payment deadline
  final DateTime? paymentDeadline;
  
  // Return journey
  final ReturnJourney? returnJourney;
  
  // Selected packages for return (not all packages in trip)
  final List<AffectedOrderDetail> affectedOrderDetails;
  
  // Return delivery images (multiple photos allowed)
  final List<String> returnDeliveryImages;

  OrderRejectionIssue({
    required this.issueId,
    required this.issueCode,
    this.description,
    required this.status,
    required this.reportedAt,
    this.resolvedAt,
    this.customerInfo,
    this.calculatedFee,
    this.adjustedFee,
    this.finalFee,
    this.returnTransaction,
    this.paymentDeadline,
    this.returnJourney,
    required this.affectedOrderDetails,
    this.returnDeliveryImages = const [],
  });

  factory OrderRejectionIssue.fromJson(Map<String, dynamic> json) {
    return OrderRejectionIssue(
      issueId: json['issueId'],
      issueCode: json['issueCode'],
      description: json['description'],
      status: json['status'],
      reportedAt: DateTime.parse(json['reportedAt']),
      resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt']) : null,
      customerInfo: json['customerInfo'] != null 
          ? CustomerInfo.fromJson(json['customerInfo']) 
          : null,
      calculatedFee: json['calculatedFee']?.toDouble(),
      adjustedFee: json['adjustedFee']?.toDouble(),
      finalFee: json['finalFee']?.toDouble(),
      returnTransaction: json['returnTransaction'] != null 
          ? ReturnTransaction.fromJson(json['returnTransaction']) 
          : null,
      paymentDeadline: json['paymentDeadline'] != null 
          ? DateTime.parse(json['paymentDeadline']) 
          : null,
      returnJourney: json['returnJourney'] != null 
          ? ReturnJourney.fromJson(json['returnJourney']) 
          : null,
      affectedOrderDetails: (json['affectedOrderDetails'] as List?)
          ?.map((e) => AffectedOrderDetail.fromJson(e))
          .toList() ?? [],
      returnDeliveryImages: (json['returnDeliveryImages'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }
}

class CustomerInfo {
  final String customerId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String? company;

  CustomerInfo({
    required this.customerId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    this.company,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      customerId: json['customerId'],
      fullName: json['fullName'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      company: json['company'],
    );
  }
}

class ReturnTransaction {
  final String id;
  final double amount;
  final String status; // PENDING, PAID, FAILED, etc.
  final String currencyCode;
  final String paymentProvider;
  final String? gatewayResponse;
  final String? gatewayOrderCode;
  final DateTime? paymentDate;

  ReturnTransaction({
    required this.id,
    required this.amount,
    required this.status,
    required this.currencyCode,
    required this.paymentProvider,
    this.gatewayResponse,
    this.gatewayOrderCode,
    this.paymentDate,
  });

  factory ReturnTransaction.fromJson(Map<String, dynamic> json) {
    return ReturnTransaction(
      id: json['id'],
      amount: json['amount']?.toDouble() ?? 0.0,
      status: json['status'],
      currencyCode: json['currencyCode'],
      paymentProvider: json['paymentProvider'],
      gatewayResponse: json['gatewayResponse'],
      gatewayOrderCode: json['gatewayOrderCode'],
      paymentDate: json['paymentDate'] != null 
          ? DateTime.parse(json['paymentDate']) 
          : null,
    );
  }
}

class ReturnJourney {
  final String id;
  final String journeyName;
  final String journeyType; // RETURN
  final String status; // ACTIVE, INACTIVE
  final String? reasonForReroute;
  final int? totalTollFee;
  final int? totalTollCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReturnJourney({
    required this.id,
    required this.journeyName,
    required this.journeyType,
    required this.status,
    this.reasonForReroute,
    this.totalTollFee,
    this.totalTollCount,
    this.createdAt,
    this.updatedAt,
  });

  factory ReturnJourney.fromJson(Map<String, dynamic> json) {
    return ReturnJourney(
      id: json['id'],
      journeyName: json['journeyName'],
      journeyType: json['journeyType'],
      status: json['status'],
      reasonForReroute: json['reasonForReroute'],
      totalTollFee: json['totalTollFee'],
      totalTollCount: json['totalTollCount'],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
    );
  }
}

class AffectedOrderDetail {
  final String trackingCode;
  final String? description;
  final double? weightBaseUnit;
  final String? unit;

  AffectedOrderDetail({
    required this.trackingCode,
    this.description,
    this.weightBaseUnit,
    this.unit,
  });

  factory AffectedOrderDetail.fromJson(Map<String, dynamic> json) {
    return AffectedOrderDetail(
      trackingCode: json['trackingCode'],
      description: json['description'],
      weightBaseUnit: json['weightBaseUnit']?.toDouble(),
      unit: json['unit'],
    );
  }
}
