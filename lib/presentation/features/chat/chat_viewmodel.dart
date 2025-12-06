import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/services/chat_notification_service.dart';
import '../../../data/datasources/chat_remote_data_source.dart';
import '../../../data/models/chat_model.dart';

/// ViewModel for Chat Screen
/// Uses global WebSocket connection from ChatNotificationService
class ChatViewModel extends ChangeNotifier {
  final ChatRemoteDataSource _chatDataSource;
  final String driverId;
  final String userId; // User ID for sending messages
  final String? vehicleAssignmentId;
  final String? _driverName;
  
  // Reference to global chat notification service
  ChatNotificationService? _chatNotificationService;

  ChatViewModel({
    required ChatRemoteDataSource chatDataSource,
    required this.driverId,
    required this.userId,
    this.vehicleAssignmentId,
    String? driverName,
  }) : _chatDataSource = chatDataSource,
       _driverName = driverName;

  // State
  ChatConversationModel? _conversation;
  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isUploading = false;
  String? _error;
  bool _hasMore = true;
  int _currentPage = 0;
  Timer? _pollingTimer;
  
  // Typing state (received from global WebSocket)
  bool _isTyping = false;
  Timer? _typingTimer;
  
  // Callbacks
  void Function(ChatMessageModel)? _onNewMessageCallback;
  void Function(bool)? _onTypingChangedCallback;

  // Getters
  ChatConversationModel? get conversation => _conversation;
  List<ChatMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isUploading => _isUploading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  bool get isConversationActive => _conversation?.status == 'ACTIVE';
  bool get isConnected => _chatNotificationService?.isConnected ?? false;
  bool get isTyping => _isTyping;
  
  /// Set callback for new messages
  void setOnNewMessageCallback(void Function(ChatMessageModel) callback) {
    _onNewMessageCallback = callback;
  }
  
  /// Set callback for typing indicator changes
  void setOnTypingChangedCallback(void Function(bool) callback) {
    _onTypingChangedCallback = callback;
  }

  /// Initialize conversation - uses global WebSocket from ChatNotificationService
  Future<void> initConversation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _conversation = await _chatDataSource.getOrCreateDriverConversation(
        driverId,
        vehicleAssignmentId: vehicleAssignmentId,
      );

      await loadMessages();

      // Register callbacks with global ChatNotificationService
      // WebSocket is already connected globally from app startup
      await _registerWithGlobalWebSocket();
      
