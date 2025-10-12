import '../../domain/entities/order_detail.dart';

class OrderDetailModel extends OrderDetail {
  const OrderDetailModel({
    required String id,
    required double weightBaseUnit,
    required String unit,
    required String description,
    required String status,
    DateTime? startTime,
    DateTime? estimatedStartTime,
    DateTime? endTime,
    DateTime? estimatedEndTime,
    required DateTime createdAt,
    required String trackingCode,
    OrderSizeModel? orderSize,
    VehicleAssignmentModel? vehicleAssignment,
  }) : super(
         id: id,
         weightBaseUnit: weightBaseUnit,
         unit: unit,
         description: description,
         status: status,
         startTime: startTime,
         estimatedStartTime: estimatedStartTime,
         endTime: endTime,
         estimatedEndTime: estimatedEndTime,
         createdAt: createdAt,
         trackingCode: trackingCode,
         orderSize: orderSize,
         vehicleAssignment: vehicleAssignment,
       );

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
    required String id,
    required String description,
    required double minLength,
    required double maxLength,
    required double minHeight,
    required double maxHeight,
    required double minWidth,
    required double maxWidth,
  }) : super(
         id: id,
         description: description,
         minLength: minLength,
         maxLength: maxLength,
         minHeight: minHeight,
         maxHeight: maxHeight,
         minWidth: minWidth,
         maxWidth: maxWidth,
       );

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
    required String id,
    VehicleModel? vehicle,
    DriverModel? primaryDriver,
    DriverModel? secondaryDriver,
    required String status,
    required String trackingCode,
    required List<JourneyHistoryModel> journeyHistories,
  }) : super(
         id: id,
         vehicle: vehicle,
         primaryDriver: primaryDriver,
         secondaryDriver: secondaryDriver,
         status: status,
         trackingCode: trackingCode,
         journeyHistories: journeyHistories,
       );

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
    String? id,
    required String manufacturer,
    required String model,
    required String licensePlateNumber,
    required String vehicleType,
  }) : super(
         id: id,
         manufacturer: manufacturer,
         model: model,
         licensePlateNumber: licensePlateNumber,
         vehicleType: vehicleType,
       );

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
    required String id,
    required String fullName,
    required String phoneNumber,
  }) : super(id: id, fullName: fullName, phoneNumber: phoneNumber);

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
    required String id,
    required String journeyName,
    required String journeyType,
    required String status,
    required double totalTollFee,
    String? reasonForReroute,
    required String vehicleAssignmentId,
    required List<JourneySegmentModel> journeySegments,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) : super(
         id: id,
         journeyName: journeyName,
         journeyType: journeyType,
         status: status,
         totalTollFee: totalTollFee,
         reasonForReroute: reasonForReroute,
         vehicleAssignmentId: vehicleAssignmentId,
         journeySegments: journeySegments,
         createdAt: createdAt,
         modifiedAt: modifiedAt,
       );

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
    required String id,
    required int segmentOrder,
    required String startPointName,
    required String endPointName,
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    required int distanceMeters,
    required String pathCoordinatesJson,
    required String status,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) : super(
         id: id,
         segmentOrder: segmentOrder,
         startPointName: startPointName,
         endPointName: endPointName,
         startLatitude: startLatitude,
         startLongitude: startLongitude,
         endLatitude: endLatitude,
         endLongitude: endLongitude,
         distanceMeters: distanceMeters,
         pathCoordinatesJson: pathCoordinatesJson,
         status: status,
         createdAt: createdAt,
         modifiedAt: modifiedAt,
       );

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
