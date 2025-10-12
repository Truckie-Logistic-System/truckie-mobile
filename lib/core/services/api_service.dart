import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../errors/exceptions.dart';
import 'service_locator.dart';
import 'token_storage_service.dart';
import '../../presentation/features/auth/viewmodels/auth_viewmodel.dart';

// Callback khi refresh token thất bại
typedef OnTokenRefreshFailedCallback = void Function();

class ApiService {
  final String baseUrl;
  final http.Client client;
  final TokenStorageService tokenStorageService;
  bool _isRefreshing = false;

  // Callback khi refresh token thất bại
  static OnTokenRefreshFailedCallback? onTokenRefreshFailed;

  ApiService({
    required this.baseUrl,
    required this.client,
    required this.tokenStorageService,
  });

  // Đặt callback khi refresh token thất bại
  static void setTokenRefreshFailedCallback(
    OnTokenRefreshFailedCallback callback,
  ) {
    onTokenRefreshFailed = callback;
  }

  Future<Map<String, String>> _getHeaders() async {
    final headers = {'Content-Type': 'application/json'};

    // Lấy access token từ memory
    final token = tokenStorageService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      debugPrint('Using token in headers: ${token.substring(0, 15)}...');
    } else {
      debugPrint('No token available for headers');

      // Thử refresh token nếu không có token
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Lấy token mới sau khi refresh
        final newToken = tokenStorageService.getAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $newToken';
          debugPrint(
            'Using new token after refresh: ${newToken.substring(0, 15)}...',
          );
        }
      }
    }

    return headers;
  }

  // Kiểm tra token trước khi gọi API
  Future<bool> _ensureValidToken() async {
    final token = tokenStorageService.getAccessToken();

    // Nếu không có token, thử refresh
    if (token == null || token.isEmpty) {
      debugPrint('No token available, attempting to refresh...');
      return await _refreshToken();
    }

    // Nếu có token, kiểm tra xem có phải token mới nhất không
    try {
      final authViewModel = getIt<AuthViewModel>();
      if (authViewModel.user != null &&
          authViewModel.user!.authToken != token) {
        debugPrint(
          'Token mismatch between memory and AuthViewModel, updating...',
        );
        await tokenStorageService.saveAccessToken(
          authViewModel.user!.authToken,
        );
        return true;
      }
    } catch (e) {
      debugPrint('Error checking token: $e');
    }

    return true;
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async {
    // Đảm bảo token hợp lệ trước khi gọi API
    await _ensureValidToken();

    try {
      final headers = await _getHeaders();

      // Xây dựng URI với query parameters nếu có
      var uri = Uri.parse('$baseUrl$endpoint');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      // Debug log
      debugPrint('GET Request: $uri');
      debugPrint('Headers: $headers');

      // Kiểm tra xem có token không
      if (!headers.containsKey('Authorization')) {
        debugPrint('WARNING: No Authorization header for request to $endpoint');
      }

      final response = await client.get(uri, headers: headers);

      // Debug log
      _logResponse('GET', endpoint, response);

      return _processResponse(response, endpoint);
    } on UnauthorizedException catch (e) {
      // Xử lý token hết hạn
      if (!_isRefreshing) {
        debugPrint(
          'Unauthorized error for $endpoint, attempting to refresh token...',
        );
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Thử lại request với token mới
          debugPrint('Token refreshed, retrying request to $endpoint');
          return get(endpoint);
        } else {
          // Nếu refresh token thất bại, gọi callback
          debugPrint('Token refresh failed, handling failure for $endpoint');
          _handleTokenRefreshFailed();
        }
      } else {
        debugPrint(
          'Already refreshing token, cannot handle unauthorized error for $endpoint',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('GET Error for $endpoint: ${e.toString()}');
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> post(String endpoint, dynamic body) async {
    // Đảm bảo token hợp lệ trước khi gọi API
    await _ensureValidToken();

    try {
      final headers = await _getHeaders();

      // Debug log
      debugPrint('POST Request: $baseUrl$endpoint');
      debugPrint('Headers: $headers');
      debugPrint('Body: $body');

      final response = await client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );

      // Debug log
      _logResponse('POST', endpoint, response);

      return _processResponse(response, endpoint);
    } on UnauthorizedException catch (e) {
      // Xử lý token hết hạn
      if (!_isRefreshing) {
        debugPrint('Unauthorized error, attempting to refresh token...');
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Thử lại request với token mới
          return post(endpoint, body);
        } else {
          // Nếu refresh token thất bại, gọi callback
          _handleTokenRefreshFailed();
        }
      }
      rethrow;
    } catch (e) {
      debugPrint('POST Error: ${e.toString()}');
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> put(String endpoint, dynamic body) async {
    // Đảm bảo token hợp lệ trước khi gọi API
    await _ensureValidToken();

    try {
      final headers = await _getHeaders();

      // Debug log
      debugPrint('PUT Request: $baseUrl$endpoint');
      debugPrint('Headers: $headers');
      debugPrint('Body: $body');

      final response = await client.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );

      // Debug log
      _logResponse('PUT', endpoint, response);

      return _processResponse(response, endpoint);
    } on UnauthorizedException catch (e) {
      // Xử lý token hết hạn
      if (!_isRefreshing) {
        debugPrint('Unauthorized error, attempting to refresh token...');
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Thử lại request với token mới
          return put(endpoint, body);
        } else {
          // Nếu refresh token thất bại, gọi callback
          _handleTokenRefreshFailed();
        }
      }
      rethrow;
    } catch (e) {
      debugPrint('PUT Error: ${e.toString()}');
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> delete(String endpoint) async {
    // Đảm bảo token hợp lệ trước khi gọi API
    await _ensureValidToken();

    try {
      final headers = await _getHeaders();

      // Debug log
      debugPrint('DELETE Request: $baseUrl$endpoint');
      debugPrint('Headers: $headers');

      final response = await client.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      // Debug log
      _logResponse('DELETE', endpoint, response);

      return _processResponse(response, endpoint);
    } on UnauthorizedException catch (e) {
      // Xử lý token hết hạn
      if (!_isRefreshing) {
        debugPrint('Unauthorized error, attempting to refresh token...');
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Thử lại request với token mới
          return delete(endpoint);
        } else {
          // Nếu refresh token thất bại, gọi callback
          _handleTokenRefreshFailed();
        }
      }
      rethrow;
    } catch (e) {
      debugPrint('DELETE Error: ${e.toString()}');
      throw ServerException(message: e.toString());
    }
  }

  Future<bool> _refreshToken() async {
    if (_isRefreshing) return false;

    _isRefreshing = true;
    try {
      // Lấy refresh token từ secure storage
      final refreshToken = await tokenStorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('No refresh token available');
        _isRefreshing = false;
        await tokenStorageService.clearAllTokens();
        return false;
      }

      debugPrint(
        'Refreshing token with refresh token: ${refreshToken.substring(0, 15)}...',
      );

      final response = await client.post(
        Uri.parse('$baseUrl/auths/mobile/token/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      _logResponse('POST', '/auths/mobile/token/refresh', response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final newAccessToken = responseData['data']['accessToken'];
          debugPrint(
            'New access token received: ${newAccessToken.substring(0, 15)}...',
          );

          // Lưu token mới
          await tokenStorageService.saveAccessToken(newAccessToken);

          // Kiểm tra xem token đã được lưu chưa
          final savedToken = tokenStorageService.getAccessToken();
          if (savedToken != newAccessToken) {
            debugPrint(
              'WARNING: Token mismatch after saving! This is a critical error.',
            );
          }

          // Thông báo cho AuthViewModel về token mới
          try {
            final authViewModel = getIt<AuthViewModel>();
            await authViewModel.handleTokenRefreshed(newAccessToken);
            debugPrint('AuthViewModel updated with new token');
          } catch (e) {
            debugPrint('Error updating AuthViewModel: $e');
          }

          _isRefreshing = false;
          return true;
        }
      }

      debugPrint(
        'Token refresh failed with status code: ${response.statusCode}',
      );
      _isRefreshing = false;
      await tokenStorageService.clearAllTokens();
      return false;
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      _isRefreshing = false;
      await tokenStorageService.clearAllTokens();
      return false;
    }
  }

  /// Public method to refresh token
  Future<bool> refreshToken() async {
    return _refreshToken();
  }

  // Xóa dữ liệu người dùng khi refresh token thất bại
  Future<void> _clearUserData() async {
    try {
      await tokenStorageService.clearAllTokens();
    } catch (e) {
      debugPrint('Error clearing user data: $e');
    }
  }

  // Gọi callback khi refresh token thất bại
  void _handleTokenRefreshFailed() {
    debugPrint('Token refresh failed, handling failure');

    // Xóa dữ liệu người dùng
    _clearUserData();

    // Gọi callback nếu được đăng ký
    if (onTokenRefreshFailed != null) {
      onTokenRefreshFailed!();
    }
  }

  void _logResponse(String method, String endpoint, http.Response response) {
    debugPrint('$method Response: $endpoint');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Response Body: ${response.body}');
  }

  dynamic _processResponse(http.Response response, String endpoint) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      String errorMessage = 'Không có quyền truy cập';
      try {
        final responseData = json.decode(response.body);
        errorMessage = responseData['message'] ?? 'Không có quyền truy cập';
      } catch (e) {
        // Ignore JSON parsing errors
      }
      throw UnauthorizedException(message: errorMessage);
    } else {
      // Special case for empty order list
      if (response.statusCode == 400 &&
          endpoint == '/orders/get-list-order-for-driver') {
        try {
          final responseData = json.decode(response.body);
          final message = responseData['message'] ?? '';
          if (message.toString().contains('Not found')) {
            // Return an empty success response with empty data array
            return {
              'success': true,
              'message': 'No orders found',
              'statusCode': 200,
              'data': [],
            };
          }
        } catch (e) {
          // Ignore JSON parsing errors
        }
      }

      String errorMessage = 'Đã xảy ra lỗi';
      try {
        final responseData = json.decode(response.body);
        errorMessage = responseData['message'] ?? 'Đã xảy ra lỗi';
      } catch (e) {
        // Ignore JSON parsing errors
      }
      throw ServerException(
        message: errorMessage,
        statusCode: response.statusCode,
      );
    }
  }
}
