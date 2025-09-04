import 'package:flutter/material.dart';

import '../../../../domain/entities/role.dart';
import '../../../../domain/entities/user.dart';
import '../../../../domain/usecases/auth/login_usecase.dart';
import '../../../../domain/usecases/auth/logout_usecase.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthViewModel extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String _errorMessage = '';

  AuthViewModel({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
  }) : _loginUseCase = loginUseCase,
       _logoutUseCase = logoutUseCase {
    // Kiểm tra trạng thái đăng nhập khi khởi tạo
    checkAuthStatus();
  }

  AuthStatus get status => _status;
  User? get user => _user;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

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
}