      // Fallback: Start polling if global WebSocket is not connected
      if (!isConnected) {
        debugPrint('⚠️ Global WebSocket not connected, starting polling fallback');
        _startPolling();
      } else {
        debugPrint('✅ Using global WebSocket connection for chat');
        // Stop polling since WebSocket is connected
        _pollingTimer?.cancel();
      }
    } catch (e) {
      _error = 'Không thể khởi tạo cuộc hội thoại: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Register callbacks with global ChatNotificationService
  Future<void> _registerWithGlobalWebSocket() async {
    try {
      _chatNotificationService = getIt<ChatNotificationService>();
      
      // Update conversation ID in global service if different
      // This ensures typing indicators are sent to the correct conversation
      if (_conversation != null && 
          _chatNotificationService!.conversationId != _conversation!.id) {
        debugPrint('🔄 Updating ChatNotificationService conversation to ${_conversation!.id}');
        await _chatNotificationService!.updateConversation(_conversation!.id);
      }
      
      // Register callbacks to receive real-time updates
      _chatNotificationService!.registerCallbacks(
        onMessage: _onMessageReceived,
        onTyping: _onTypingReceived,
        onReadStatus: _onReadStatusReceived,
      );
      
      debugPrint('✅ Registered callbacks with global ChatNotificationService');
    } catch (e) {
      debugPrint('⚠️ Failed to register with ChatNotificationService: $e');
    }
  }
  
  /// Handle message received from global WebSocket
  void _onMessageReceived(ChatMessageModel message) {
    // Skip empty messages
    if (message.content.isEmpty && !message.isImage) {
      return;
    }
    
    // Check if message already exists
    final exists = _messages.any((m) => m.id == message.id);
    if (!exists) {
      _messages.add(message);
      notifyListeners();
      
      // Notify callback
      _onNewMessageCallback?.call(message);
    }
  }
  
  /// Handle typing indicator from global WebSocket
  void _onTypingReceived(bool isTyping, String? senderType) {
    // Only show typing indicator for staff
    final isStaffTyping = isTyping && senderType != 'DRIVER';
    
    if (_isTyping != isStaffTyping) {
      _isTyping = isStaffTyping;
      notifyListeners();
      
      // Notify callback for scroll handling
      _onTypingChangedCallback?.call(_isTyping);
      
      // Auto-hide typing indicator after 3 seconds
      if (_isTyping) {
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          _isTyping = false;
          notifyListeners();
        });
      }
    }
  }
  
  /// Handle read status update from global WebSocket
  void _onReadStatusReceived() {
    // Refresh messages to get updated read status
    loadMessages();
  }

  /// Load messages
  Future<void> loadMessages() async {
    if (_conversation == null) return;

    try {
      final response = await _chatDataSource.getMessages(
        _conversation!.id,
        page: 0,
        size: 50,
      );

      // Backend already returns messages in correct order (oldest first, newest at bottom)
      // after Collections.reverse() in UserChatServiceImpl.getMessages()
      _messages = response.messages;
      _hasMore = response.hasMore;
      _currentPage = 1;
      notifyListeners();
    } catch (e) {
      _error = 'Không thể tải tin nhắn: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Load more messages
  Future<void> loadMoreMessages() async {
    if (_conversation == null || _isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _chatDataSource.getMessages(
        _conversation!.id,
        page: _currentPage,
        size: 50,
      );

      // Prepend older messages at the beginning (already in correct order from backend)
      _messages = [...response.messages, ..._messages];
      _hasMore = response.hasMore;
      _currentPage++;
    } catch (e) {
      _error = 'Không thể tải thêm tin nhắn: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send message
  Future<void> sendMessage(String content) async {
    if (_conversation == null || content.trim().isEmpty) return;

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final request = SendMessageRequest(
        conversationId: _conversation!.id,
        senderId: userId, // Use userId for backend to identify sender
        content: content.trim(),
        messageType: 'TEXT',
      );

      final newMessage = await _chatDataSource.sendMessage(request);
      
      // Check if message already exists (from WebSocket)
      final exists = _messages.any((m) => m.id == newMessage.id);
      if (!exists) {
        _messages.add(newMessage);
      }
      notifyListeners();
    } catch (e) {
      _error = 'Không thể gửi tin nhắn: ${e.toString()}';
      notifyListeners();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
  
  /// Send typing indicator via global WebSocket
  void sendTypingIndicator(bool isTyping) {
    if (_conversation == null) return;
    
    // Use global ChatNotificationService to send typing indicator
    _chatNotificationService?.sendTypingIndicator(
      isTyping,
      userId,
      _driverName ?? 'Tài xế',
    );
  }
  
  /// Mark messages as read
  Future<void> markMessagesAsRead() async {
    if (_conversation == null) return;
    
    try {
      await _chatDataSource.markAsRead(_conversation!.id);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Send image message
  Future<void> sendImageMessage(File imageFile) async {
    if (_conversation == null) return;

    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      // Upload image
      final imageUrl = await _chatDataSource.uploadImage(
        imageFile,
        _conversation!.id,
      );

      // Send message with image
      final request = SendMessageRequest(
        conversationId: _conversation!.id,
        senderId: userId,
        content: '',
        messageType: 'IMAGE',
        imageUrl: imageUrl,
      );

      final newMessage = await _chatDataSource.sendMessage(request);
      
      // Check if message already exists (from WebSocket)
      final exists = _messages.any((m) => m.id == newMessage.id);
      if (!exists) {
        _messages.add(newMessage);
      }
      notifyListeners();
    } catch (e) {
      _error = 'Không thể gửi hình ảnh: ${e.toString()}';
      notifyListeners();
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Start polling for new messages
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollNewMessages();
    });
  }

  /// Poll for new messages
  Future<void> _pollNewMessages() async {
    if (_conversation == null) return;

    try {
      final response = await _chatDataSource.getMessages(
        _conversation!.id,
        page: 0,
        size: 50,
      );

      // Only update if there are new messages (backend returns in correct order)
      if (response.messages.length > _messages.length) {
        _messages = response.messages;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail polling errors
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh conversation
  Future<void> refresh() async {
    await loadMessages();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _typingTimer?.cancel();
    
    // Unregister callbacks from global ChatNotificationService
    // Don't disconnect WebSocket - it's global and should stay connected
    _chatNotificationService?.unregisterCallbacks();
    
    super.dispose();
  }
}
