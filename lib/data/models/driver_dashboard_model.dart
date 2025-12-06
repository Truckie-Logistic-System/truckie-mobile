/// Model cho Driver Dashboard Response
/// Chứa thông tin tổng quan cho tài xế - phiên bản đơn giản hóa

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
