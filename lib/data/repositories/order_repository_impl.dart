import 'package:dartz/dartz.dart' hide Order;

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/services/api_service.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_with_details.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/order_model.dart';
import '../models/order_with_details_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  final ApiService _apiService;

  OrderRepositoryImpl({required ApiService apiService})
    : _apiService = apiService;

  @override
  Future<Either<Failure, List<Order>>> getDriverOrders() async {
    try {
      final response = await _apiService.get(
        '/orders/get-list-order-for-driver',
      );

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> ordersJson = response['data'];
        final List<Order> orders = ordersJson
            .map((orderJson) => OrderModel.fromJson(orderJson))
            .toList();
        return Right(orders);
      } else {
        // Check if this is a "Not found" response for no orders
        if (response['statusCode'] == 400 &&
            response['message'] != null &&
            response['message'].toString().contains('Not found')) {
          // Return an empty list instead of an error
          return const Right([]);
        }

        return Left(
          ServerFailure(
            message: response['message'] ?? 'Lỗi khi lấy danh sách đơn hàng',
          ),
        );
      }
    } on ServerException catch (e) {
      // Check if this is a "Not found" exception for no orders
      if (e.statusCode == 400 && e.message.contains('Not found')) {
        // Return an empty list instead of an error
        return const Right([]);
      }
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderWithDetails>> getOrderDetails(
    String orderId,
  ) async {
    try {
      final response = await _apiService.get(
        '/orders/get-order-by-id/$orderId',
      );

      if (response['success'] == true &&
          response['data'] != null &&
          response['data']['order'] != null) {
        final orderJson = response['data']['order'];
        final orderWithDetails = OrderWithDetailsModel.fromJson(orderJson);
        return Right(orderWithDetails);
      } else {
        return Left(
          ServerFailure(
            message: response['message'] ?? 'Lỗi khi lấy chi tiết đơn hàng',
          ),
        );
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, OrderWithDetails>> getOrderDetailsForDriver(
    String orderId,
  ) async {
    try {
      final response = await _apiService.get(
        '/orders/get-order-for-driver-by-order-id/$orderId',
      );

      if (response['success'] == true &&
          response['data'] != null &&
          response['data']['order'] != null) {
        final orderJson = response['data']['order'];
        final orderWithDetails = OrderWithDetailsModel.fromJson(orderJson);
        return Right(orderWithDetails);
      } else {
        return Left(
          ServerFailure(
            message: response['message'] ?? 'Lỗi khi lấy chi tiết đơn hàng',
          ),
        );
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
