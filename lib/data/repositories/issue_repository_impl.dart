import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/issue.dart';
import '../../domain/repositories/issue_repository.dart';
import '../datasources/api_client.dart';

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
      debugPrint('📤 Creating issue via API...');
      debugPrint('   - Description: $description');
      debugPrint('   - Issue Type ID: $issueTypeId');
      debugPrint('   - Vehicle Assignment ID: $vehicleAssignmentId');
      debugPrint('   - Location: $locationLatitude, $locationLongitude');

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

      debugPrint('✅ Issue created successfully');
      return Issue.fromJson(response.data['data'] as Map<String, dynamic>);
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating issue: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Không thể tạo sự cố: $e');
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
        debugPrint('⚠️ Warning: ID "$id" may not be a valid UUID format');
      }
      
      debugPrint('📤 Fetching issue by ID: $id');

      final response = await _apiClient.get('/issues/$id');

      debugPrint('✅ Issue fetched successfully');
      return Issue.fromJson(response.data['data'] as Map<String, dynamic>);
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching issue: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Không thể tải thông tin sự cố: $e');
    }
  }

  @override
  Future<List<IssueType>> getAllIssueTypes() async {
    try {
      debugPrint('📤 Fetching all issue types...');
      debugPrint('📤 Calling API endpoint: /issue-types');

      final response = await _apiClient.get('/issue-types');
      debugPrint('✅ Response status: ${response.statusCode}');
      debugPrint('✅ Response data keys: ${response.data.keys.toList()}');

      final data = response.data['data'] as List<dynamic>;
      final issueTypes = data
          .map((json) => IssueType.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Fetched ${issueTypes.length} issue types');
      return issueTypes;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching issue types: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Không thể tải danh sách loại sự cố: $e');
    }
  }

  @override
  Future<List<IssueType>> getActiveIssueTypes() async {
    try {
      final types = await getAllIssueTypes();
      return types.where((type) => type.isActive).toList();
    } catch (e) {
      debugPrint('Error getting active issue types: $e');
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
      debugPrint('📤 Uploading seal removal image: $sealRemovalImage');
      
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
        debugPrint('✅ Seal removal issue reported successfully');
        return Issue.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to report seal issue');
      }
    } catch (e) {
      debugPrint('❌ Error reporting seal issue: $e');
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
      debugPrint('Error confirming new seal: $e');
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
      debugPrint('📤 Getting IN_USE seal for vehicle assignment: $vehicleAssignmentId');
      final response = await _apiClient.get(
        '/issues/vehicle-assignment/$vehicleAssignmentId/in-use-seal',
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        debugPrint('✅ Got IN_USE seal: ${response.data['data']}');
        return response.data['data'];
      } else {
        debugPrint('⚠️ No IN_USE seal found');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting IN_USE seal: $e');
      rethrow;
    }
  }

  @override
  Future<List<Issue>> getPendingSealReplacements(String vehicleAssignmentId) async {
    try {
      debugPrint('📤 Getting pending seal replacements for vehicle assignment: $vehicleAssignmentId');
      final response = await _apiClient.get(
        '/issues/vehicle-assignment/$vehicleAssignmentId/pending-seal-replacements',
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final List<dynamic> issuesJson = response.data['data'];
        final issues = issuesJson.map((json) => Issue.fromJson(json)).toList();
        debugPrint('✅ Got ${issues.length} pending seal replacement(s)');
        return issues;
      } else {
        debugPrint('⚠️ No pending seal replacements found');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error getting pending seal replacements: $e');
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
      debugPrint('📦 Reporting damaged goods issue...');
      debugPrint('   - Vehicle Assignment ID: $vehicleAssignmentId');
      debugPrint('   - Issue Type ID: $issueTypeId');
      debugPrint('   - Order Detail ID: $orderDetailId');
      debugPrint('   - Description: $description');
      debugPrint('   - Damage images count: ${damageImagePaths.length}');

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
        debugPrint('📤 Adding damage image ${i + 1}: $imagePath');
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
        debugPrint('✅ Damage issue reported successfully');
        return Issue.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to report damage issue');
      }
    } catch (e) {
      debugPrint('❌ Error reporting damage issue: $e');
      rethrow;
    }
  }
}
