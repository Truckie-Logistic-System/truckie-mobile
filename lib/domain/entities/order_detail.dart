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
  final VehicleAssignment? vehicleAssignment;

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
    this.vehicleAssignment,
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
    vehicleAssignment,
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

  const VehicleAssignment({
    required this.id,
    this.vehicle,
    this.primaryDriver,
    this.secondaryDriver,
    required this.status,
    required this.trackingCode,
    required this.journeyHistories,
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
  ];
}

class Vehicle extends Equatable {
  final String? id;
  final String manufacturer;
  final String model;
  final String licensePlateNumber;
  final String vehicleType;

  const Vehicle({
    this.id,
    required this.manufacturer,
    required this.model,
    required this.licensePlateNumber,
    required this.vehicleType,
  });

  @override
  List<Object?> get props => [
    id,
    manufacturer,
    model,
    licensePlateNumber,
    vehicleType,
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
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final int distanceMeters;
  final String pathCoordinatesJson;
  final String status;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const JourneySegment({
    required this.id,
    required this.segmentOrder,
    required this.startPointName,
    required this.endPointName,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.distanceMeters,
    required this.pathCoordinatesJson,
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
    distanceMeters,
    pathCoordinatesJson,
    status,
    createdAt,
    modifiedAt,
  ];
}
