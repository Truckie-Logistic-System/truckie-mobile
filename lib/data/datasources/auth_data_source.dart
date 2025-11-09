import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors/exceptions.dart';
import 'api_client.dart';
import '../../core/services/token_storage_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/role.dart';
import '../models/auth_response_model.dart';
import '../models/token_response_model.dart';
import '../models/user_model.dart';
import '../models/role_model.dart';

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
  Future<User> refreshToken();

  /// Đổi mật khẩu
  Future<bool> changePassword(
    String username,
    String oldPassword,
    String newPassword,
    String confirmNewPassword,
  );
}

class AuthDataSourceImpl implements AuthDataSource {
  final ApiClient _apiClient;
  final SharedPreferences sharedPreferences;
  final TokenStorageService tokenStorageService;

  AuthDataSourceImpl({
    required ApiClient apiClient,
    required this.sharedPreferences,
    required this.tokenStorageService,
  }) : _apiClient = apiClient;

  @override
  Future<User> login(String username, String password) async {
    try {
      debugPrint('🔐 [login] START - Attempting login for user: $username');

      // Sử dụng endpoint mobile
      final response = await _apiClient.dio.post('/auths/mobile', data: {
        'username': username,
        'password': password,
      });

      debugPrint('🔐 [login] Response received from backend');

      if (response.data['success'] != true) {
        debugPrint('❌ [login] Login failed: ${response.data['message']}');
        throw ServerException(
          message: response.data['message'] ?? 'Đăng nhập thất bại',
          statusCode: response.statusCode ?? 400,
        );
      }

      debugPrint('✅ [login] Login successful, processing user data');
      final authResponseModel = AuthResponseModel.fromJson(response.data['data']);
      final authResponse = authResponseModel.toEntity();

      debugPrint('✅ [login] Access token: ${authResponse.authToken.substring(0, 20)}...');
      debugPrint('✅ [login] Refresh token: ${authResponse.refreshToken.substring(0, 20)}...');

      // Lưu tokens
      await tokenStorageService.saveAccessToken(authResponse.authToken);
      debugPrint('✅ [login] Access token saved to memory');
      
      await tokenStorageService.saveRefreshToken(authResponse.refreshToken);
      debugPrint('✅ [login] Refresh token saved to secure storage');

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
      debugPrint('✅ [login] User info saved to SharedPreferences');
      debugPrint('✅ [login] Login completed successfully');
      return user;
    } catch (e) {
      debugPrint('❌ [login] Login exception: ${e.toString()}');
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(message: 'Đăng nhập thất bại');
    }
  }

