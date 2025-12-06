import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/services/chat_notification_service.dart';
import '../../../data/datasources/chat_remote_data_source.dart';
import '../../../data/models/chat_model.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import 'chat_viewmodel.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';

/// Chat Screen for Driver to communicate with Staff
class ChatScreen extends StatefulWidget {
  final String? vehicleAssignmentId;
  final String? trackingCode;
  final bool fromTabNavigation;

  const ChatScreen({
    super.key,
    this.vehicleAssignmentId,
    this.trackingCode,
    this.fromTabNavigation = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FocusNode _inputFocusNode = FocusNode();
  
  // Store viewModel reference for lifecycle callbacks
  ChatViewModel? _viewModel;
  
  bool _showScrollToTop = false;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Setup scroll listener
    _scrollController.addListener(_onScroll);
    
    // Setup input focus listener
    _inputFocusNode.addListener(_onInputFocusChange);
    
    // Mark chat screen as active
    _setChatScreenActive(true);
  }
  
  void _setChatScreenActive(bool active) {
    try {
      final chatNotificationService = getIt<ChatNotificationService>();
      chatNotificationService.setChatScreenActive(active);
    } catch (e) {
      debugPrint('Error setting chat screen active: $e');
    }
  }
  
  void _initializeChat(ChatViewModel viewModel) {
    _viewModel = viewModel;
    viewModel.setOnNewMessageCallback(_onNewMessage);
    viewModel.setOnTypingChangedCallback(_onTypingChanged);
    // With reverse: true ListView, messages automatically start from bottom
    // No need to manually scroll
    viewModel.initConversation();
  }
  
  void _onTypingChanged(bool isTyping) {
    // Auto scroll to bottom when typing indicator appears
    if (isTyping && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh messages when app comes back to foreground
      _viewModel?.refresh();
    }
  }
  
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    // With reverse: true:
    // - offset 0 = bottom (newest messages)
    // - maxScrollExtent = top (oldest messages)
    final scrollOffset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final distanceFromTop = maxScroll - scrollOffset; // Distance to oldest messages
    
    // Show/hide scroll buttons (reversed logic)
    setState(() {
      _showScrollToTop = distanceFromTop > 200; // Show when scrolled away from oldest
      _showScrollToBottom = scrollOffset > 150; // Show when scrolled away from newest
    });
  }
  
  void _onInputFocusChange() {
    if (_inputFocusNode.hasFocus) {
      // Mark messages as read when input is focused
      _viewModel?.markMessagesAsRead();
    }
  }
  
