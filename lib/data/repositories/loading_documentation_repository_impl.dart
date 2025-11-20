import 'dart:io';
import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/loading_documentation_repository.dart';
import '../datasources/api_client.dart';

class LoadingDocumentationRepositoryImpl
    implements LoadingDocumentationRepository {
  final ApiClient _apiClient;

  LoadingDocumentationRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<Either<Failure, bool>> documentLoadingAndSeal({
    required String vehicleAssignmentId,
    required String sealCode,
    required List<File> packingProofImages,
    required File sealImage,
  }) async {
    try {
      // Create FormData
      final formData = FormData();

      // Add request fields separately (for @ModelAttribute binding)
      formData.fields.add(MapEntry('vehicleAssignmentId', vehicleAssignmentId));
      formData.fields.add(MapEntry('sealCode', sealCode));

      // Debug log

      // Add packing proof images
      for (int i = 0; i < packingProofImages.length; i++) {
        final file = packingProofImages[i];

        
        

        formData.files.add(
          MapEntry(
            'packingProofImages',
            await MultipartFile.fromFile(
              file.path,
              filename: 'packing_proof_$i.jpg',
            ),
          ),
        );
      }

      // Add seal image
      
      
      formData.files.add(
        MapEntry(
          'sealImage',
          await MultipartFile.fromFile(
            sealImage.path,
            filename: 'seal_image.jpg',
          ),
        ),
      );

      // Log API endpoint

      // Call API
      final response = await _apiClient.dio.post(
        '/loading-documentation/document-loading-and-seal',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return const Right(true);
        } else {
          return Left(
            ServerFailure(
              message: responseData['message'] ?? 'Lỗi khi gửi tài liệu đóng gói và seal',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            message: 'Lỗi khi gửi tài liệu đóng gói và seal: ${response.statusCode}',
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
