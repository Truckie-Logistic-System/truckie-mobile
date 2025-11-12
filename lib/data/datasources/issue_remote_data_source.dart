import 'package:dio/dio.dart';
import '../../core/services/api_service.dart';
import '../models/order_rejection_detail_response.dart';

class IssueRemoteDataSource {
  final ApiService _apiService;

  IssueRemoteDataSource(this._apiService);

  /// Report order rejection by recipient (Driver)
  Future<Map<String, dynamic>> reportOrderRejection({
    required String vehicleAssignmentId,
    required String issueTypeId,
    String? description,
    double? locationLatitude,
    double? locationLongitude,
  }) async {
    try {
      final response = await _apiService.dio.post(
        '/issues/order-rejection',
        data: {
          'vehicleAssignmentId': vehicleAssignmentId,
          'issueTypeId': issueTypeId,
          'description': description,
          'locationLatitude': locationLatitude,
          'locationLongitude': locationLongitude,
        },
      );
      return response.data['data'];
    } catch (e) {
      rethrow;
    }
  }

  /// Get ORDER_REJECTION issue detail
  Future<OrderRejectionDetailResponse> getOrderRejectionDetail(String issueId) async {
    try {
      final response = await _apiService.dio.get(
        '/issues/order-rejection/$issueId/detail',
      );
      return OrderRejectionDetailResponse.fromJson(response.data['data']);
    } catch (e) {
      rethrow;
    }
  }

  /// Confirm return delivery at pickup location (Driver)
  Future<Map<String, dynamic>> confirmReturnDelivery({
    required String issueId,
    required List<String> returnDeliveryImages,
  }) async {
    try {
      final response = await _apiService.dio.put(
        '/issues/order-rejection/confirm-return',
        data: {
          'issueId': issueId,
          'returnDeliveryImages': returnDeliveryImages,
        },
      );
      return response.data['data'];
    } catch (e) {
      rethrow;
    }
  }

  /// Upload image to server
  Future<String> uploadImage(String filePath) async {
    try {
      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _apiService.dio.post(
        '/cloudinary/upload',
        data: formData,
      );
      
      return response.data['data']['url'];
    } catch (e) {
      rethrow;
    }
  }
}
