enum OrderStatus {
  pending('PENDING'),
  processing('PROCESSING'),
  contractDraft('CONTRACT_DRAFT'),
  contractSigned('CONTRACT_SIGNED'),
  onPlanning('ON_PLANNING'),
  assignedToDriver('ASSIGNED_TO_DRIVER'),
  fullyPaid('FULLY_PAID'),
  pickingUp('PICKING_UP'),
  onDelivered('ON_DELIVERED'),
  ongoingDelivered('ONGOING_DELIVERED'),
  delivered('DELIVERED'),
  inTroubles('IN_TROUBLES'),
  resolved('RESOLVED'),
  compensation('COMPENSATION'),
  successful('SUCCESSFUL'),
  rejectOrder('REJECT_ORDER'),
  returning('RETURNING'),
  returned('RETURNED');

  final String value;
  const OrderStatus(this.value);

  /// Convert from string value to enum
  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OrderStatus.pending,
    );
  }

  /// Get Vietnamese translation for the status
  String toVietnamese() {
    switch (this) {
      case OrderStatus.pending:
        return 'Chờ xử lý';
      case OrderStatus.processing:
        return 'Đang xử lý';
      case OrderStatus.contractDraft:
        return 'Nháp hợp đồng';
      case OrderStatus.contractSigned:
        return 'Đã ký hợp đồng';
      case OrderStatus.onPlanning:
        return 'Đang lên kế hoạch';
      case OrderStatus.assignedToDriver:
        return 'Đã phân công tài xế';
      case OrderStatus.fullyPaid:
        return 'Chờ lấy hàng';
      case OrderStatus.pickingUp:
        return 'Đang lấy hàng';
      case OrderStatus.onDelivered:
        return 'Đang giao hàng';
      case OrderStatus.ongoingDelivered:
        return 'Sắp giao hàng tới';
      case OrderStatus.delivered:
        return 'Đã giao hàng';
      case OrderStatus.inTroubles:
        return 'Gặp sự cố';
      case OrderStatus.resolved:
        return 'Đã giải quyết';
      case OrderStatus.compensation:
        return 'Đã đền bù';
      case OrderStatus.successful:
        return 'Hoàn thành';
      case OrderStatus.rejectOrder:
        return 'Đã từ chối';
      case OrderStatus.returning:
        return 'Đang hoàn trả';
      case OrderStatus.returned:
        return 'Đã hoàn trả';
    }
  }

  /// Check if order is in active delivery state (needs WebSocket tracking)
  bool get isActiveDelivery {
    return this == OrderStatus.pickingUp ||
        this == OrderStatus.onDelivered ||
        this == OrderStatus.ongoingDelivered;
  }

  /// Check if order can start delivery
  bool get canStartDelivery {
    return this == OrderStatus.assignedToDriver ||
        this == OrderStatus.fullyPaid;
  }

  /// Check if order can confirm pre-delivery documentation
  bool get canConfirmPreDelivery {
    return this == OrderStatus.pickingUp;
  }
}
