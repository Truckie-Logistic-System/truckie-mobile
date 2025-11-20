import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';

abstract class VehicleFuelConsumptionDataSource {
  /// Create vehicle fuel consumption record
  Future<String> createVehicleFuelConsumption(
    String orderId,
    double fuelConsumption,
    double odometer,
  );
  
  /// Update final odometer reading with image
  Future<Either<Failure, bool>> updateFinalReading({
    required String fuelConsumptionId,
    required double odometerReadingAtEnd,
    required File odometerImage,
  });
  
  /// Get fuel consumption by vehicle assignment ID
  Future<Either<Failure, Map<String, dynamic>>> getByVehicleAssignmentId(String vehicleAssignmentId);
  
  /// Update invoice image for fuel consumption
  Future<Either<Failure, bool>> updateInvoiceImage({
    required String fuelConsumptionId,
    required File invoiceImage,
  });
}

class VehicleFuelConsumptionDataSourceImpl implements VehicleFuelConsumptionDataSource {
  final ApiClient _apiClient;

  VehicleFuelConsumptionDataSourceImpl(this._apiClient);

  @override
  Future<String> createVehicleFuelConsumption(
    String orderId,
    double fuelConsumption,
    double odometer,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/vehicle-fuel-consumptions',
        data: {
          'orderId': orderId,
          'fuelConsumption': fuelConsumption,
          'odometerReadingAtStart': odometer,
        },
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data']['id'] as String;
      } else {
        throw ServerException(
          message: response.data['message'] ?? 'Failed to create fuel consumption',
          statusCode: response.statusCode ?? 500,
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(
        message: 'Failed to create fuel consumption: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

  @override
  Future<Either<Failure, bool>> updateFinalReading({
    required String fuelConsumptionId,
    required double odometerReadingAtEnd,
    required File odometerImage,
  }) async {
    try {

      
      

      // Create multipart form data
      final multipartFile = await MultipartFile.fromFile(
        odometerImage.path,
        filename: 'odometer_end_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      
      final formData = FormData.fromMap({
        'id': fuelConsumptionId,
        'odometerReadingAtEnd': odometerReadingAtEnd.toStringAsFixed(2),
        'odometerAtEndImage': multipartFile,
      });

      

      final response = await _apiClient.dio.put(
        '/vehicle-fuel-consumptions/final-reading',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': '*/*'},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return const Right(true);
        } else {
          return Left(
            ServerFailure(
              message: responseData['message'] ?? 'Lỗi khi cập nhật đồng hồ cuối',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            message: 'Lỗi khi cập nhật đồng hồ cuối: ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {

      return Left(
        ServerFailure(message: e.message ?? 'Lỗi kết nối đến máy chủ'),
      );
    } on ServerException catch (e) {

      return Left(ServerFailure(message: e.message));
    } catch (e) {
      
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getByVehicleAssignmentId(String vehicleAssignmentId) async {
    try {

      final response = await _apiClient.dio.get(
        '/vehicle-fuel-consumptions/vehicle-assignment/$vehicleAssignmentId',
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true && responseData['data'] != null) {
          return Right(responseData);
        } else {
          return Left(
            ServerFailure(
              message: responseData['message'] ?? 'Không tìm thấy thông tin nhiên liệu',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            message: 'Lỗi khi lấy thông tin nhiên liệu: ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {

      // Handle 404 Not Found specifically
      if (e.response?.statusCode == 404) {
        return Left(
          ServerFailure(message: 'Chưa có bản ghi tiêu thụ nhiên liệu cho xe này'),
        );
      }
      
      return Left(
        ServerFailure(message: e.message ?? 'Lỗi kết nối đến máy chủ'),
      );
    } on ServerException catch (e) {

      return Left(ServerFailure(message: e.message));
    } catch (e) {
      
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> updateInvoiceImage({
    required String fuelConsumptionId,
    required File invoiceImage,
  }) async {
    try {

      
      

      // Create multipart form data
      final multipartFile = await MultipartFile.fromFile(
        invoiceImage.path,
        filename: 'fuel_invoice_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      
      final formData = FormData.fromMap({
        'id': fuelConsumptionId,
        'companyInvoiceImage': multipartFile,
      });

      final response = await _apiClient.dio.put(
        '/vehicle-fuel-consumptions/invoice',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': '*/*'},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return const Right(true);
        } else {
          return Left(
            ServerFailure(
              message: responseData['message'] ?? 'Lỗi khi cập nhật hóa đơn xăng',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            message: 'Lỗi khi cập nhật hóa đơn xăng: ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {

      return Left(
        ServerFailure(message: e.message ?? 'Lỗi kết nối đến máy chủ'),
      );
    } on ServerException catch (e) {

      return Left(ServerFailure(message: e.message));
    } catch (e) {
      
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
