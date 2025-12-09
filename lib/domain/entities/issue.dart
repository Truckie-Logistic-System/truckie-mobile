/// Issue entity
class Issue {
  final String id;
  final String description;
  final double? locationLatitude;
  final double? locationLongitude;
  final IssueStatus status;
  final IssueCategory issueCategory;
  final String? vehicleAssignmentId;
  final String? issueTypeId;
  final String? staffId;
  final DateTime? reportedAt;
  final DateTime? resolvedAt;

  // Seal replacement specific fields
  final Seal? oldSeal;
  final Seal? newSeal;
  final String? sealRemovalImage;
  final String? newSealAttachedImage;
  final DateTime? newSealConfirmedAt;

  Issue({
    required this.id,
    required this.description,
    this.locationLatitude,
    this.locationLongitude,
    required this.status,
    required this.issueCategory,
    this.vehicleAssignmentId,
    this.issueTypeId,
    this.staffId,
    this.reportedAt,
    this.resolvedAt,
    this.oldSeal,
    this.newSeal,
    this.sealRemovalImage,
    this.newSealAttachedImage,
    this.newSealConfirmedAt,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] as String,
      description: json['description'] as String,
      locationLatitude: json['locationLatitude'] != null
          ? (json['locationLatitude'] as num).toDouble()
          : null,
      locationLongitude: json['locationLongitude'] != null
          ? (json['locationLongitude'] as num).toDouble()
          : null,
      status: IssueStatus.fromString(json['status'] as String),
      issueCategory: IssueCategory.fromString(json['issueCategory'] as String? ?? 'GENERAL'),
      vehicleAssignmentId: json['vehicleAssignmentEntity']?['id'] as String?,
      issueTypeId: json['issueTypeEntity']?['id'] as String?,
      staffId: json['staff']?['id'] as String?,
      reportedAt: json['reportedAt'] != null
          ? DateTime.parse(json['reportedAt'] as String)
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      oldSeal: json['oldSeal'] != null
          ? (json['oldSeal'] is Map<String, dynamic>
              ? Seal.fromJson(json['oldSeal'] as Map<String, dynamic>)
              : null) // If it's a String (ID), ignore it for now
          : null,
      newSeal: json['newSeal'] != null
          ? (json['newSeal'] is Map<String, dynamic>
              ? Seal.fromJson(json['newSeal'] as Map<String, dynamic>)
              : null) // If it's a String (ID), ignore it for now
          : null,
      sealRemovalImage: json['sealRemovalImage'] as String?,
      newSealAttachedImage: json['newSealAttachedImage'] as String?,
      newSealConfirmedAt: json['newSealConfirmedAt'] != null
          ? DateTime.parse(json['newSealConfirmedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'status': status.value,
      'issueCategory': issueCategory.value,
      if (vehicleAssignmentId != null) 'vehicleAssignmentId': vehicleAssignmentId,
      if (issueTypeId != null) 'issueTypeId': issueTypeId,
      if (staffId != null) 'staffId': staffId,
      if (reportedAt != null) 'reportedAt': reportedAt!.toIso8601String(),
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
      if (oldSeal != null) 'oldSeal': oldSeal!.toJson(),
      if (newSeal != null) 'newSeal': newSeal!.toJson(),
      if (sealRemovalImage != null) 'sealRemovalImage': sealRemovalImage,
      if (newSealAttachedImage != null) 'newSealAttachedImage': newSealAttachedImage,
      if (newSealConfirmedAt != null) 'newSealConfirmedAt': newSealConfirmedAt!.toIso8601String(),
    };
  }
}

/// Issue status enum
enum IssueStatus {
  open('OPEN', 'Chờ xử lý'),
  inProgress('IN_PROGRESS', 'Đang xử lý'),
  resolved('RESOLVED', 'Đã giải quyết'),
  paymentOverdue('PAYMENT_OVERDUE', 'Quá hạn thanh toán');

  final String value;
  final String label;

  const IssueStatus(this.value, this.label);

  static IssueStatus fromString(String value) {
    return IssueStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => IssueStatus.open,
    );
  }
}

/// Issue category enum - must match backend IssueCategoryEnum
enum IssueCategory {
  damage('DAMAGE', 'Hư hỏng'),
  missingItems('MISSING_ITEMS', 'Thiếu hàng'),
  wrongItems('WRONG_ITEMS', 'Sai hàng'),
  general('GENERAL', 'Sự cố chung'),
  accident('ACCIDENT', 'Tai nạn'),
  sealReplacement('SEAL_REPLACEMENT', 'Thay thế seal'),
  orderRejection('ORDER_REJECTION', 'Từ chối đơn hàng'),
  penalty('PENALTY', 'Vi phạm giao thông'),
  reroute('REROUTE', 'Tái định tuyến'),
  offRouteRunaway('OFF_ROUTE_RUNAWAY', 'Tài xế đi lệch tuyến');

  final String value;
  final String label;

  const IssueCategory(this.value, this.label);

  static IssueCategory fromString(String value) {
    return IssueCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => IssueCategory.general,
    );
  }
}

/// Seal entity
class Seal {
  final String id;
  final String sealCode;
  final SealStatus status;
  final DateTime? sealDate;
  final String? description;
  final String? sealAttachedImage; // Ảnh seal khi được gắn lần đầu

  Seal({
    required this.id,
    required this.sealCode,
    required this.status,
    this.sealDate,
    this.description,
    this.sealAttachedImage,
  });

  factory Seal.fromJson(Map<String, dynamic> json) {
    return Seal(
      id: json['id'] as String,
      sealCode: json['sealCode'] as String,
      status: SealStatus.fromString(json['status'] as String),
      sealDate: json['sealDate'] != null
          ? DateTime.parse(json['sealDate'] as String)
          : null,
      description: json['description'] as String?,
      sealAttachedImage: json['sealAttachedImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sealCode': sealCode,
      'status': status.value,
      if (sealDate != null) 'sealDate': sealDate!.toIso8601String(),
      if (description != null) 'description': description,
      if (sealAttachedImage != null) 'sealAttachedImage': sealAttachedImage,
    };
  }
}

/// Seal status enum
enum SealStatus {
  active('ACTIVE', 'Sẵn sàng'),
  inUse('IN_USE', 'Đang sử dụng'),
  removed('REMOVED', 'Đã gỡ'),
  replaced('REPLACED', 'Đã thay thế'),
  damaged('DAMAGED', 'Bị hỏng'),
  expired('EXPIRED', 'Hết hạn');

  final String value;
  final String label;

  const SealStatus(this.value, this.label);

  static SealStatus fromString(String value) {
    return SealStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SealStatus.active,
    );
  }
}

/// Issue type entity
class IssueType {
  final String id;
  final String issueTypeName;
  final String? description;
  final IssueCategory issueCategory;
  final bool isActive;

  IssueType({
    required this.id,
    required this.issueTypeName,
    this.description,
    required this.issueCategory,
    required this.isActive,
  });

  factory IssueType.fromJson(Map<String, dynamic> json) {
    return IssueType(
      id: json['id'] as String,
      issueTypeName: json['issueTypeName'] as String,
      description: json['description'] as String?,
      issueCategory: IssueCategory.fromString(
        json['issueCategory'] as String? ?? 'GENERAL',
      ),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issueTypeName': issueTypeName,
      if (description != null) 'description': description,
      'issueCategory': issueCategory.value,
      'isActive': isActive,
    };
  }
}
