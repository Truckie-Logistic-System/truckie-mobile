import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/sound_utils.dart';
import '../constants/api_constants.dart';
import '../services/token_storage_service.dart';
import '../../presentation/widgets/common/seal_assignment_notification_dialog.dart';
import '../../presentation/widgets/common/damage_resolved_notification_dialog.dart';
import '../../presentation/widgets/common/order_rejection_resolved_notification_dialog.dart';
import '../../app/di/service_locator.dart';
import '../../presentation/features/auth/viewmodels/auth_viewmodel.dart';

/// Singleton service for managing WebSocket notifications
/// Automatically connects when driver is authenticated 
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _initializeLocalNotifications();
  }

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

  // Flutter Local Notifications
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;

  /// Initialize flutter_local_notifications
  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('📲 [NotificationService] Notification tapped: ${response.payload}');
        },
      );

      _localNotificationsInitialized = true;
      debugPrint('✅ [NotificationService] Local notifications initialized');
    } catch (e) {
      debugPrint('❌ [NotificationService] Error initializing local notifications: $e');
    }
  }

  /// Show a local notification
  Future<void> showNotification({
    required String title,
    required String body,
    bool isHighPriority = false,
    String? payload,
  }) async {
    if (!_localNotificationsInitialized) {
      await _initializeLocalNotifications();
    }

    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'capstone_mobile_channel',
        'Capstone Mobile',
        channelDescription: 'Notifications for Capstone Mobile app',
        importance: isHighPriority ? Importance.high : Importance.defaultImportance,
        priority: isHighPriority ? Priority.high : Priority.defaultPriority,
        showWhen: true,
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugPrint('✅ [NotificationService] Local notification shown: $title');
    } catch (e) {
      debugPrint('❌ [NotificationService] Error showing notification: $e');
    }
  }

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
    debugPrint('🔄 [NotificationService] ========================================');
    debugPrint('🔄 [NotificationService] connect() called for driver: $driverId');
    debugPrint('🔄 [NotificationService] Current driver: $_currentDriverId');
    debugPrint('🔄 [NotificationService] Is connected: $isConnected');
    debugPrint('🔄 [NotificationService] Stomp client connected: ${_stompClient?.connected}');
    debugPrint('🔄 [NotificationService] Retry count: $_retryCount');
    debugPrint('🔄 [NotificationService] ========================================');

    // CRITICAL: Always disconnect to ensure fresh connection
    // Even if isConnected is false, the client might still exist and try to reconnect
    if (_stompClient != null) {
      debugPrint('🔄 [NotificationService] Cleaning up existing client...');
      disconnect();
      // Give old client time to fully disconnect
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _currentDriverId = driverId;
    debugPrint('🔌 [NotificationService] ========================================');
    debugPrint('🔌 [NotificationService] Connecting for driver ID: $driverId');
    debugPrint('🔌 [NotificationService] ========================================');

    // Get JWT token for authentication
    final tokenStorageService = getIt<TokenStorageService>();
    final jwtToken = tokenStorageService.getAccessToken();
    
    if (jwtToken == null || jwtToken.isEmpty) {
      debugPrint('❌ [NotificationService] No JWT token available');
      return;
    }

    final wsUrl = '${ApiConstants.wsBaseUrl}${ApiConstants.wsVehicleTrackingEndpoint}';
    debugPrint('🔌 [NotificationService] Connecting to WebSocket URL: $wsUrl');

    // Create a new completer for this connection attempt
    _connectionCompleter = Completer<void>();

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        webSocketConnectHeaders: {'Authorization': 'Bearer $jwtToken'},
        onConnect: (StompFrame frame) {
          debugPrint('✅ [NotificationService] ========================================');
          debugPrint('✅ [NotificationService] WebSocket connected successfully!');
          debugPrint('✅ [NotificationService] Frame: ${frame.body}');
          debugPrint('✅ [NotificationService] Headers: ${frame.headers}');
          debugPrint('✅ [NotificationService] Command: ${frame.command}');
          debugPrint('✅ [NotificationService] ========================================');
          debugPrint('📡 [NotificationService] Now subscribing to driver notifications...');
          _subscribeToDriverNotifications(driverId);
          // Reset retry count on successful connection
          _retryCount = 0;
          
          // Complete the connection completer
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.complete();
            debugPrint('✅ [NotificationService] Connection completer completed');
          }
        },
        onWebSocketError: (dynamic error) {
          debugPrint('❌ [NotificationService] WebSocket error: $error');
          
          // Complete the completer with error
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.completeError(error);
          }
          
          _handleWebSocketError(error);
        },
        onStompError: (StompFrame frame) {
          debugPrint('❌ [NotificationService] STOMP error: ${frame.body}');
          
          // Complete the completer with error
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.completeError(frame.body ?? 'STOMP error');
          }
          
          _handleStompError(frame);
        },
        onDisconnect: (StompFrame frame) {
          // debugPrint('🔌 [NotificationService] WebSocket disconnected');
        },
        // CRITICAL: Disable auto-reconnect to prevent reconnection with stale tokens
        // We handle reconnection manually via _retryConnection() with fresh tokens
        reconnectDelay: const Duration(seconds: 0),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
      ),
    );

    debugPrint('🚀 [NotificationService] Activating StompClient...');
    _stompClient!.activate();
    debugPrint('🚀 [NotificationService] StompClient activated, waiting for connection...');
    
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
    debugPrint('📡 [NotificationService] ========================================');
    debugPrint('📡 [NotificationService] Subscribing to topic: $topic');
    debugPrint('📡 [NotificationService] Driver ID: $driverId');
    debugPrint('📡 [NotificationService] ========================================');

    _currentSubscription = _stompClient!.subscribe(
      destination: topic,
      callback: (StompFrame frame) {
        debugPrint('📬 [NotificationService] ========================================');
        debugPrint('📬 [NotificationService] Received message on topic: $topic');
        debugPrint('📬 [NotificationService] Frame body: ${frame.body}');
        debugPrint('📬 [NotificationService] ========================================');
        
        if (frame.body != null) {
          try {
            final notification = jsonDecode(frame.body!);
            debugPrint('📲 [NotificationService] Parsed notification type: ${notification['type']}');
            debugPrint('📲 [NotificationService] Notification data: $notification');
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
    final title = notification['title'] as String?;
    final body = notification['message'] as String?;
    final priority = notification['priority'] as String?;

    debugPrint('========================================');
    debugPrint('📲 [NotificationService] Handling notification');
    debugPrint('   - Type: $type');
    debugPrint('   - Title: $title');
    debugPrint('   - Body: $body');
    debugPrint('   - Priority: $priority');
    debugPrint('   - Full notification: $notification');
    debugPrint('========================================');

    switch (type) {
      case 'SEAL_ASSIGNMENT':
        _showSealAssignmentNotification(notification);
        break;
      case 'RETURN_PAYMENT_SUCCESS':
        _handleReturnPaymentSuccess(notification);
        break;
      case 'RETURN_PAYMENT_TIMEOUT':
        _handleReturnPaymentTimeout(notification);
        break;
      case 'RETURN_PAYMENT_REJECTED':
        _handleReturnPaymentRejected(notification);
        break;
      case 'DAMAGE_RESOLVED':
        _handleDamageResolved(notification);
        break;
      case 'ORDER_REJECTION_RESOLVED':
        _handleOrderRejectionResolved(notification);
        break;
      default:
        debugPrint('⚠️ [NotificationService] Unknown notification type: $type');
    }

    // Show local notification for all types
    if (title != null && body != null) {
      showNotification(
        title: title,
        body: body,
        isHighPriority: priority == 'HIGH' || priority == 'URGENT',
      );
    }
  }

  /// Show seal assignment notification dialog
  /// Pattern 2: Action-required notification
  /// Flow: Confirm modal → Navigate to navigation screen → Show bottom sheet (DON'T resume)
  /// After bottom sheet submit → Fetch order → Auto resume simulation
  void _showSealAssignmentNotification(Map<String, dynamic> notification) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      debugPrint('❌ [NotificationService] Navigator key is null, cannot show dialog');
      return;
    }

    // Play sound for seal assignment notification
    SoundUtils.playSealAssignmentSound();

    final issue = notification['issue'] as Map<String, dynamic>?;
    if (issue == null) {
      debugPrint('❌ [NotificationService] Missing issue data in notification');
      return;
    }
    
    final issueId = issue['id'] as String?;
    if (issueId == null) {
      debugPrint('❌ [NotificationService] Missing issue ID in notification');
      return;
    }
    
    // Create unique notification ID from issue ID and timestamp
    final timestamp = notification['timestamp'] ?? DateTime.now().toIso8601String();
    final notificationId = '$issueId-$timestamp';
    
    // Check if this exact notification was already shown
    if (_lastNotificationId == notificationId || _shownNotifications.contains(notificationId)) {
      debugPrint('⚠️ [NotificationService] Duplicate notification detected, skipping: $notificationId');
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
    
    debugPrint('✅ [NotificationService] New SEAL_ASSIGNMENT notification: $notificationId');

    // Extract seal codes from issue
    final oldSeal = issue['oldSeal'] as Map<String, dynamic>?;
    final newSeal = issue['newSeal'] as Map<String, dynamic>?;
    final staff = issue['staff'] as Map<String, dynamic>?;
    
    // Check current route
    final currentRoute = _getCurrentRouteName();
    final isOnNavigationScreen = currentRoute == '/navigation';
    
    debugPrint('🔍 [NotificationService] Current route: $currentRoute');
    debugPrint('🔍 [NotificationService] Is on navigation screen: $isOnNavigationScreen');
    
    // Show global notification dialog
    showDialog(
      context: _navigatorKey!.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade600, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Thay thế seal',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['message'] ?? 'Nhân viên đã gán seal mới cho xe của bạn',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seal cũ: ${oldSeal?['sealCode'] ?? 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seal mới: ${newSeal?['sealCode'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nhân viên: ${staff?['fullName'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Pattern 2: Action-required notification
              // Navigate to navigation screen + show bottom sheet (DON'T auto-resume)
              if (!isOnNavigationScreen) {
                debugPrint('🗺️ [NotificationService] Not on navigation screen, navigating there first...');
                _navigateToNavigationScreenForAction(
                  shouldShowSealBottomSheet: true,
                  issueIdForSeal: issueId,
                );
              } else {
                debugPrint('✅ [NotificationService] Already on navigation screen, triggering bottom sheet...');
                // Already on navigation screen, just trigger to show bottom sheet
                _showSealBottomSheetController.add(issueId);
              }
            },
            child: const Text('Xác nhận', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    
    debugPrint('🔄 [NotificationService] SEAL_ASSIGNMENT dialog displayed globally');
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
  
  // Stream controller for showing seal bottom sheet
  final _showSealBottomSheetController = StreamController<String>.broadcast();
  Stream<String> get showSealBottomSheetStream => _showSealBottomSheetController.stream;

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
    
    // CRITICAL: Always deactivate and null out the client
    // This prevents zombie clients from attempting reconnection with stale tokens
    if (_stompClient != null) {
      try {
        // debugPrint('🔌 [NotificationService] Deactivating WebSocket client');
        _stompClient!.deactivate();
      } catch (e) {
        // debugPrint('⚠️ [NotificationService] Error deactivating client: $e');
      }
      _stompClient = null; // CRITICAL: Set to null to prevent reconnect attempts
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

  /// Get current route name from navigator
  String? _getCurrentRouteName() {
    try {
      final navigator = _navigatorKey?.currentState;
      if (navigator != null) {
        final overlay = navigator.overlay;
        if (overlay != null) {
          final context = overlay.context;
          final modalRoute = ModalRoute.of(context);
          return modalRoute?.settings.name;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error getting route name: $e');
    }
    return null;
  }

  /// Handle return payment success notification
  /// Customer paid, journey is now ACTIVE, driver can proceed with return
  void _handleReturnPaymentSuccess(Map<String, dynamic> notification) {
    debugPrint('✅ [NotificationService] Return payment SUCCESS - Customer paid');
    
    final issueId = notification['issueId'] as String?;
    final vehicleAssignmentId = notification['vehicleAssignmentId'] as String?;
    final returnJourneyId = notification['returnJourneyId'] as String?;
    final orderId = notification['orderId'] as String?;
    
    debugPrint('📦 [NotificationService] Payment notification data:');
    debugPrint('   - issueId: $issueId');
    debugPrint('   - vehicleAssignmentId: $vehicleAssignmentId');
    debugPrint('   - returnJourneyId: $returnJourneyId');
    debugPrint('   - orderId: $orderId');
    
    // Play success sound
    SoundUtils.playPaymentSuccessSound();
    
    // Check current route to determine navigation behavior
    final currentRoute = _getCurrentRouteName();
    final isOnNavigationScreen = currentRoute == '/navigation';
    
    debugPrint('🔍 [NotificationService] Current route: $currentRoute');
    debugPrint('🔍 [NotificationService] Is on navigation screen: $isOnNavigationScreen');
    
    // Show simple success dialog to driver
    if (_navigatorKey?.currentContext != null) {
      showDialog(
        context: _navigatorKey!.currentContext!,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.green.shade600,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              // Message
              const Text(
                'Khách hàng đã thanh toán\nVui lòng trả hàng về điểm lấy hàng',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  
                  // Refresh order list to show updated journey
                  _refreshOrderList();
                  
                  // Handle navigation based on current screen
                  if (isOnNavigationScreen) {
                    // Already on navigation screen - just trigger refresh to resume simulation
                    debugPrint('✅ [NotificationService] On navigation screen, triggering refresh to resume');
                    triggerNavigationScreenRefresh();
                  } else {
                    // Not on navigation screen - navigate there with simulation mode
                    debugPrint('🗺️ [NotificationService] Not on navigation screen, navigating there');
                    _navigateToNavigationScreen(orderId: orderId);
                  }
                  
                  debugPrint('🗺️ [NotificationService] Handled payment success for return journey: $returnJourneyId');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Đã hiểu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        ),
      );
    }
  }
  
  /// Navigate to navigation screen with simulation mode
  /// Pattern 1: Info-only notification - auto resume after fetch
  void _navigateToNavigationScreen({String? orderId}) {
    if (_navigatorKey?.currentContext != null) {
      debugPrint('🗺️ [NotificationService] Navigating to navigation screen (Pattern 1: auto-resume)...');
      debugPrint('   - orderId: $orderId');
      
      Navigator.of(_navigatorKey!.currentContext!).pushNamedAndRemoveUntil(
        '/navigation',
        (route) => false,
        arguments: {
          'orderId': orderId, // Pass orderId from notification
          'isSimulationMode': true, // Enable simulation mode
        },
      );
    } else {
      debugPrint('❌ [NotificationService] Cannot navigate - navigator key or context is null');
    }
  }
  
  /// Navigate to navigation screen for action-required notification
  /// Pattern 2: Action-required - show bottom sheet without auto-resume
  void _navigateToNavigationScreenForAction({
    bool shouldShowSealBottomSheet = false,
    String? issueIdForSeal,
  }) {
    if (_navigatorKey?.currentContext != null) {
      debugPrint('🗺️ [NotificationService] Navigating to navigation screen (Pattern 2: show bottom sheet)...');
      debugPrint('   - shouldShowSealBottomSheet: $shouldShowSealBottomSheet');
      debugPrint('   - issueIdForSeal: $issueIdForSeal');
      
      Navigator.of(_navigatorKey!.currentContext!).pushNamedAndRemoveUntil(
        '/navigation',
        (route) => false,
        arguments: {
          'orderId': null,
          'isSimulationMode': false, // DON'T auto-start simulation
          'shouldShowSealBottomSheet': shouldShowSealBottomSheet,
          'issueIdForSeal': issueIdForSeal,
        },
      );
      
      // Also trigger the bottom sheet stream for the navigation screen to pick up
      if (shouldShowSealBottomSheet && issueIdForSeal != null) {
        // Delay slightly to ensure navigation screen is mounted
        Future.delayed(const Duration(milliseconds: 500), () {
          _showSealBottomSheetController.add(issueIdForSeal);
        });
      }
    } else {
      debugPrint('❌ [NotificationService] Cannot navigate - navigator key or context is null');
    }
  }
  
  /// Handle return payment timeout notification
  /// Payment deadline passed, journey remains INACTIVE
  void _handleReturnPaymentTimeout(Map<String, dynamic> notification) {
    debugPrint('⏰ [NotificationService] Return payment TIMEOUT - Continue original route');
    
    final issueId = notification['issueId'] as String?;
    final vehicleAssignmentId = notification['vehicleAssignmentId'] as String?;
    
    // Refresh order list
    _refreshOrderList();
  }
  
  /// Handle return payment rejected notification
  /// Customer rejected payment, journey remains INACTIVE
  void _handleReturnPaymentRejected(Map<String, dynamic> notification) {
    debugPrint('❌ [NotificationService] Return payment REJECTED - Customer refused to pay');
    
    final issueId = notification['issueId'] as String?;
    final vehicleAssignmentId = notification['vehicleAssignmentId'] as String?;
    
    // Refresh order list
    _refreshOrderList();
  }
  
  /// Handle damage resolved notification
  /// Staff resolved damage issue, driver can continue the trip
  /// Pattern 1: Info-only notification
  /// Flow: Confirm modal → Navigate to navigation screen (if needed) → Fetch order → Auto resume simulation
  void _handleDamageResolved(Map<String, dynamic> notification) {
    debugPrint('📦 [NotificationService] Damage issue RESOLVED - Driver can continue trip');
    
    final issue = notification['issue'] as Map<String, dynamic>?;
    final issueId = issue?['id'] as String?;
    
    debugPrint('✅ [NotificationService] Damage issue $issueId resolved, showing global dialog');
    
    // Play sound for damage resolved notification
    SoundUtils.playDamageResolvedSound();
    
    // Show dialog to driver
    _showDamageResolvedNotification(notification);
  }
  
  /// Show damage resolved notification dialog
  /// Pattern 1: Info-only notification - navigate + fetch + auto-resume
  void _showDamageResolvedNotification(Map<String, dynamic> notification) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      debugPrint('❌ [NotificationService] Navigator key is null, cannot show dialog');
      return;
    }

    final issue = notification['issue'] as Map<String, dynamic>?;
    if (issue == null) {
      debugPrint('❌ [NotificationService] Missing issue data in notification');
      return;
    }
    
    // Get issue ID and check for duplicates
    final issueId = issue['id'] as String?;
    if (issueId == null) {
      debugPrint('❌ [NotificationService] Missing issue ID in notification');
      return;
    }
    
    // Create unique notification ID
    final timestamp = notification['timestamp'] ?? DateTime.now().toIso8601String();
    final notificationId = '$issueId-damage-resolved-$timestamp';
    
    // Check if this notification was already shown
    if (_lastNotificationId == notificationId || _shownNotifications.contains(notificationId)) {
      debugPrint('⚠️ [NotificationService] Duplicate notification detected, skipping: $notificationId');
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
    
    debugPrint('✅ [NotificationService] New DAMAGE_RESOLVED notification: $notificationId');
    
    // Check current route
    final currentRoute = _getCurrentRouteName();
    final isOnNavigationScreen = currentRoute == '/navigation';
    
    debugPrint('🔍 [NotificationService] Current route: $currentRoute');
    debugPrint('🔍 [NotificationService] Is on navigation screen: $isOnNavigationScreen');
    
    // Show global notification dialog
    showDialog(
      context: _navigatorKey!.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sự cố đã được xử lý',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['message'] ?? 'Sự cố hàng hóa đã được xử lý xong. Bạn có thể tiếp tục hành trình.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hành trình sẽ tự động tiếp tục',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Pattern 1: Info-only notification
              // Navigate to navigation screen (if needed) + fetch + auto-resume
              if (!isOnNavigationScreen) {
                debugPrint('🗺️ [NotificationService] Not on navigation screen, navigating there...');
                _navigateToNavigationScreen();
              } else {
                debugPrint('✅ [NotificationService] Already on navigation screen, triggering refresh...');
                // Already on navigation screen, just trigger refresh to fetch + resume
                triggerNavigationScreenRefresh();
              }
            },
            child: const Text('Đã hiểu', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    
    debugPrint('🔄 [NotificationService] DAMAGE_RESOLVED dialog displayed globally');
  }
  
  /// Handle order rejection resolved notification
  /// Staff resolved ORDER_REJECTION issue, driver can proceed with return route
  /// Pattern 1: Info-only notification
  /// Flow: Confirm modal → Navigate to navigation screen (if needed) → Fetch order → Auto resume simulation
  void _handleOrderRejectionResolved(Map<String, dynamic> notification) {
    debugPrint('📦 [NotificationService] ORDER_REJECTION issue RESOLVED - Driver can proceed');
    
    final issue = notification['issue'] as Map<String, dynamic>?;
    final issueId = issue?['id'] as String?;
    
    debugPrint('✅ [NotificationService] ORDER_REJECTION issue $issueId resolved, showing global dialog');
    
    // Play sound for order rejection resolved notification
    SoundUtils.playOrderRejectionResolvedSound();
    
    // Show dialog to driver
    _showOrderRejectionResolvedNotification(notification);
  }
  
  /// Show order rejection resolved notification dialog
  /// Pattern 1: Info-only notification - navigate + fetch + auto-resume
  void _showOrderRejectionResolvedNotification(Map<String, dynamic> notification) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      debugPrint('❌ [NotificationService] Navigator key is null, cannot show dialog');
      return;
    }

    final issue = notification['issue'] as Map<String, dynamic>?;
    if (issue == null) {
      debugPrint('❌ [NotificationService] Missing issue data in notification');
      return;
    }
    
    // Get issue ID and check for duplicates
    final issueId = issue['id'] as String?;
    if (issueId == null) {
      debugPrint('❌ [NotificationService] Missing issue ID in notification');
      return;
    }
    
    // Create unique notification ID
    final timestamp = notification['timestamp'] ?? DateTime.now().toIso8601String();
    final notificationId = '$issueId-order-rejection-resolved-$timestamp';
    
    // Check if this notification was already shown
    if (_lastNotificationId == notificationId || _shownNotifications.contains(notificationId)) {
      debugPrint('⚠️ [NotificationService] Duplicate notification detected, skipping: $notificationId');
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
    
    debugPrint('✅ [NotificationService] New ORDER_REJECTION_RESOLVED notification: $notificationId');

    // Check current route
    final currentRoute = _getCurrentRouteName();
    final isOnNavigationScreen = currentRoute == '/navigation';
    
    debugPrint('🔍 [NotificationService] Current route: $currentRoute');
    debugPrint('🔍 [NotificationService] Is on navigation screen: $isOnNavigationScreen');
    
    // Show global notification dialog
    showDialog(
      context: _navigatorKey!.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Yêu cầu trả hàng đã xử lý',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['message'] ?? 'Nhân viên đã xử lý yêu cầu trả hàng. Bạn có thể tiếp tục hành trình.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hành trình sẽ tự động tiếp tục',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Pattern 1: Info-only notification
              // Navigate to navigation screen (if needed) + fetch + auto-resume
              if (!isOnNavigationScreen) {
                debugPrint('🗺️ [NotificationService] Not on navigation screen, navigating there...');
                _navigateToNavigationScreen();
              } else {
                debugPrint('✅ [NotificationService] Already on navigation screen, triggering refresh...');
                // Already on navigation screen, just trigger refresh to fetch + resume
                triggerNavigationScreenRefresh();
              }
            },
            child: const Text('Đã hiểu', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    
    debugPrint('🔄 [NotificationService] ORDER_REJECTION_RESOLVED dialog displayed globally');
  }
  
  /// Trigger order list refresh
  /// Note: Since OrderListViewModel is registered as Factory, we cannot directly refresh
  /// The UI will auto-refresh when user navigates to orders screen via Provider
  void _refreshOrderList() {
    debugPrint('🔄 [NotificationService] Order list needs refresh - will update when user opens orders screen');
    // TODO: Implement proper event-based refresh mechanism
    // For now, rely on UI auto-refresh when screen becomes active
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
    _refreshController.close();
    _showSealBottomSheetController.close();
  }
}
