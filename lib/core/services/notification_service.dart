import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../constants/api_constants.dart';
import '../services/token_storage_service.dart';
import '../../presentation/widgets/common/seal_assignment_notification_dialog.dart';
import '../../app/di/service_locator.dart';
import '../../presentation/features/auth/viewmodels/auth_viewmodel.dart';

/// Singleton service for managing WebSocket notifications
/// Automatically connects when driver is authenticated
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  StompClient? _stompClient;
  dynamic _currentSubscription;
  String? _currentDriverId;
  GlobalKey<NavigatorState>? _navigatorKey;
  AuthViewModel? _authViewModel;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  Completer<void>? _connectionCompleter;
  
  // Track shown notifications to prevent duplicates
  final Set<String> _shownNotifications = {};
  String? _lastNotificationId;
  bool _isInitialized = false;

  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  bool get isConnected => _stompClient?.connected ?? false;

  /// Initialize with navigator key for showing dialogs
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    if (_isInitialized) {
      // debugPrint('⚠️ [NotificationService] Already initialized, skipping...');
      return;
    }
    
    // debugPrint('🔧 [NotificationService] Initializing...');
    _navigatorKey = navigatorKey;
    _authViewModel = getIt<AuthViewModel>();
    _listenToNotifications();
    _isInitialized = true;
    // debugPrint('✅ [NotificationService] Initialized successfully');
  }

  /// Connect to WebSocket with driver ID
  Future<void> connect(String driverId) async {
    // debugPrint('🔄 [NotificationService] ========================================');
    // debugPrint('🔄 [NotificationService] connect() called for driver: $driverId');
    // debugPrint('🔄 [NotificationService] Current driver: $_currentDriverId');
    // debugPrint('🔄 [NotificationService] Is connected: $isConnected');
    // debugPrint('🔄 [NotificationService] Stomp client connected: ${_stompClient?.connected}');
    // debugPrint('🔄 [NotificationService] Retry count: $_retryCount');
    // debugPrint('🔄 [NotificationService] ========================================');

    // Always disconnect to ensure fresh connection
    if (isConnected) {
      // debugPrint('🔄 [NotificationService] Disconnecting existing connection...');
      disconnect();
    }

    _currentDriverId = driverId;
    // debugPrint('🔌 [NotificationService] ========================================');
    // debugPrint('🔌 [NotificationService] Connecting for driver ID: $driverId');
    // debugPrint('🔌 [NotificationService] ========================================');

    // Get JWT token for authentication
    final tokenStorageService = getIt<TokenStorageService>();
    final jwtToken = tokenStorageService.getAccessToken();
    
    if (jwtToken == null || jwtToken.isEmpty) {
      // debugPrint('❌ [NotificationService] No JWT token available');
      return;
    }

    final wsUrl = '${ApiConstants.wsBaseUrl}${ApiConstants.wsVehicleTrackingEndpoint}';
    // debugPrint('🔌 [NotificationService] Connecting to WebSocket URL: $wsUrl');

    // Create a new completer for this connection attempt
    _connectionCompleter = Completer<void>();

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        webSocketConnectHeaders: {'Authorization': 'Bearer $jwtToken'},
        onConnect: (StompFrame frame) {
          // debugPrint('✅ [NotificationService] ========================================');
          // debugPrint('✅ [NotificationService] WebSocket connected successfully!');
          // debugPrint('✅ [NotificationService] Frame: ${frame.body}');
          // debugPrint('✅ [NotificationService] Headers: ${frame.headers}');
          // debugPrint('✅ [NotificationService] Command: ${frame.command}');
          // debugPrint('✅ [NotificationService] ========================================');
          // debugPrint('📡 [NotificationService] Now subscribing to driver notifications...');
          _subscribeToDriverNotifications(driverId);
          // Reset retry count on successful connection
          _retryCount = 0;
          
          // Complete the connection completer
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.complete();
            // debugPrint('✅ [NotificationService] Connection completer completed');
          }
        },
        onWebSocketError: (dynamic error) {
          // debugPrint('❌ [NotificationService] WebSocket error: $error');
          
          // Complete the completer with error
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.completeError(error);
          }
          
          _handleWebSocketError(error);
        },
        onStompError: (StompFrame frame) {
          // debugPrint('❌ [NotificationService] STOMP error: ${frame.body}');
          
          // Complete the completer with error
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.completeError(frame.body ?? 'STOMP error');
          }
          
          _handleStompError(frame);
        },
        onDisconnect: (StompFrame frame) {
          // debugPrint('🔌 [NotificationService] WebSocket disconnected');
        },
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
      ),
    );

    // debugPrint('🚀 [NotificationService] Activating StompClient...');
    _stompClient!.activate();
    // debugPrint('🚀 [NotificationService] StompClient activated, waiting for connection...');
    
    // Wait for connection to complete (with timeout)
    try {
      await _connectionCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // debugPrint('⏱️ [NotificationService] Connection timeout after 10 seconds');
          throw TimeoutException('WebSocket connection timeout');
        },
      );
      // debugPrint('✅ [NotificationService] Connection completed successfully');
    } catch (e) {
      // debugPrint('❌ [NotificationService] Connection failed: $e');
      // Don't rethrow - let the app continue even if connection fails
    }
  }

  /// Subscribe to driver-specific notification topic
  void _subscribeToDriverNotifications(String driverId) {
    // Unsubscribe from previous subscription if exists
    if (_currentSubscription != null) {
      // debugPrint('🔄 [NotificationService] Unsubscribing from previous subscription...');
      try {
        _currentSubscription.unsubscribe();
      } catch (e) {
        // debugPrint('⚠️ [NotificationService] Error unsubscribing: $e');
      }
      _currentSubscription = null;
    }
    
    final topic = '/topic/driver/$driverId/notifications';
    // debugPrint('📡 [NotificationService] ========================================');
    // debugPrint('📡 [NotificationService] Subscribing to topic: $topic');
    // debugPrint('📡 [NotificationService] Driver ID: $driverId');
    // debugPrint('📡 [NotificationService] ========================================');

    _currentSubscription = _stompClient!.subscribe(
      destination: topic,
      callback: (StompFrame frame) {
        // debugPrint('📬 [NotificationService] ========================================');
        // debugPrint('📬 [NotificationService] Received message on topic: $topic');
        // debugPrint('📬 [NotificationService] Frame body: ${frame.body}');
        // debugPrint('📬 [NotificationService] ========================================');
        
        if (frame.body != null) {
          try {
            final notification = jsonDecode(frame.body!);
            // debugPrint('📲 [NotificationService] Parsed notification type: ${notification['type']}');
            // debugPrint('📲 [NotificationService] Notification data: $notification');
            _notificationController.add(notification);
          } catch (e) {
            // debugPrint('❌ [NotificationService] Error parsing notification: $e');
            // debugPrint('❌ [NotificationService] Raw body: ${frame.body}');
          }
        } else {
          // debugPrint('⚠️ [NotificationService] Received frame with null body');
        }
      },
    );
  }

  /// Listen to notification stream and handle notifications
  void _listenToNotifications() {
    _notificationController.stream.listen((notification) {
      _handleNotification(notification);
    });
  }

  /// Handle incoming notification
  void _handleNotification(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;

    switch (type) {
      case 'SEAL_ASSIGNMENT':
        _showSealAssignmentNotification(notification);
        break;
      default:
        // debugPrint('⚠️ [NotificationService] Unknown notification type: $type');
    }
  }

  /// Show seal assignment notification dialog
  void _showSealAssignmentNotification(Map<String, dynamic> notification) {
    if (_navigatorKey == null) {
      // debugPrint('❌ [NotificationService] Navigator key is null, cannot show dialog');
      return;
    }

    final issue = notification['issue'] as Map<String, dynamic>?;

    if (issue == null) {
      // debugPrint('❌ [NotificationService] Missing issue data in notification');
      return;
    }
    
    // 🆕 Check for duplicate notification
    final issueId = issue['id'] as String?;
    if (issueId == null) {
      // debugPrint('❌ [NotificationService] Missing issue ID in notification');
      return;
    }
    
    // Create unique notification ID from issue ID and timestamp
    final timestamp = notification['timestamp'] ?? DateTime.now().toIso8601String();
    final notificationId = '$issueId-$timestamp';
    
    // debugPrint('🔍 [NotificationService] Checking notification: $notificationId');
    // debugPrint('🔍 [NotificationService] Last notification: $_lastNotificationId');
    // debugPrint('🔍 [NotificationService] Shown notifications count: ${_shownNotifications.length}');
    
    // Check if this exact notification was already shown
    if (_lastNotificationId == notificationId || _shownNotifications.contains(notificationId)) {
      // debugPrint('⚠️ [NotificationService] Duplicate notification detected, skipping: $notificationId');
      return;
    }
    
    // Mark as shown
    _lastNotificationId = notificationId;
    _shownNotifications.add(notificationId);
    
    // Clean up old notifications (keep only last 10)
    if (_shownNotifications.length > 10) {
      final toRemove = _shownNotifications.length - 10;
      _shownNotifications.removeAll(_shownNotifications.take(toRemove));
    }
    
    // debugPrint('✅ [NotificationService] New notification, will show: $notificationId');

    // Extract seal codes from issue
    final oldSeal = issue['oldSeal'] as Map<String, dynamic>?;
    final newSeal = issue['newSeal'] as Map<String, dynamic>?;
    final staff = issue['staff'] as Map<String, dynamic>?;

    // 🆕 Check navigator key before showing dialog
    // debugPrint('🔍 [NotificationService] Navigator key check:');
    // debugPrint('   - Navigator key null: ${_navigatorKey == null}');
    // debugPrint('   - Current context null: ${_navigatorKey?.currentContext == null}');
    
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      // debugPrint('⚠️ [NotificationService] Navigator key is null, cannot show dialog');
      return;
    }
    
    // 🆕 Check if current route is navigation screen
    // Try to get route name from navigator state
    String? routeName;
    try {
      final navigator = _navigatorKey!.currentState;
      if (navigator != null) {
        // Get current route from overlay
        final overlay = navigator.overlay;
        if (overlay != null) {
          final context = overlay.context;
          final modalRoute = ModalRoute.of(context);
          routeName = modalRoute?.settings.name;
        }
      }
    } catch (e) {
      // debugPrint('⚠️ [NotificationService] Error getting route name: $e');
    }
    
    // debugPrint('🔍 [NotificationService] Current route: $routeName');
    
    // If we can't determine route, show dialog anyway (driver is likely on navigation screen)
    if (routeName != null && routeName != '/navigation') {
      // debugPrint('⚠️ [NotificationService] Not on navigation screen, skipping dialog');
      return;
    }
    
    // debugPrint('✅ [NotificationService] On navigation screen or route unknown - showing dialog');
    
    // debugPrint('📱 [NotificationService] Showing seal assignment notification dialog...');
    
    // 🆕 Get vehicle assignment ID from notification to fetch pending seals
    final vehicleAssignment = issue['vehicleAssignmentEntity'] as Map<String, dynamic>?;
    final vehicleAssignmentId = vehicleAssignment?['id'] as String?;
    
    showDialog(
      context: _navigatorKey!.currentContext!,
      barrierDismissible: false,
      builder: (context) => SealAssignmentNotificationDialog(
        title: notification['title'] ?? 'Thông báo',
        message: notification['message'] ?? '',
        issueId: issue['id'] ?? '',
        newSealCode: newSeal?['sealCode'] ?? 'N/A',
        oldSealCode: oldSeal?['sealCode'] ?? 'N/A',
        staffName: staff?['fullName'] ?? 'N/A',
        vehicleAssignmentId: vehicleAssignmentId,
      ),
    );
    
    // debugPrint('🔄 [NotificationService] Dialog displayed on navigation screen');
  }

  /// Refresh pending seals in navigation screen
  void refreshPendingSeals() {
    // debugPrint('🔄 [NotificationService] Triggering pending seals refresh...');
    
    // 🆕 Navigate to navigation screen to trigger refresh
    if (_navigatorKey?.currentContext != null) {
      // debugPrint('🔄 [NotificationService] Navigating to navigation screen for refresh...');
      
      // Navigate to navigation screen - this will trigger _fetchPendingSealReplacements()
      Navigator.of(_navigatorKey!.currentContext!).pushNamedAndRemoveUntil(
        '/navigation',
        (route) => false,
        arguments: {
          'orderId': null, // Navigation screen will find current active order
          'isSimulationMode': false,
        },
      );
    } else {
      // debugPrint('⚠️ [NotificationService] Cannot navigate - navigator key or context is null');
    }
  }
  
  /// Trigger manual refresh of navigation screen without navigation
  void triggerNavigationScreenRefresh() {
    // debugPrint('🔄 [NotificationService] Triggering navigation screen refresh...');
    
    // 🆕 Send a refresh signal to navigation screen
    // This will be handled by NavigationScreen through a stream or callback
    _refreshController.add(null);
  }
  
  // Stream controller for refresh signals
  final _refreshController = StreamController<void>.broadcast();
  Stream<void> get refreshStream => _refreshController.stream;

  /// Force reconnect with current driver (useful after token refresh)
  Future<void> forceReconnect() async {
    if (_currentDriverId != null) {
      // debugPrint('🔄 [NotificationService] Force reconnecting for driver: $_currentDriverId');
      _retryCount = 0; // Reset retry count for fresh attempt
      await connect(_currentDriverId!);
    } else {
      // debugPrint('⚠️ [NotificationService] No current driver to reconnect');
    }
  }

  /// Disconnect from WebSocket
  void disconnect() {
    // Unsubscribe first
    if (_currentSubscription != null) {
      // debugPrint('🔄 [NotificationService] Unsubscribing...');
      try {
        _currentSubscription.unsubscribe();
      } catch (e) {
        // debugPrint('⚠️ [NotificationService] Error unsubscribing: $e');
      }
      _currentSubscription = null;
    }
    
    if (_stompClient?.connected ?? false) {
      // debugPrint('🔌 [NotificationService] Disconnecting WebSocket');
      _stompClient!.deactivate();
    }
    _currentDriverId = null;
    _retryCount = 0;
    
    // Clear notification tracking
    _shownNotifications.clear();
    _lastNotificationId = null;
    // debugPrint('🧹 [NotificationService] Cleared notification tracking');
  }

  /// Handle WebSocket error with token refresh logic
  Future<void> _handleWebSocketError(dynamic error) async {
    // debugPrint('❌ [NotificationService] WebSocket error: $error');
    
    // Check if error is related to authentication (401)
    if (error.toString().contains('401') || error.toString().contains('unauthorized')) {
      // debugPrint('🔄 [NotificationService] Authentication error detected, attempting token refresh...');
      await _handleAuthError();
    } else {
      // For other errors, just retry connection with exponential backoff
      _retryConnection();
    }
  }

  /// Handle STOMP error with token refresh logic
  Future<void> _handleStompError(StompFrame frame) async {
    // debugPrint('❌ [NotificationService] STOMP error: ${frame.body}');
    
    // Check if error is related to authentication
    if (frame.body?.toString().contains('401') == true || 
        frame.body?.toString().contains('unauthorized') == true) {
      // debugPrint('🔄 [NotificationService] STOMP authentication error detected, attempting token refresh...');
      await _handleAuthError();
    } else {
      // For other errors, just retry connection
      _retryConnection();
    }
  }

  /// Handle authentication errors by refreshing token
  Future<void> _handleAuthError() async {
    if (_retryCount >= _maxRetries) {
      // debugPrint('❌ [NotificationService] Max retries reached, giving up');
      return;
    }

    // debugPrint('🔄 [NotificationService] Attempting force token refresh (attempt ${_retryCount + 1}/$_maxRetries)...');
    
    try {
      // Attempt to force refresh token
      final refreshSuccess = await _authViewModel?.forceRefreshToken();
      
      if (refreshSuccess == true) {
        // debugPrint('✅ [NotificationService] Force token refresh successful, reconnecting...');
        _retryCount++;
        // Wait a bit before reconnecting
        await Future.delayed(Duration(seconds: 2 * _retryCount));
        
        // Reconnect with new token
        if (_currentDriverId != null) {
          await connect(_currentDriverId!);
        }
      } else {
        // debugPrint('❌ [NotificationService] Force token refresh failed');
        _retryCount++;
        
        // If refresh failed, try again after longer delay
        if (_retryCount < _maxRetries) {
          await Future.delayed(Duration(seconds: 10 * _retryCount));
          await _handleAuthError();
        }
      }
    } catch (e) {
      // debugPrint('❌ [NotificationService] Error during force token refresh: $e');
      _retryCount++;
      
      // Try again after longer delay
      if (_retryCount < _maxRetries) {
        await Future.delayed(Duration(seconds: 10 * _retryCount));
        await _handleAuthError();
      }
    }
  }

  /// Retry connection with exponential backoff
  void _retryConnection() {
    if (_retryCount >= _maxRetries) {
      // debugPrint('❌ [NotificationService] Max retries reached, giving up');
      return;
    }

    _retryCount++;
    // debugPrint('🔄 [NotificationService] Retrying connection (attempt $_retryCount/$_maxRetries)...');
    
    // Schedule retry with exponential backoff
    Future.delayed(Duration(seconds: 5 * _retryCount), () async {
      if (_currentDriverId != null && _retryCount <= _maxRetries) {
        await connect(_currentDriverId!);
      }
    });
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
