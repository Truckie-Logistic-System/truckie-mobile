import 'package:equatable/equatable.dart';

class OrderDetail extends Equatable {
  final String id;
  final double weightBaseUnit;
  final String unit;
  final String description;
  final String status;
  final DateTime? startTime;
  final DateTime? estimatedStartTime;
  final DateTime? endTime;
  final DateTime? estimatedEndTime;
  final DateTime createdAt;
  final String trackingCode;
  final OrderSize? orderSize;
  final String? vehicleAssignmentId; // Changed from full object to ID reference

  const OrderDetail({
    required this.id,
    required this.weightBaseUnit,
    required this.unit,
    required this.description,
    required this.status,
    this.startTime,
    this.estimatedStartTime,
    this.endTime,
    this.estimatedEndTime,
    required this.createdAt,
    required this.trackingCode,
    this.orderSize,
    this.vehicleAssignmentId,
  });

  @override
  List<Object?> get props => [
    id,
    weightBaseUnit,
    unit,
    description,
    status,
    startTime,
    estimatedStartTime,
    endTime,
    estimatedEndTime,
    createdAt,
    trackingCode,
    orderSize,
    vehicleAssignmentId,
  ];
}

class OrderSize extends Equatable {
  final String id;
  final String description;
  final double minLength;
  final double maxLength;
  final double minHeight;
  final double maxHeight;
  final double minWidth;
  final double maxWidth;

  const OrderSize({
    required this.id,
    required this.description,
    required this.minLength,
    required this.maxLength,
    required this.minHeight,
    required this.maxHeight,
    required this.minWidth,
    required this.maxWidth,
  });

  @override
  List<Object?> get props => [
    id,
    description,
    minLength,
    maxLength,
    minHeight,
    maxHeight,
    minWidth,
    maxWidth,
  ];
}

class VehicleAssignment extends Equatable {
  final String id;
  final Vehicle? vehicle;
  final Driver? primaryDriver;
  final Driver? secondaryDriver;
  final String status;
  final String trackingCode;
  final List<JourneyHistory> journeyHistories;
  final List<OrderSeal> orderSeals; // Deprecated, use seals instead
  final List<VehicleIssue> issues; // New field for issues in this vehicle assignment
  final List<PhotoCompletion> photoCompletions; // New field for photo completions
  final List<VehicleSeal> seals; // New field for seals (replaces orderSeals)

  const VehicleAssignment({
    required this.id,
    this.vehicle,
    this.primaryDriver,
    this.secondaryDriver,
    required this.status,
    required this.trackingCode,
    required this.journeyHistories,
    this.orderSeals = const [], // Deprecated
    this.issues = const [],
    this.photoCompletions = const [],
    this.seals = const [],
  });

  @override
  List<Object?> get props => [
    id,
    vehicle,
    primaryDriver,
    secondaryDriver,
    status,
    trackingCode,
    journeyHistories,
    orderSeals,
    issues,
    photoCompletions,
    seals,
  ];
}

class Vehicle extends Equatable {
  final String? id;
  final String manufacturer;
  final String model;
  final String licensePlateNumber;
  final String vehicleType;
  final String? vehicleTypeDescription; // Vehicle type description from backend

  const Vehicle({
    this.id,
    required this.manufacturer,
    required this.model,
    required this.licensePlateNumber,
    required this.vehicleType,
    this.vehicleTypeDescription, // Optional vehicle type description
  });

  @override
  List<Object?> get props => [
    id,
    manufacturer,
    model,
    licensePlateNumber,
    vehicleType,
    vehicleTypeDescription,
  ];
}

class Driver extends Equatable {
  final String id;
  final String fullName;
  final String phoneNumber;

  const Driver({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
  });

  @override
  List<Object?> get props => [id, fullName, phoneNumber];
}

class JourneyHistory extends Equatable {
  final String id;
  final String journeyName;
  final String journeyType;
  final String status;
  final double totalTollFee;
  final int? totalTollCount;
  final int? totalDistance;
  final String? reasonForReroute;
  final String vehicleAssignmentId;
  final List<JourneySegment> journeySegments;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const JourneyHistory({
    required this.id,
    required this.journeyName,
    required this.journeyType,
    required this.status,
    required this.totalTollFee,
    this.totalTollCount,
    this.totalDistance,
    this.reasonForReroute,
    required this.vehicleAssignmentId,
    required this.journeySegments,
    required this.createdAt,
    required this.modifiedAt,
  });

  @override
  List<Object?> get props => [
    id,
    journeyName,
    journeyType,
    status,
    totalTollFee,
    totalTollCount,
    totalDistance,
    reasonForReroute,
    vehicleAssignmentId,
    journeySegments,
    createdAt,
    modifiedAt,
  ];
}

class JourneySegment extends Equatable {
  final String id;
  final int segmentOrder;
  final String startPointName;
  final String endPointName;
  final double? startLatitude; // Nullable for return journey segments
  final double? startLongitude; // Nullable for return journey segments
  final double? endLatitude; // Nullable for return journey segments
  final double? endLongitude; // Nullable for return journey segments
  final double distanceKilometers;
  final String? pathCoordinatesJson; // Nullable for return journey segments
  final String status;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const JourneySegment({
    required this.id,
    required this.segmentOrder,
    required this.startPointName,
    required this.endPointName,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    required this.distanceKilometers,
    this.pathCoordinatesJson,
    required this.status,
    required this.createdAt,
    required this.modifiedAt,
  });

