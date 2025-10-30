import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/order_detail_status.dart';
import '../../repositories/order_repository.dart';

/// Use case to update OrderDetail status for a specific vehicle assignment
/// This is the primary method for drivers to update delivery status in multi-trip orders
class UpdateOrderDetailStatusUseCase {
  final OrderRepository _orderRepository;

  UpdateOrderDetailStatusUseCase(this._orderRepository);

  /// Update OrderDetail status for all order details in a vehicle assignment
  /// 
  /// [assignmentId] - ID of the vehicle assignment (trip)
  /// [status] - New status to set for all order details in this trip
  /// 
  /// Returns true if update was successful, Failure otherwise
  Future<Either<Failure, bool>> call({
    required String assignmentId,
    required OrderDetailStatus status,
  }) async {
    return await _orderRepository.updateOrderDetailStatus(
      assignmentId: assignmentId,
      status: status,
    );
  }
}
