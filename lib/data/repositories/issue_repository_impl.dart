import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/issue.dart';
import '../../domain/repositories/issue_repository.dart';
import '../datasources/api_client.dart';
import '../../core/errors/error_mapper.dart';

/// Concrete implementation of IssueRepository
class IssueRepositoryImpl implements IssueRepository {
  final ApiClient _apiClient;

  IssueRepositoryImpl(this._apiClient);

  @override
  Future<Issue> createIssue({
    required String description,
    required String issueTypeId,
    String? vehicleAssignmentId,
    double? locationLatitude,
    double? locationLongitude,
  }) async {
    try {
      final response = await _apiClient.post(
        '/issue',
        data: {
          'description': description,
          'issueTypeId': issueTypeId,
          'vehicleAssignmentId': vehicleAssignmentId,
          if (locationLatitude != null) 'locationLatitude': locationLatitude,
          if (locationLongitude != null) 'locationLongitude': locationLongitude,
        },
      );
      return Issue.fromJson(response.data['data'] as Map<String, dynamic>);
    } catch (e, stackTrace) {
      // Use ErrorMapper for user-friendly message
      final friendlyMessage = ErrorMapper.mapToUserFriendlyMessage(e);
      throw Exception('Không thể tạo sự cố: $friendlyMessage');
    }
  }

  @override
  Future<Issue> getIssueById(String id) async {
    try {
      // Validate UUID format to prevent "get-all" being passed as ID
      if (id.isEmpty || id == 'get-all' || id == 'getAll') {
        throw Exception('ID không hợp lệ: "$id". Đây không phải là định dạng UUID.');
      }
      
      // Basic UUID format validation validation (UUID v4 format)
      final uuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
      if (!uuidPattern.hasMatch(id.toLowerCase())) {
      }
      final response = await _apiClient.get('/issues/$id');
      return Issue.fromJson(response.data['data'] as Map<String, dynamic>);
    } catch (e, stackTrace) {
      // Use ErrorMapper for user-friendly message
      final friendlyMessage = ErrorMapper.mapToUserFriendlyMessage(e);
      throw Exception('Không thể tải thông tin sự cố: $friendlyMessage');
    }
  }

  @override
  Future<List<IssueType>> getAllIssueTypes() async {
    try {
      final response = await _apiClient.get('/issue-types');
      

      final data = response.data['data'] as List<dynamic>;
      final issueTypes = data
          .map((json) => IssueType.fromJson(json as Map<String, dynamic>))
          .toList();
      return issueTypes;
    } catch (e, stackTrace) {
      // Use ErrorMapper for user-friendly message
      final friendlyMessage = ErrorMapper.mapToUserFriendlyMessage(e);
      throw Exception('Không thể tải danh sách loại sự cố: $friendlyMessage');
    }
  }

