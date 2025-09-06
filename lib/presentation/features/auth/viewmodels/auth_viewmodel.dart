import 'package:flutter/material.dart';

import '../../../../domain/entities/role.dart';
import '../../../../domain/entities/user.dart';
import '../../../../domain/usecases/auth/login_usecase.dart';
import '../../../../domain/usecases/auth/logout_usecase.dart';
import '../../../../domain/usecases/auth/refresh_token_usecase.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthViewModel extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String _errorMessage = '';
  bool _isRefreshing = false;

  AuthViewModel({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
  }) : _loginUseCase = loginUseCase,
       _logoutUseCase = logoutUseCase,
       _refreshTokenUseCase = refreshTokenUseCase {
    // Kiểm tra trạng thái đăng nhập khi khởi tạo
    checkAuthStatus();
  }

  AuthStatus get status => _status;
  User? get user => _user;
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
      (user) {
        _status = AuthStatus.authenticated;
        _user = user;
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final result = await _logoutUseCase(NoParams());

    return result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _status = AuthStatus.unauthenticated;
        _user = null;
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
      // Giả lập dữ liệu người dùng cho mục đích demo
      await Future.delayed(const Duration(seconds: 1));

      // Tạo dữ liệu người dùng mẫu
      final role = Role(
        id: 'R002',
        roleName: 'Tài xế',
        description: 'Tài xế giao hàng',
        isActive: true,
      );

      _user = User(
        id: 'TX001',
        username: 'driver1',
        fullName: 'Nguyễn Văn A',
        email: 'driver1@truckie.com',
        phoneNumber: '0987654321',
        gender: true,
        dateOfBirth: '1990-01-01',
        imageUrl: '',
        status: 'Đang hoạt động',
        role: role,
        authToken: 'sample_auth_token',
        refreshToken: 'sample_refresh_token',
      );

      _status = AuthStatus.authenticated;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Không thể lấy thông tin người dùng';
    }

    notifyListeners();
  }

  // Xử lý lỗi token hết hạn
  Future<bool> handleTokenExpired() async {
    return await refreshToken();
  }
}
