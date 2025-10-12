import '../../core/errors/exceptions.dart';
import '../../core/services/api_service.dart';
import '../../domain/entities/driver.dart';

abstract class DriverDataSource {
  /// Get driver information for the current authenticated user
  /// Throws [ServerException] for all error codes
  Future<Driver> getDriverInfo();

  /// Get driver information by user ID
  /// Throws [ServerException] for all error codes
  Future<Driver> getDriverByUserId(String userId);

  /// Update driver information
  /// Throws [ServerException] for all error codes
  Future<Driver> updateDriverInfo(
    String driverId,
    Map<String, dynamic> driverInfo,
  );
}

class DriverDataSourceImpl implements DriverDataSource {
  final ApiService apiService;

  DriverDataSourceImpl({required this.apiService});

  @override
  Future<Driver> getDriverInfo() async {
    try {
      // Using the new API endpoint that doesn't require userId parameter
      final response = await apiService.get('/drivers/user');

      if (response['success'] == true && response['data'] != null) {
        return Driver.fromJson(response['data']);
      } else {
        throw ServerException(
          message: response['message'] ?? 'Không thể lấy thông tin tài xế',
          statusCode: response['statusCode'] ?? 500,
        );
      }
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Không thể lấy thông tin tài xế');
    }
  }

  @override
  Future<Driver> getDriverByUserId(String userId) async {
    try {
      // Using the new API endpoint that doesn't require userId parameter
      final response = await apiService.get('/drivers/user');

      if (response['success'] == true && response['data'] != null) {
        return Driver.fromJson(response['data']);
      } else {
        throw ServerException(
          message: response['message'] ?? 'Không thể lấy thông tin tài xế',
          statusCode: response['statusCode'] ?? 500,
        );
      }
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Không thể lấy thông tin tài xế');
    }
  }

  @override
  Future<Driver> updateDriverInfo(
    String driverId,
    Map<String, dynamic> driverInfo,
  ) async {
    try {
      final response = await apiService.put('/drivers/$driverId', driverInfo);

      if (response['success'] == true && response['data'] != null) {
        return Driver.fromJson(response['data']);
      } else {
        throw ServerException(
          message: response['message'] ?? 'Không thể cập nhật thông tin tài xế',
          statusCode: response['statusCode'] ?? 500,
        );
      }
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Không thể cập nhật thông tin tài xế');
    }
  }
}