  @override
  Future<List<IssueType>> getActiveIssueTypes() async {
    try {
      final types = await getAllIssueTypes();
      return types.where((type) => type.isActive).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Issue> reportSealIssue({
    required String vehicleAssignmentId,
    required String issueTypeId,
    required String sealId,
    required String description,
    required String sealRemovalImage,
    double? locationLatitude,
    double? locationLongitude,
  }) async {
    try {
      // Create multipart form data
      final formData = FormData.fromMap({
        'vehicleAssignmentId': vehicleAssignmentId,
        'issueTypeId': issueTypeId,
        'sealId': sealId,
        'description': description,
        'sealRemovalImage': await MultipartFile.fromFile(
          sealRemovalImage,
          filename: sealRemovalImage.split('/').last,
        ),
        if (locationLatitude != null) 'locationLatitude': locationLatitude.toString(),
        if (locationLongitude != null) 'locationLongitude': locationLongitude.toString(),
      });

      final response = await _apiClient.post(
        '/issues/seal-removal',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        return Issue.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to report seal issue');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Issue> confirmNewSeal({
    required String issueId,
    required String newSealAttachedImage,
  }) async {
    try {
      final response = await _apiClient.put(
        '/issues/seal-replacement/confirm',
        data: {
          'issueId': issueId,
          'newSealAttachedImage': newSealAttachedImage,
        },
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        return Issue.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to confirm new seal');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Issue> confirmSealReplacement({
    required String issueId,
    required String newSealAttachedImage,
  }) async {
    // Alias for confirmNewSeal - same implementation
    return confirmNewSeal(
      issueId: issueId,
      newSealAttachedImage: newSealAttachedImage,
    );
  }

  @override
  Future<dynamic> getInUseSeal(String vehicleAssignmentId) async {
    try {
      final response = await _apiClient.get(
        '/issues/vehicle-assignment/$vehicleAssignmentId/in-use-seal',
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data'];
      } else {
        return null;
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Issue>> getPendingSealReplacements(String vehicleAssignmentId) async {
    try {
      final response = await _apiClient.get(
        '/issues/vehicle-assignment/$vehicleAssignmentId/pending-seal-replacements',
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final List<dynamic> issuesJson = response.data['data'];
        final issues = issuesJson.map((json) => Issue.fromJson(json)).toList();
        
        return issues;
      } else {
        return [];
      }
    } catch (e) {
      // Return empty list instead of throwing to avoid breaking UI
      return [];
    }
  }

  @override
  Future<Issue> reportDamageIssue({
    required String vehicleAssignmentId,
    required String issueTypeId,
    required String orderDetailId,
    required String description,
    required List<String> damageImagePaths,
    double? locationLatitude,
    double? locationLongitude,
  }) async {
    try {
      // Create multipart form data
      final formData = FormData();
      formData.fields.add(MapEntry('vehicleAssignmentId', vehicleAssignmentId));
      formData.fields.add(MapEntry('issueTypeId', issueTypeId));
      formData.fields.add(MapEntry('orderDetailIds', orderDetailId));
      formData.fields.add(MapEntry('description', description));
      
      if (locationLatitude != null) {
        formData.fields.add(MapEntry('locationLatitude', locationLatitude.toString()));
      }
      if (locationLongitude != null) {
        formData.fields.add(MapEntry('locationLongitude', locationLongitude.toString()));
      }

      // Add multiple image files
      for (int i = 0; i < damageImagePaths.length; i++) {
        final imagePath = damageImagePaths[i];
        formData.files.add(
          MapEntry(
            'damageImages',
            await MultipartFile.fromFile(
              imagePath,
              filename: imagePath.split('/').last,
            ),
          ),
        );
      }

      final response = await _apiClient.post(
        '/issues/damage',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        return Issue.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to report damage issue');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> reportPenaltyIssue({
    required String vehicleAssignmentId,
    required String issueTypeId,
    required String violationType,
    required String violationImagePath,
    double? locationLatitude,
    double? locationLongitude,
  }) async {
    try {
      // Create multipart form data
      final formData = FormData();
      formData.fields.add(MapEntry('vehicleAssignmentId', vehicleAssignmentId));
      formData.fields.add(MapEntry('issueTypeId', issueTypeId));
      formData.fields.add(MapEntry('violationType', violationType));
      
      if (locationLatitude != null) {
        formData.fields.add(MapEntry('locationLatitude', locationLatitude.toString()));
      }
      if (locationLongitude != null) {
        formData.fields.add(MapEntry('locationLongitude', locationLongitude.toString()));
      }

      // Add violation record image file
      formData.files.add(
        MapEntry(
          'trafficViolationRecordImage',
          await MultipartFile.fromFile(
            violationImagePath,
            filename: violationImagePath.split('/').last,
          ),
        ),
      );

      final response = await _apiClient.post(
        '/issues/penalty',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
      } else {
        throw Exception('Failed to report penalty issue');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ===== ORDER_REJECTION flow methods =====

  @override
  Future<Issue> reportOrderRejection({
    required String vehicleAssignmentId,
    required List<String> orderDetailIds,
    double? locationLatitude,
    double? locationLongitude,
  }) async {
    try {
      final response = await _apiClient.post(
        '/issues/order-rejection',
        data: {
          'vehicleAssignmentId': vehicleAssignmentId,
          'orderDetailIds': orderDetailIds,
          if (locationLatitude != null) 'locationLatitude': locationLatitude,
          if (locationLongitude != null) 'locationLongitude': locationLongitude,
        },
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        
        return Issue.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to report order rejection');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<dynamic> getOrderRejectionDetail(String issueId) async {
    try {
      final response = await _apiClient.get(
        '/issues/order-rejection/$issueId/detail',
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data'];
      } else {
        throw Exception('Failed to get order rejection detail');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Issue> confirmReturnDelivery({
    required String issueId,
    required List<dynamic> returnDeliveryImages,
  }) async {
    try {
      

      // Prepare FormData to send files directly (like PhotoCompletion)
      final formData = FormData();
      
      // Add issueId as a part
      formData.fields.add(MapEntry('issueId', issueId));
      
      // Add files
      for (var image in returnDeliveryImages) {
        if (image is File) {
          formData.files.add(
            MapEntry(
              'files',
              await MultipartFile.fromFile(
                image.path,
                filename: image.path.split('/').last,
              ),
            ),
          );
        }
      }
      // Send directly to backend, backend will upload to Cloudinary
      final response = await _apiClient.post(
        '/issues/order-rejection/confirm-return',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        return Issue.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to confirm return delivery');
      }
    } catch (e) {
      rethrow;
    }
  }
}
