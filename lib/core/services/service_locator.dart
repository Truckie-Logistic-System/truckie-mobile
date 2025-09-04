import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/auth_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import 'api_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  getIt.registerLazySingleton<http.Client>(() => http.Client());

  // Core
  getIt.registerLazySingleton<ApiService>(
    () => ApiService(
      baseUrl: 'http://10.0.2.2:8080/api/v1',
      client: getIt<http.Client>(),
    ),
  );

  // Data sources
  getIt.registerLazySingleton<AuthDataSource>(
    () => AuthDataSourceImpl(
      apiService: getIt<ApiService>(),
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dataSource: getIt<AuthDataSource>()),
  );

  // Use cases
  getIt.registerLazySingleton<LoginUseCase>(
    () => LoginUseCase(getIt<AuthRepository>()),
  );
  getIt.registerLazySingleton<LogoutUseCase>(
    () => LogoutUseCase(getIt<AuthRepository>()),
  );

  // ViewModels
  getIt.registerFactory<AuthViewModel>(
    () => AuthViewModel(
      loginUseCase: getIt<LoginUseCase>(),
      logoutUseCase: getIt<LogoutUseCase>(),
    ),
  );
}
