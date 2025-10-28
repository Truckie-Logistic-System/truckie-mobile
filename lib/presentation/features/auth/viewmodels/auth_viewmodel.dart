import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../../data/models/user_model.dart';
import '../../../../domain/entities/driver.dart';
import '../../../../domain/entities/role.dart';
import '../../../../domain/entities/user.dart';
import '../../../../domain/usecases/auth/get_driver_info_usecase.dart';
import '../../../../domain/usecases/auth/login_usecase.dart';
import '../../../../domain/usecases/auth/logout_usecase.dart';
import '../../../../domain/usecases/auth/refresh_token_usecase.dart';
import '../../../../app/app_routes.dart';
import '../../../../app/di/service_locator.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../../common_widgets/base_viewmodel.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthViewModel extends BaseViewModel {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final GetDriverInfoUseCase? _getDriverInfoUseCase;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  Driver? _driver;
  String _errorMessage = '';
  bool _isRefreshing = false;

  // Static instance to handle hot reload
  static AuthViewModel? _instance;

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
    if (_instance == null) {
      _instance = this;
      checkAuthStatus();
    } else {
      // Copy state from existing instance
      _status = _instance!._status;
      _user = _instance!._user;
      _driver = _instance!._driver;
      _errorMessage = _instance!._errorMessage;
      _isRefreshing = _instance!._isRefreshing;
    }
  }

  AuthStatus get status => _status;
  User? get user => _user;
  Driver? get driver => _driver;
  String get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isRefreshing => _isRefreshing;

  // Setter cho status để thêm logic chuyển hướng
  set status(AuthStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  // Setter cho status với chuyển hướng
  void setStatusWithNavigation(AuthStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;

      // Nếu trạng thái thay đổi thành authenticated và có navigatorKey
      if (_status == AuthStatus.authenticated &&
          navigatorKey?.currentState != null) {
        // debugPrint(
        //   'Auth status changed to authenticated, navigating to main screen',
        // );
        navigatorKey!.currentState!.pushNamedAndRemoveUntil(
          AppRoutes.main,
          (route) => false,
        );
      }
      // Nếu trạng thái thay đổi thành unauthenticated và có navigatorKey
      else if (_status == AuthStatus.unauthenticated &&
          navigatorKey?.currentState != null) {
        // debugPrint(
        //   'Auth status changed to unauthenticated, navigating to login screen',
        // );
        navigatorKey!.currentState!.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
      }

      notifyListeners();
    }
  }

  // GlobalKey để điều hướng mà không cần context
  static GlobalKey<NavigatorState>? navigatorKey;

  // Đặt navigatorKey
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  Future<bool> login(String username, String password) async {
    status = AuthStatus.loading;
    _errorMessage = '';

    final params = LoginParams(username: username, password: password);
    final result = await _loginUseCase(params);

    return result.fold(
      (failure) {
        status = AuthStatus.error;
        _errorMessage = failure.message;
        return false;
      },
      (user) async {
        _user = user;
        // Keep loading status until driver info is fetched
        notifyListeners();

        // Fetch driver information if available
        if (_getDriverInfoUseCase != null && user.role.roleName == 'DRIVER') {
          await _fetchDriverInfo();
        }

        // Now set authenticated status with navigation
        setStatusWithNavigation(AuthStatus.authenticated);
        return true;
      },
    );
  }

  Future<void> _fetchDriverInfo() async {
    if (_getDriverInfoUseCase == null) return;

    final result = await _getDriverInfoUseCase(const GetDriverInfoParams());

    result.fold(
      (failure) async {
        // debugPrint('Failed to fetch driver info: ${failure.message}');

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          // debugPrint('Token refreshed, retrying to fetch driver info...');
          await _fetchDriverInfo();
        }
      },
      (driver) {
        _driver = driver;
        notifyListeners();
      },
    );
  }

  /// Refresh driver information from the server
  Future<bool> refreshDriverInfo() async {
    if (_getDriverInfoUseCase == null) return false;

    final result = await _getDriverInfoUseCase(const GetDriverInfoParams());

    return result.fold(
      (failure) async {
        // debugPrint('Failed to refresh driver info: ${failure.message}');

        // Sử dụng handleUnauthorizedError từ BaseViewModel
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          // Nếu refresh token thành công, thử lại
          // debugPrint('Token refreshed, retrying to get driver info...');
          return await refreshDriverInfo();
        }

        return false;
      },
      (driver) {
        _driver = driver;
        notifyListeners();
        return true;
      },
    );
  }

  /// Logs out the user by clearing local data and calling the logout API
  /// Returns true if local data was cleared successfully, regardless of API result
  Future<bool> logout() async {
    try {
      // First clear local data
      await _clearUserData();

      // Update state
      _user = null;
      _driver = null;
      setStatusWithNavigation(AuthStatus.unauthenticated);

      try {
        // Then try to call the logout API, but don't wait for it
        _logoutUseCase(NoParams())
            .then((result) {
              result.fold(
                (failure) {
                  // debugPrint('Logout API error: ${failure.message}');
                },
                (_) {
                  // debugPrint('Logout API success');
                },
              );
            })
            .catchError((e) {
              // debugPrint('Error during logout API call: $e');
            });
      } catch (e) {
        // debugPrint('Error initiating logout API call: $e');
      }

      return true;
    } catch (e) {
      // debugPrint('Error during logout: $e');
      return false;
    }
  }

  Future<bool> refreshToken() async {
    if (_isRefreshing) return false;

    _isRefreshing = true;
    notifyListeners();

    final result = await _refreshTokenUseCase(NoParams());

    return result.fold(
      (failure) {
        _isRefreshing = false;
        status = AuthStatus.unauthenticated;
        _errorMessage = failure.message;
        return false;
      },
      (tokenResponse) async {
        _isRefreshing = false;

        // Cập nhật token trong user
        if (_user != null) {
          _user = tokenResponse;
        }

        status = AuthStatus.authenticated;
        return true;
      },
    );
  }

  /// Force refresh token khi cần thiết
  Future<bool> forceRefreshToken() async {
    // debugPrint('Force refreshing token...');

    // Đánh dấu đang refresh để tránh gọi nhiều lần
    _isRefreshing = true;
    notifyListeners();

    final result = await _refreshTokenUseCase(NoParams());

    return result.fold(
      (failure) {
        _isRefreshing = false;
        // debugPrint('Force refresh token failed: ${failure.message}');
        return false;
      },
      (tokenResponse) async {
        _isRefreshing = false;

        // Cập nhật token trong user
        if (_user != null) {
          final oldToken = _user!.authToken;
          _user = tokenResponse;

          // debugPrint(
          //   'Token updated from ${oldToken.substring(0, 15)}... to ${tokenResponse.authToken.substring(0, 15)}...',
          // );

          // Lưu thông tin người dùng vào SharedPreferences
          try {
            final prefs = await SharedPreferences.getInstance();
            final userModel = UserModel(
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
              authToken: _user!.authToken,
              refreshToken: _user!.refreshToken,
            );
            final userJson = json.encode(userModel.toJson());
            await prefs.setString('user_info', userJson);
            // debugPrint(
            //   'User info saved to SharedPreferences after force refresh token',
            // );
          } catch (e) {
            // debugPrint('Error saving user info to SharedPreferences: $e');
          }
        }

        // Tải lại thông tin tài xế
        await refreshDriverInfo();

        return true;
      },
    );
  }

  Future<void> checkAuthStatus() async {
    status = AuthStatus.loading;

    try {
      // Check if user is logged in by retrieving stored user info
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_info');

      if (userJson == null) {
        status = AuthStatus.unauthenticated;
        return;
      }

      // Parse stored user info
      try {
        final userMap = json.decode(userJson);
        final userModel = UserModel.fromJson(userMap);
        _user = userModel.toEntity();
        
        // CRITICAL: Load access token vào TokenStorageService ngay khi restore user
        // Điều này đảm bảo TokenStorageService có token ngay từ đầu
        await _loadTokenToStorage();

        // Fetch driver information if user is a driver BEFORE setting authenticated status
        // This ensures driver info is available when UI needs to check primary driver
        if (_getDriverInfoUseCase != null && _user!.role.roleName == 'DRIVER') {
          await _fetchDriverInfo();
        }
        
        status = AuthStatus.authenticated;
      } catch (e) {
        // debugPrint('Error parsing stored user info: $e');
        status = AuthStatus.unauthenticated;
        await _clearUserData();
      }
    } catch (e) {
      // debugPrint('Error checking auth status: $e');
      status = AuthStatus.unauthenticated;
      _errorMessage = 'Không thể lấy thông tin người dùng';
    }
  }

  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_info');
      // Tokens sẽ được xóa bởi AuthDataSource thông qua TokenStorageService
    } catch (e) {
      // debugPrint('Error clearing user data: $e');
    }
  }

  /// Load access token từ user vào TokenStorageService
  /// Được gọi khi restore user từ SharedPreferences để đảm bảo
  /// TokenStorageService có token ngay từ đầu
  Future<void> _loadTokenToStorage() async {
    if (_user != null && _user!.authToken.isNotEmpty) {
      try {
        final tokenStorage = getIt<TokenStorageService>();
        await tokenStorage.saveAccessToken(_user!.authToken);
        // debugPrint(
        //   'Loaded access token to storage: ${_user!.authToken.substring(0, 15)}...',
        // );
      } catch (e) {
        // debugPrint('Error loading token to storage: $e');
      }
    }
  }

  // Xử lý lỗi token hết hạn
  Future<bool> handleTokenExpired() async {
    return await refreshToken();
  }

  // Xử lý khi token đã được làm mới thành công từ bên ngoài
  Future<void> handleTokenRefreshed(String newAccessToken) async {
    // debugPrint(
    //   'handleTokenRefreshed called with token: ${newAccessToken.substring(0, 15)}...',
    // );

    if (_user != null) {
      // debugPrint(
      //   'Updating user token from: ${_user!.authToken.substring(0, 15)}... to: ${newAccessToken.substring(0, 15)}...',
      // );

      // Cập nhật token trong user
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
        authToken: newAccessToken,
      );

      // Lưu thông tin người dùng vào SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final userModel = UserModel(
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
          authToken: _user!.authToken,
          refreshToken: _user!.refreshToken,
        );
        final userJson = json.encode(userModel.toJson());
        await prefs.setString('user_info', userJson);
        // debugPrint('User info saved to SharedPreferences after token refresh');

        // Kiểm tra xem đã lưu thành công chưa
        final savedJson = prefs.getString('user_info');
        if (savedJson != null) {
          final savedUserModel = UserModel.fromJson(json.decode(savedJson));
          final savedUser = savedUserModel.toEntity();
          if (savedUser.authToken != newAccessToken) {
            // debugPrint('WARNING: Token mismatch in SharedPreferences!');
          } else {
            // debugPrint('Token verified in SharedPreferences');
          }
        }
      } catch (e) {
        // debugPrint('Error saving user info to SharedPreferences: $e');
      }
    } else {
      // debugPrint(
      //   'Cannot update token: user is null. Creating new user with token',
      // );

      // Tạo user mới với token nếu user hiện tại là null
      _user = User(
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
      );

      // Lưu user tạm thời vào SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final userModel = UserModel(
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
          authToken: _user!.authToken,
          refreshToken: _user!.refreshToken,
        );
        await prefs.setString('user_info', json.encode(userModel.toJson()));
      } catch (e) {
        // debugPrint('Error saving temporary user: $e');
      }
    }

    // Đặt trạng thái đã xác thực
    status = AuthStatus.authenticated;

    // Cập nhật thông tin tài xế nếu cần
    if (_getDriverInfoUseCase != null && _user?.role.roleName == 'DRIVER') {
      await _fetchDriverInfo();
    }
  }

  // Update driver info in the view model (not calling API)
  void updateDriverInfo(Driver updatedDriver) {
    _driver = updatedDriver;
    notifyListeners();
  }

  // Reset error state
  void resetErrorState() {
    if (_status == AuthStatus.error) {
      _status = AuthStatus.initial;
      _errorMessage = '';
      notifyListeners();
    }
  }

  // Reset the view model for hot reload
  static void resetInstance() {
    _instance = null;
  }
}
