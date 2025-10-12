import 'package:dartz/dartz.dart' hide Order;

import '../../core/errors/failures.dart';
import '../entities/order.dart';
import '../entities/order_with_details.dart';

abstract class OrderRepository {
  Future<Either<Failure, List<Order>>> getDriverOrders();
  Future<Either<Failure, OrderWithDetails>> getOrderDetails(String orderId);
  Future<Either<Failure, OrderWithDetails>> getOrderDetailsForDriver(
    String orderId,
  );
}