  @override
  List<Object?> get props => [
    id,
    segmentOrder,
    startPointName,
    endPointName,
    startLatitude,
    startLongitude,
    endLatitude,
    endLongitude,
    distanceKilometers,
    pathCoordinatesJson,
    status,
    createdAt,
    modifiedAt,
  ];
}

class OrderSeal extends Equatable {
  final String id;
  final String description;
  final DateTime sealDate;
  final String status; // ACTIVE, IN_USED, REMOVED, USED
  final String sealId;
  final String sealCode;
  final String? sealAttachedImage;
  final DateTime? sealRemovalTime;
  final String? sealRemovalReason;

  const OrderSeal({
    required this.id,
    required this.description,
    required this.sealDate,
    required this.status,
    required this.sealId,
    required this.sealCode,
    this.sealAttachedImage,
    this.sealRemovalTime,
    this.sealRemovalReason,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isInUsed => status == 'IN_USED';
  bool get isRemoved => status == 'REMOVED';
  bool get isUsed => status == 'USED';
  bool get canBeSelected => status == 'ACTIVE';

  @override
  List<Object?> get props => [
    id,
    description,
    sealDate,
    status,
    sealId,
    sealCode,
    sealAttachedImage,
    sealRemovalTime,
    sealRemovalReason,
  ];
}

/// VehicleIssue - Issue attached to a vehicle assignment
class VehicleIssue extends Equatable {
  final String id;
  final String description;
  final double? locationLatitude;
  final double? locationLongitude;
  final String status; // OPEN, IN_PROGRESS, RESOLVED
  final String vehicleAssignmentId;
  final dynamic staff; // Can be null or staff object
  final String issueTypeName;
  final String? issueTypeDescription; // Description from IssueType
  final DateTime? reportedAt; // When the issue was reported
  final String issueCategory; // ORDER_REJECTION, SEAL_REPLACEMENT, etc.
  final List<String> issueImages;
  
  // Seal replacement fields
  final dynamic oldSeal;
  final dynamic newSeal;
  final String? sealRemovalImage;
  final String? newSealAttachedImage;
  final DateTime? newSealConfirmedAt;
  
  // Order rejection fields
  final DateTime? paymentDeadline;
  final double? calculatedFee;
  final double? adjustedFee;
  final double? finalFee;
  final dynamic affectedOrderDetails;
  final dynamic refund;
  final dynamic transaction;

  const VehicleIssue({
    required this.id,
    required this.description,
    this.locationLatitude,
    this.locationLongitude,
    required this.status,
    required this.vehicleAssignmentId,
    this.staff,
    required this.issueTypeName,
    this.issueTypeDescription,
    this.reportedAt,
    required this.issueCategory,
    this.issueImages = const [],
    this.oldSeal,
    this.newSeal,
    this.sealRemovalImage,
    this.newSealAttachedImage,
    this.newSealConfirmedAt,
    this.paymentDeadline,
    this.calculatedFee,
    this.adjustedFee,
    this.finalFee,
    this.affectedOrderDetails,
    this.refund,
    this.transaction,
  });

  @override
  List<Object?> get props => [
    id,
    description,
    locationLatitude,
    locationLongitude,
    status,
    vehicleAssignmentId,
    staff,
    issueTypeName,
    issueTypeDescription,
    reportedAt,
    issueCategory,
    issueImages,
    oldSeal,
    newSeal,
    sealRemovalImage,
    newSealAttachedImage,
    newSealConfirmedAt,
    paymentDeadline,
    calculatedFee,
    adjustedFee,
    finalFee,
    affectedOrderDetails,
    refund,
    transaction,
  ];
}

/// PhotoCompletion - Completion photo for delivery
class PhotoCompletion extends Equatable {
  final String id;
  final String imageUrl;
  final String? description;
  final DateTime? createdAt;
  final String vehicleAssignmentId;

  const PhotoCompletion({
    required this.id,
    required this.imageUrl,
    this.description,
    this.createdAt,
    required this.vehicleAssignmentId,
  });

  @override
  List<Object?> get props => [
    id,
    imageUrl,
    description,
    createdAt,
    vehicleAssignmentId,
  ];
}

/// VehicleSeal - Seal attached to a vehicle (replaces OrderSeal)
class VehicleSeal extends Equatable {
  final String id;
  final String description;
  final DateTime sealDate;
  final String status; // ACTIVE, IN_USE, REMOVED, etc.
  final String sealCode;
  final String? sealAttachedImage;

  const VehicleSeal({
    required this.id,
    required this.description,
    required this.sealDate,
    required this.status,
    required this.sealCode,
    this.sealAttachedImage,
  });

  bool get isActive => status == 'ACTIVE';
  bool get isInUse => status == 'IN_USE';
  bool get isInUsed => status == 'IN_USE'; // Alias for backward compatibility
  bool get isRemoved => status == 'REMOVED';
  bool get canBeSelected => status == 'ACTIVE';

  @override
  List<Object?> get props => [
    id,
    description,
    sealDate,
    status,
    sealCode,
    sealAttachedImage,
  ];
}
