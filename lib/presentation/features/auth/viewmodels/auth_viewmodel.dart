import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../domain/entities/driver.dart';
import '../../../../domain/entities/role.dart';
import '../../../../domain/entities/user.dart';
import '../../../../domain/usecases/auth/get_driver_info_usecase.dart';
import '../../../../domain/usecases/auth/login_usecase.dart';
import '../../../../domain/usecases/auth/logout_usecase.dart';
import '../../../../domain/usecases/auth/refresh_token_usecase.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthViewModel extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final GetDriverInfoUseCase? _getDriverInfoUseCase;

  AuthStatus _status = AuthStatus.initial;
  User? _user = null;
  Driver? _driver = null;
  String _errorMessage = '';
  bool _isRefreshing = false;

  AuthViewModel({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
    GetDriverInfoUseCase? getDriverInfoUseCase,
  }) : _loginUseCase = loginUseCase,
       _logoutUseCase = logoutUseCase,
       _refreshTokenUseCase = refreshTokenUseCase,
       _getDriverInfoUseCase = getDriverInfoUseCase {
    // Kiểm tra trạng thái đăng nhập khi khởi tạo
    checkAuthStatus();
  }

  AuthStatus get status => _status;
  User? get user => _user;
  Driver? get driver => _driver;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isRefreshing => _isRefreshing;

  Future<bool> login(String username, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = '';
    notifyListeners();

    final params = LoginParams(username: username, password: password);
    final result = await _loginUseCase(params);

    return result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (user) async {
        _user = user;
        // Keep loading status until driver info is fetched
        notifyListeners();

        // Fetch driver information if available
        if (_getDriverInfoUseCase != null && user.role.roleName == 'DRIVER') {
          await _fetchDriverInfo(user.id);
        }

        // Now set authenticated status
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> _fetchDriverInfo(String userId) async {
    if (_getDriverInfoUseCase == null) return;

    final result = await _getDriverInfoUseCase!(
      GetDriverInfoParams(userId: userId),
    );

    result.fold(
      (failure) {
        debugPrint('Failed to fetch driver info: ${failure.message}');
      },
      (driver) {
        _driver = driver;
        notifyListeners();
      },
    );
  }

  Future<bool> logout() async {
    // Không đặt trạng thái loading để tránh hiển thị thông báo trung gian
    // _status = AuthStatus.loading;
    // notifyListeners();

    final result = await _logoutUseCase(NoParams());

    return result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        // Reset data
        _user = null;
        _driver = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> refreshToken() async {
    if (_isRefreshing) return false;

    _isRefreshing = true;
    notifyListeners();

    final result = await _refreshTokenUseCase(NoParams());

    return result.fold(
      (failure) {
        _isRefreshing = false;
        _status = AuthStatus.unauthenticated;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (tokenResponse) async {
        _isRefreshing = false;

        // Cập nhật token trong user
        if (_user != null) {
          _user = User(
            id: _user!.id,
            username: _user!.username,
            fullName: _user!.fullName,
            email: _user!.email,
            phoneNumber: _user!.phoneNumber,
            gender: _user!.gender,
            dateOfBirth: _user!.dateOfBirth,
            imageUrl: _user!.imageUrl,
            status: _user!.status,
            role: _user!.role,
            authToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
          );
        }

        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      },
    );
  }

  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // Check if user is logged in by retrieving stored token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userJson = prefs.getString('user_info');

      if (token == null || token.isEmpty || userJson == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // Parse stored user info
      try {
        final userMap = json.decode(userJson);
        _user = User.fromJson(userMap);
        _status = AuthStatus.authenticated;

        // Fetch driver information if user is a driver
        if (_getDriverInfoUseCase != null && _user!.role.roleName == 'DRIVER') {
          await _fetchDriverInfo(_user!.id);
        }
      } catch (e) {
        debugPrint('Error parsing stored user info: $e');
        _status = AuthStatus.unauthenticated;
        await _clearUserData();
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Không thể lấy thông tin người dùng';
    }

    notifyListeners();
  }

  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_info');
  }

  // Xử lý lỗi token hết hạn
  Future<bool> handleTokenExpired() async {
    return await refreshToken();
  }

  // Update driver info in the view model (not calling API)
  void updateDriverInfo(Driver updatedDriver) {
    _driver = updatedDriver;
    notifyListeners();
  }
}
