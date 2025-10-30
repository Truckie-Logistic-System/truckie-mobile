import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../../core/services/token_storage_service.dart';
import '../../core/services/http_client_interface.dart';
import '../../app/di/service_locator.dart';

typedef OnUnauthorizedCallback = Future<void> Function();

class ApiClient implements IHttpClient {
  final String baseUrl;
  late final Dio dio;
  late final TokenStorageService _tokenStorageService;
  OnUnauthorizedCallback? _onUnauthorizedCallback;
  bool _isRefreshing = false; // Lock to prevent concurrent refresh calls
  List<DioException> _requestQueue = []; // Queue to hold 401 errors while refreshing

  ApiClient({required this.baseUrl}) {
    _tokenStorageService = getIt<TokenStorageService>();

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
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
          
          final token = _tokenStorageService.getAccessToken();
          if (token != null) {
            debugPrint(
              '✅ [ApiClient] Using token in request: ${token.substring(0, 15)}...',
            );
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            debugPrint('❌ [ApiClient] NO TOKEN AVAILABLE! Request will fail with 401');
          }
          debugPrint('📤 [ApiClient] Request: ${options.method} ${options.path}');
          if (options.path == '/auths/mobile/token/refresh') {
            debugPrint('📤 [ApiClient] REFRESH TOKEN REQUEST - Token: ${token?.substring(0, 15) ?? "NULL"}...');
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
              _requestQueue.add(e);
              debugPrint('🔓 Queue size: ${_requestQueue.length}');
              return handler.next(e);
            }
            
            // Set lock IMMEDIATELY before any async operation
            _isRefreshing = true;
            debugPrint('🔓 401 Unauthorized - Setting _isRefreshing = true');
            debugPrint('🔓 401 Unauthorized - Calling logout callback (ONLY ONCE)');
            
            // Call the callback if it's set
            if (_onUnauthorizedCallback != null) {
              try {
                await _onUnauthorizedCallback!();
                debugPrint('🔓 401 Unauthorized - Callback completed successfully');
              } catch (ex) {
                debugPrint('❌ Error in unauthorized callback: $ex');
              }
            }
            
            _isRefreshing = false;
            debugPrint('🔓 401 Unauthorized - Setting _isRefreshing = false');
            
            // Process queued requests
            debugPrint('🔓 401 Unauthorized - Processing ${_requestQueue.length} queued requests');
            final queue = _requestQueue.toList();
            _requestQueue.clear();
            
            for (final queuedError in queue) {
              debugPrint('🔓 Processing queued request: ${queuedError.requestOptions.method} ${queuedError.requestOptions.path}');
              // Just pass through - they will be retried with new token
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
}
