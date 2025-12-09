import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/datasources/chat_remote_data_source.dart';
import '../../data/models/chat_model.dart';
import '../constants/api_constants.dart';
import 'token_storage_service.dart';
import '../../app/di/service_locator.dart';
import '../../presentation/features/auth/viewmodels/auth_viewmodel.dart';

/// Service to manage chat notifications and unread count
class ChatNotificationService extends ChangeNotifier {
  final ChatRemoteDataSource _chatDataSource;
  
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _conversationId;
  Timer? _pollingTimer;
  StompClient? _stompClient;
  bool _isConnected = false;
  bool _isChatScreenActive = false; // Track if user is on chat screen
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;
  
  // Token refresh handling
  AuthViewModel? _authViewModel;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  bool _isRefreshingToken = false;
  String? _currentDriverId;
  
  // Message deduplication to prevent double counting
  final Set<String> _processedMessageIds = {};
  
  // Callbacks for chat screen to receive real-time updates
  void Function(ChatMessageModel)? _onMessageCallback;
  void Function(bool isTyping, String? senderType)? _onTypingCallback;
  void Function()? _onReadStatusCallback;
  
  ChatNotificationService({
    required ChatRemoteDataSource chatDataSource,
  }) : _chatDataSource = chatDataSource {
    _initNotifications();
  }
  
  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    await _notificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _notificationsInitialized = true;
  }
  
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get conversationId => _conversationId;
  bool get hasUnread => _unreadCount > 0;
  bool get isConnected => _isConnected;
  StompClient? get stompClient => _stompClient;
  
  /// Update conversation ID and reconnect WebSocket if needed
  /// This is called when entering chat screen with a specific conversation
  Future<void> updateConversation(String conversationId) async {
    if (_conversationId == conversationId) return;
    
    debugPrint('🔄 Updating conversation from $_conversationId to $conversationId');
    _conversationId = conversationId;
    
    // Reconnect WebSocket to subscribe to new conversation topics
    if (_stompClient != null) {
      _stompClient!.deactivate();
      _stompClient = null;
      _isConnected = false;
    }
    
    await _connectWebSocket();
  }
  
  /// Register callbacks for chat screen
  void registerCallbacks({
    void Function(ChatMessageModel)? onMessage,
    void Function(bool isTyping, String? senderType)? onTyping,
    void Function()? onReadStatus,
  }) {
    _onMessageCallback = onMessage;
    _onTypingCallback = onTyping;
    _onReadStatusCallback = onReadStatus;
  }
  
  /// Unregister callbacks when leaving chat screen
  void unregisterCallbacks() {
    _onMessageCallback = null;
    _onTypingCallback = null;
    _onReadStatusCallback = null;
  }
  
  /// Set chat screen active state
  void setChatScreenActive(bool active) {
    _isChatScreenActive = active;
    if (active) {
      // Mark as read when entering chat screen
      markAsRead();
    }
  }
  
  /// Initialize and start listening for chat messages
  Future<void> initialize(String driverId, {String? vehicleAssignmentId}) async {
    _isLoading = true;
    _currentDriverId = driverId;
    notifyListeners();
    
    // Initialize AuthViewModel reference for token refresh
    try {
      _authViewModel = getIt<AuthViewModel>();
    } catch (e) {
      debugPrint('⚠️ Could not get AuthViewModel: $e');
    }
    
    try {
      // Always fetch conversation to get latest unread count
      // This ensures badge is updated even after app restart
      final conversation = await _chatDataSource.getOrCreateDriverConversation(
        driverId,
        vehicleAssignmentId: vehicleAssignmentId,
      );
      
      // Check if conversation changed
      final isNewConversation = _conversationId != conversation.id;
      final oldUnreadCount = _unreadCount;
      
      _conversationId = conversation.id;
      _unreadCount = conversation.unreadCount;
      
      // Log unread count changes
      if (oldUnreadCount != _unreadCount) {
        debugPrint('📬 Unread count updated: $oldUnreadCount -> $_unreadCount');
      }
      
      // Disconnect existing connection before creating new one
      if (_stompClient != null && isNewConversation) {
        debugPrint('🔄 Disconnecting old WebSocket before reconnecting...');
        _stompClient!.deactivate();
        _stompClient = null;
        _isConnected = false;
      }
      
      // Connect to WebSocket for real-time updates (only if not already connected)
      if (!_isConnected) {
        await _connectWebSocket();
      }
      
      // Start polling as fallback
      _startPolling();
      
      debugPrint('✅ ChatNotificationService initialized - unreadCount: $_unreadCount');
    } catch (e) {
      debugPrint('Error initializing chat notification service: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Connect to WebSocket for real-time chat notifications
  Future<void> _connectWebSocket() async {
    if (_conversationId == null) return;
    
    try {
      final tokenStorage = getIt<TokenStorageService>();
      final token = tokenStorage.getAccessToken();
      if (token == null) return;
      
      final wsUrl = '${ApiConstants.wsBaseUrl}${ApiConstants.wsChatEndpoint}';
      debugPrint('🔌 Chat WebSocket connecting to: $wsUrl');
      
      _stompClient = StompClient(
        config: StompConfig(
          url: wsUrl,
          // HTTP upgrade headers for handshake
          webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
          // STOMP CONNECT frame headers for message layer authentication
          stompConnectHeaders: {'Authorization': 'Bearer $token'},
          onConnect: _onWebSocketConnected,
          onDisconnect: _onWebSocketDisconnected,
          onWebSocketError: (error) {
            debugPrint('❌ Chat WS error: $error');
            _handleWebSocketError(error);
          },
          onStompError: (frame) {
            debugPrint('❌ Chat STOMP error: ${frame.body}');
            _handleStompError(frame);
          },
          // CRITICAL: Disable auto-reconnect to prevent reconnection with stale tokens
          // We handle reconnection manually via _retryConnection() with fresh tokens
          reconnectDelay: const Duration(seconds: 0),
          heartbeatIncoming: const Duration(seconds: 10),
          heartbeatOutgoing: const Duration(seconds: 10),
          // onDebugMessage: (msg) => debugPrint('🔍 Chat STOMP debug: $msg'),
        ),
      );
      
      _stompClient!.activate();
    } catch (e) {
      debugPrint('Error connecting chat WebSocket: $e');
    }
  }
  
  void _onWebSocketConnected(StompFrame frame) {
    debugPrint('✅ Chat notification WebSocket connected globally');
    debugPrint('   Connected to conversation: $_conversationId');
    debugPrint('   STOMP client active: ${_stompClient?.isActive}');
    _isConnected = true;
    notifyListeners();
    
    // Fetch latest unread count when reconnecting
    // This ensures badge is updated with messages received while disconnected
    _refreshUnreadCount();
    
    // Subscribe to conversation messages
    if (_conversationId != null) {
      debugPrint('📡 Subscribing to /topic/chat/conversation/$_conversationId');
      _stompClient?.subscribe(
        destination: '/topic/chat/conversation/$_conversationId',
        callback: _onMessageReceived,
      );
      
      // Subscribe to typing indicators
      debugPrint('📡 Subscribing to /topic/chat/conversation/$_conversationId/typing');
      _stompClient?.subscribe(
        destination: '/topic/chat/conversation/$_conversationId/typing',
        callback: _onTypingReceived,
      );
      
      // Subscribe to read status
      debugPrint('📡 Subscribing to /topic/chat/conversation/$_conversationId/read');
      _stompClient?.subscribe(
        destination: '/topic/chat/conversation/$_conversationId/read',
        callback: _onReadStatusReceived,
      );
      
      debugPrint('✅ Subscribed to all chat topics for conversation: $_conversationId');
    }
  }
  
  /// Refresh unread count from server
  /// Called when WebSocket reconnects to sync with messages received while disconnected
  Future<void> _refreshUnreadCount() async {
    if (_conversationId == null) return;
    
    try {
      // Get latest conversation data including unread count
      final conversation = await _chatDataSource.getConversation(_conversationId!);
      final newUnreadCount = conversation.unreadCount;
      if (newUnreadCount != _unreadCount) {
        debugPrint('🔄 Unread count updated: $_unreadCount -> $newUnreadCount');
        _unreadCount = newUnreadCount;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing unread count: $e');
    }
  }
  
  void _onWebSocketDisconnected(StompFrame frame) {
    debugPrint('🔌 Chat notification WebSocket disconnected');
    debugPrint('   Frame command: ${frame.command}');
    debugPrint('   Frame headers: ${frame.headers}');
    debugPrint('   Frame body: ${frame.body}');
    _isConnected = false;
    
    // CRITICAL: Check if disconnect was due to auth error
    // If so, trigger token refresh and reconnect
    final bodyStr = frame.body?.toString().toLowerCase() ?? '';
    final headersStr = frame.headers.toString().toLowerCase();
    
    if (bodyStr.contains('401') || 
        bodyStr.contains('unauthorized') ||
        headersStr.contains('401') ||
        headersStr.contains('unauthorized')) {
      debugPrint('🔐 Chat WS disconnected due to auth error, attempting token refresh...');
      _handleAuthError();
    } else if (_conversationId != null) {
      // Normal disconnect, retry connection
      debugPrint('⚠️ Chat WS disconnected normally, scheduling reconnection...');
      _retryConnection();
    }
  }
  
  void _onMessageReceived(StompFrame frame) {
    if (frame.body == null) return;
    
    try {
      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      final messageId = data['id'] as String?;
      
      // Deduplicate messages to prevent double counting
      if (messageId != null && _processedMessageIds.contains(messageId)) {
        debugPrint('⚠️ Skipping duplicate message: $messageId');
        return;
      }
      if (messageId != null) {
        _processedMessageIds.add(messageId);
        // Keep set size manageable
        if (_processedMessageIds.length > 100) {
          _processedMessageIds.remove(_processedMessageIds.first);
        }
      }
      
      final senderType = data['senderType'] as String?;
      final content = data['content'] as String? ?? '';
      final senderName = data['senderName'] as String? ?? 'Nhân viên hỗ trợ';
      
      // Parse message and notify callback
      final message = ChatMessageModel.fromJson(data);
      _onMessageCallback?.call(message);
      
      // Only notify for staff messages when not on chat screen
      if (senderType == 'STAFF' && !_isChatScreenActive) {
        _unreadCount++;
        notifyListeners();
        
        // Show notification
        _showChatNotification(senderName, content);
      }
    } catch (e) {
      debugPrint('Error parsing chat message: $e');
    }
  }
  
  void _onTypingReceived(StompFrame frame) {
    if (frame.body == null) return;
    
    try {
      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      final senderType = data['senderType'] as String?;
      final isTyping = data['isTyping'] as bool? ?? false;
      
      // Only notify for staff typing (not driver's own typing)
      if (senderType != 'DRIVER') {
        _onTypingCallback?.call(isTyping, senderType);
      }
    } catch (e) {
      debugPrint('Error parsing typing indicator: $e');
    }
  }
  
  void _onReadStatusReceived(StompFrame frame) {
    if (frame.body == null) return;
    
    try {
      _onReadStatusCallback?.call();
    } catch (e) {
      debugPrint('Error parsing read status: $e');
    }
  }
  
  /// Show notification for new chat message
  Future<void> _showChatNotification(String senderName, String content) async {
    debugPrint('🔔 Showing chat notification: $senderName - $content');
    
    // Vibrate
    HapticFeedback.mediumImpact();
    
    // Play notification sound
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
    
    // Show local notification
    try {
      const androidDetails = AndroidNotificationDetails(
        'chat_messages',
        'Tin nhắn chat',
        channelDescription: 'Thông báo tin nhắn chat từ nhân viên hỗ trợ',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Tin nhắn mới từ $senderName',
        content.isEmpty ? '[Hình ảnh]' : content,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }
  
  /// Load unread count from server
  Future<void> _loadUnreadCount() async {
    if (_conversationId == null) return;
    
    try {
      final messagesPage = await _chatDataSource.getMessages(
        _conversationId!,
        page: 0,
        size: 100,
      );
      
      // Count unread messages from staff
      int unread = 0;
      for (final message in messagesPage.messages) {
        if (message.isFromStaff && !message.isRead) {
          unread++;
        }
      }
      
      if (_unreadCount != unread) {
        _unreadCount = unread;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }
  
  /// Start polling for new messages
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadUnreadCount();
    });
  }
  
  /// Refresh unread count
  Future<void> refresh() async {
    await _loadUnreadCount();
  }
  
  /// Mark all messages as read (call when entering chat screen)
  void markAsRead() {
    if (_unreadCount > 0) {
      _unreadCount = 0;
      notifyListeners();
    }
  }
  
  /// Increment unread count (call when receiving new message via WebSocket)
  void incrementUnread() {
    _unreadCount++;
    notifyListeners();
  }
  
  /// Send typing indicator via global WebSocket
  void sendTypingIndicator(bool isTyping, String senderId, String senderName) {
    final clientActive = _stompClient?.isActive ?? false;
    debugPrint('📝 sendTypingIndicator called: isTyping=$isTyping, senderId=$senderId');
    debugPrint('   conversationId=$_conversationId, isConnected=$_isConnected, hasClient=${_stompClient != null}, clientActive=$clientActive');
    
    if (_stompClient == null || !_isConnected || _conversationId == null) {
      debugPrint('⚠️ Cannot send typing indicator: client=${_stompClient != null}, connected=$_isConnected, conversationId=$_conversationId');
      return;
    }
    
    if (!clientActive) {
      debugPrint('⚠️ STOMP client exists but is NOT active!');
    }
    
    try {
      final body = jsonEncode({
        'senderId': senderId,
        'senderType': 'DRIVER',
        'senderName': senderName,
        'isTyping': isTyping,
      });
      
      final destination = '/app/user-chat.typing/$_conversationId';
      debugPrint('📤 Sending typing indicator to $destination');
      debugPrint('📤 Body: $body');
      
      _stompClient!.send(
        destination: destination,
        body: body,
        headers: {'content-type': 'application/json'},
      );
      debugPrint('✅ Typing indicator sent successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending typing indicator: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }
  
  /// Disconnect WebSocket
  void disconnect() {
    _stompClient?.deactivate();
    _stompClient = null;
    _isConnected = false;
    _retryCount = 0;
  }
  
  /// Handle WebSocket error with token refresh logic
  Future<void> _handleWebSocketError(dynamic error) async {
    debugPrint('🔧 [ChatNotificationService] Handling Chat WS error: $error');
    debugPrint('🔍 Error type: ${error.runtimeType}');
    
    // Check if error is related to authentication (401)
    final errorStr = error.toString().toLowerCase();
    debugPrint('🔍 Error string (lowercase): $errorStr');
    
    final is401Error = errorStr.contains('401') || 
        errorStr.contains('unauthorized') ||
        errorStr.contains('not upgraded');
    
    debugPrint('🔍 Is 401 error: $is401Error');
    
    if (is401Error) {
      debugPrint('🔐 Chat WS: Authentication error detected, attempting token refresh...');
      await _handleAuthError();
    } else {
      debugPrint('⚠️ Chat WS: Non-auth error, retrying connection...');
      // For other errors, just retry connection with exponential backoff
      _retryConnection();
    }
  }
  
  /// Handle STOMP error with token refresh logic
  Future<void> _handleStompError(StompFrame frame) async {
    debugPrint('🔧 Handling Chat STOMP error: ${frame.body}');
    
    // Check if error is related to authentication
    final bodyStr = frame.body?.toString().toLowerCase() ?? '';
    if (bodyStr.contains('401') || bodyStr.contains('unauthorized')) {
      debugPrint('🔐 Chat STOMP: Authentication error detected, attempting token refresh...');
      await _handleAuthError();
    } else {
      // For other errors, just retry connection
      _retryConnection();
    }
  }
  
  /// Handle authentication errors by refreshing token
  Future<void> _handleAuthError() async {
    if (_isRefreshingToken) {
      debugPrint('⏳ Token refresh already in progress, skipping...');
      return;
    }
    
    if (_retryCount >= _maxRetries) {
      debugPrint('❌ Max retry attempts reached for Chat WS token refresh');
      return;
    }
    
    _isRefreshingToken = true;
    debugPrint('🔄 Attempting to refresh token for Chat WS (attempt ${_retryCount + 1}/$_maxRetries)...');
    
    try {
      // Attempt to force refresh token
      final refreshSuccess = await _authViewModel?.forceRefreshToken();
      
      if (refreshSuccess == true) {
        debugPrint('✅ Token refreshed successfully, reconnecting Chat WS...');
        _retryCount++;
        _isRefreshingToken = false;
        
        // Wait a bit before reconnecting
        await Future.delayed(Duration(seconds: 2));
        
        // Reconnect with new token
        await _connectWebSocket();
      } else {
        debugPrint('❌ Token refresh failed for Chat WS');
        _retryCount++;
        _isRefreshingToken = false;
        
        // If refresh failed, try again after longer delay
        if (_retryCount < _maxRetries) {
          await Future.delayed(Duration(seconds: 5 * _retryCount));
          await _handleAuthError();
        }
      }
    } catch (e) {
      debugPrint('❌ Error during token refresh for Chat WS: $e');
      _retryCount++;
      _isRefreshingToken = false;
      
      // Try again after longer delay
      if (_retryCount < _maxRetries) {
        await Future.delayed(Duration(seconds: 5 * _retryCount));
        await _handleAuthError();
      }
    }
  }
  
  /// Retry connection with exponential backoff
  void _retryConnection() {
    if (_retryCount >= _maxRetries) {
      debugPrint('❌ Max retry attempts reached for Chat WS connection');
      
      // Reset counter after longer delay for next round
      Future.delayed(const Duration(seconds: 60), () {
        _retryCount = 0;
      });
      return;
    }
    
    _retryCount++;
    final delaySeconds = (_retryCount * 3).clamp(3, 15);
    
    debugPrint('🔄 Scheduling Chat WS reconnection in ${delaySeconds}s (attempt $_retryCount/$_maxRetries)...');
    
    Future.delayed(Duration(seconds: delaySeconds), () async {
      if (_conversationId != null) {
        await _connectWebSocket();
      }
    });
  }
  
  /// Force reconnect with fresh token (useful after manual token refresh)
  Future<void> forceReconnect() async {
    debugPrint('🔄 Force reconnecting Chat WS for driver: $_currentDriverId...');
    _retryCount = 0;
    _isRefreshingToken = false;
    
    // Disconnect existing connection
    disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Reconnect if we have a conversation
    if (_conversationId != null) {
      await _connectWebSocket();
    } else if (_currentDriverId != null) {
      // Re-initialize with stored driver ID
      await initialize(_currentDriverId!);
    }
  }
  
  @override
  void dispose() {
    _pollingTimer?.cancel();
    disconnect();
    _audioPlayer.dispose();
    super.dispose();
  }
}
