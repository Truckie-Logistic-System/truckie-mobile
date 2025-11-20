import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/failures.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../datasources/api_client.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  final ApiClient _apiClient;

  VehicleRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<Either<Failure, bool>> createVehicleFuelConsumption({
    required String vehicleAssignmentId,
    required Decimal odometerReadingAtStart,
    required File odometerAtStartImage,
  }) async {
    try {

      // Kiểm tra file có tồn tại không
      if (!await odometerAtStartImage.exists()) {

        return Left(ServerFailure(message: 'File ảnh không tồn tại'));
      }

      final formData = FormData.fromMap({
        'vehicleAssignmentId': vehicleAssignmentId,
        'odometerReadingAtStart': odometerReadingAtStart.toString(),
        'odometerAtStartImage': await MultipartFile.fromFile(
          odometerAtStartImage.path,
          filename: 'odometer_image.jpg',
        ),
      });

      final response = await _apiClient.dio.post(
        '/vehicle-fuel-consumptions',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': '*/*'},
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {

        return const Right(true);
      } else {

        return Left(
          ServerFailure(message: 'Không thể tạo bản ghi tiêu thụ nhiên liệu'),
        );
      }
    } on DioException catch (e) {

      return Left(
        ServerFailure(
          message: 'Lỗi khi tạo bản ghi tiêu thụ nhiên liệu: ${e.toString()}',
        ),
      );
    } catch (e) {
      
      return Left(
        ServerFailure(
          message: 'Lỗi khi tạo bản ghi tiêu thụ nhiên liệu: ${e.toString()}',
        ),
      );
    }
  }
}
