import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/token_storage_service.dart';
import '../../core/services/service_locator.dart';

class ApiClient {
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
            debugPrint(
              'Using token in ApiClient: ${token.substring(0, 15)}...',
            );
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          debugPrint('DIO ERROR: ${e.message}');
          return handler.next(e);
        },
        onResponse: (response, handler) {
          debugPrint('DIO RESPONSE [${response.statusCode}]');
          return handler.next(response);
        },
      ),
    );
  }
}
