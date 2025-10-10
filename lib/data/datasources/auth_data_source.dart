import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/exceptions.dart';
import '../../core/services/api_service.dart';
import '../../core/services/token_storage_service.dart';
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
  Future<TokenResponse> refreshToken();

  /// Đổi mật khẩu
  Future<bool> changePassword(
    String username,
    String oldPassword,
    String newPassword,
    String confirmNewPassword,
  );
}

class AuthDataSourceImpl implements AuthDataSource {
  final ApiService apiService;
  final SharedPreferences sharedPreferences;
  final TokenStorageService tokenStorageService;

  AuthDataSourceImpl({
    required this.apiService,
    required this.sharedPreferences,
    required this.tokenStorageService,
  });

  @override
  Future<User> login(String username, String password) async {
    try {
      debugPrint('Attempting login for user: $username');

      // Sử dụng endpoint mobile
      final response = await apiService.post('/auths/mobile', {
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
      
      // Lưu tokens
      await tokenStorageService.saveAccessToken(authResponse.authToken);
      await tokenStorageService.saveRefreshToken(authResponse.refreshToken);
      
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
      );

      await saveUserInfo(user);
      return user;
    } catch (e) {
      debugPrint('Login exception: ${e.toString()}');
      if (e is ServerException) {
        throw e;
      }
      throw ServerException(message: 'Đăng nhập thất bại');
    }
  }

  @override
  Future<TokenResponse> refreshToken() async {
    try {
      debugPrint('Attempting to refresh token');

      // Lấy refresh token từ secure storage
      final refreshToken = await tokenStorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw ServerException(
          message: 'Không tìm thấy refresh token',
          statusCode: 401,
        );
      }

      // Sử dụng endpoint mobile
      final response = await apiService.post('/auths/mobile/token/refresh', {
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

      // Lưu access token mới vào memory
      await tokenStorageService.saveAccessToken(tokenResponse.accessToken);

      // Cập nhật token trong thông tin người dùng
      final userJson = sharedPreferences.getString('user_info');
      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        userMap['authToken'] = tokenResponse.accessToken;
        await sharedPreferences.setString('user_info', json.encode(userMap));
      }

      return tokenResponse;
    } catch (e) {
      debugPrint('Refresh token exception: ${e.toString()}');
      if (e is ServerException) {
        throw e;
      }
      throw ServerException(message: 'Làm mới token thất bại');
    }
  }

  @override
  Future<bool> changePassword(
    String username,
    String oldPassword,
    String newPassword,
    String confirmNewPassword,
  ) async {
    try {
      debugPrint('Attempting to change password for user: $username');

      final response = await apiService.put('/auths/change-password', {
        'username': username,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      });

      debugPrint('Change password response received: $response');

      if (!response['success']) {
        debugPrint('Change password failed: ${response['message']}');
        throw ServerException(
          message: response['message'] ?? 'Đổi mật khẩu thất bại',
          statusCode: response['statusCode'] ?? 400,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Change password exception: ${e.toString()}');
      if (e is ServerException) {
        throw e;
      }
      throw ServerException(message: 'Đổi mật khẩu thất bại');
    }
  }

  @override
  Future<bool> logout() async {
    try {
      // Lấy refresh token để gửi lên server
      final refreshToken = await tokenStorageService.getRefreshToken();
      
      // Call the logout API endpoint với refresh token
      final response = await apiService.post('/auths/mobile/logout', {
        'refreshToken': refreshToken ?? '',
      });

      if (!response['success']) {
        debugPrint('Logout failed: ${response['message']}');
        throw ServerException(
          message: response['message'] ?? 'Đăng xuất thất bại',
          statusCode: response['statusCode'] ?? 400,
        );
      }

      // Clear local storage regardless of API response
      await clearUserInfo();
      return true;
    } catch (e) {
      // Try to clear local storage even if API call fails
      try {
        await clearUserInfo();
      } catch (_) {
        // Ignore any errors when clearing user info
      }

      if (e is ServerException) {
        throw e;
      }
      throw ServerException(message: 'Đăng xuất thất bại: ${e.toString()}');
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      // Kiểm tra access token trong memory hoặc refresh token trong secure storage
      final hasAccessToken = tokenStorageService.hasAccessToken();
      final hasRefreshToken = await tokenStorageService.hasRefreshToken();
      return hasAccessToken || hasRefreshToken;
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
      // Access token đã được lưu trong TokenStorageService khi login
      // Chỉ cần lưu thông tin user vào SharedPreferences
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
      // Xóa tokens từ TokenStorageService
      await tokenStorageService.clearAllTokens();
      
      // Xóa thông tin user từ SharedPreferences
      await sharedPreferences.remove('auth_token');
      await sharedPreferences.remove('user_info');
    } catch (e) {
      throw CacheException(
        message: 'Xóa thông tin người dùng thất bại: ${e.toString()}',
      );
    }
  }
}
