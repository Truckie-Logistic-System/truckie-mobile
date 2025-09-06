import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/exceptions.dart';
import '../../core/services/api_service.dart';
import '../../domain/entities/auth_response.dart';
import '../../domain/entities/token_response.dart';
import '../../domain/entities/user.dart';

abstract class AuthDataSource {
  /// Đăng nhập với tên đăng nhập và mật khẩu
  Future<User> login(String username, String password);

  /// Đăng xuất
  Future<bool> logout();

  /// Kiểm tra trạng thái đăng nhập
  Future<bool> isLoggedIn();

  /// Lấy thông tin người dùng hiện tại
  Future<User> getCurrentUser();

  /// Lưu thông tin người dùng
  Future<void> saveUserInfo(User user);

  /// Xóa thông tin người dùng
  Future<void> clearUserInfo();

  /// Refresh token
  Future<TokenResponse> refreshToken(String refreshToken);
}

class AuthDataSourceImpl implements AuthDataSource {
  final ApiService apiService;
  final SharedPreferences sharedPreferences;

  AuthDataSourceImpl({
    required this.apiService,
    required this.sharedPreferences,
  });

  @override
  Future<User> login(String username, String password) async {
    try {
      debugPrint('Attempting login for user: $username');

      // Đảm bảo endpoint đúng theo API
      final response = await apiService.post('/auths', {
        'username': username,
        'password': password,
      });

      debugPrint('Login response received: $response');

      if (!response['success']) {
        debugPrint('Login failed: ${response['message']}');
        throw ServerException(
          message: response['message'] ?? 'Đăng nhập thất bại',
          statusCode: response['statusCode'] ?? 400,
        );
      }

      debugPrint('Login successful, processing user data');
      final authResponse = AuthResponse.fromJson(response['data']);
      final user = User(
        id: authResponse.user.id,
        username: authResponse.user.username,
        fullName: authResponse.user.fullName,
        email: authResponse.user.email,
        phoneNumber: authResponse.user.phoneNumber,
        gender: authResponse.user.gender,
        dateOfBirth: authResponse.user.dateOfBirth,
        imageUrl: authResponse.user.imageUrl,
        status: authResponse.user.status,
        role: authResponse.user.role,
        authToken: authResponse.authToken,
        refreshToken: authResponse.refreshToken,
      );

      await saveUserInfo(user);
      return user;
    } catch (e) {
      debugPrint('Login exception: ${e.toString()}');
      if (e is ServerException) {
        throw e;
      }
      throw ServerException(message: 'Đăng nhập thất bại: ${e.toString()}');
    }
  }

  @override
  Future<TokenResponse> refreshToken(String refreshToken) async {
    try {
      debugPrint('Attempting to refresh token');

      final response = await apiService.post('/auths/token/refresh', {
        'refreshToken': refreshToken,
      });

      debugPrint('Refresh token response received: $response');

      if (!response['success']) {
        debugPrint('Refresh token failed: ${response['message']}');
        throw ServerException(
          message: response['message'] ?? 'Làm mới token thất bại',
          statusCode: response['statusCode'] ?? 400,
        );
      }

      final tokenResponse = TokenResponse.fromJson(response['data']);

      // Cập nhật token trong SharedPreferences
      await sharedPreferences.setString(
        'auth_token',
        tokenResponse.accessToken,
      );
      await sharedPreferences.setString(
        'refresh_token',
        tokenResponse.refreshToken,
      );

      // Cập nhật token trong thông tin người dùng
      final userJson = sharedPreferences.getString('user_info');
      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        userMap['authToken'] = tokenResponse.accessToken;
        userMap['refreshToken'] = tokenResponse.refreshToken;
        await sharedPreferences.setString('user_info', json.encode(userMap));
      }

      return tokenResponse;
    } catch (e) {
      debugPrint('Refresh token exception: ${e.toString()}');
      if (e is ServerException) {
        throw e;
      }
      throw ServerException(message: 'Làm mới token thất bại: ${e.toString()}');
    }
  }

  @override
  Future<bool> logout() async {
    try {
      await clearUserInfo();
      return true;
    } catch (e) {
      throw CacheException(message: 'Đăng xuất thất bại: ${e.toString()}');
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final token = sharedPreferences.getString('auth_token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<User> getCurrentUser() async {
    try {
      final userJson = sharedPreferences.getString('user_info');
      if (userJson == null) {
        throw CacheException(message: 'Không tìm thấy thông tin người dùng');
      }

      final userMap = json.decode(userJson);
      return User.fromJson(userMap);
    } catch (e) {
      throw CacheException(
        message: 'Lấy thông tin người dùng thất bại: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> saveUserInfo(User user) async {
    try {
      await sharedPreferences.setString('auth_token', user.authToken);
      await sharedPreferences.setString('refresh_token', user.refreshToken);

      final userMap = {
        'id': user.id,
        'username': user.username,
        'fullName': user.fullName,
        'email': user.email,
        'phoneNumber': user.phoneNumber,
        'gender': user.gender,
        'dateOfBirth': user.dateOfBirth,
        'imageUrl': user.imageUrl,
        'status': user.status,
        'role': {
          'id': user.role.id,
          'roleName': user.role.roleName,
          'description': user.role.description,
          'isActive': user.role.isActive,
        },
        'authToken': user.authToken,
        'refreshToken': user.refreshToken,
      };

      await sharedPreferences.setString('user_info', json.encode(userMap));
    } catch (e) {
      throw CacheException(
        message: 'Lưu thông tin người dùng thất bại: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> clearUserInfo() async {
    try {
      await sharedPreferences.remove('auth_token');
      await sharedPreferences.remove('refresh_token');
      await sharedPreferences.remove('user_info');
    } catch (e) {
      throw CacheException(
        message: 'Xóa thông tin người dùng thất bại: ${e.toString()}',
      );
    }
  }
}
