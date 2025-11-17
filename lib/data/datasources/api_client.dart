import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../core/services/token_storage_service.dart';
import '../../core/services/http_client_interface.dart';
import '../../app/di/service_locator.dart';

typedef OnUnauthorizedCallback = Future<void> Function();

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
          
          debugPrint('📤 [ApiClient] Request: ${options.method} ${options.path}');
          
          // CRITICAL: Do NOT add Authorization header for refresh token endpoint!
          // The refresh token endpoint only needs refreshToken in the request body,
          // not the expired access token in the Authorization header.
          // Adding expired token causes 401/400 errors from backend.
          if (options.path.contains('/auths/mobile/token/refresh')) {
            debugPrint('🔄 [ApiClient] REFRESH TOKEN REQUEST - Skipping Authorization header');
            debugPrint('🔄 [ApiClient] Request headers: ${options.headers}');
            debugPrint('🔄 [ApiClient] Request body: ${options.data}');
            debugPrint('🔄 [ApiClient] Request method: ${options.method}');
            debugPrint('🔄 [ApiClient] Request path: ${options.path}');
            debugPrint('🔄 [ApiClient] Full URL: ${options.uri}');
            return handler.next(options);
          }
          
          final token = _tokenStorageService.getAccessToken();
          if (token != null) {
            debugPrint(
              '✅ [ApiClient] Using token in request: ${token.substring(0, 15)}...',
            );
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            debugPrint('❌ [ApiClient] NO TOKEN AVAILABLE! Request will fail with 401');
          }
          
          // Check token expiry (optional - for proactive refresh)
          if (token != null && _isTokenExpiringSoon(token)) {
            debugPrint('⚠️ [ApiClient] Token expiring soon - consider proactive refresh');
          }
          
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          debugPrint('❌ DIO ERROR:');
          debugPrint('   - Type: ${e.type}');
          debugPrint('   - Message: ${e.message}');
          debugPrint('   - Status Code: ${e.response?.statusCode}');
          debugPrint('   - URL: ${e.requestOptions.path}');
          debugPrint('   - Headers: ${e.requestOptions.headers}');
          
          // Handle 401 Unauthorized errors
          if (e.response?.statusCode == 401) {
            debugPrint('🔓 401 Unauthorized - Checking if already refreshing...');
            debugPrint('🔓 Request URL: ${e.requestOptions.method} ${e.requestOptions.path}');
            debugPrint('🔓 Authorization header: ${e.requestOptions.headers['Authorization']}');
            debugPrint('🔓 Current _isRefreshing: $_isRefreshing');
            
            // CRITICAL: Use lock to prevent concurrent refresh calls
            // Check BEFORE any async operation
            if (_isRefreshing) {
              debugPrint('🔓 401 Unauthorized - Already refreshing, queuing this request');
              
              // Clean up old requests before adding new one
              _cleanupOldQueuedRequests();
              
              // Check queue size limit
              if (_requestQueue.length >= _maxQueueSize) {
                debugPrint('⚠️ Request queue full (${_requestQueue.length}/$_maxQueueSize), dropping oldest request');
                _requestQueue.removeAt(0);
              }
              
              _requestQueue.add(_QueuedRequest(
                error: e,
                timestamp: DateTime.now(),
              ));
              debugPrint('🔓 Queue size: ${_requestQueue.length}');
              return handler.next(e);
            }
            
            // Set lock IMMEDIATELY before any async operation
            _isRefreshing = true;
            debugPrint('🔓 401 Unauthorized - Setting _isRefreshing = true');
            debugPrint('🔓 401 Unauthorized - Calling refresh token callback (ONLY ONCE)');
            
            // Call the callback if it's set (callback will refresh token)
            if (_onUnauthorizedCallback != null) {
              try {
                await _onUnauthorizedCallback!();
                debugPrint('🔓 401 Unauthorized - Callback completed successfully');
                
                // After callback completes, get new token and retry the request
                final newToken = _tokenStorageService.getAccessToken();
                if (newToken != null) {
                  debugPrint('✅ [401 Retry] Got new token, retrying original request');
                  
                  // Update the request with new token
                  e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                  
                  // Retry the original request
                  try {
                    final response = await dio.fetch(e.requestOptions);
                    debugPrint('✅ [401 Retry] Request succeeded with new token');
                    _isRefreshing = false;
                    
                    // Clean up old queued requests before processing
                    _cleanupOldQueuedRequests();
                    
                    // Process queued requests
                    debugPrint('🔓 Processing ${_requestQueue.length} queued requests');
                    final queue = _requestQueue.toList();
                    _requestQueue.clear();
                    
                    for (final queuedRequest in queue) {
                      final queuedError = queuedRequest.error;
                      final age = DateTime.now().difference(queuedRequest.timestamp);
                      
                      if (age > _queueTimeout) {
                        debugPrint('⏰ Skipping queued request (timeout ${age.inSeconds}s): ${queuedError.requestOptions.method} ${queuedError.requestOptions.path}');
                        continue;
                      }
                      
                      debugPrint('🔓 Retrying queued request: ${queuedError.requestOptions.method} ${queuedError.requestOptions.path}');
                      queuedError.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                      try {
                        await dio.fetch(queuedError.requestOptions);
                      } catch (retryError) {
                        debugPrint('❌ Error retrying queued request: $retryError');
                      }
                    }
                    
                    return handler.resolve(response);
                  } catch (retryError) {
                    debugPrint('❌ [401 Retry] Request failed even with new token: $retryError');
                    _isRefreshing = false;
                    _requestQueue.clear();
                    return handler.next(e);
                  }
                } else {
                  debugPrint('❌ [401 Retry] No new token available after callback - user logged out');
                  _isRefreshing = false;
                  _requestQueue.clear();
                  return handler.next(e);
                }
              } catch (ex) {
                debugPrint('❌ Error in unauthorized callback: $ex');
                _isRefreshing = false;
                _requestQueue.clear();
                return handler.next(e);
              }
            } else {
              debugPrint('⚠️ No unauthorized callback set');
              _isRefreshing = false;
              return handler.next(e);
            }
          }
          
          return handler.next(e);
        },
        onResponse: (response, handler) {
          // debugPrint('DIO RESPONSE [${response.statusCode}]');
          return handler.next(response);
        },
      ),
    );
  }

  /// Set callback to be called when 401 Unauthorized error occurs
  void setOnUnauthorizedCallback(OnUnauthorizedCallback callback) {
    _onUnauthorizedCallback = callback;
  }

  /// Clean up old queued requests that have exceeded timeout
  void _cleanupOldQueuedRequests() {
    final now = DateTime.now();
    _requestQueue.removeWhere((queuedRequest) {
      final age = now.difference(queuedRequest.timestamp);
      final isOld = age > _queueTimeout;
      if (isOld) {
        debugPrint('🧹 Removing old queued request (age: ${age.inSeconds}s): ${queuedRequest.error.requestOptions.method} ${queuedRequest.error.requestOptions.path}');
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
      debugPrint('❌ [ApiClient] Error checking token expiry: $e');
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
