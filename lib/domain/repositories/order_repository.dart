import 'package:dartz/dartz.dart' hide Order;

import '../../core/errors/failures.dart';
import '../entities/order.dart';
import '../entities/order_detail_status.dart';
import '../entities/order_with_details.dart';

abstract class OrderRepository {
  Future<Either<Failure, List<Order>>> getDriverOrders();
  Future<Either<Failure, OrderWithDetails>> getOrderDetails(String orderId);
  Future<Either<Failure, OrderWithDetails>> getOrderDetailsForDriver(
    String orderId,
  );
  
  /// Update order status to ONGOING_DELIVERED when near delivery point (within 3km)
  Future<Either<Failure, bool>> updateToOngoingDelivered(String orderId);
  
  /// Update order status to DELIVERED when arriving at delivery point
  Future<Either<Failure, bool>> updateToDelivered(String orderId);
  
  /// Update order status to SUCCESSFUL when driver confirms trip completion
  Future<Either<Failure, bool>> updateToSuccessful(String orderId);
  
  /// NEW: Update OrderDetail status for a specific vehicle assignment
  /// This is the primary method for multi-trip orders
  /// [assignmentId] - ID of the vehicle assignment (trip)
  /// [status] - New status to set for all order details in this trip
  Future<Either<Failure, bool>> updateOrderDetailStatus({
    required String assignmentId,
    required OrderDetailStatus status,
  });
}
