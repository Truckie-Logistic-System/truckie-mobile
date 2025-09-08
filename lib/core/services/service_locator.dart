import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../../data/datasources/auth_data_source.dart';
import '../../data/datasources/driver_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/driver_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../domain/usecases/auth/change_password_usecase.dart';
import '../../domain/usecases/auth/get_driver_info_usecase.dart';
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../domain/usecases/auth/refresh_token_usecase.dart';
import '../../domain/usecases/auth/update_driver_info_usecase.dart';
import '../../presentation/features/account/viewmodels/account_viewmodel.dart';
import '../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import 'api_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  getIt.registerLazySingleton<http.Client>(() => http.Client());

  // Kiểm tra kết nối tới API
  final apiUrl = 'http://10.0.2.2:8080/api/v1';
  debugPrint('Initializing API service with URL: $apiUrl');

  try {
    final response = await http.get(Uri.parse('$apiUrl/health'));
    debugPrint(
      'API health check response: ${response.statusCode} - ${response.body}',
    );
  } catch (e) {
    debugPrint('API health check failed: ${e.toString()}');
    debugPrint('Continuing with setup anyway...');
  }

  // Core
  getIt.registerLazySingleton<ApiService>(
    () => ApiService(baseUrl: apiUrl, client: getIt<http.Client>()),
  );

  // Data sources
  getIt.registerLazySingleton<AuthDataSource>(
    () => AuthDataSourceImpl(
      apiService: getIt<ApiService>(),
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );

  getIt.registerLazySingleton<DriverDataSource>(
    () => DriverDataSourceImpl(apiService: getIt<ApiService>()),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dataSource: getIt<AuthDataSource>()),
  );

  getIt.registerLazySingleton<DriverRepository>(
    () => DriverRepositoryImpl(dataSource: getIt<DriverDataSource>()),
  );

  // Use cases
  getIt.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<LogoutUseCase>(
    () => LogoutUseCase(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<RefreshTokenUseCase>(
    () => RefreshTokenUseCase(getIt<AuthRepository>()),
  );

  getIt.registerLazySingleton<GetDriverInfoUseCase>(
    () => GetDriverInfoUseCase(getIt<DriverRepository>()),
  );

  getIt.registerLazySingleton<UpdateDriverInfoUseCase>(
    () => UpdateDriverInfoUseCase(getIt<DriverRepository>()),
  );

  getIt.registerLazySingleton<ChangePasswordUseCase>(
    () => ChangePasswordUseCase(getIt<AuthRepository>()),
  );

  // View models
  getIt.registerFactory<AuthViewModel>(
    () => AuthViewModel(
      loginUseCase: getIt<LoginUseCase>(),
      logoutUseCase: getIt<LogoutUseCase>(),
      refreshTokenUseCase: getIt<RefreshTokenUseCase>(),
      getDriverInfoUseCase: getIt<GetDriverInfoUseCase>(),
    ),
  );

  getIt.registerFactory<AccountViewModel>(
    () => AccountViewModel(
      getDriverInfoUseCase: getIt<GetDriverInfoUseCase>(),
      updateDriverInfoUseCase: getIt<UpdateDriverInfoUseCase>(),
      changePasswordUseCase: getIt<ChangePasswordUseCase>(),
    ),
  );
}
