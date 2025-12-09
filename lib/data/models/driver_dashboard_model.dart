/// Model cho Driver Dashboard Response
/// Chứa thông tin tổng quan cho tài xế - phiên bản đơn giản hóa

/// Thông tin điểm dừng/ghé
class StopInfo {
  final bool isPickup;
  final String address;
  final String? note;

  StopInfo({
    required this.isPickup,
    required this.address,
    this.note,
  });

  factory StopInfo.fromJson(Map<String, dynamic> json) {
    return StopInfo(
      isPickup: json['isPickup'] as bool? ?? false,
      address: json['address'] as String? ?? '',
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isPickup': isPickup,
      'address': address,
      'note': note,
    };
  }
}

/// Thông tin chuyến đi hiện tại
class CurrentTrip {
  final String orderId;
  final String orderCode;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final String estimatedTime;
  final double distance;
  final bool hasActiveTrip;
  final String trackingCode;
  final int completedStops;
  final int totalStops;
  final double progress;
  final StopInfo? currentStop;
  final String vehiclePlate;

  CurrentTrip({
    required this.orderId,
    required this.orderCode,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.estimatedTime,
    required this.distance,
    this.hasActiveTrip = true,
    this.trackingCode = '',
    this.completedStops = 0,
    this.totalStops = 0,
    this.progress = 0.0,
    this.currentStop,
    this.vehiclePlate = '',
  });

