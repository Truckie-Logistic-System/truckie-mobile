import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../core/services/token_storage_service.dart';
import '../../core/services/http_client_interface.dart';
import '../../app/di/service_locator.dart';

typedef OnUnauthorizedCallback = Future<void> Function();
typedef OnForbiddenCallback = Future<void> Function();

/// Wrapper class to track queued requests with timestamp
class _QueuedRequest {
  final DioException error;
  final DateTime timestamp;
  
  _QueuedRequest({required this.error, required this.timestamp});
}

class ApiClient implements IHttpClient {
  final String baseUrl;
  late final Dio dio;
  late final TokenStorageService _tokenStorageService;
  OnUnauthorizedCallback? _onUnauthorizedCallback;
  OnForbiddenCallback? _onForbiddenCallback;
  bool _isRefreshing = false; // Lock to prevent concurrent refresh calls
  
  // CRITICAL: Add max queue size and timeout to prevent memory leak
  final List<_QueuedRequest> _requestQueue = [];
  static const int _maxQueueSize = 10; // Max 10 queued requests
  static const Duration _queueTimeout = Duration(seconds: 30); // 30 second timeout

  ApiClient({required this.baseUrl}) {
    _tokenStorageService = getIt<TokenStorageService>();

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptor for authentication
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // CRITICAL: Disable proactive token refresh!
          // This causes issues with token rotation after login:
          // 1. Login → Token saved (fresh, 1 hour)
          // 2. API call → Proactive refresh → Token rotation
          // 3. Next API call → Uses old token (revoked) → 401 → logout
          // 
          // Token has 1 hour validity, no need to refresh proactively.
          // Token will be refreshed on 401 error instead.
          // CRITICAL: Do NOT add Authorization header for refresh token endpoint!
          // The refresh token endpoint only needs refreshToken in the request body,
          // not the expired access token in the Authorization header.
          // Adding expired token causes 401/400 errors from backend.
          if (options.path.contains('/auths/mobile/token/refresh')) {
            return handler.next(options);
          }
          
          final token = _tokenStorageService.getAccessToken();
          if (token != null) {
            
            options.headers['Authorization'] = 'Bearer $token';
          } else {
          }
          
          // Check token expiry (optional - for proactive refresh)
          if (token != null && _isTokenExpiringSoon(token)) {
          }
          
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Handle 403 Forbidden errors from DriverOnboardingFilter
          if (e.response?.statusCode == 403) {
            final message = e.response?.data?['message'] as String?;
            if (message != null && message.contains('Vui lòng hoàn tất đăng ký tài khoản trước khi sử dụng ứng dụng')) {
              // INACTIVE driver attempting to access restricted endpoint - trigger callback
              if (_onForbiddenCallback != null) {
                await _onForbiddenCallback!();
              }
              return handler.next(e);
            }
          }

          // Handle 401 Unauthorized errors
          if (e.response?.statusCode == 401) {
            // CRITICAL: Use lock to prevent concurrent refresh calls
            // Check BEFORE any async operation
            if (_isRefreshing) {
              // Clean up old requests before adding new one
              _cleanupOldQueuedRequests();
              
              // Check queue size limit
              if (_requestQueue.length >= _maxQueueSize) {
                
                _requestQueue.removeAt(0);
              }
              
              _requestQueue.add(_QueuedRequest(
                error: e,
                timestamp: DateTime.now(),
              ));
              return handler.next(e);
            }
            
            // Set lock IMMEDIATELY before any async operation
            _isRefreshing = true;
            
            
            // Call the callback if it's set (callback will refresh token)
            if (_onUnauthorizedCallback != null) {
              try {
                await _onUnauthorizedCallback!();
                // After callback completes, get new token and retry the request
                final newToken = _tokenStorageService.getAccessToken();
                if (newToken != null) {
                  // Update the request with new token
                  e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                  
                  // Retry the original request
                  try {
                    final response = await dio.fetch(e.requestOptions);
                    _isRefreshing = false;
                    
                    // Clean up old queued requests before processing
                    _cleanupOldQueuedRequests();
                    
                    // Process queued requests
                    final queue = _requestQueue.toList();
                    _requestQueue.clear();
                    
                    for (final queuedRequest in queue) {
                      final queuedError = queuedRequest.error;
                      final age = DateTime.now().difference(queuedRequest.timestamp);
                      
                      if (age > _queueTimeout) {
                        
                        continue;
                      }
                      queuedError.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                      try {
                        await dio.fetch(queuedError.requestOptions);
                      } catch (retryError) {
                      }
                    }
                    
                    return handler.resolve(response);
                  } catch (retryError) {
                    _isRefreshing = false;
                    _requestQueue.clear();
                    return handler.next(e);
                  }
                } else {
                  _isRefreshing = false;
                  _requestQueue.clear();
                  return handler.next(e);
                }
              } catch (ex) {
                _isRefreshing = false;
                _requestQueue.clear();
                return handler.next(e);
              }
            } else {
              _isRefreshing = false;
              return handler.next(e);
            }
          }
          
          return handler.next(e);
        },
        onResponse: (response, handler) {
          // 
          return handler.next(response);
        },
      ),
    );
  }

  /// Set callback to be called when 401 Unauthorized error occurs
  void setOnUnauthorizedCallback(OnUnauthorizedCallback callback) {
    _onUnauthorizedCallback = callback;
  }

  /// Set callback to be called when 403 Forbidden error occurs (INACTIVE driver access)
  void setOnForbiddenCallback(OnForbiddenCallback callback) {
    _onForbiddenCallback = callback;
  }

  /// Clean up old queued requests that have exceeded timeout
  void _cleanupOldQueuedRequests() {
    final now = DateTime.now();
    _requestQueue.removeWhere((queuedRequest) {
      final age = now.difference(queuedRequest.timestamp);
      final isOld = age > _queueTimeout;
      if (isOld) {
        
      }
      return isOld;
    });
  }
  
  /// Check if token is expiring soon (< 5 minutes)
  bool _isTokenExpiringSoon(String token) {
    try {
      // Decode JWT manually (without verification)
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      // Decode payload
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      
      final exp = json['exp'] as int?;
      if (exp == null) return false;
      
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      final timeUntilExpiry = expiryTime.difference(now);
      
      // Return true if expiring within 5 minutes
      return timeUntilExpiry.inMinutes < 5;
    } catch (e) {
      return false;
    }
  }

  // CRITICAL: Proactive token refresh methods commented out!
  // These were causing double refresh token calls after login:
  // 1. Login → Token saved
  // 2. Multiple API calls → Each calls _refreshTokenIfNeeded()
  // 3. Race condition → 2 refresh calls → Token rotation → Old token revoked
  // 4. Next API → Uses old token (revoked) → 401 → logout
  //
  // Token will be refreshed on 401 error instead via AuthViewModel.

  // /// Check if JWT token is expired or expiring soon (within 5 minutes)
  // bool _isTokenExpiringSoon(String token) {
  //   ...
  // }

  // /// Proactively refresh token if expiring soon
  // Future<void> _refreshTokenIfNeeded() async {
  //   ...
  // }

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.get(path, queryParameters: queryParameters, options: options);
  }

  @override
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  @override
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  @override
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Upload a file to the server
  Future<Response> uploadFile(
    String path,
    dynamic file, {
    String fieldName = 'file',
    Map<String, dynamic>? additionalData,
    Options? options,
  }) async {
    FormData formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
      if (additionalData != null) ...additionalData,
    });

    return dio.post(
      path,
      data: formData,
      options: options,
    );
  }
}
