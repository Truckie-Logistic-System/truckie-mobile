import 'dart:async';
import 'package:flutter/material.dart';

/// Chat input widget with text field and action buttons
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onTakePhoto;
  final bool isSending;
  final bool isUploading;
  final void Function(bool isTyping)? onTypingChanged;

  const ChatInput({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
    required this.onPickImage,
    required this.onTakePhoto,
    this.isSending = false,
    this.isUploading = false,
    this.onTypingChanged,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Listen to text changes to rebuild send button state
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    // Rebuild to update send button state
    setState(() {});
  }
  
  void _onTextChanged(String text) {
    // Send typing indicator
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      widget.onTypingChanged?.call(true);
    }
    
    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        widget.onTypingChanged?.call(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Image picker button
              _buildActionButton(
                icon: Icons.photo_library,
                onPressed: widget.isUploading ? null : widget.onPickImage,
                isLoading: widget.isUploading,
                tooltip: 'Chọn ảnh',
              ),
              const SizedBox(width: 4),
              // Camera button
              _buildActionButton(
                icon: Icons.camera_alt,
                onPressed: widget.isUploading ? null : widget.onTakePhoto,
                tooltip: 'Chụp ảnh',
              ),
              const SizedBox(width: 8),
              // Text input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      _isTyping = false;
                      widget.onTypingChanged?.call(false);
                      widget.onSend();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              _buildSendButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onPressed,
    bool isLoading = false,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onPressed == null ? Colors.grey.shade200 : Colors.grey.shade100,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      icon,
                      color: onPressed == null ? Colors.grey.shade400 : Colors.grey.shade700,
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final bool canSend = widget.controller.text.trim().isNotEmpty && !widget.isSending;
    
    return Tooltip(
      message: 'Gửi tin nhắn',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        child: Material(
          color: canSend ? const Color(0xFF1565C0) : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(24),
          elevation: canSend ? 2 : 0,
          child: InkWell(
            onTap: canSend ? () {
              _isTyping = false;
              widget.onTypingChanged?.call(false);
              widget.onSend();
            } : null,
            borderRadius: BorderRadius.circular(24),
            child: Center(
              child: widget.isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