  factory CurrentTrip.fromJson(Map<String, dynamic> json) {
    return CurrentTrip(
      orderId: json['orderId'] as String? ?? '',
      orderCode: json['orderCode'] as String? ?? '',
      status: json['status'] as String? ?? '',
      pickupAddress: json['pickupAddress'] as String? ?? '',
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      estimatedTime: json['estimatedTime'] as String? ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      hasActiveTrip: json['hasActiveTrip'] as bool? ?? true,
      trackingCode: json['trackingCode'] as String? ?? '',
      completedStops: (json['completedStops'] as num?)?.toInt() ?? 0,
      totalStops: (json['totalStops'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      currentStop: json['currentStop'] != null ? StopInfo.fromJson(json['currentStop'] as Map<String, dynamic>) : null,
      vehiclePlate: json['vehiclePlate'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderCode': orderCode,
      'status': status,
      'pickupAddress': pickupAddress,
      'deliveryAddress': deliveryAddress,
      'estimatedTime': estimatedTime,
      'distance': distance,
      'hasActiveTrip': hasActiveTrip,
      'trackingCode': trackingCode,
      'completedStops': completedStops,
      'totalStops': totalStops,
      'progress': progress,
      'currentStop': currentStop?.toJson(),
      'vehiclePlate': vehiclePlate,
    };
  }
}

/// Thống kê theo kỳ (ngày/tuần/tháng)
class PeriodSummary {
  final String period;
  final int completedTrips;
  final double totalDistance;
  final double earnings;
  final int onTimeDeliveryRate;
  final int totalTrips;
  final int pendingTrips;
  final int totalStops;
  final int completedStops;
  final double tripCompletionRate;
  final int cancelledTrips;
  final int issuesEncountered;
  final double hoursWorked;

  PeriodSummary({
    required this.period,
    required this.completedTrips,
    required this.totalDistance,
    required this.earnings,
    required this.onTimeDeliveryRate,
    this.totalTrips = 0,
    this.pendingTrips = 0,
    this.totalStops = 0,
    this.completedStops = 0,
    this.tripCompletionRate = 0.0,
    this.cancelledTrips = 0,
    this.issuesEncountered = 0,
    this.hoursWorked = 0.0,
  });

  factory PeriodSummary.fromJson(Map<String, dynamic> json) {
    return PeriodSummary(
      period: json['period'] as String? ?? '',
      completedTrips: (json['completedTrips'] as num?)?.toInt() ?? 0,
      totalDistance: (json['totalDistance'] as num?)?.toDouble() ?? 0.0,
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0.0,
      onTimeDeliveryRate: (json['onTimeDeliveryRate'] as num?)?.toInt() ?? 0,
      totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
      pendingTrips: (json['pendingTrips'] as num?)?.toInt() ?? 0,
      totalStops: (json['totalStops'] as num?)?.toInt() ?? 0,
      completedStops: (json['completedStops'] as num?)?.toInt() ?? 0,
      tripCompletionRate: (json['tripCompletionRate'] as num?)?.toDouble() ?? 0.0,
      cancelledTrips: (json['cancelledTrips'] as num?)?.toInt() ?? 0,
      issuesEncountered: (json['issuesEncountered'] as num?)?.toInt() ?? 0,
      hoursWorked: (json['hoursWorked'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'completedTrips': completedTrips,
      'totalDistance': totalDistance,
      'earnings': earnings,
      'onTimeDeliveryRate': onTimeDeliveryRate,
      'totalTrips': totalTrips,
      'pendingTrips': pendingTrips,
      'totalStops': totalStops,
      'completedStops': completedStops,
      'tripCompletionRate': tripCompletionRate,
      'cancelledTrips': cancelledTrips,
      'issuesEncountered': issuesEncountered,
      'hoursWorked': hoursWorked,
    };
  }
}

/// KPI cá nhân của tài xế
class PersonalKpi {
  final double targetTrips;
  final double actualTrips;
  final double targetDistance;
  final double actualDistance;
  final double targetEarnings;
  final double actualEarnings;
  final double targetOnTimeRate;
  final double actualOnTimeRate;
  final int totalTripsCompleted;
  final int totalDeliveriesCompleted;
  final double onTimeRate;
  final double rating;
  final int issuesReported;
  final double fuelEfficiency;

  PersonalKpi({
    required this.targetTrips,
    required this.actualTrips,
    required this.targetDistance,
    required this.actualDistance,
    required this.targetEarnings,
    required this.actualEarnings,
    required this.targetOnTimeRate,
    required this.actualOnTimeRate,
    this.totalTripsCompleted = 0,
    this.totalDeliveriesCompleted = 0,
    this.onTimeRate = 0.0,
    this.rating = 0.0,
    this.issuesReported = 0,
    this.fuelEfficiency = 0.0,
  });

  factory PersonalKpi.fromJson(Map<String, dynamic> json) {
    return PersonalKpi(
      targetTrips: (json['targetTrips'] as num?)?.toDouble() ?? 0.0,
      actualTrips: (json['actualTrips'] as num?)?.toDouble() ?? 0.0,
      targetDistance: (json['targetDistance'] as num?)?.toDouble() ?? 0.0,
      actualDistance: (json['actualDistance'] as num?)?.toDouble() ?? 0.0,
      targetEarnings: (json['targetEarnings'] as num?)?.toDouble() ?? 0.0,
      actualEarnings: (json['actualEarnings'] as num?)?.toDouble() ?? 0.0,
      targetOnTimeRate: (json['targetOnTimeRate'] as num?)?.toDouble() ?? 0.0,
      actualOnTimeRate: (json['actualOnTimeRate'] as num?)?.toDouble() ?? 0.0,
      totalTripsCompleted: (json['totalTripsCompleted'] as num?)?.toInt() ?? 0,
      totalDeliveriesCompleted: (json['totalDeliveriesCompleted'] as num?)?.toInt() ?? 0,
      onTimeRate: (json['onTimeRate'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      issuesReported: (json['issuesReported'] as num?)?.toInt() ?? 0,
      fuelEfficiency: (json['fuelEfficiency'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetTrips': targetTrips,
      'actualTrips': actualTrips,
      'targetDistance': targetDistance,
      'actualDistance': actualDistance,
      'targetEarnings': targetEarnings,
      'actualEarnings': actualEarnings,
      'targetOnTimeRate': targetOnTimeRate,
      'actualOnTimeRate': actualOnTimeRate,
      'totalTripsCompleted': totalTripsCompleted,
      'totalDeliveriesCompleted': totalDeliveriesCompleted,
      'onTimeRate': onTimeRate,
      'rating': rating,
      'issuesReported': issuesReported,
      'fuelEfficiency': fuelEfficiency,
    };
  }

  /// Tính % hoàn thành KPI chuyến đi
  double get tripsCompletionRate => targetTrips > 0 ? (actualTrips / targetTrips) * 100 : 0.0;

  /// Tính % hoàn thành KPI quãng đường
  double get distanceCompletionRate => targetDistance > 0 ? (actualDistance / targetDistance) * 100 : 0.0;

  /// Tính % hoàn thành KPI doanh thu
  double get earningsCompletionRate => targetEarnings > 0 ? (actualEarnings / targetEarnings) * 100 : 0.0;

  /// Tính % hoàn thành KPI đúng giờ
  double get onTimeRateCompletionRate => targetOnTimeRate > 0 ? (actualOnTimeRate / targetOnTimeRate) * 100 : 0.0;
}

class DriverDashboardModel {
  final int completedTripsCount;
  final int incidentsCount;
  final int trafficViolationsCount;
  final List<TripTrendPoint> tripTrend;
  final List<RecentOrder> recentOrders;

  DriverDashboardModel({
    required this.completedTripsCount,
    required this.incidentsCount,
    required this.trafficViolationsCount,
    this.tripTrend = const [],
    this.recentOrders = const [],
  });

  factory DriverDashboardModel.fromJson(Map<String, dynamic> json) {
    return DriverDashboardModel(
      completedTripsCount: (json['completedTripsCount'] as num?)?.toInt() ?? 0,
      incidentsCount: (json['incidentsCount'] as num?)?.toInt() ?? 0,
      trafficViolationsCount: (json['trafficViolationsCount'] as num?)?.toInt() ?? 0,
      tripTrend: (json['tripTrend'] as List<dynamic>?)
              ?.map((e) => TripTrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentOrders: (json['recentOrders'] as List<dynamic>?)
              ?.map((e) => RecentOrder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completedTripsCount': completedTripsCount,
      'incidentsCount': incidentsCount,
      'trafficViolationsCount': trafficViolationsCount,
      'tripTrend': tripTrend.map((e) => e.toJson()).toList(),
      'recentOrders': recentOrders.map((e) => e.toJson()).toList(),
    };
  }
}

/// Đơn hàng gần đây (Order Entity)
class RecentOrder {
  final String orderId; // Order ID
  final String orderCode; // Order code from OrderEntity
  final String status; // Order status
  final String receiverName; // Receiver name
  final String receiverPhone; // Receiver phone
  final String createdDate; // Order created date
  final String trackingCode; // Order detail tracking code

  RecentOrder({
    required this.orderId,
    required this.orderCode,
    required this.status,
    required this.receiverName,
    required this.receiverPhone,
    required this.createdDate,
    required this.trackingCode,
  });

  factory RecentOrder.fromJson(Map<String, dynamic> json) {
    return RecentOrder(
      orderId: json['orderId'] as String? ?? '',
      orderCode: json['orderCode'] as String? ?? '',
      status: json['status'] as String? ?? '',
      receiverName: json['receiverName'] as String? ?? '',
      receiverPhone: json['receiverPhone'] as String? ?? '',
      createdDate: json['createdDate'] as String? ?? '',
      trackingCode: json['trackingCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderCode': orderCode,
      'status': status,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'createdDate': createdDate,
      'trackingCode': trackingCode,
    };
  }
}

/// Điểm dữ liệu xu hướng chuyến xe (cho line chart - chỉ hoàn thành)
class TripTrendPoint {
  final String label; // Nhãn thời gian (dd/MM, Tuần X, MM/yyyy)
  final int tripsCompleted; // Số chuyến hoàn thành

  TripTrendPoint({
    required this.label,
    this.tripsCompleted = 0,
  });

  factory TripTrendPoint.fromJson(Map<String, dynamic> json) {
    return TripTrendPoint(
      label: json['label'] as String? ?? '',
      tripsCompleted: (json['tripsCompleted'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'tripsCompleted': tripsCompleted,
    };
  }
}
