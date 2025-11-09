import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/api_client.dart';
import '../../data/datasources/auth_data_source.dart';
import '../../data/datasources/driver_data_source.dart';
import '../../data/datasources/order_data_source.dart';
import '../../data/datasources/photo_completion_data_source.dart';
import '../../data/datasources/vehicle_fuel_consumption_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/driver_repository_impl.dart';
import '../../data/repositories/loading_documentation_repository_impl.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../data/repositories/vehicle_repository_impl.dart';
import '../../data/repositories/photo_completion_repository_impl.dart';
import '../../data/repositories/vehicle_fuel_consumption_repository_impl.dart';
import '../../data/repositories/issue_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../domain/repositories/loading_documentation_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/repositories/photo_completion_repository.dart';
import '../../domain/repositories/vehicle_fuel_consumption_repository.dart';
import '../../domain/repositories/issue_repository.dart';
import '../../domain/usecases/auth/change_password_usecase.dart';
import '../../domain/usecases/auth/get_driver_info_usecase.dart';
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../domain/usecases/auth/refresh_token_usecase.dart';
import '../../domain/usecases/auth/update_driver_info_usecase.dart';
import '../../domain/usecases/orders/get_driver_orders_usecase.dart';
import '../../domain/usecases/orders/get_order_details_usecase.dart';
import '../../domain/usecases/orders/upload_seal_image_usecase.dart';
import '../../domain/usecases/orders/update_order_to_ongoing_delivered_usecase.dart';
import '../../domain/usecases/orders/update_order_to_delivered_usecase.dart';
import '../../domain/usecases/orders/update_order_to_successful_usecase.dart';
import '../../domain/usecases/orders/update_order_detail_status_usecase.dart';
import '../../domain/usecases/vehicle/create_vehicle_fuel_consumption_usecase.dart';
import '../../presentation/features/account/viewmodels/account_viewmodel.dart';
import '../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../presentation/features/delivery/viewmodels/navigation_viewmodel.dart';
import '../../presentation/features/orders/viewmodels/order_detail_viewmodel.dart';
import '../../presentation/features/orders/viewmodels/order_list_viewmodel.dart';
import '../../presentation/features/orders/viewmodels/pre_delivery_documentation_viewmodel.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/vehicle_websocket_service.dart';
import '../../core/services/mock_vehicle_websocket_service.dart';
import '../../core/services/enhanced_location_tracking_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/location_queue_service.dart';
import '../../core/services/token_storage_service.dart';
import '../../core/services/vietmap_service.dart';
import '../../core/services/global_location_manager.dart';
import '../../core/services/navigation_state_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  try {
    // Check if already setup to avoid duplicate registration on hot reload
    if (getIt.isRegistered<SharedPreferences>()) {
      debugPrint('ℹ️ Service locator already setup, skipping...');
      return;
    }
    
    // External dependencies
    final sharedPreferences = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(sharedPreferences);

    // Token storage service
    debugPrint('Registering TokenStorageService...');
    final tokenStorageService = TokenStorageService();
    getIt.registerSingleton<TokenStorageService>(tokenStorageService);
    debugPrint('TokenStorageService registered successfully');

    // API Client with base URL from constants
    debugPrint('Initializing ApiClient with base URL: ${ApiConstants.baseUrl}');
    getIt.registerLazySingleton<ApiClient>(
      () => ApiClient(baseUrl: ApiConstants.baseUrl),
    );

    // Register VietMapService
    getIt.registerLazySingleton<VietMapService>(
      () => VietMapService(apiClient: getIt<ApiClient>()),
    );

    // Register NotificationService as singleton
    debugPrint('Registering NotificationService...');
    getIt.registerSingleton<NotificationService>(NotificationService());
    debugPrint('✅ NotificationService registered');

    // WebSocket services
    // Sử dụng mock service cho testing - đổi thành false để sử dụng dịch vụ thật
    final bool useMockWebSocket = false;

    if (useMockWebSocket) {
      getIt.registerLazySingleton<VehicleWebSocketService>(
        () => MockVehicleWebSocketService(),
      );
    } else {
      getIt.registerLazySingleton<VehicleWebSocketService>(
        () => VehicleWebSocketService(baseUrl: ApiConstants.wsBaseUrl),
      );
    }

    // Location tracking services - Simplified architecture
    // Only EnhancedLocationTrackingService and GlobalLocationManager are used

    // Enhanced location tracking services
    getIt.registerLazySingleton<LocationQueueService>(
      () => LocationQueueService(),
    );

    getIt.registerLazySingleton<EnhancedLocationTrackingService>(
      () => EnhancedLocationTrackingService(
        webSocketService: getIt<VehicleWebSocketService>(),
        queueService: getIt<LocationQueueService>(),
      ),
    );

    // Navigation state service for persistence
    getIt.registerLazySingleton<NavigationStateService>(
      () => NavigationStateService(getIt<SharedPreferences>()),
    );

    // NOTE: Recovery and background services removed as part of architecture simplification
    // GlobalLocationManager now handles all location tracking directly

    // Initialize Global Location Manager (must be after dependencies)
    GlobalLocationManager.initialize(
      getIt<EnhancedLocationTrackingService>(),
      getIt<NavigationStateService>(),
    );

    // Register Global Location Manager instance
    getIt.registerSingleton<GlobalLocationManager>(GlobalLocationManager.instance);

    // Data sources
    getIt.registerLazySingleton<AuthDataSourceImpl>(
      () => AuthDataSourceImpl(
        apiClient: getIt<ApiClient>(),
        sharedPreferences: getIt<SharedPreferences>(),
        tokenStorageService: getIt<TokenStorageService>(),
      ),
    );

    getIt.registerLazySingleton<DriverDataSourceImpl>(
      () => DriverDataSourceImpl(apiClient: getIt<ApiClient>()),
    );

    getIt.registerLazySingleton<OrderDataSource>(
      () => OrderDataSourceImpl(getIt<ApiClient>()),
    );

    getIt.registerLazySingleton<PhotoCompletionDataSource>(
      () => PhotoCompletionDataSourceImpl(getIt<ApiClient>()),
    );

    getIt.registerLazySingleton<VehicleFuelConsumptionDataSource>(
      () => VehicleFuelConsumptionDataSourceImpl(getIt<ApiClient>()),
    );

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(dataSource: getIt<AuthDataSourceImpl>()),
  );

  getIt.registerLazySingleton<DriverRepository>(
    () => DriverRepositoryImpl(dataSource: getIt<DriverDataSourceImpl>()),
  );

  getIt.registerLazySingleton<LoadingDocumentationRepository>(
    () => LoadingDocumentationRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(
      apiClient: getIt<ApiClient>(),
      orderDataSource: getIt<OrderDataSource>(),
    ),
  );

  getIt.registerLazySingleton<VehicleRepository>(
    () => VehicleRepositoryImpl(apiClient: getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<PhotoCompletionRepository>(
    () => PhotoCompletionRepositoryImpl(dataSource: getIt<PhotoCompletionDataSource>()),
  );

  getIt.registerLazySingleton<VehicleFuelConsumptionRepository>(
    () => VehicleFuelConsumptionRepositoryImpl(dataSource: getIt<VehicleFuelConsumptionDataSource>()),
  );

  getIt.registerLazySingleton<IssueRepository>(
    () => IssueRepositoryImpl(getIt<ApiClient>()),
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

  getIt.registerLazySingleton<GetDriverOrdersUseCase>(
    () => GetDriverOrdersUseCase(orderRepository: getIt<OrderRepository>()),
  );

  getIt.registerLazySingleton<GetOrderDetailsUseCase>(
    () => GetOrderDetailsUseCase(orderRepository: getIt<OrderRepository>()),
  );

  getIt.registerLazySingleton<DocumentLoadingAndSealUseCase>(
    () => DocumentLoadingAndSealUseCase(
      getIt<LoadingDocumentationRepository>(),
    ),
  );

  getIt.registerLazySingleton<CreateVehicleFuelConsumptionUseCase>(
    () => CreateVehicleFuelConsumptionUseCase(getIt<VehicleRepository>()),
  );

  getIt.registerLazySingleton<UpdateOrderToOngoingDeliveredUseCase>(
    () => UpdateOrderToOngoingDeliveredUseCase(getIt<OrderRepository>()),
  );

  getIt.registerLazySingleton<UpdateOrderToDeliveredUseCase>(
    () => UpdateOrderToDeliveredUseCase(getIt<OrderRepository>()),
  );

  getIt.registerLazySingleton<UpdateOrderToSuccessfulUseCase>(
    () => UpdateOrderToSuccessfulUseCase(getIt<OrderRepository>()),
  );

  getIt.registerLazySingleton<UpdateOrderDetailStatusUseCase>(
    () => UpdateOrderDetailStatusUseCase(getIt<OrderRepository>()),
  );

  // View models
  // Register AuthViewModel as LazySingleton to maintain state across the app
  debugPrint('📝 Registering AuthViewModel...');
  getIt.registerLazySingleton<AuthViewModel>(
    () => AuthViewModel(
      loginUseCase: getIt<LoginUseCase>(),
      logoutUseCase: getIt<LogoutUseCase>(),
      refreshTokenUseCase: getIt<RefreshTokenUseCase>(),
      getDriverInfoUseCase: getIt<GetDriverInfoUseCase>(),
    ),
    // Remove instanceName to allow direct access via getIt<AuthViewModel>()
  );
  debugPrint('✅ AuthViewModel registered');

  // NOTE: LocationTrackingViewModel removed - testing feature

  getIt.registerFactory<AccountViewModel>(
    () => AccountViewModel(
      getDriverInfoUseCase: getIt<GetDriverInfoUseCase>(),
      updateDriverInfoUseCase: getIt<UpdateDriverInfoUseCase>(),
      changePasswordUseCase: getIt<ChangePasswordUseCase>(),
    ),
  );

  getIt.registerFactory<OrderListViewModel>(
    () => OrderListViewModel(
      getDriverOrdersUseCase: getIt<GetDriverOrdersUseCase>(),
    ),
  );

  getIt.registerFactory<OrderDetailViewModel>(
    () => OrderDetailViewModel(
      getOrderDetailsUseCase: getIt<GetOrderDetailsUseCase>(),
      createVehicleFuelConsumptionUseCase: getIt<CreateVehicleFuelConsumptionUseCase>(),
      photoCompletionRepository: getIt<PhotoCompletionRepository>(),
      fuelConsumptionRepository: getIt<VehicleFuelConsumptionRepository>(),
      updateToDeliveredUseCase: getIt<UpdateOrderToDeliveredUseCase>(),
      updateToOngoingDeliveredUseCase: getIt<UpdateOrderToOngoingDeliveredUseCase>(),
      authViewModel: getIt<AuthViewModel>(),
    ),
  );

  getIt.registerFactory<PreDeliveryDocumentationViewModel>(
    () => PreDeliveryDocumentationViewModel(
      documentLoadingAndSealUseCase: getIt<DocumentLoadingAndSealUseCase>(),
    ),
  );

    // Đăng ký NavigationViewModel as Factory để mỗi NavigationScreen có instance riêng
    // CRITICAL: Không dùng LazySingleton vì khi có 2 giả lập chạy cùng lúc,
    // device 2 sẽ overwrite route segments của device 1
    getIt.registerFactory<NavigationViewModel>(() => NavigationViewModel());
    debugPrint('✅ All service locator registrations complete');
  } catch (e) {
    debugPrint('❌ Error during service locator setup: $e');
    debugPrint('Stack trace: ${StackTrace.current}');
    rethrow;
  }
}
