import 'package:flutter/material.dart';

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
       _logoutUseCase = logoutUseCase;

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

  void checkAuthStatus() {
    // TODO: Kiểm tra trạng thái đăng nhập từ local storage
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
