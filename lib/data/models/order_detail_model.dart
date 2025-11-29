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
    super.vehicleAssignmentId,
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
      vehicleAssignmentId: json['vehicleAssignmentId'] as String?,
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
      'vehicleAssignmentId': vehicleAssignmentId,
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
    List<OrderSealModel> super.orderSeals = const [],
    List<VehicleIssueModel> super.issues = const [],
    List<PhotoCompletionModel> super.photoCompletions = const [],
    List<VehicleSealModel> super.seals = const [],
  });

  factory VehicleAssignmentModel.fromJson(Map<String, dynamic> json) {
    // Handle both 'seals' (new format) and 'orderSeals' (old format for backwards compatibility)
    final orderSealsJson = json['orderSeals'] ?? [];
    final sealsJson = json['seals'] ?? [];
    final issuesJson = json['issues'] ?? [];
    final photoCompletionsJson = json['photoCompletions'] ?? [];
    
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
      orderSeals:
          (orderSealsJson as List<dynamic>?)
              ?.map((e) => OrderSealModel.fromJson(e))
              .toList() ??
          [],
      issues:
          (issuesJson as List<dynamic>?)
              ?.map((e) => VehicleIssueModel.fromJson(e))
              .toList() ??
          [],
      photoCompletions:
          (photoCompletionsJson as List<dynamic>?)
              ?.map((e) {
                // Handle both String URLs and Map objects
                if (e is String) {
                  // If it's just a URL string, create a PhotoCompletion with minimal data
                  return PhotoCompletionModel(
                    id: '', // Empty ID since backend doesn't provide it
                    imageUrl: e,
                    vehicleAssignmentId: json['id'] ?? '',
                  );
                } else if (e is Map<String, dynamic>) {
                  // If it's a full object, parse it normally
                  return PhotoCompletionModel.fromJson(e);
                }
                return null;
              })
              .whereType<PhotoCompletionModel>() // Filter out nulls
              .toList() ??
          [],
      seals:
          (sealsJson as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>() // Filter out non-Map items (like String IDs)
              .map((e) => VehicleSealModel.fromJson(e))
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
      'orderSeals': orderSeals
          .map((e) => (e as OrderSealModel).toJson())
          .toList(),
      'issues': issues
          .map((e) => (e as VehicleIssueModel).toJson())
          .toList(),
      'photoCompletions': photoCompletions
          .map((e) => (e as PhotoCompletionModel).toJson())
          .toList(),
      'seals': seals
          .map((e) => (e as VehicleSealModel).toJson())
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
    super.vehicleTypeDescription, // Optional vehicle type description
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'],
      manufacturer: json['manufacturer'] ?? '',
      model: json['model'] ?? '',
      licensePlateNumber: json['licensePlateNumber'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      vehicleTypeDescription: json['vehicleTypeDescription'], // Extract from backend response
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
    super.totalTollCount,
    super.totalDistance,
    super.reasonForReroute,
    required super.vehicleAssignmentId,
    required List<JourneySegmentModel> super.journeySegments,
    required super.createdAt,
    required super.modifiedAt,
  });

  factory JourneyHistoryModel.fromJson(Map<String, dynamic> json) {
    // Handle totalDistance which can be int or double
    int? totalDistance;
    if (json['totalDistance'] != null) {
      final distance = json['totalDistance'];
      if (distance is int) {
        totalDistance = distance;
      } else if (distance is double) {
        totalDistance = distance.toInt();
      }
    }

    return JourneyHistoryModel(
      id: json['id'] ?? '',
      journeyName: json['journeyName'] ?? '',
      journeyType: json['journeyType'] ?? '',
      status: json['status'] ?? '',
      totalTollFee: json['totalTollFee']?.toDouble() ?? 0.0,
      totalTollCount: json['totalTollCount'] as int?,
      totalDistance: totalDistance,
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
      'totalTollCount': totalTollCount,
      'totalDistance': totalDistance,
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
    required super.distanceKilometers,
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
      startLatitude: json['startLatitude']?.toDouble(),
      startLongitude: json['startLongitude']?.toDouble(),
      endLatitude: json['endLatitude']?.toDouble(),
      endLongitude: json['endLongitude']?.toDouble(),
      distanceKilometers: (json['distanceKilometers'] ?? 0).toDouble(),
      pathCoordinatesJson: json['pathCoordinatesJson'],
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
      'distanceKilometers': distanceKilometers,
      'pathCoordinatesJson': pathCoordinatesJson,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }
}

class OrderSealModel extends OrderSeal {
  const OrderSealModel({
    required super.id,
    required super.description,
    required super.sealDate,
    required super.status,
    required super.sealId,
    required super.sealCode,
    super.sealAttachedImage,
    super.sealRemovalTime,
    super.sealRemovalReason,
  });

  factory OrderSealModel.fromJson(Map<String, dynamic> json) {
    return OrderSealModel(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      sealDate: json['sealDate'] != null
          ? DateTime.parse(json['sealDate'])
          : DateTime.now(),
      status: json['status'] ?? '',
      sealId: json['sealId'] ?? '',
      sealCode: json['sealCode'] ?? '',
      sealAttachedImage: json['sealAttachedImage'],
      sealRemovalTime: json['sealRemovalTime'] != null
          ? DateTime.parse(json['sealRemovalTime'])
          : null,
      sealRemovalReason: json['sealRemovalReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'sealDate': sealDate.toIso8601String(),
      'status': status,
      'sealId': sealId,
      'sealCode': sealCode,
      'sealAttachedImage': sealAttachedImage,
      'sealRemovalTime': sealRemovalTime?.toIso8601String(),
      'sealRemovalReason': sealRemovalReason,
    };
  }
}

class VehicleIssueModel extends VehicleIssue {
  const VehicleIssueModel({
    required super.id,
    required super.description,
    super.locationLatitude,
    super.locationLongitude,
    required super.status,
    required super.vehicleAssignmentId,
    super.staff,
    required super.issueTypeName,
    super.issueTypeDescription,
    super.reportedAt,
    required super.issueCategory,
    super.issueImages = const [],
    super.oldSeal,
    super.newSeal,
    super.sealRemovalImage,
    super.newSealAttachedImage,
    super.newSealConfirmedAt,
    super.paymentDeadline,
    super.calculatedFee,
    super.adjustedFee,
    super.finalFee,
    super.affectedOrderDetails,
    super.refund,
    super.transaction,
  });

  factory VehicleIssueModel.fromJson(Map<String, dynamic> json) {
    return VehicleIssueModel(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      locationLatitude: json['locationLatitude']?.toDouble(),
      locationLongitude: json['locationLongitude']?.toDouble(),
      status: json['status'] ?? '',
      vehicleAssignmentId: json['vehicleAssignmentId'] ?? '',
      staff: json['staff'],
      issueTypeName: json['issueTypeName'] ?? '',
      issueTypeDescription: json['issueTypeDescription'],
      reportedAt: json['reportedAt'] != null
          ? DateTime.parse(json['reportedAt'])
          : null,
      issueCategory: json['issueCategory'] ?? '',
      issueImages: (json['issueImages'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      oldSeal: json['oldSeal'],
      newSeal: json['newSeal'],
      sealRemovalImage: json['sealRemovalImage'],
      newSealAttachedImage: json['newSealAttachedImage'],
      newSealConfirmedAt: json['newSealConfirmedAt'] != null
          ? DateTime.parse(json['newSealConfirmedAt'])
          : null,
      paymentDeadline: json['paymentDeadline'] != null
          ? DateTime.parse(json['paymentDeadline'])
          : null,
      calculatedFee: json['calculatedFee']?.toDouble(),
      adjustedFee: json['adjustedFee']?.toDouble(),
      finalFee: json['finalFee']?.toDouble(),
      affectedOrderDetails: json['affectedOrderDetails'],
      refund: json['refund'],
      transaction: json['transaction'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'status': status,
      'vehicleAssignmentId': vehicleAssignmentId,
      'staff': staff,
      'issueTypeName': issueTypeName,
      'issueTypeDescription': issueTypeDescription,
      'reportedAt': reportedAt?.toIso8601String(),
      'issueCategory': issueCategory,
      'issueImages': issueImages,
      'oldSeal': oldSeal,
      'newSeal': newSeal,
      'sealRemovalImage': sealRemovalImage,
      'newSealAttachedImage': newSealAttachedImage,
      'newSealConfirmedAt': newSealConfirmedAt?.toIso8601String(),
      'paymentDeadline': paymentDeadline?.toIso8601String(),
      'calculatedFee': calculatedFee,
      'adjustedFee': adjustedFee,
      'finalFee': finalFee,
      'affectedOrderDetails': affectedOrderDetails,
      'refund': refund,
      'transaction': transaction,
    };
  }
}

class PhotoCompletionModel extends PhotoCompletion {
  const PhotoCompletionModel({
    required super.id,
    required super.imageUrl,
    super.description,
    super.createdAt,
    required super.vehicleAssignmentId,
  });

  factory PhotoCompletionModel.fromJson(Map<String, dynamic> json) {
    return PhotoCompletionModel(
      id: json['id'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      description: json['description'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      vehicleAssignmentId: json['vehicleAssignmentId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'description': description,
      'createdAt': createdAt?.toIso8601String(),
      'vehicleAssignmentId': vehicleAssignmentId,
    };
  }
}

class VehicleSealModel extends VehicleSeal {
  const VehicleSealModel({
    required super.id,
    required super.description,
    required super.sealDate,
    required super.status,
    required super.sealCode,
    super.sealAttachedImage,
  });

  factory VehicleSealModel.fromJson(Map<String, dynamic> json) {
    return VehicleSealModel(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      sealDate: json['sealDate'] != null
          ? DateTime.parse(json['sealDate'])
          : DateTime.now(),
      status: json['status'] ?? '',
      sealCode: json['sealCode'] ?? '',
      sealAttachedImage: json['sealAttachedImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'sealDate': sealDate.toIso8601String(),
      'status': status,
      'sealCode': sealCode,
      'sealAttachedImage': sealAttachedImage,
    };
  }
}