  void _onNewMessage(ChatMessageModel message) {
    // Play notification sound for staff messages
    if (message.isFromStaff) {
      _playNotificationSound();
      // Vibrate
      HapticFeedback.mediumImpact();
    }
    
    // Always auto scroll to bottom when new message arrives
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToBottom();
      }
    });
  }
  
  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      // Fallback: just vibrate if sound fails
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    // Mark chat screen as inactive
    _setChatScreenActive(false);
    
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _inputFocusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _showScrollToBottom = false;
      // With reverse: true, bottom is at minScrollExtent (0)
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {});
    }
  }
  
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _showScrollToTop = false;
      // With reverse: true, top (oldest messages) is at maxScrollExtent
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        await _viewModel?.sendImageMessage(File(image.path));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        await _viewModel?.sendImageMessage(File(image.path));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chụp ảnh: $e')),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _viewModel?.sendMessage(text);
    _messageController.clear();
    // Scroll to bottom after message is added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }
  
  Future<void> _onRefresh() async {
    await _viewModel?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Get driver ID and user ID from AuthViewModel
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final driverId = authViewModel.driver?.id ?? '';
    final userId = authViewModel.driver?.userResponse.id ?? '';
    final driverName = authViewModel.driver?.userResponse.fullName ?? 'Tài xế';
    
    if (driverId.isEmpty || userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          title: const Text('Hỗ trợ trực tuyến'),
        ),
        body: const Center(
          child: Text('Vui lòng đăng nhập để sử dụng chat'),
        ),
      );
    }
    
    return ChangeNotifierProvider<ChatViewModel>(
      create: (_) {
        final viewModel = ChatViewModel(
          chatDataSource: getIt<ChatRemoteDataSource>(),
          driverId: driverId,
          userId: userId,
          vehicleAssignmentId: widget.vehicleAssignmentId,
          driverName: driverName,
        );
        // Initialize chat after viewModel is created
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeChat(viewModel);
        });
        return viewModel;
      },
      builder: (context, child) => _buildChatContent(context),
    );
  }
  
  Widget _buildChatContent(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 2,
        automaticallyImplyLeading: !widget.fromTabNavigation,
        title: Consumer<ChatViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Hỗ trợ trực tuyến',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    // Connection status indicator
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: viewModel.isConnected ? Colors.greenAccent : Colors.orange,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (widget.trackingCode != null)
                      Text(
                        'Chuyến xe: ${widget.trackingCode}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                      )
                    else
                      Text(
                        viewModel.isConnected ? 'Đang kết nối' : 'Đang kết nối lại...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: viewModel.isConnected ? Colors.white70 : Colors.orange.shade100,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          Consumer<ChatViewModel>(
            builder: (context, viewModel, child) {
              return IconButton(
                icon: viewModel.isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh),
                onPressed: viewModel.isLoading ? null : () => viewModel.refresh(),
                tooltip: 'Làm mới',
              );
            },
          ),
        ],
      ),
      body: Consumer<ChatViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.messages.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (viewModel.error != null && viewModel.messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => viewModel.initConversation(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Error banner
              if (viewModel.error != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          viewModel.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: viewModel.clearError,
                      ),
                    ],
                  ),
                ),

              // Conversation closed banner
              if (!viewModel.isConversationActive)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade200,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'Cuộc hội thoại đã kết thúc',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

              // Messages list
              Expanded(
                child: viewModel.messages.isEmpty
                    ? _buildEmptyState()
                    : Stack(
                        children: [
                          _buildMessagesList(viewModel),
                          // Scroll navigation buttons
                          if (_showScrollToTop || _showScrollToBottom)
                            _buildScrollButtons(),
                          // Note: Typing indicator is now rendered inside _buildMessagesList
                        ],
                      ),
              ),

              // Input area
              if (viewModel.isConversationActive)
                ChatInput(
                  controller: _messageController,
                  focusNode: _inputFocusNode,
                  onSend: _sendMessage,
                  onPickImage: _pickImage,
                  onTakePhoto: _takePhoto,
                  isSending: viewModel.isSending,
                  isUploading: viewModel.isUploading,
                  onTypingChanged: (isTyping) {
                    viewModel.sendTypingIndicator(isTyping);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Chào bạn!\nHãy gửi tin nhắn để được hỗ trợ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ChatViewModel viewModel) {
    // Total items = messages + typing indicator (if typing)
    final messageCount = viewModel.messages.length;
    final itemCount = messageCount + (viewModel.isTyping ? 1 : 0);
    
    // Use reverse: true to start from bottom (like all chat apps)
    // This means index 0 = newest message, so we need to reverse the logic
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF1565C0),
      child: ListView.builder(
        controller: _scrollController,
        reverse: true, // Start from bottom
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // With reverse: true, index 0 is at the bottom
          // Show typing indicator at index 0 (bottom)
          if (index == 0 && viewModel.isTyping) {
            return _buildTypingIndicatorMessage();
          }
          
          // Adjust index for messages when typing indicator is shown
          final messageIndex = viewModel.isTyping ? index - 1 : index;
          // Reverse the message index since list is reversed
          final reversedIndex = messageCount - 1 - messageIndex;
          
          if (reversedIndex < 0 || reversedIndex >= messageCount) {
            return const SizedBox.shrink();
          }
          
          final message = viewModel.messages[reversedIndex];
          // For date divider, check the PREVIOUS message in original order (next in reversed list)
          final previousMessageInOriginal = reversedIndex > 0 
              ? viewModel.messages[reversedIndex - 1] 
              : null;
          final showDate = previousMessageInOriginal == null ||
              !_isSameDay(message.createdAt, previousMessageInOriginal.createdAt);
          
          // Check if this is the last read message from driver
          final isLastReadOwnMessage = _isLastReadOwnMessage(viewModel.messages, reversedIndex);

          return Column(
            children: [
              // Date divider goes BEFORE the message in reversed list (which is AFTER in visual order)
              if (showDate) _buildDateDivider(message.createdAt),
              ChatBubble(
                message: message,
                isFromMe: message.isFromDriver,
                showReadStatus: isLastReadOwnMessage,
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// Build typing indicator as a message-like widget (takes space in the list)
  Widget _buildTypingIndicatorMessage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Staff name label
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 4),
            child: Text(
              'Nhân viên hỗ trợ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          // Typing bubble row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Staff avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Typing bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedTypingDot(0),
                    const SizedBox(width: 4),
                    _buildAnimatedTypingDot(1),
                    const SizedBox(width: 4),
                    _buildAnimatedTypingDot(2),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnimatedTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.shade500.withValues(alpha: value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
  
  bool _isLastReadOwnMessage(List<ChatMessageModel> messages, int index) {
    final message = messages[index];
    if (!message.isRead || !message.isFromDriver) return false;
    
    // Check if there are any more own messages after this one that are also read
    for (int i = index + 1; i < messages.length; i++) {
      final nextMsg = messages[i];
      if (nextMsg.isFromDriver && nextMsg.isRead) {
        return false;
      }
    }
    return true;
  }
  
  Widget _buildScrollButtons() {
    return Positioned(
      bottom: 70, // Move above input area
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showScrollToTop)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                elevation: 4,
                shape: const CircleBorder(),
                color: Colors.white,
                child: InkWell(
                  onTap: _scrollToTop,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: const Icon(
                      Icons.keyboard_arrow_up,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
            ),
          if (_showScrollToBottom)
            Material(
              elevation: 4,
              shape: const CircleBorder(),
              color: const Color(0xFF1565C0),
              child: InkWell(
                onTap: _scrollToBottom,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    String dateText;

    if (_isSameDay(date, now)) {
      dateText = 'Hôm nay';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      dateText = 'Hôm qua';
    } else {
      dateText = DateFormat('dd/MM/yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              dateText,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
