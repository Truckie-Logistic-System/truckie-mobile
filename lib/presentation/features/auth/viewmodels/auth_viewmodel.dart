import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import '../../../../data/models/user_model.dart';
import '../../../../data/models/role_model.dart';
import '../../../../data/datasources/api_client.dart';
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
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/chat_notification_service.dart';
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
  Completer<bool>? _refreshCompleter;

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
      _setupUnauthorizedCallback();
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
      if (_status == AuthStatus.authenticated) {
        _navigateWhenReady(AppRoutes.main);
      }
      // Nếu trạng thái thay đổi thành unauthenticated và có navigatorKey
      else if (_status == AuthStatus.unauthenticated) {
        _navigateWhenReady(AppRoutes.login);
      }

      notifyListeners();
    } else {}
  }

  /// Navigate when navigator is ready (with retry mechanism)
  void _navigateWhenReady(String route) async {
    int attempts = 0;
    const maxAttempts = 10;
    const delayMs = 100;

    while (attempts < maxAttempts) {
      if (navigatorKey?.currentState != null) {
        navigatorKey!.currentState!.pushNamedAndRemoveUntil(
          route,
          (route) => false,
        );
        return;
      }

      attempts++;

      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }

  // GlobalKey để điều hướng mà không cần context
  static GlobalKey<NavigatorState>? navigatorKey;

  // Đặt navigatorKey
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  // Store password temporarily for onboarding flow
  String? _tempPasswordForOnboarding;
  String? get tempPasswordForOnboarding => _tempPasswordForOnboarding;

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
        notifyListeners();

        // Check if driver needs onboarding (first-time login)
        if (user.needsOnboarding) {
          // Store password for onboarding screen
          _tempPasswordForOnboarding = password;
          
          // Navigate to onboarding screen instead of main
          _navigateToOnboarding(password);
          return true;
        }

        // Clear temp password if not needed
        _tempPasswordForOnboarding = null;

        // CRITICAL: Don't fetch driver info immediately after login!
        // This can cause API failures which trigger token refresh,
        // and the new token gets revoked by the backend's token rotation.
        // Driver info will be fetched on-demand when needed.

        // CRITICAL FIX: Set authenticated status FIRST to trigger navigation
        // Then connect to WebSocket AFTER MaterialApp has mounted
        // This ensures navigatorKey.currentContext is ready when notifications arrive
        _status = AuthStatus.loading;
        setStatusWithNavigation(AuthStatus.authenticated);

        // Wait for navigation to complete, then connect WebSocket
        // This prevents dialog timing issues on first app launch
        _connectNotificationService();

        return true;
      },
    );
  }

  /// Navigate to driver onboarding screen
  void _navigateToOnboarding(String currentPassword) async {
    int attempts = 0;
    const maxAttempts = 10;
    const delayMs = 100;

    while (attempts < maxAttempts) {
      if (navigatorKey?.currentState != null) {
        navigatorKey!.currentState!.pushNamedAndRemoveUntil(
          AppRoutes.driverOnboarding,
          (route) => false,
          arguments: {'currentPassword': currentPassword},
        );
        return;
      }

      attempts++;
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }

  Future<void> _fetchDriverInfo() async {
    if (_getDriverInfoUseCase == null) return;

    final result = await _getDriverInfoUseCase(const GetDriverInfoParams());

    result.fold(
      (failure) async {
        // Nếu BE trả về lỗi yêu cầu hoàn tất onboarding (INACTIVE driver bị chặn)
        // thì tự động logout thay vì cố refresh token.
        if (failure.message.contains('Vui lòng hoàn tất đăng ký tài khoản trước khi sử dụng ứng dụng')) {
          await logout();
          return;
        }

        // Ngược lại, xử lý lỗi 401/token hết hạn như cũ
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
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
        // Nếu BE trả về lỗi yêu cầu hoàn tất onboarding (INACTIVE driver bị chặn)
        // thì tự động logout thay vì cố refresh token.
        if (failure.message.contains('Vui lòng hoàn tất đăng ký tài khoản trước khi sử dụng ứng dụng')) {
          await logout();
          return false;
        }

        // Ngược lại, xử lý lỗi 401/token hết hạn như cũ
        final shouldRetry = await handleUnauthorizedError(failure.message);
        if (shouldRetry) {
          return await refreshDriverInfo();
        }

        return false;
      },
      (driver) async {
        _driver = driver;
        notifyListeners();

        // CRITICAL FIX: Auto-reconnect notification service after driver info is fetched
        // This handles the case where initial connection failed due to missing driver info
        try {
          final notificationService = getIt<NotificationService>();
          if (!notificationService.isConnected) {
            await Future.delayed(const Duration(milliseconds: 500));
            await notificationService.connect(_driver!.id);
          }
        } catch (e) { // Ignore: Error handling not implemented
        }

        return true;
      },
    );
  }

  /// Logs out the user by clearing local data and calling the logout API
  /// Returns true if local data was cleared successfully, regardless of API result
  Future<bool> logout() async {
    try {
      // WebSocket services will be cleaned up automatically
      // NotificationService will be disconnected below in _clearUserData()

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
                  //
                },
                (_) {
                  //
                },
              );
            })
            .catchError((e) {
              //
            });
      } catch (e) {
        //
      }

      return true;
    } catch (e) {
      //
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
    // CRITICAL: If already refreshing, wait for the current refresh to complete
    if (_isRefreshing && _refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }

    // Đánh dấu đang refresh để tránh gọi nhiều lần
    _isRefreshing = true;
    _refreshCompleter = Completer<bool>();
    notifyListeners();

    final result = await _refreshTokenUseCase(NoParams());

    bool success = false;

    await result.fold(
      (failure) async {
        success = false;
      },
      (tokenResponse) async {
        // Cập nhật token trong user
        if (_user != null) {
          final oldToken = _user!.authToken;
          _user = tokenResponse;

          // CRITICAL: Save tokens to TokenStorageService FIRST!
          // This ensures the new token is available for next API calls
          try {
            final tokenStorage = getIt<TokenStorageService>();
            await tokenStorage.saveAccessToken(_user!.authToken);
            await tokenStorage.saveRefreshToken(_user!.refreshToken ?? '');
          } catch (e) { // Ignore: Error handling not implemented

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
              role: RoleModel.fromEntity(_user!.role),
              authToken: _user!.authToken,
              refreshToken: _user!.refreshToken,
            );
            final userJson = json.encode(userModel.toJson());
            await prefs.setString('user_info', userJson);
          } catch (e) { // Ignore: Error handling not implemented
          }
        }

        // Tải lại thông tin tài xế
        await refreshDriverInfo();

        success = true;
        }
      },
    );

    // CRITICAL: After successful token refresh, reconnect WebSocket services
    // This ensures they use the new token for authentication
    if (success) {
      await _reconnectWebSocketServices();
    }

    // Reset lock and complete the completer
    _isRefreshing = false;
    _refreshCompleter?.complete(success);
    _refreshCompleter = null;
    return success;
  }
  
  /// Reconnect WebSocket services after token refresh
  Future<void> _reconnectWebSocketServices() async {
    debugPrint('🔄 Reconnecting WebSocket services after token refresh...');
    
    try {
      // Reconnect NotificationService
      final notificationService = getIt<NotificationService>();
      await notificationService.forceReconnect();
      debugPrint('✅ NotificationService reconnected');
    } catch (e) {
      debugPrint('⚠️ Failed to reconnect NotificationService: $e');
    }
    
    try {
      // Reconnect ChatNotificationService
      final chatNotificationService = getIt<ChatNotificationService>();
      await chatNotificationService.forceReconnect();
      debugPrint('✅ ChatNotificationService reconnected');
    } catch (e) {
      debugPrint('⚠️ Failed to reconnect ChatNotificationService: $e');
    }
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

        // CRITICAL: Don't fetch driver info during checkAuthStatus!
        // This can cause API failures which trigger token refresh,
        // and the new token gets revoked by the backend's token rotation.
        // Driver info will be fetched on-demand when needed.

        status = AuthStatus.authenticated;

        // Connect to notification WebSocket (don't await to avoid blocking UI during startup)
        // This will run in background and connect when ready
        _connectNotificationService().catchError((error) {});
      } catch (e) {
        //
        status = AuthStatus.unauthenticated;
        await _clearUserData();
      }
    } catch (e) {
      //
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
      //
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
        //
      } catch (e) {
        //
      }
    }
  }

  // Xử lý lỗi token hết hạn
  Future<bool> handleTokenExpired() async {
    return await refreshToken();
  }

  // Xử lý khi token đã được làm mới thành công từ bên ngoài
  Future<void> handleTokenRefreshed(String newAccessToken) async {
    //

    if (_user != null) {
      //

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
          role: RoleModel.fromEntity(_user!.role),
          authToken: _user!.authToken,
          refreshToken: _user!.refreshToken,
        );
        final userJson = json.encode(userModel.toJson());
        await prefs.setString('user_info', userJson);
        //

        // Kiểm tra xem đã lưu thành công chưa
        final savedJson = prefs.getString('user_info');
        if (savedJson != null) {
          final savedUserModel = UserModel.fromJson(json.decode(savedJson));
          final savedUser = savedUserModel.toEntity();
          if (savedUser.authToken != newAccessToken) {
            //
          } else {
            //
          }
        }
      } catch (e) {
        //
      }
    } else {
      //

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
          role: RoleModel.fromEntity(_user!.role),
          authToken: _user!.authToken,
          refreshToken: _user!.refreshToken,
        );
        await prefs.setString('user_info', json.encode(userModel.toJson()));
      } catch (e) {
        //
      }
    }

    // Đặt trạng thái đã xác thực
    status = AuthStatus.authenticated;

    // CRITICAL: Don't fetch driver info here!
    // This will cause API failures which trigger another token refresh,
    // leading to the new token being revoked by the backend's token rotation.
    // Driver info will be fetched on-demand when needed.
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

  /// Setup callback for 401 Unauthorized errors
  /// When API returns 401, try to refresh token first before logging out
  void _setupUnauthorizedCallback() {
    try {
      final apiClient = getIt<ApiClient>();
      apiClient.setOnUnauthorizedCallback(() async {
        // Try to refresh token first
        try {
          final success = await forceRefreshToken();

          if (success) {
            // Token refreshed successfully, the request will be retried automatically
            return;
          } else {
            await logout();
          }
        } catch (e) {
          await logout();
        }
      });

      // Setup callback for 403 Forbidden errors (INACTIVE driver access)
      apiClient.setOnForbiddenCallback(() async {
        // INACTIVE driver attempting to access restricted endpoint - logout immediately
        await logout();
      });
    } catch (e) { // Ignore: Error handling not implemented
    }
  }

  /// Connect to notification WebSocket service
  Future<void> _connectNotificationService() async {
    if (_user == null) {
      return;
    }

    // 🆕 Fetch driver info if not available
    if (_driver == null) {
      await refreshDriverInfo();

      if (_driver == null) {
        return;
      }
    }
    try {
      // CRITICAL: Wait for MaterialApp navigation to complete
      // This ensures navigatorKey.currentContext is ready before WebSocket connects
      // Reduces the number of retry attempts needed for showing notification dialogs
      await Future.delayed(const Duration(milliseconds: 500));
      final notificationService = getIt<NotificationService>();

      // 🆕 CRITICAL: Use driver ID instead of user ID and AWAIT connection
      await notificationService.connect(_driver!.id);
      // NotificationService now handles ALL notifications including return goods
      // No need for separate WebSocketService
      
      // 🆕 CRITICAL: Initialize ChatNotificationService globally
      // This ensures chat notifications and badge updates work even when not on chat screen
      try {
        final chatNotificationService = getIt<ChatNotificationService>();
        await chatNotificationService.initialize(
          _driver!.id,
          vehicleAssignmentId: null, // Will be updated when entering specific trip
        );
        debugPrint('✅ ChatNotificationService initialized globally');
      } catch (e) {
        debugPrint('⚠️ Failed to initialize ChatNotificationService: $e');
      }
    } catch (e) { // Ignore: Error handling not implemented
    }
  }
}
