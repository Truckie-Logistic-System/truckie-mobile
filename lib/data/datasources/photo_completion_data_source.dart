import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';

abstract class PhotoCompletionDataSource {
  /// Upload photo completion image
  Future<Either<Failure, bool>> uploadPhotoCompletion({
    required File imageFile,
    required String vehicleAssignmentId,
    String? description,
  });

  /// Upload multiple photo completion images
  Future<Either<Failure, bool>> uploadMultiplePhotoCompletion({
    required List<File> imageFiles,
    required String vehicleAssignmentId,
    String? description,
  });
}

class PhotoCompletionDataSourceImpl implements PhotoCompletionDataSource {
  final ApiClient _apiClient;

  PhotoCompletionDataSourceImpl(this._apiClient);

  @override
  Future<Either<Failure, bool>> uploadPhotoCompletion({
    required File imageFile,
    required String vehicleAssignmentId,
    String? description,
  }) async {
    try {

      
      

      // Create multipart form data
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'photo_completion_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'request': MultipartFile.fromString(
          '{"vehicleAssignmentId":"$vehicleAssignmentId","description":"${description ?? 'Photo completion at delivery'}"}',
          contentType: DioMediaType('application', 'json'),
        ),
      });

      final response = await _apiClient.dio.post(
        '/photo-completions/upload',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return const Right(true);
        } else {
          return Left(
            ServerFailure(
              message: responseData['message'] ?? 'Lỗi khi upload ảnh xác nhận',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            message: 'Lỗi khi upload ảnh xác nhận: ${response.statusCode}',
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
  Future<Either<Failure, bool>> uploadMultiplePhotoCompletion({
    required List<File> imageFiles,
    required String vehicleAssignmentId,
    String? description,
  }) async {
    try {

      // Validate all files exist
      for (var i = 0; i < imageFiles.length; i++) {

        
        
      }

      // Create multipart form data with multiple files
      final List<MultipartFile> multipartFiles = [];
      for (var imageFile in imageFiles) {
        multipartFiles.add(
          await MultipartFile.fromFile(
            imageFile.path,
            filename: 'photo_completion_${DateTime.now().millisecondsSinceEpoch}_${multipartFiles.length}.jpg',
          ),
        );
      }

      final formData = FormData.fromMap({
        'files': multipartFiles,
        'request': MultipartFile.fromString(
          '{"vehicleAssignmentId":"$vehicleAssignmentId","description":"${description ?? 'Photo completion at delivery'}"}',
          contentType: DioMediaType('application', 'json'),
        ),
      });

      final response = await _apiClient.dio.post(
        '/photo-completions/upload-multiple',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return const Right(true);
        } else {
          return Left(
            ServerFailure(
              message: responseData['message'] ?? 'Lỗi khi upload ảnh xác nhận',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            message: 'Lỗi khi upload ảnh xác nhận: ${response.statusCode}',
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
