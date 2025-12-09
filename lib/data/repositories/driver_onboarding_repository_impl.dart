import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../core/errors/failures.dart';
import '../../core/services/token_storage_service.dart';
import '../../domain/entities/driver.dart';
import '../datasources/api_client.dart';
import '../models/driver_model.dart';
import 'driver_onboarding_repository.dart';

/// Implementation of DriverOnboardingRepository
class DriverOnboardingRepositoryImpl implements DriverOnboardingRepository {
  final ApiClient _apiClient;
  // ignore: unused_field
  final TokenStorageService _tokenStorage;

  DriverOnboardingRepositoryImpl({
    required ApiClient apiClient,
    required TokenStorageService tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  @override
  Future<Either<Failure, Driver>> submitOnboardingWithImage({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
    required File faceImageFile,
  }) async {
    try {
      // Validate file before upload
      final fileValidationResult = _validateImageFile(faceImageFile);
      if (fileValidationResult != null) {
        return Left(fileValidationResult);
      }

      // Create multipart request (follow working pattern from PhotoCompletionDataSource)
      final formData = FormData.fromMap({
        'faceImage': await MultipartFile.fromFile(
          faceImageFile.path,
          filename:
              'face_image_${DateTime.now().millisecondsSinceEpoch}.${_getFileExtension(faceImageFile.path)}',
        ),
        'data': MultipartFile.fromString(
          jsonEncode({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
            'confirmPassword': confirmPassword,
          }),
          contentType: DioMediaType('application', 'json'),
        ),
      });

      // Use raw Dio client to be consistent with other multipart uploads
      final response = await _apiClient.dio.post(
        '/drivers/onboarding/submit',
        data: formData,
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final driverModel = DriverModel.fromJson(
          response.data['data'] as Map<String, dynamic>,
        );
        return Right(driverModel.toEntity());
      } else {
        return Left(ServerFailure(
          message: response.data['message'] ?? 'Kích hoạt tài khoản thất bại',
        ));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Lỗi kết nối server';
      return Left(ServerFailure(message: message));
    } catch (e) {
      return Left(ServerFailure(message: 'Lỗi: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> needsOnboarding() async {
    try {
      final response = await _apiClient.get('/drivers/onboarding/status');

      if (response.data['success'] == true) {
        final needsOnboarding = response.data['data'] as bool? ?? false;
        return Right(needsOnboarding);
      } else {
        return Left(ServerFailure(
          message: response.data['message'] ?? 'Không thể kiểm tra trạng thái',
        ));
      }
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Lỗi kết nối server';
      return Left(ServerFailure(message: message));
    } catch (e) {
      return Left(ServerFailure(message: 'Lỗi: ${e.toString()}'));
    }
  }

  /// Validate image file before upload
  Failure? _validateImageFile(File file) {
    // Check file size (max 5MB)
    final fileSize = file.lengthSync();
    if (fileSize > 5 * 1024 * 1024) {
      return ServerFailure(message: 'Kích thước ảnh không được vượt quá 5MB');
    }

    // Check file type
    final extension = _getFileExtension(file.path).toLowerCase();
    if (!['jpg', 'jpeg', 'png'].contains(extension)) {
      return ServerFailure(message: 'Ảnh phải có định dạng JPG hoặc PNG');
    }

    return null;
  }

  /// Get file extension from path
  String _getFileExtension(String path) {
    return path.split('.').last;
  }
}
