import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../errors/exceptions.dart';
import 'token_storage_service.dart';
import '../../app/di/service_locator.dart';

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
      // 
    } else {
      // 

      // Thử refresh token nếu không có token
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Lấy token mới sau khi refresh
        final newToken = tokenStorageService.getAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $newToken';
          // 
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
      // 
      return await _refreshToken();
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
      // 
      // 

      // Kiểm tra xem có token không
      if (!headers.containsKey('Authorization')) {
        // 
      }

      final response = await client.get(uri, headers: headers);

      // Debug log
      // _logResponse('GET', endpoint, response);

      return _processResponse(response, endpoint);
    } on UnauthorizedException {
      // Xử lý token hết hạn
      if (!_isRefreshing) {
        // 
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Thử lại request với token mới
          // 
          return get(endpoint);
        } else {
          // Nếu refresh token thất bại, gọi callback
          // 
          _handleTokenRefreshFailed();
        }
      } else {
        // 
      }
      rethrow;
    } catch (e) {
      // 
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> post(String endpoint, dynamic body) async {
    // Đảm bảo token hợp lệ trước khi gọi API
    await _ensureValidToken();

    try {
      final headers = await _getHeaders();

      // Debug log
      // 
      // 
      // 

      final response = await client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );

      // Debug log
      // _logResponse('POST', endpoint, response);

      return _processResponse(response, endpoint);
    } on UnauthorizedException {
      // Xử lý token hết hạn
      if (!_isRefreshing) {
        // 
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
      // 
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> put(String endpoint, dynamic body) async {
    // Đảm bảo token hợp lệ trước khi gọi API
    await _ensureValidToken();

    try {
      final headers = await _getHeaders();

      // Debug log
      // 
      // 
      // 

      final response = await client.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: json.encode(body),
      );

      // Debug log
      // _logResponse('PUT', endpoint, response);

      return _processResponse(response, endpoint);
    } on UnauthorizedException {
      // Xử lý token hết hạn
      if (!_isRefreshing) {
        // 
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
      // 
      throw ServerException(message: e.toString());
    }
  }

  Future<dynamic> delete(String endpoint) async {
    // Đảm bảo token hợp lệ trước khi gọi API
    await _ensureValidToken();

    try {
      final headers = await _getHeaders();

      // Debug log
      // 
      // 

      final response = await client.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      );

      // Debug log
      // _logResponse('DELETE', endpoint, response);

      return _processResponse(response, endpoint);
    } on UnauthorizedException {
      // Xử lý token hết hạn
      if (!_isRefreshing) {
        // 
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
      // 
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
        // 
        _isRefreshing = false;
        await tokenStorageService.clearAllTokens();
        return false;
      }

      // 

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
          // 

          // Lưu token mới
          await tokenStorageService.saveAccessToken(newAccessToken);

          // Kiểm tra xem token đã được lưu chưa
          final savedToken = tokenStorageService.getAccessToken();
          if (savedToken != newAccessToken) {
            // 
          }

          // Thông báo cho AuthViewModel về token mới
          try {
            final authViewModel = getIt.get(instanceName: 'AuthViewModel');
            if (authViewModel != null) {
              // Cast to dynamic to access the method
              final dynamic dynamicViewModel = authViewModel;
              if (dynamicViewModel.handleTokenRefreshed != null) {
                await dynamicViewModel.handleTokenRefreshed(newAccessToken);
              }
            }
            // 
          } catch (e) {
            // 
          }

          _isRefreshing = false;
          return true;
        }
      }

      // 
      _isRefreshing = false;
      await tokenStorageService.clearAllTokens();
      return false;
    } catch (e) {
      // 
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
      // 
    }
  }

  // Gọi callback khi refresh token thất bại
  void _handleTokenRefreshFailed() {
    // 

    // Xóa dữ liệu người dùng
    _clearUserData();

    // Gọi callback nếu được đăng ký
    if (onTokenRefreshFailed != null) {
      onTokenRefreshFailed!();
    }
  }

  void _logResponse(String method, String endpoint, http.Response response) {
    // 
    // 
    // 
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
