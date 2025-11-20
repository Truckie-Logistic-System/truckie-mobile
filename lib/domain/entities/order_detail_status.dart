/// Status enum for OrderDetail entity
/// Tracks the status of individual order details within a vehicle assignment (trip)
/// This allows multiple trips for the same order to have independent status tracking
/// 
/// Status flow:
/// ASSIGNED_TO_DRIVER → PICKING_UP → ON_DELIVERED → ONGOING_DELIVERED → DELIVERED → SUCCESSFUL
/// 
/// Alternative flows:
/// - Any status → IN_TROUBLES → RESOLVED → (resume normal flow)
/// - Any status → REJECTED (terminal)
/// - DELIVERED → RETURNING → RETURNED (return flow)
enum OrderDetailStatus {
  /// OrderDetail has been assigned to a vehicle and driver
  /// Initial status when vehicle assignment is created
  assignedToDriver('ASSIGNED_TO_DRIVER'),
  
  /// Driver is on the way to pick up the goods
  /// Triggered when driver starts the trip/simulation
  pickingUp('PICKING_UP'),
  
  /// Driver is transporting the goods to delivery point
  /// Triggered after pickup confirmation (seal completed)
  onDelivered('ON_DELIVERED'),
  
  /// Driver is near delivery point (within 3km threshold)
  /// Auto-triggered by proximity detection
  ongoingDelivered('ONGOING_DELIVERED'),
  
  /// Goods have been delivered to customer
  /// Triggered after uploading delivery confirmation photos
  delivered('DELIVERED'),
  
  /// Trip completed - driver has returned to warehouse
  /// Triggered after uploading odometer end reading
  successful('SUCCESSFUL'),
  
  /// OrderDetail has issues during delivery
  /// Can occur at any stage
  inTroubles('IN_TROUBLES'),
  
  /// OrderDetail has been compensated due to damage
  /// Terminal status for damaged goods
  compensation('COMPENSATION'),
  
  /// Issues have been resolved
  /// Returns to previous normal flow
  resolved('RESOLVED'),
  
  /// OrderDetail/Trip has been rejected or cancelled
  /// Terminal status
  rejected('REJECTED'),
  
  /// Goods are being returned to sender
  /// Triggered when return process starts
  returning('RETURNING'),
  
  /// Goods have been returned to sender
  /// Terminal status for return flow
  returned('RETURNED');

  final String value;
  const OrderDetailStatus(this.value);

  /// Convert from string value to enum
  static OrderDetailStatus fromString(String value) {
    return OrderDetailStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OrderDetailStatus.assignedToDriver,
    );
  }

  /// Get Vietnamese translation for the status
  String toVietnamese() {
    switch (this) {
      case OrderDetailStatus.assignedToDriver:
        return 'Đã phân công';
      case OrderDetailStatus.pickingUp:
        return 'Đang lấy hàng';
      case OrderDetailStatus.onDelivered:
        return 'Đang vận chuyển';
      case OrderDetailStatus.ongoingDelivered:
        return 'Sắp đến nơi giao';
      case OrderDetailStatus.delivered:
        return 'Đã giao hàng';
      case OrderDetailStatus.successful:
        return 'Hoàn thành';
      case OrderDetailStatus.inTroubles:
        return 'Gặp sự cố';
      case OrderDetailStatus.compensation:
        return 'Đã đền bù';
      case OrderDetailStatus.resolved:
        return 'Đã giải quyết';
      case OrderDetailStatus.rejected:
        return 'Đã từ chối';
      case OrderDetailStatus.returning:
        return 'Đang trả hàng';
      case OrderDetailStatus.returned:
        return 'Đã trả hàng';
    }
  }

  /// Check if this is a terminal status (cannot transition further)
  bool get isTerminal {
    return this == OrderDetailStatus.successful ||
        this == OrderDetailStatus.rejected ||
        this == OrderDetailStatus.returned ||
        this == OrderDetailStatus.compensation;
  }

  /// Check if status indicates active delivery
  bool get isActiveDelivery {
    return this == OrderDetailStatus.pickingUp ||
        this == OrderDetailStatus.onDelivered ||
        this == OrderDetailStatus.ongoingDelivered;
  }
}
