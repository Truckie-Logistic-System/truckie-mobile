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
  Future<Either<Failure, bool>> submitPreDeliveryDocumentation({
    required String vehicleAssignmentId,
    required String sealCode,
    required List<File>? packingProofImages,
    required File? sealImage,
  }) async {
    try {
      // Tạo FormData
      final formData = FormData();

      // Thêm các trường form riêng lẻ thay vì JSON
      // @ModelAttribute trong Spring Boot mong đợi các trường form riêng lẻ
      formData.fields.add(MapEntry('vehicleAssignmentId', vehicleAssignmentId));
      formData.fields.add(MapEntry('sealCode', sealCode));

      // Debug log để kiểm tra request
      debugPrint('========== REQUEST DEBUG INFO ==========');
      debugPrint('vehicleAssignmentId: $vehicleAssignmentId');
      debugPrint('sealCode: $sealCode');

      // Thêm hình ảnh đóng gói
      if (packingProofImages != null && packingProofImages.isNotEmpty) {
        debugPrint('Số lượng packingProofImages: ${packingProofImages.length}');
        for (int i = 0; i < packingProofImages.length; i++) {
          final file = packingProofImages[i];
          debugPrint('packingProofImage[$i] path: ${file.path}');
          debugPrint('packingProofImage[$i] exists: ${file.existsSync()}');
          debugPrint('packingProofImage[$i] size: ${file.lengthSync()} bytes');

          formData.files.add(
            MapEntry(
              'packingProofImages',
              await MultipartFile.fromFile(
                file.path,
                filename: 'packing_proof_${i}.jpg',
              ),
            ),
          );
        }
      } else {
        debugPrint('Không có packingProofImages');
      }

      // Thêm hình ảnh seal
      if (sealImage != null) {
        debugPrint('sealImage path: ${sealImage.path}');
        debugPrint('sealImage exists: ${sealImage.existsSync()}');
        debugPrint('sealImage size: ${sealImage.lengthSync()} bytes');

        formData.files.add(
          MapEntry(
            'sealImage',
            await MultipartFile.fromFile(
              sealImage.path,
              filename: 'seal_image.jpg',
            ),
          ),
        );
      } else {
        debugPrint('Không có sealImage');
      }

      // Debug log để kiểm tra formData
      debugPrint(
        'FormData fields: ${formData.fields.map((e) => "${e.key}: ${e.value}").join(', ')}',
      );
      debugPrint('FormData files count: ${formData.files.length}');
      formData.files.forEach((file) {
        debugPrint('File name: ${file.key}, filename: ${file.value.filename}');
      });

      // Log thông tin API endpoint
      debugPrint(
        'API Endpoint: ${_apiClient.dio.options.baseUrl}/loading-documentation/pre-delivery',
      );
      debugPrint('========== END REQUEST DEBUG INFO ==========');

      // Gọi API
      final response = await _apiClient.dio.post(
        '/loading-documentation/pre-delivery',
        data: formData,
      );

      debugPrint('========== RESPONSE DEBUG INFO ==========');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Response Data: ${response.data}');
      debugPrint('========== END RESPONSE DEBUG INFO ==========');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return const Right(true);
        } else {
          return Left(
            ServerFailure(
              message:
                  responseData['message'] ?? 'Lỗi khi gửi tài liệu đóng gói',
            ),
          );
        }
      } else {
        return Left(
          ServerFailure(
            message: 'Lỗi khi gửi tài liệu đóng gói: ${response.statusCode}',
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint('========== ERROR DEBUG INFO ==========');
      debugPrint('DioException: ${e.message}');
      debugPrint('DioException type: ${e.type}');
      debugPrint('DioException error: ${e.error}');
      debugPrint('DioException requestOptions: ${e.requestOptions.uri}');
      debugPrint(
        'DioException requestOptions headers: ${e.requestOptions.headers}',
      );
      debugPrint('DioException response status: ${e.response?.statusCode}');
      debugPrint('DioException response data: ${e.response?.data}');
      debugPrint('========== END ERROR DEBUG INFO ==========');
      return Left(
        ServerFailure(message: e.message ?? 'Lỗi kết nối đến máy chủ'),
      );
    } on ServerException catch (e) {
      debugPrint('ServerException: ${e.message}');
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      debugPrint('Exception: ${e.toString()}');
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
