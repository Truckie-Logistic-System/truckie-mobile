import 'package:dartz/dartz.dart' hide Order;

import '../../../core/errors/failures.dart';
import '../../entities/order.dart';
import '../../repositories/order_repository.dart';

class GetDriverOrdersUseCase {
  final OrderRepository _orderRepository;

  GetDriverOrdersUseCase({required OrderRepository orderRepository})
    : _orderRepository = orderRepository;

  Future<Either<Failure, List<Order>>> call() async {
    return await _orderRepository.getDriverOrders();
  }
}
