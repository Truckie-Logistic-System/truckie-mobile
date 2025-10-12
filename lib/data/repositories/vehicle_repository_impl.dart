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
      debugPrint('🔄 Tạo FormData cho tiêu thụ nhiên liệu...');
      debugPrint('🔄 vehicleAssignmentId: $vehicleAssignmentId');
      debugPrint('🔄 odometerReadingAtStart: $odometerReadingAtStart');
      debugPrint('🔄 odometerAtStartImage path: ${odometerAtStartImage.path}');

      // Kiểm tra file có tồn tại không
      if (!await odometerAtStartImage.exists()) {
        debugPrint('❌ File ảnh không tồn tại: ${odometerAtStartImage.path}');
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

      debugPrint('📤 Gửi request tạo tiêu thụ nhiên liệu...');
      final response = await _apiClient.dio.post(
        '/vehicle-fuel-consumptions',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          headers: {'Accept': '*/*'},
        ),
      );

      debugPrint('📥 Nhận response: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Tạo tiêu thụ nhiên liệu thành công');
        return const Right(true);
      } else {
        debugPrint(
          '❌ Tạo tiêu thụ nhiên liệu thất bại: ${response.statusCode}',
        );
        return Left(
          ServerFailure(message: 'Không thể tạo bản ghi tiêu thụ nhiên liệu'),
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ DioException: ${e.message}');
      debugPrint('❌ DioException response: ${e.response?.data}');
      debugPrint('❌ DioException status code: ${e.response?.statusCode}');

      return Left(
        ServerFailure(
          message: 'Lỗi khi tạo bản ghi tiêu thụ nhiên liệu: ${e.toString()}',
        ),
      );
    } catch (e) {
      debugPrint('❌ Exception: ${e.toString()}');
      return Left(
        ServerFailure(
          message: 'Lỗi khi tạo bản ghi tiêu thụ nhiên liệu: ${e.toString()}',
        ),
      );
    }
  }
}
