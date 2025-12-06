import 'package:dio/dio.dart';
import '../models/driver_dashboard_model.dart';
import 'api_client.dart';

/// Data source cho Dashboard API
class DashboardDataSource {
  final ApiClient _apiClient;

  DashboardDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Lấy dữ liệu dashboard cho tài xế
  /// [range] - Khoảng thời gian: TODAY, WEEK, MONTH, YEAR, CUSTOM
  /// [fromDate] - Ngày bắt đầu (chỉ dùng khi range = CUSTOM)
  /// [toDate] - Ngày kết thúc (chỉ dùng khi range = CUSTOM)
  Future<DriverDashboardModel> getDriverDashboard({
    String range = 'TODAY',
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'range': range,
      };

      if (range == 'CUSTOM') {
        if (fromDate != null) queryParams['fromDate'] = fromDate;
        if (toDate != null) queryParams['toDate'] = toDate;
      }

      final response = await _apiClient.dio.get(
        '/dashboard/driver',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // API trả về dạng { success: true, data: {...} }
        if (data is Map<String, dynamic>) {
          final dashboardData = data['data'] as Map<String, dynamic>?;
          if (dashboardData != null) {
            return DriverDashboardModel.fromJson(dashboardData);
          }
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception('Failed to load driver dashboard: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (e.response?.statusCode == 400) {
        final message = e.response?.data?['message'] ?? 'Bad request';
        throw Exception(message);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching driver dashboard: $e');
    }
  }

  /// Lấy AI summary cho dashboard tài xế
  /// [range] - Khoảng thời gian: TODAY, WEEK, MONTH, YEAR, CUSTOM
  /// [fromDate] - Ngày bắt đầu (chỉ dùng khi range = CUSTOM)
  /// [toDate] - Ngày kết thúc (chỉ dùng khi range = CUSTOM)
  Future<String> getDriverAiSummary({
    String range = 'TODAY',
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'range': range,
      };

      if (range == 'CUSTOM') {
        if (fromDate != null) queryParams['fromDate'] = fromDate;
        if (toDate != null) queryParams['toDate'] = toDate;
      }

      final response = await _apiClient.dio.get(
        '/dashboard/driver/ai-summary',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // API trả về dạng { success: true, data: "AI summary text" }
        if (data is Map<String, dynamic>) {
          final summary = data['data'] as String?;
          if (summary != null) {
            return summary;
          }
        }
        throw Exception('Invalid response format');
      } else {
        throw Exception('Failed to load AI summary: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (e.response?.statusCode == 400) {
        final message = e.response?.data?['message'] ?? 'Bad request';
        throw Exception(message);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching AI summary: $e');
    }
  }
}
