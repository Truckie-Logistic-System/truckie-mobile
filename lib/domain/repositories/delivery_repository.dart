import 'package:dartz/dartz.dart' hide Order;

import '../entities/order.dart';
import '../entities/delivery.dart';
import '../entities/location.dart';
import '../../core/errors/failures.dart';

abstract class DeliveryRepository {
  /// Lấy danh sách đơn hàng
  Future<Either<Failure, List<Order>>> getOrders();

  /// Lấy chi tiết đơn hàng
  Future<Either<Failure, Order>> getOrderDetail(String orderId);

  /// Cập nhật trạng thái đơn hàng
  Future<Either<Failure, bool>> updateOrderStatus(
    String orderId,
    String status,
  );

  /// Bắt đầu giao hàng
  Future<Either<Failure, bool>> startDelivery(String orderId);

  /// Hoàn thành giao hàng
  Future<Either<Failure, bool>> completeDelivery(String orderId);

  /// Cập nhật vị trí giao hàng
  Future<Either<Failure, bool>> updateDeliveryLocation(
    String deliveryId,
    LocationEntity location,
  );

  /// Lấy thông tin giao hàng hiện tại
  Future<Either<Failure, Delivery>> getCurrentDelivery();
}
