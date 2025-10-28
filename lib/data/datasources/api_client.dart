import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/token_storage_service.dart';
import '../../core/services/http_client_interface.dart';
import '../../app/di/service_locator.dart';

class ApiClient implements IHttpClient {
  final String baseUrl;
  late final Dio dio;
  late final TokenStorageService _tokenStorageService;

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
          final token = _tokenStorageService.getAccessToken();
          if (token != null) {
            // debugPrint(
            //   'Using token in ApiClient: ${token.substring(0, 15)}...',
            // );
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          debugPrint('DIO ERROR: ${e.message}');
          return handler.next(e);
        },
        onResponse: (response, handler) {
          // debugPrint('DIO RESPONSE [${response.statusCode}]');
          return handler.next(response);
        },
      ),
    );
  }

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