  @override
  Future<User> refreshToken() async {
    try {
      // debugPrint('Attempting to refresh token');

      // Lấy refresh token từ secure storage
      final refreshToken = await tokenStorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw ServerException(
          message: 'Không tìm thấy refresh token',
          statusCode: 401,
        );
      }

      // Sử dụng endpoint mobile
      debugPrint('🔄 [refreshToken] Calling /auths/mobile/token/refresh');
      debugPrint('🔄 [refreshToken] Refresh token: ${refreshToken.substring(0, 20)}...');
      
      final response = await _apiClient.dio.post('/auths/mobile/token/refresh', data: {
        'refreshToken': refreshToken,
      });

      debugPrint('🔄 [refreshToken] Response received from backend');
      debugPrint('🔄 [refreshToken] Response status: ${response.statusCode}');
      debugPrint('🔄 [refreshToken] Response data: ${response.data}');

      if (response.data['success'] == true && response.data['data'] != null) {
        final tokenData = response.data['data'];
        final newAccessToken = tokenData['accessToken'];
        
        // CRITICAL: Backend MUST return new refresh token (token rotation)
        // Do NOT fallback to old token - that would break token rotation!
        final newRefreshToken = tokenData['refreshToken'];
        
        if (newAccessToken == null || newAccessToken.isEmpty) {
          debugPrint('❌ [refreshToken] ERROR: Backend did not return new access token!');
          throw ServerException(
            message: 'Backend did not return new access token',
            statusCode: 500,
          );
        }
        
        if (newRefreshToken == null || newRefreshToken.isEmpty) {
          debugPrint('❌ [refreshToken] ERROR: Backend did not return new refresh token!');
          debugPrint('❌ [refreshToken] This breaks token rotation - old token will be revoked!');
          throw ServerException(
            message: 'Backend did not return new refresh token - token rotation failed',
            statusCode: 500,
          );
        }

        debugPrint('✅ [refreshToken] Token rotation successful');
        debugPrint('✅ [refreshToken] New access token: ${newAccessToken.substring(0, 20)}...');
        debugPrint('✅ [refreshToken] New refresh token: ${newRefreshToken.substring(0, 20)}...');

        // CRITICAL: Save both tokens FIRST - access token AND refresh token
        // This ensures we always have the latest refresh token from backend
        // Even if something fails later, tokens are already saved
        try {
          await tokenStorageService.saveAccessToken(newAccessToken);
          await tokenStorageService.saveRefreshToken(newRefreshToken);
          debugPrint('✅ [refreshToken] Tokens saved to storage');
        } catch (e) {
          debugPrint('❌ [refreshToken] ERROR saving tokens: $e');
          rethrow;
        }

        // Parse user info from backend response
        // Backend returns user info in the refresh token response
        final userData = tokenData['user'];
        if (userData != null) {
          debugPrint('✅ [refreshToken] User info found in response');
          final userModel = UserModel.fromJson(userData);
          final user = User(
            id: userModel.id,
            username: userModel.username,
            fullName: userModel.fullName,
            email: userModel.email,
            phoneNumber: userModel.phoneNumber,
            gender: userModel.gender,
            dateOfBirth: userModel.dateOfBirth,
            imageUrl: userModel.imageUrl,
            status: userModel.status,
            role: userModel.role,
            authToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          
          // Save user info to SharedPreferences
          await saveUserInfo(user);
          debugPrint('✅ [refreshToken] User info saved to SharedPreferences');
          
          return user;
        } else {
          debugPrint('⚠️ [refreshToken] No user info in response - creating minimal user');
          // Fallback: Create minimal user if backend doesn't return user info
          return User(
            id: 'temp_id',
            username: 'temp_username',
            fullName: 'Temporary User',
            email: 'temp@example.com',
            phoneNumber: '',
            gender: false,
            dateOfBirth: '',
            imageUrl: '',
            status: 'ACTIVE',
            role: Role(id: '', roleName: 'DRIVER', description: '', isActive: true),
            authToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
        }
      } else {
        throw ServerException(
          message: response.data['message'] ?? 'Làm mới token thất bại',
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ [refreshToken] DioException caught');
      debugPrint('❌ [refreshToken] Status code: ${e.response?.statusCode}');
      debugPrint('❌ [refreshToken] Response data: ${e.response?.data}');
      debugPrint('❌ [refreshToken] Error message: ${e.message}');
      
      // Handle specific error codes
      if (e.response?.statusCode == 400) {
        final errorMessage = e.response?.data['message'] ?? 'Refresh token không hợp lệ';
        debugPrint('❌ [refreshToken] 400 Bad Request: $errorMessage');
        throw ServerException(
          message: errorMessage,
          statusCode: 400,
        );
      } else if (e.response?.statusCode == 401) {
        debugPrint('❌ [refreshToken] 401 Unauthorized: Refresh token đã hết hạn hoặc bị thu hồi');
        throw ServerException(
          message: 'Refresh token đã hết hạn hoặc bị thu hồi',
          statusCode: 401,
        );
      }
      
      throw ServerException(
        message: e.response?.data['message'] ?? 'Làm mới token thất bại',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      debugPrint('❌ [refreshToken] Unexpected error: ${e.toString()}');
      if (e is ServerException) {
        rethrow;
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
      // debugPrint('Attempting to change password for user: $username');

      final response = await _apiClient.dio.put('/auths/change-password', data: {
        'username': username,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      });

      // debugPrint('Change password response received: $response');

      if (response.data['success'] == true) {
        return true;
      } else {
        throw ServerException(
          message: response.data['message'] ?? 'Đổi mật khẩu thất bại',
        );
      }
    } catch (e) {
      // debugPrint('Change password exception: ${e.toString()}');
      if (e is ServerException) {
        rethrow;
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
      final response = await _apiClient.dio.post('/auths/mobile/logout', data: {
        'refreshToken': refreshToken ?? '',
      });

      if (!response.data['success']) {
        // debugPrint('Logout failed: ${response.data['message']}');
        throw ServerException(
          message: response.data['message'] ?? 'Không thể làm mới token',
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
        rethrow;
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
      final userModel = UserModel.fromJson(userMap);
      return userModel.toEntity();
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
      
      // Convert User entity to UserModel for serialization
      final userModel = UserModel(
        id: user.id,
        username: user.username,
        fullName: user.fullName,
        email: user.email,
        phoneNumber: user.phoneNumber,
        gender: user.gender,
        dateOfBirth: user.dateOfBirth,
        imageUrl: user.imageUrl,
        status: user.status,
        role: RoleModel.fromEntity(user.role),
        authToken: user.authToken,
        refreshToken: user.refreshToken,
      );

      await sharedPreferences.setString('user_info', json.encode(userModel.toJson()));
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
