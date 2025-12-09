import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/sound_utils.dart';
import '../constants/api_constants.dart';
import '../services/token_storage_service.dart';
import '../services/navigation_state_service.dart';
import '../../presentation/widgets/common/seal_assignment_notification_dialog.dart';
import '../../presentation/widgets/common/damage_resolved_notification_dialog.dart';
import '../../presentation/widgets/common/order_rejection_resolved_notification_dialog.dart';
import '../../presentation/features/delivery/widgets/report_seal_issue_bottom_sheet.dart';
import '../../app/di/service_locator.dart';
import '../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/issue_repository.dart';
import '../../domain/entities/order_detail.dart';
import 'global_dialog_service.dart';

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
  static const int _maxRetries = 10; // Increased from 3 to 10 for better reliability
  Completer<void>? _connectionCompleter;
  Timer? _reconnectTimer; // Track reconnection timer
  
  // Track shown notifications to prevent duplicates
  final Set<String> _shownNotifications = {};
  String? _lastNotificationId;
  bool _isInitialized = false;
  bool _isManualDisconnect = false; // Track if disconnect is intentional

  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  bool get isConnected => _stompClient?.connected ?? false;

  // Flutter Local Notifications
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;

  // ✅ CRITICAL: Stream controllers for dialog events (to avoid context issues)
  final StreamController<Map<String, dynamic>> _sealAssignmentController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get sealAssignmentStream => _sealAssignmentController.stream;
  
  final StreamController<Map<String, dynamic>> _damageResolvedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get damageResolvedStream => _damageResolvedController.stream;
  
  final StreamController<Map<String, dynamic>> _orderRejectionResolvedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get orderRejectionResolvedStream => _orderRejectionResolvedController.stream;
  
  final StreamController<Map<String, dynamic>> _paymentTimeoutController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get paymentTimeoutStream => _paymentTimeoutController.stream;
  
  final StreamController<Map<String, dynamic>> _rerouteResolvedController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get rerouteResolvedStream => _rerouteResolvedController.stream;

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
          
        },
      );

      _localNotificationsInitialized = true;
      
    } catch (e) {
      
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

      
    } catch (e) {
      
    }
  }

  /// Initialize with navigator key for showing dialogs
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    if (_isInitialized) {
      print('⚠️ [NotificationService] initialize called but already initialized');
      return;
    }

    print('🚀 [NotificationService] initialize called');
    _navigatorKey = navigatorKey;
    _authViewModel = getIt<AuthViewModel>();
    _listenToNotifications();
    _isInitialized = true;
    print('✅ [NotificationService] Initialization completed');
  }

  /// Connect to WebSocket with driver ID
  Future<void> connect(String driverId) async {
    print('🚀 [NotificationService] connect called with driverId=$driverId');

    // CRITICAL: Always disconnect to ensure fresh connection
    // Even if isConnected is false, the client might still exist and try to reconnect
    if (_stompClient != null) {
      print('🔌 [NotificationService] Existing StompClient found, disconnecting before reconnect...');
      disconnect();
      // Give old client time to fully disconnect
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Reset manual disconnect flag when starting new connection
    _isManualDisconnect = false;
    _currentDriverId = driverId;
    print('🔑 [NotificationService] _currentDriverId set to $driverId');

    // Get JWT token for authentication
    final tokenStorageService = getIt<TokenStorageService>();
    final jwtToken = tokenStorageService.getAccessToken();
    
    if (jwtToken == null || jwtToken.isEmpty) {
      
      return;
    }

    final wsUrl = '${ApiConstants.wsBaseUrl}${ApiConstants.wsVehicleTrackingEndpoint}';
    print('🌐 [NotificationService] WebSocket URL: $wsUrl');

    // Create a new completer for this connection attempt
    _connectionCompleter = Completer<void>();

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        webSocketConnectHeaders: {'Authorization': 'Bearer $jwtToken'},
        onConnect: (StompFrame frame) {
          print('✅ [NotificationService] WebSocket connected');
          print('   STOMP headers: ${frame.headers}');
          _subscribeToDriverNotifications(driverId);
          // Reset retry count on successful connection
          _retryCount = 0;
          
          // Check and log connection status after successful connection
          Future.delayed(const Duration(seconds: 1), () {
            checkConnectionStatus();
          });
          
          // Complete the connection completer
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.complete();
            print('✅ [NotificationService] Connection completer completed');
          }
        },
        onWebSocketError: (dynamic error) {
          print('❌ [NotificationService] WebSocket error: $error');
          // Complete the completer with error
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.completeError(error);
          }
          
          _handleWebSocketError(error);
        },
        onStompError: (StompFrame frame) {
          print('❌ [NotificationService] STOMP error: ${frame.body}');
          // Complete the completer with error
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.completeError(frame.body ?? 'STOMP error');
          }
          
          _handleStompError(frame);
        },
        onDisconnect: (StompFrame frame) {
          print('⚠️ [NotificationService] WebSocket disconnected. isManualDisconnect=$_isManualDisconnect');
          // CRITICAL: Auto-reconnect when connection is lost
          // This ensures driver always receives notifications even after network issues
          if (_currentDriverId != null && !_isManualDisconnect) {
            print('🔄 [NotificationService] Scheduling reconnect for driverId=$_currentDriverId');
            _retryConnection();
          } else {
            print('ℹ️ [NotificationService] Manual disconnect or no currentDriverId, will not auto-reconnect');
          }
        },
        // CRITICAL: Disable auto-reconnect to prevent reconnection with stale tokens
        // We handle reconnection manually via _retryConnection() with fresh tokens
        reconnectDelay: const Duration(seconds: 0),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
      ),
    );

    print('⚡ [NotificationService] Activating StompClient...');
    _stompClient!.activate();
    print('✅ [NotificationService] StompClient.activate() called');
    // Wait for connection to complete (with timeout)
    try {
      await _connectionCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ [NotificationService] WebSocket connection timeout');
          throw TimeoutException('WebSocket connection timeout');
        },
      );
      print('✅ [NotificationService] WebSocket connection future completed');
    } catch (e) {
      print('❌ [NotificationService] Error while waiting for connection: $e');
      // Don't rethrow - let the app continue even if connection fails
    }
  }

  /// Subscribe to driver-specific notification topic
  void _subscribeToDriverNotifications(String driverId) {
    print('📡 [NotificationService] _subscribeToDriverNotifications called');
    print('   Driver ID: $driverId');
    
    // Unsubscribe from previous subscription if exists
    if (_currentSubscription != null) {
      print('   Unsubscribing from previous subscription...');
      try {
        _currentSubscription.unsubscribe();
      } catch (e) {
        print('   Error unsubscribing: $e');
      }
      _currentSubscription = null;
    }
    
    final topic = '/topic/driver/$driverId/notifications';
    print('   Subscribing to topic: $topic');
    
    // Check if stomp client is available and connected before subscribing
    if (_stompClient == null || !_stompClient!.connected) {
      print('⚠️ WebSocket client not available or not connected, skipping subscription');
      return;
    }

    _currentSubscription = _stompClient!.subscribe(
      destination: topic,
      callback: (StompFrame frame) {
        print('📬 WebSocket message received on topic: $topic');
        print('   Frame headers: ${frame.headers}');
        print('   Frame body length: ${frame.body?.length ?? 0}');
        
        if (frame.body != null) {
          try {
            print('🔍 Parsing JSON body...');
            final notification = jsonDecode(frame.body!);
            print('✅ JSON parsed successfully: $notification');
            print('   Notification type: ${notification['type']}');
            
            _notificationController.add(notification);
            print('📤 Notification added to stream controller');
          } catch (e) {
            print('❌ JSON parse error: $e');
            print('   Raw body: ${frame.body}');
          }
        } else {
          print('⚠️ Frame body is null');
        }
      },
    );
    
    print('✅ [NotificationService] Successfully subscribed to topic: $topic');
    print('   Subscription active: ${_currentSubscription != null}');
  }

  /// Listen to notification stream and handle notifications
  void _listenToNotifications() {
    print('🎧 Setting up notification stream listener...');
    _notificationController.stream.listen((notification) {
      print('🔊 Notification stream received: $notification');
      _handleNotification(notification);
    });
    print('✅ Notification stream listener setup complete');
  }

  /// Handle incoming notification
  void _handleNotification(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    final title = notification['title'] as String?;
    final body = notification['message'] as String?;
    final priority = notification['priority'] as String?;

    print('📨 _handleNotification called');
    print('   Type: $type');
    print('   Title: $title');
    print('   Body: $body');
    print('   Priority: $priority');
    print('   Full notification: $notification');

    switch (type) {
      case 'SEAL_ASSIGNMENT':
      case 'SEAL_ASSIGNED':
        // Hỗ trợ cả hai kiểu type để tương thích với backend cũ/mới
        print('🔄 Dispatching to GlobalDialogService.handleSealAssignment');
        _delegateToGlobalDialogService(GlobalDialogType.sealAssignment, notification);
        break;
      case 'RETURN_PAYMENT_SUCCESS':
        print('🔄 Dispatching to GlobalDialogService.handleReturnPaymentSuccess');
        _delegateToGlobalDialogService(GlobalDialogType.returnPaymentSuccess, notification);
        break;
      case 'RETURN_PAYMENT_TIMEOUT':
        print('🔄 Dispatching to GlobalDialogService.handleReturnPaymentTimeout');
        _delegateToGlobalDialogService(GlobalDialogType.returnPaymentTimeout, notification);
        break;
      case 'RETURN_PAYMENT_REJECTED':
        _handleReturnPaymentRejected(notification);
        break;
      case 'DAMAGE_RESOLVED':
        print('🔄 Dispatching to GlobalDialogService.handleDamageResolved');
        _delegateToGlobalDialogService(GlobalDialogType.damageResolved, notification);
        break;
      case 'ORDER_REJECTION_RESOLVED':
        print('🔄 Dispatching to GlobalDialogService.handleOrderRejectionResolved');
        _delegateToGlobalDialogService(GlobalDialogType.orderRejectionResolved, notification);
        break;
      case 'REROUTE_RESOLVED':
        print('🔄 Dispatching to GlobalDialogService.handleRerouteResolved');
        _delegateToGlobalDialogService(GlobalDialogType.rerouteResolved, notification);
        break;
      default:
        
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

  /// Delegate notification handling to GlobalDialogService
  /// This ensures dialogs are shown regardless of current screen
  void _delegateToGlobalDialogService(GlobalDialogType type, Map<String, dynamic> notification) {
    try {
      final globalDialogService = getIt<GlobalDialogService>();
      
      // Extract relevant data based on notification type
      Map<String, dynamic> data;
      
      switch (type) {
        case GlobalDialogType.returnPaymentSuccess:
          data = {
            'issueId': notification['issueId'],
            'vehicleAssignmentId': notification['vehicleAssignmentId'],
            'orderId': notification['orderId'],
            'returnJourneyId': notification['returnJourneyId'],
            'timestamp': notification['timestamp'] ?? DateTime.now().toIso8601String(),
          };
          globalDialogService.handleReturnPaymentSuccess(data);
          break;
          
        case GlobalDialogType.returnPaymentTimeout:
          data = {
            'issue': notification['issue'],
            'issueId': notification['issueId'],
            'vehicleAssignmentId': notification['vehicleAssignmentId'],
            'timestamp': notification['timestamp'] ?? DateTime.now().toIso8601String(),
          };
          globalDialogService.handleReturnPaymentTimeout(data);
          break;
          
        case GlobalDialogType.sealAssignment:
          final issue = notification['issue'] as Map<String, dynamic>?;
          data = {
            'issueId': issue?['id'],
            'oldSeal': issue?['oldSeal'],
            'newSeal': issue?['newSeal'],
            'staff': issue?['staff'],
            'timestamp': notification['timestamp'] ?? DateTime.now().toIso8601String(),
          };
          globalDialogService.handleSealAssignment(data);
          break;
          
        case GlobalDialogType.damageResolved:
          data = {
            'issue': notification['issue'],
            'timestamp': notification['timestamp'] ?? DateTime.now().toIso8601String(),
          };
          globalDialogService.handleDamageResolved(data);
          break;
          
        case GlobalDialogType.orderRejectionResolved:
          data = {
            'issue': notification['issue'],
            'timestamp': notification['timestamp'] ?? DateTime.now().toIso8601String(),
          };
          globalDialogService.handleOrderRejectionResolved(data);
          break;
          
        case GlobalDialogType.rerouteResolved:
          data = {
            'issueId': notification['issueId'],
            'orderId': notification['orderId'],
            'timestamp': notification['timestamp'] ?? DateTime.now().toIso8601String(),
          };
          globalDialogService.handleRerouteResolved(data);
          break;
      }
      
      print('✅ [NotificationService] Delegated $type to GlobalDialogService');
    } catch (e) {
      print('❌ [NotificationService] Failed to delegate to GlobalDialogService: $e');
    }
  }

  /// Show seal assignment notification dialog
  /// Pattern 2: Action-required notification
  /// Flow: Confirm modal → Navigate to navigation screen → Show bottom sheet (DON'T resume)
  /// After bottom sheet submit → Fetch order → Auto resume simulation
  void _showSealAssignmentNotification(Map<String, dynamic> notification, {int retryCount = 0}) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      
      
      // CRITICAL: Retry after a delay to wait for MaterialApp to mount
      // This fixes the issue where dialogs don't show on first app launch
      if (retryCount < 5) {
        
        Future.delayed(const Duration(milliseconds: 500), () {
          _showSealAssignmentNotification(notification, retryCount: retryCount + 1);
        });
      } else {
        
      }
      return;
    }

    // Play sound for seal assignment notification
    SoundUtils.playSealAssignmentSound();

    print('🔍 Parsing seal assignment notification data...');
    final issue = notification['issue'] as Map<String, dynamic>?;
    if (issue == null) {
      print('❌ Issue data is null in notification');
      return;
    }
    
    print('   Issue data found: $issue');
    final issueId = issue['id'] as String?;
    if (issueId == null) {
      print('❌ Issue ID is null');
      return;
    }
    
    print('   Issue ID: $issueId');
    
    // Create unique notification ID from issue ID and timestamp
    final timestamp = notification['timestamp'] ?? DateTime.now().toIso8601String();
    final notificationId = '$issueId-$timestamp';
    
    // Check if this exact notification was already shown
    if (_lastNotificationId == notificationId || _shownNotifications.contains(notificationId)) {
      
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
    
    

    // Extract seal codes from issue
    final oldSeal = issue['oldSeal'] as Map<String, dynamic>?;
    final newSeal = issue['newSeal'] as Map<String, dynamic>?;
    final staff = issue['staff'] as Map<String, dynamic>?;
    
    // Check current route
    final currentRoute = _getCurrentRouteName();
    final isOnNavigationScreen = currentRoute == '/navigation';
    
    // ✅ CRITICAL: Check if stream has listeners before emitting
    if (!_sealAssignmentController.hasListener) {
      print('⚠️ Seal assignment: No listeners yet, scheduling retry...');
      
      if (retryCount < 5) {
        print('🔄 Will retry in 300ms (attempt ${retryCount + 1}/5)');
        Future.delayed(const Duration(milliseconds: 300), () {
          _showSealAssignmentNotification(notification, retryCount: retryCount + 1);
        });
      } else {
        print('❌ Max retries reached, no listeners available');
      }
      return;
    }
    
    // ✅ CRITICAL: Emit event to stream instead of showing dialog directly
    // This allows NavigationScreen to show dialog with proper BuildContext
    print('📢 [NotificationService] Emitting seal assignment event to stream');
    print('   Has listeners: ${_sealAssignmentController.hasListener}');
    print('   Listener count: ${_sealAssignmentController.hasListener ? "1+" : "0"}');
    print('   Issue ID: $issueId');
    print('   Old Seal: ${oldSeal?['sealCode']}');
    print('   New Seal: ${newSeal?['sealCode']}');
    print('   Staff: ${staff?['fullName']}');
    print('   Is on NavigationScreen: $isOnNavigationScreen');
    
    final eventData = {
      'issueId': issueId,
      'oldSeal': oldSeal,
      'newSeal': newSeal,
      'staff': staff,
      'isOnNavigationScreen': isOnNavigationScreen,
    };
    
    print('📦 [NotificationService] Event data prepared: ${eventData.keys}');
    _sealAssignmentController.add(eventData);
    print('✅ [NotificationService] Seal assignment event emitted to ${_sealAssignmentController.hasListener ? "active listeners" : "NO LISTENERS (will be lost!)"}');
  }

  /// Refresh pending seals in navigation screen
  void refreshPendingSeals() {
    // 
    
    // 🆕 Navigate to navigation screen to trigger refresh
    if (_navigatorKey?.currentContext != null) {
      // 
      
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
      // 
    }
  }
  
  /// Trigger manual refresh of navigation screen without navigation
  void triggerNavigationScreenRefresh() {
    // 
    
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
  
  // Stream controller for return payment success notification
  final _returnPaymentSuccessController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get returnPaymentSuccessStream => _returnPaymentSuccessController.stream;

  /// Force reconnect with current driver (useful after token refresh)
  Future<void> forceReconnect() async {
    if (_currentDriverId != null) {
      
      _retryCount = 0; // Reset retry count for fresh attempt
      await connect(_currentDriverId!);
    } else {
      
    }
  }

  /// Debug method to check WebSocket connection status
  void checkConnectionStatus() {
    
    
    
    
    
    
    
    
    
    
    
  }

  /// Disconnect from WebSocket
  void disconnect() {
    // Set manual disconnect flag to prevent auto-reconnect
    _isManualDisconnect = true;
    
    // Cancel any pending reconnect timer
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    // Unsubscribe first
    if (_currentSubscription != null) {
      // 
      try {
        _currentSubscription.unsubscribe();
      } catch (e) {
        // 
      }
      _currentSubscription = null;
    }
    
    // CRITICAL: Always deactivate and null out the client
    // This prevents zombie clients from attempting reconnection with stale tokens
    if (_stompClient != null) {
      try {
        // 
        _stompClient!.deactivate();
      } catch (e) {
        // 
      }
      _stompClient = null; // CRITICAL: Set to null to prevent reconnect attempts
    }
    
    _currentDriverId = null;
    _retryCount = 0;
    
    // Clear notification tracking
    _shownNotifications.clear();
    _lastNotificationId = null;
    // 
  }

  /// Handle WebSocket error with token refresh logic
  Future<void> _handleWebSocketError(dynamic error) async {
    // 
    
    // Check if error is related to authentication (401)
    if (error.toString().contains('401') || error.toString().contains('unauthorized')) {
      // 
      await _handleAuthError();
    } else {
      // For other errors, just retry connection with exponential backoff
      _retryConnection();
    }
  }

  /// Handle STOMP error with token refresh logic
  Future<void> _handleStompError(StompFrame frame) async {
    // 
    
    // Check if error is related to authentication
    if (frame.body?.toString().contains('401') == true || 
        frame.body?.toString().contains('unauthorized') == true) {
      // 
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
      
    }
    return null;
  }

  /// Handle return payment success notification
  /// Customer paid, journey is now ACTIVE, driver MUST report seal removal before proceeding
  void _handleReturnPaymentSuccess(Map<String, dynamic> notification, {int retryCount = 0}) {
    print('🔔 RETURN_PAYMENT_SUCCESS notification received: $notification');
    print('📱 Retry count: $retryCount');
    print('🗝️ Navigator key available: ${_navigatorKey != null}');
    
    final issueId = notification['issueId'] as String?;
    final vehicleAssignmentId = notification['vehicleAssignmentId'] as String?;
    final returnJourneyId = notification['returnJourneyId'] as String?;
    final orderId = notification['orderId'] as String?;
    
    print('📦 Extracted data - issueId: $issueId, vehicleAssignmentId: $vehicleAssignmentId, orderId: $orderId');
    
    
    
    
    
    
    
    // CRITICAL: Check if navigator key is available
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      print('⚠️ Navigator key not available, scheduling retry...');
      print('   _navigatorKey: $_navigatorKey');
      print('   currentContext: ${_navigatorKey?.currentContext}');
      
      // CRITICAL: Retry after a delay to wait for MaterialApp to mount
      if (retryCount < 3) {
        print('🔄 Will retry in 500ms (attempt ${retryCount + 1}/3)');
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleReturnPaymentSuccess(notification, retryCount: retryCount + 1);
        });
      } else {
        print('❌ Max retries reached, notification dialog cannot be shown');
      }
      return;
    }
    
    print('✅ Navigator key available, checking for listeners...');
    
    // ✅ CRITICAL: Check if stream has listeners before emitting
    // Broadcast streams don't buffer - if no listener, event is lost
    if (!_returnPaymentSuccessController.hasListener) {
      print('⚠️ No listeners yet, scheduling retry...');
      
      // Retry after delay to wait for NavigationScreen to mount and setup listeners
      if (retryCount < 5) {
        print('🔄 Will retry in 300ms (attempt ${retryCount + 1}/5)');
        Future.delayed(const Duration(milliseconds: 300), () {
          _handleReturnPaymentSuccess(notification, retryCount: retryCount + 1);
        });
      } else {
        print('❌ Max retries reached, no listeners available');
      }
      return;
    }
    
    print('✅ Listener detected, emitting return payment event...');
    
    // Play success sound
    SoundUtils.playPaymentSuccessSound();
    
    // 🔐 CRITICAL: Emit event to stream instead of showing dialog directly
    // This allows screens to show dialog with proper context that has Provider access
    _returnPaymentSuccessController.add({
      'issueId': issueId,
      'vehicleAssignmentId': vehicleAssignmentId,
      'orderId': orderId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Refresh order list to show updated journey
    _refreshOrderList();
    
    print('✅ Return payment event emitted to stream');
  }
  
  /// Navigate to navigation screen with simulation mode
  /// Pattern 1: Info-only notification - auto resume after fetch
  void _navigateToNavigationScreen({String? orderId}) {
    if (_navigatorKey?.currentContext != null) {
      
      
      
      Navigator.of(_navigatorKey!.currentContext!).pushNamedAndRemoveUntil(
        '/navigation',
        (route) => false,
        arguments: {
          'orderId': orderId, // Pass orderId from notification
          'isSimulationMode': true, // Enable simulation mode
        },
      );
    } else {
      
    }
  }
  
  /// Navigate to navigation screen for action-required notification
  /// Pattern 2: Action-required - show bottom sheet without auto-resume
  void _navigateToNavigationScreenForAction({
    bool shouldShowSealBottomSheet = false,
    String? issueIdForSeal,
  }) {
    if (_navigatorKey?.currentContext != null) {
      
      
      
      // CRITICAL: Get orderId from NavigationStateService (saved during tracking)
      final navigationStateService = getIt<NavigationStateService>();
      final savedOrderId = navigationStateService.getActiveOrderId();
      
      Navigator.of(_navigatorKey!.currentContext!).pushNamedAndRemoveUntil(
        '/navigation',
        (route) => false,
        arguments: {
          'orderId': savedOrderId, // Pass orderId from saved state
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
      
    }
  }
  
  /// Handle return payment timeout notification
  /// Payment deadline passed, journey remains INACTIVE, driver continues to carrier
  void _handleReturnPaymentTimeout(Map<String, dynamic> notification, {int retryCount = 0}) {
    
    
    
    
    
    
    final issue = notification['issue'] as Map<String, dynamic>?;
    final issueId = notification['issueId'] as String?;
    final vehicleAssignmentId = notification['vehicleAssignmentId'] as String?;
    
    // Play warning sound
    SoundUtils.playWarningSound();
    
    // Check current route
    final currentRoute = _getCurrentRouteName();
    final isOnNavigationScreen = currentRoute == '/navigation';
    
    // ✅ CRITICAL: Check if stream has listeners before emitting
    if (!_paymentTimeoutController.hasListener) {
      print('⚠️ Payment timeout: No listeners yet, scheduling retry...');
      
      if (retryCount < 5) {
        print('🔄 Will retry in 300ms (attempt ${retryCount + 1}/5)');
        Future.delayed(const Duration(milliseconds: 300), () {
          _handleReturnPaymentTimeout(notification, retryCount: retryCount + 1);
        });
      } else {
        print('❌ Max retries reached, no listeners available');
      }
      return;
    }
    
    // ✅ CRITICAL: Emit event to stream instead of showing dialog directly
    print('📢 Emitting payment timeout event to stream');
    _paymentTimeoutController.add({
      'issue': issue,
      'issueId': issueId,
      'vehicleAssignmentId': vehicleAssignmentId,
      'isOnNavigationScreen': isOnNavigationScreen,
    });
  }
  
  /// Handle return payment rejected notification
  /// Customer rejected payment, journey remains INACTIVE
  /// NOTE: This notification does NOT show dialog, only refreshes order list
  void _handleReturnPaymentRejected(Map<String, dynamic> notification) {
    
    
    final issueId = notification['issueId'] as String?;
    final vehicleAssignmentId = notification['vehicleAssignmentId'] as String?;
    
    
    
    
    
    
    // Refresh order list to show updated status
    _refreshOrderList();
  }
  
  /// Handle damage resolved notification
  /// Staff resolved damage issue, driver can continue the trip
  /// Pattern 1: Info-only notification
  /// Flow: Confirm modal → Navigate to navigation screen (if needed) → Fetch order → Auto resume simulation
  void _handleDamageResolved(Map<String, dynamic> notification, {int retryCount = 0}) {
    
    
    final issue = notification['issue'] as Map<String, dynamic>?;
    final issueId = issue?['id'] as String?;
    
    
    
    // Play sound for damage resolved notification
    SoundUtils.playDamageResolvedSound();
    
    // Show dialog to driver
    _showDamageResolvedNotification(notification);
  }
  
  /// Show damage resolved notification dialog
  /// Pattern 1: Info-only notification - navigate + fetch + auto-resume
  void _showDamageResolvedNotification(Map<String, dynamic> notification, {int retryCount = 0}) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      
      
      // CRITICAL: Retry after a delay to wait for MaterialApp to mount
      if (retryCount < 5) {
        
        Future.delayed(const Duration(milliseconds: 500), () {
          _showDamageResolvedNotification(notification, retryCount: retryCount + 1);
        });
      } else {
        
      }
      return;
    }

    final issue = notification['issue'] as Map<String, dynamic>?;
    if (issue == null) {
      
      return;
    }
    
    // Get issue ID and check for duplicates
    final issueId = issue['id'] as String?;
    if (issueId == null) {
      
      return;
    }
    
    // Create unique notification ID
    final timestamp = notification['timestamp'] ?? DateTime.now().toIso8601String();
    final notificationId = '$issueId-damage-resolved-$timestamp';
    
    // Check if this notification was already shown
    if (_lastNotificationId == notificationId || _shownNotifications.contains(notificationId)) {
      
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
    
    
    
    // Check current route
    final currentRoute = _getCurrentRouteName();
    final isOnNavigationScreen = currentRoute == '/navigation';
    
    // ✅ CRITICAL: Check if stream has listeners before emitting
    if (!_damageResolvedController.hasListener) {
      print('⚠️ Damage resolved: No listeners yet, scheduling retry...');
      
      if (retryCount < 5) {
        print('🔄 Will retry in 300ms (attempt ${retryCount + 1}/5)');
        Future.delayed(const Duration(milliseconds: 300), () {
          _showDamageResolvedNotification(notification, retryCount: retryCount + 1);
        });
      } else {
        print('❌ Max retries reached, no listeners available');
      }
      return;
    }
    
    // ✅ CRITICAL: Emit event to stream instead of showing dialog directly
    print('📢 Emitting damage resolved event to stream');
    _damageResolvedController.add({
      'issue': issue,
      'isOnNavigationScreen': isOnNavigationScreen,
    });
  }
  
  /// Handle order rejection resolved notification
  /// Staff resolved ORDER_REJECTION issue, driver can proceed with return route
  /// Pattern 1: Info-only notification
  /// Flow: Confirm modal → Navigate to navigation screen (if needed) → Fetch order → Auto resume simulation
  void _handleOrderRejectionResolved(Map<String, dynamic> notification) {
    
    
    final issue = notification['issue'] as Map<String, dynamic>?;
    final issueId = issue?['id'] as String?;
    
    
    
    // Play sound for order rejection resolved notification
    SoundUtils.playOrderRejectionResolvedSound();
    
    // Show dialog to driver
    _showOrderRejectionResolvedNotification(notification);
  }
  
  /// Show order rejection resolved notification dialog
  /// Pattern 1: Info-only notification - navigate + fetch + auto-resume
  void _showOrderRejectionResolvedNotification(Map<String, dynamic> notification, {int retryCount = 0}) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      
      
      // CRITICAL: Retry after a delay to wait for MaterialApp to mount
      if (retryCount < 5) {
        
        Future.delayed(const Duration(milliseconds: 500), () {
          _showOrderRejectionResolvedNotification(notification, retryCount: retryCount + 1);
        });
      } else {
        
      }
      return;
    }

    final issue = notification['issue'] as Map<String, dynamic>?;
    if (issue == null) {
      
      return;
    }
    
    // Get issue ID and check for duplicates
    final issueId = issue['id'] as String?;
    if (issueId == null) {
      
      return;
    }
    
    // Create unique notification ID
    final timestamp = notification['timestamp'] ?? DateTime.now().toIso8601String();
    final notificationId = '$issueId-order-rejection-resolved-$timestamp';
    
    // Check if this notification was already shown
    if (_lastNotificationId == notificationId || _shownNotifications.contains(notificationId)) {
      
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
    
    

    // Check current route
    final currentRoute = _getCurrentRouteName();
    final isOnNavigationScreen = currentRoute == '/navigation';
    
    // ✅ CRITICAL: Check if stream has listeners before emitting
    if (!_orderRejectionResolvedController.hasListener) {
      print('⚠️ Order rejection resolved: No listeners yet, scheduling retry...');
      
      if (retryCount < 5) {
        print('🔄 Will retry in 300ms (attempt ${retryCount + 1}/5)');
        Future.delayed(const Duration(milliseconds: 300), () {
          _showOrderRejectionResolvedNotification(notification, retryCount: retryCount + 1);
        });
      } else {
        print('❌ Max retries reached, no listeners available');
      }
      return;
    }
    
    // ✅ CRITICAL: Emit event to stream instead of showing dialog directly
    print('📢 Emitting order rejection resolved event to stream');
    _orderRejectionResolvedController.add({
      'issue': issue,
      'isOnNavigationScreen': isOnNavigationScreen,
    });
  }
  
  /// Handle reroute resolved notification
  /// Staff created new journey, driver should fetch and continue with new route
  /// Pattern 1: Info-only notification
  /// Flow: Confirm modal → Fetch order → Re-render map → Auto resume simulation
  void _handleRerouteResolved(Map<String, dynamic> notification, {int retryCount = 0}) {
    print('🔄 _handleRerouteResolved called');
    print('   Notification: $notification');
    
    final issueId = notification['issueId'] as String?;
    final orderId = notification['orderId'] as String?;
    
    print('   Issue ID: $issueId');
    print('   Order ID: $orderId');
    
    // Play sound for reroute resolved notification
    SoundUtils.playOrderRejectionResolvedSound(); // Reuse similar sound
    
    // Show dialog to driver
    _showRerouteResolvedNotification(notification);
  }
  
  /// Show reroute resolved notification dialog
  /// Pattern 1: Info-only notification - fetch order + re-render map + auto-resume
  void _showRerouteResolvedNotification(Map<String, dynamic> notification, {int retryCount = 0}) {
    if (_navigatorKey == null || _navigatorKey!.currentContext == null) {
      print('⚠️ Navigator key or context is null, retrying...');
      
      // CRITICAL: Retry after a delay to wait for MaterialApp to mount
      if (retryCount < 5) {
        print('🔄 Will retry in 500ms (attempt ${retryCount + 1}/5)');
        Future.delayed(const Duration(milliseconds: 500), () {
          _showRerouteResolvedNotification(notification, retryCount: retryCount + 1);
        });
      } else {
        print('❌ Max retries reached for reroute resolved notification');
      }
      return;
    }

    final issueId = notification['issueId'] as String?;
    final orderId = notification['orderId'] as String?;
    
    if (issueId == null || orderId == null) {
      print('❌ Missing issueId or orderId in reroute notification');
      return;
    }
    
    // Create unique notification ID
    final timestamp = notification['timestamp'] ?? DateTime.now().toIso8601String();
    final notificationId = '$issueId-reroute-resolved-$timestamp';
    
    // Check if this notification was already shown
    if (_lastNotificationId == notificationId || _shownNotifications.contains(notificationId)) {
      print('⚠️ Reroute notification already shown: $notificationId');
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
    
    print('✅ Reroute notification marked as shown: $notificationId');

    // Check current route
    final currentRoute = _getCurrentRouteName();
    final isOnNavigationScreen = currentRoute == '/navigation';
    
    print('   Current route: $currentRoute');
    print('   Is on navigation screen: $isOnNavigationScreen');
    
    // ✅ CRITICAL: Check if stream has listeners before emitting
    if (!_rerouteResolvedController.hasListener) {
      print('⚠️ Reroute resolved: No listeners yet, scheduling retry...');
      
      if (retryCount < 5) {
        print('🔄 Will retry in 300ms (attempt ${retryCount + 1}/5)');
        Future.delayed(const Duration(milliseconds: 300), () {
          _showRerouteResolvedNotification(notification, retryCount: retryCount + 1);
        });
      } else {
        print('❌ Max retries reached, no listeners available');
      }
      return;
    }
    
    // ✅ CRITICAL: Emit event to stream instead of showing dialog directly
    print('📢 Emitting reroute resolved event to stream');
    _rerouteResolvedController.add({
      'issueId': issueId,
      'orderId': orderId,
      'isOnNavigationScreen': isOnNavigationScreen,
    });
    print('✅ Reroute resolved event emitted successfully');
  }
  
  /// Trigger order list refresh
  /// Note: Since OrderListViewModel is registered as Factory, we cannot directly refresh
  /// The UI will auto-refresh when user navigates to orders screen via Provider
  void _refreshOrderList() {
    
    // TODO: Implement proper event-based refresh mechanism
    // For now, rely on UI auto-refresh when screen becomes active
  }

  /// Handle authentication errors by refreshing token
  Future<void> _handleAuthError() async {
    if (_retryCount >= _maxRetries) {
      // 
      return;
    }

    // 
    
    try {
      // Attempt to force refresh token
      final refreshSuccess = await _authViewModel?.forceRefreshToken();
      
      if (refreshSuccess == true) {
        // 
        _retryCount++;
        // Wait a bit before reconnecting
        await Future.delayed(Duration(seconds: 2 * _retryCount));
        
        // Reconnect with new token
        if (_currentDriverId != null) {
          await connect(_currentDriverId!);
        }
      } else {
        // 
        _retryCount++;
        
        // If refresh failed, try again after longer delay
        if (_retryCount < _maxRetries) {
          await Future.delayed(Duration(seconds: 10 * _retryCount));
          await _handleAuthError();
        }
      }
    } catch (e) {
      // 
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
    // Cancel any existing reconnect timer
    _reconnectTimer?.cancel();
    
    if (_retryCount >= _maxRetries) {
      
      
      
      // Even after max retries, schedule one more attempt after longer delay
      // This ensures we keep trying indefinitely with longer intervals
      _reconnectTimer = Timer(const Duration(seconds: 60), () {
        _retryCount = 0; // Reset counter for next round of attempts
        _retryConnection();
      });
      return;
    }

    _retryCount++;
    
    
    // Exponential backoff: min(5 * attempt, 30) seconds
    final delaySeconds = (_retryCount * 5).clamp(5, 30);
    
    
    // Schedule retry with exponential backoff
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_currentDriverId != null && !_isManualDisconnect) {
        
        await connect(_currentDriverId!);
      } else {
        
      }
    });
  }

  /// Open seal removal report bottom sheet (mandatory for return flow)
  /// Driver MUST report seal removal before proceeding with return delivery
  Future<void> _openSealRemovalReportSheet({
    required BuildContext context,
    String? vehicleAssignmentId,
    bool isOnNavigationScreen = false,
  }) async {
    if (vehicleAssignmentId == null) {
      
      return;
    }

    try {
      // Use the same approach as normal flow - get IN_USE seal via dedicated API
      // This is more reliable than fetching full order details
      final issueRepository = getIt<IssueRepository>();
      
      // Fetch IN_USE seal for this vehicle assignment
      final inUseSealData = await issueRepository.getInUseSeal(vehicleAssignmentId);
      
      if (inUseSealData == null) {
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy seal nào đang sử dụng'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Parse seal data - backend returns Map<String, dynamic>
      final List<VehicleSeal> activeSeals = [];
      if (inUseSealData is Map<String, dynamic>) {
        // Single seal returned as object
        activeSeals.add(VehicleSeal(
          id: inUseSealData['id'] ?? '',
          description: inUseSealData['description'] ?? '',
          sealDate: inUseSealData['sealDate'] != null 
              ? DateTime.parse(inUseSealData['sealDate']) 
              : DateTime.now(),
          status: inUseSealData['status'] ?? 'IN_USE',
          sealCode: inUseSealData['sealCode'] ?? '',
          sealAttachedImage: inUseSealData['sealAttachedImage'],
        ));
      } else if (inUseSealData is List) {
        // Multiple seals returned as array (backward compatibility)
        for (var sealMap in inUseSealData) {
          if (sealMap is Map<String, dynamic>) {
            activeSeals.add(VehicleSeal(
              id: sealMap['id'] ?? '',
              description: sealMap['description'] ?? '',
              sealDate: sealMap['sealDate'] != null 
                  ? DateTime.parse(sealMap['sealDate']) 
                  : DateTime.now(),
              status: sealMap['status'] ?? 'IN_USE',
              sealCode: sealMap['sealCode'] ?? '',
              sealAttachedImage: sealMap['sealAttachedImage'],
            ));
          }
        }
      }

      if (activeSeals.isEmpty) {
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải thông tin seal'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      

      // Show seal removal report bottom sheet (MANDATORY)
      final sealReportResult = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false, // Cannot dismiss - must report
        enableDrag: false, // Cannot drag to dismiss
        builder: (context) => ReportSealIssueBottomSheet(
          vehicleAssignmentId: vehicleAssignmentId,
          currentLatitude: null, // Will get from location service
          currentLongitude: null,
          availableSeals: activeSeals,
        ),
      );

      

      // After seal removal report submitted successfully
      // Result will be non-null if submission was successful
      if (sealReportResult != null) {
        
        
        // Show waiting message for staff to assign new seal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔓 Đã báo cáo seal bị gỡ. Vui lòng chờ staff gán seal mới...'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );

        // Refresh order list
        _refreshOrderList();

        // Navigate to appropriate screen
        if (!isOnNavigationScreen) {
          
          _navigateToNavigationScreen(); // Navigation screen will restore from state
        } else {
          
          triggerNavigationScreenRefresh();
        }
      }
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi mở báo cáo seal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _notificationController.close();
    _refreshController.close();
    _showSealBottomSheetController.close();
    _sealAssignmentController.close();
    _damageResolvedController.close();
    _orderRejectionResolvedController.close();
    _paymentTimeoutController.close();
    _rerouteResolvedController.close();
  }
}
