import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/order_with_details.dart';
import '../../repositories/order_repository.dart';

class GetOrderDetailsUseCase {
  final OrderRepository orderRepository;

  GetOrderDetailsUseCase({required this.orderRepository});

  Future<Either<Failure, OrderWithDetails>> call(String orderId) async {
    return await orderRepository.getOrderDetailsForDriver(orderId);
  }
}
