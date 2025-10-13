import '../../domain/entities/order_detail.dart';

class OrderDetailModel extends OrderDetail {
  const OrderDetailModel({
    required super.id,
    required super.weightBaseUnit,
    required super.unit,
    required super.description,
    required super.status,
    super.startTime,
    super.estimatedStartTime,
    super.endTime,
    super.estimatedEndTime,
    required super.createdAt,
    required super.trackingCode,
    OrderSizeModel? super.orderSize,
    VehicleAssignmentModel? super.vehicleAssignment,
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    return OrderDetailModel(
      id: json['id'] ?? '',
      weightBaseUnit: json['weightBaseUnit']?.toDouble() ?? 0.0,
      unit: json['unit'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? '',
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      estimatedStartTime: json['estimatedStartTime'] != null
          ? DateTime.parse(json['estimatedStartTime'])
          : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      estimatedEndTime: json['estimatedEndTime'] != null
          ? DateTime.parse(json['estimatedEndTime'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      trackingCode: json['trackingCode'] ?? '',
      orderSize: json['orderSize'] != null
          ? OrderSizeModel.fromJson(json['orderSize'])
          : null,
      vehicleAssignment: json['vehicleAssignment'] != null
          ? VehicleAssignmentModel.fromJson(json['vehicleAssignment'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'weightBaseUnit': weightBaseUnit,
      'unit': unit,
      'description': description,
      'status': status,
      'startTime': startTime?.toIso8601String(),
      'estimatedStartTime': estimatedStartTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'estimatedEndTime': estimatedEndTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'trackingCode': trackingCode,
      'orderSize': orderSize != null
          ? (orderSize as OrderSizeModel).toJson()
          : null,
      'vehicleAssignment': vehicleAssignment != null
          ? (vehicleAssignment as VehicleAssignmentModel).toJson()
          : null,
    };
  }
}

class OrderSizeModel extends OrderSize {
  const OrderSizeModel({
    required super.id,
    required super.description,
    required super.minLength,
    required super.maxLength,
    required super.minHeight,
    required super.maxHeight,
    required super.minWidth,
    required super.maxWidth,
  });

  factory OrderSizeModel.fromJson(Map<String, dynamic> json) {
    return OrderSizeModel(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      minLength: json['minLength']?.toDouble() ?? 0.0,
      maxLength: json['maxLength']?.toDouble() ?? 0.0,
      minHeight: json['minHeight']?.toDouble() ?? 0.0,
      maxHeight: json['maxHeight']?.toDouble() ?? 0.0,
      minWidth: json['minWidth']?.toDouble() ?? 0.0,
      maxWidth: json['maxWidth']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'minLength': minLength,
      'maxLength': maxLength,
      'minHeight': minHeight,
      'maxHeight': maxHeight,
      'minWidth': minWidth,
      'maxWidth': maxWidth,
    };
  }
}

class VehicleAssignmentModel extends VehicleAssignment {
  const VehicleAssignmentModel({
    required super.id,
    VehicleModel? super.vehicle,
    DriverModel? super.primaryDriver,
    DriverModel? super.secondaryDriver,
    required super.status,
    required super.trackingCode,
    required List<JourneyHistoryModel> super.journeyHistories,
  });

  factory VehicleAssignmentModel.fromJson(Map<String, dynamic> json) {
    return VehicleAssignmentModel(
      id: json['id'] ?? '',
      vehicle: json['vehicle'] != null
          ? VehicleModel.fromJson(json['vehicle'])
          : null,
      primaryDriver: json['primaryDriver'] != null
          ? DriverModel.fromJson(json['primaryDriver'])
          : null,
      secondaryDriver: json['secondaryDriver'] != null
          ? DriverModel.fromJson(json['secondaryDriver'])
          : null,
      status: json['status'] ?? '',
      trackingCode: json['trackingCode'] ?? '',
      journeyHistories:
          (json['journeyHistories'] as List<dynamic>?)
              ?.map((e) => JourneyHistoryModel.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle': vehicle != null ? (vehicle as VehicleModel).toJson() : null,
      'primaryDriver': primaryDriver != null
          ? (primaryDriver as DriverModel).toJson()
          : null,
      'secondaryDriver': secondaryDriver != null
          ? (secondaryDriver as DriverModel).toJson()
          : null,
      'status': status,
      'trackingCode': trackingCode,
      'journeyHistories': journeyHistories
          .map((e) => (e as JourneyHistoryModel).toJson())
          .toList(),
    };
  }
}

class VehicleModel extends Vehicle {
  const VehicleModel({
    super.id,
    required super.manufacturer,
    required super.model,
    required super.licensePlateNumber,
    required super.vehicleType,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      manufacturer: json['manufacturer'] ?? '',
      model: json['model'] ?? '',
      licensePlateNumber: json['licensePlateNumber'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'manufacturer': manufacturer,
      'model': model,
      'licensePlateNumber': licensePlateNumber,
      'vehicleType': vehicleType,
    };
  }
}

class DriverModel extends Driver {
  const DriverModel({
    required super.id,
    required super.fullName,
    required super.phoneNumber,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'fullName': fullName, 'phoneNumber': phoneNumber};
  }
}

class JourneyHistoryModel extends JourneyHistory {
  const JourneyHistoryModel({
    required super.id,
    required super.journeyName,
    required super.journeyType,
    required super.status,
    required super.totalTollFee,
    super.reasonForReroute,
    required super.vehicleAssignmentId,
    required List<JourneySegmentModel> super.journeySegments,
    required super.createdAt,
    required super.modifiedAt,
  });

  factory JourneyHistoryModel.fromJson(Map<String, dynamic> json) {
    return JourneyHistoryModel(
      id: json['id'] ?? '',
      journeyName: json['journeyName'] ?? '',
      journeyType: json['journeyType'] ?? '',
      status: json['status'] ?? '',
      totalTollFee: json['totalTollFee']?.toDouble() ?? 0.0,
      reasonForReroute: json['reasonForReroute'],
      vehicleAssignmentId: json['vehicleAssignmentId'] ?? '',
      journeySegments:
          (json['journeySegments'] as List<dynamic>?)
              ?.map((e) => JourneySegmentModel.fromJson(e))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journeyName': journeyName,
      'journeyType': journeyType,
      'status': status,
      'totalTollFee': totalTollFee,
      'reasonForReroute': reasonForReroute,
      'vehicleAssignmentId': vehicleAssignmentId,
      'journeySegments': journeySegments
          .map((e) => (e as JourneySegmentModel).toJson())
          .toList(),
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }
}

class JourneySegmentModel extends JourneySegment {
  const JourneySegmentModel({
    required super.id,
    required super.segmentOrder,
    required super.startPointName,
    required super.endPointName,
    required super.startLatitude,
    required super.startLongitude,
    required super.endLatitude,
    required super.endLongitude,
    required super.distanceMeters,
    required super.pathCoordinatesJson,
    required super.status,
    required super.createdAt,
    required super.modifiedAt,
  });

  factory JourneySegmentModel.fromJson(Map<String, dynamic> json) {
    return JourneySegmentModel(
      id: json['id'] ?? '',
      segmentOrder: json['segmentOrder'] ?? 0,
      startPointName: json['startPointName'] ?? '',
      endPointName: json['endPointName'] ?? '',
      startLatitude: json['startLatitude']?.toDouble() ?? 0.0,
      startLongitude: json['startLongitude']?.toDouble() ?? 0.0,
      endLatitude: json['endLatitude']?.toDouble() ?? 0.0,
      endLongitude: json['endLongitude']?.toDouble() ?? 0.0,
      distanceMeters: json['distanceMeters'] ?? 0,
      pathCoordinatesJson: json['pathCoordinatesJson'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'segmentOrder': segmentOrder,
      'startPointName': startPointName,
      'endPointName': endPointName,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'distanceMeters': distanceMeters,
      'pathCoordinatesJson': pathCoordinatesJson,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }
}
