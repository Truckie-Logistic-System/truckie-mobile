/// API configuration constants
class ApiConstants {
  // Private constructor to prevent instantiation
  ApiConstants._();

  /// Base API URL for development (Android Emulator)
  /// NOTE: Already includes /api/v1 prefix - do NOT add /api/v1 to endpoint paths!
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  /// WebSocket base URL for development (Android Emulator)
  static const String wsBaseUrl = 'ws://10.0.2.2:8080';

  /// WebSocket endpoint for vehicle tracking notifications
  static const String wsVehicleTrackingEndpoint = '/vehicle-tracking';

  /// WebSocket endpoint for chat messaging (uses same as vehicle tracking for mobile JWT support)
  static const String wsChatEndpoint = '/vehicle-tracking';

  // ============================================================================
  // AUTHENTICATION ENDPOINTS
  // ============================================================================
  /// Login endpoint (mobile)
  static const String loginMobile = '/auths/mobile';

  /// Refresh token endpoint (mobile)
  static const String refreshTokenMobile = '/auths/mobile/token/refresh';

  /// Logout endpoint (mobile)
  static const String logoutMobile = '/auths/mobile/logout';

  /// Change password endpoint
  static const String changePassword = '/auths/change-password';

  // ============================================================================
  // DRIVER ENDPOINTS
  // ============================================================================
  /// Get current driver information
  static const String getDriverInfo = '/drivers/user';

  /// Update driver information
  /// Usage: PUT /drivers/{driverId}
  static const String updateDriver = '/drivers';

  // ============================================================================
  // ORDER ENDPOINTS
  // ============================================================================
  /// Get list of orders for driver
  static const String getDriverOrders = '/orders/get-list-order-for-driver';

  /// Get order details by order ID
  /// Usage: GET /orders/get-order-by-id/{orderId}
  static const String getOrderDetails = '/orders/get-order-by-id';

  /// Get order details for driver by order ID
  /// Usage: GET /orders/get-order-for-driver-by-order-id/{orderId}
  static const String getOrderDetailsForDriver =
      '/orders/get-order-for-driver-by-order-id';

  /// Update order status to ONGOING_DELIVERED (within 3km of delivery point)
  /// Usage: PUT /orders/{orderId}/start-ongoing-delivery
  static const String startOngoingDelivery = '/orders/';

  /// Update order status to DELIVERED (arrived at delivery point)
  /// Usage: PUT /orders/{orderId}/arrive-at-delivery
  static const String arriveAtDelivery = '/orders';

  /// Update order status to SUCCESSFUL (trip completed)
  /// Usage: PUT /orders/{orderId}/complete-trip
  static const String completeTrip = '/orders';

  // ============================================================================
  // LOADING DOCUMENTATION ENDPOINTS
  // ============================================================================
  /// Document loading and seal endpoint
  /// POST multipart form data with packing proof images and seal image
  static const String documentLoadingAndSeal =
      '/loading-documentation/document-loading-and-seal';

  // ============================================================================
  // PHOTO COMPLETION ENDPOINTS
  // ============================================================================
  /// Upload single photo completion image
  /// POST multipart form data with image file
  static const String uploadPhotoCompletion = '/photo-completions/upload';

  /// Upload multiple photo completion images
  /// POST multipart form data with multiple image files
  static const String uploadMultiplePhotoCompletion =
      '/photo-completions/upload-multiple';

  // ============================================================================
  // VEHICLE FUEL CONSUMPTION ENDPOINTS
  // ============================================================================
  /// Update final odometer reading with image
  /// PUT multipart form data with odometer image
  static const String updateFinalReading =
      '/vehicle-fuel-consumptions/final-reading';

  /// Get fuel consumption by vehicle assignment ID
  /// Usage: GET /vehicle-fuel-consumptions/vehicle-assignment/{vehicleAssignmentId}
  static const String getFuelConsumption =
      '/vehicle-fuel-consumptions/vehicle-assignment';

  // ============================================================================
  // REQUEST TIMEOUT CONFIGURATIONS
  // ============================================================================
  /// Connection timeout duration
  static const Duration connectTimeout = Duration(seconds: 30);

  /// Receive timeout duration
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Send timeout duration
  static const Duration sendTimeout = Duration(seconds: 30);

  // ============================================================================
  // WEBSOCKET CONFIGURATION
  // ============================================================================
  /// WebSocket reconnection delay
  static const Duration wsReconnectDelay = Duration(seconds: 5);

  /// Maximum WebSocket reconnection attempts
  static const int wsMaxReconnectAttempts = 5;

  // ============================================================================
  // HTTP STATUS CODES
  // ============================================================================
  /// Success status codes
  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusAccepted = 202;

  /// Client error status codes
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;

  /// Server error status codes
  static const int statusInternalServerError = 500;
  static const int statusServiceUnavailable = 503;
}
