import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../data/models/chat_model.dart';

/// Chat bubble widget for displaying messages
class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isFromMe;
  final bool showReadStatus;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isFromMe,
    this.showReadStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    // System message
    if (message.isSystem) {
      return _buildSystemMessage();
    }
    
    // Skip empty messages (no content and no image)
    if (message.content.isEmpty && !message.isImage) {
      return const SizedBox.shrink();
    }

    // Image-only message (no bubble border)
    if (message.isImage && message.imageUrl != null && message.imageUrl!.isNotEmpty) {
      return _buildImageOnlyMessage(context);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isFromMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      // Always show 'Nhân viên hỗ trợ' for staff messages
                      message.isFromStaff ? 'Nhân viên hỗ trợ' : (message.senderName ?? 'Người dùng'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: isFromMe
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          isFromMe ? const Radius.circular(16) : Radius.zero,
                      bottomRight:
                          isFromMe ? Radius.zero : const Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 12,
                          top: 12,
                          bottom: 4,
                        ),
                        child: Text(
                          message.content,
                          style: TextStyle(
                            color: isFromMe ? Colors.white : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          right: 12,
                          bottom: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(message.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isFromMe
                                    ? Colors.white70
                                    : Colors.grey.shade500,
                              ),
                            ),
                            if (isFromMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.isRead ? Icons.done_all : Icons.done,
                                size: 14,
                                color: message.isRead 
                                    ? Colors.blue.shade200 
                                    : (isFromMe ? Colors.white54 : Colors.grey.shade400),
                              ),
                            ],
                            // Show "Đã xem" text only for the last read message
                            if (showReadStatus && message.isRead) ...[
                              const SizedBox(width: 4),
                              Text(
                                '· Đã xem',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isFromMe ? Colors.white70 : Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build image-only message without bubble border
  Widget _buildImageOnlyMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe) ...[
            _buildAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isFromMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      // Always show 'Nhân viên hỗ trợ' for staff messages
                      message.isFromStaff ? 'Nhân viên hỗ trợ' : (message.senderName ?? 'Người dùng'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                // Image without bubble
                GestureDetector(
                  onTap: () => _showFullImage(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                        maxHeight: 250,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: message.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 150,
                          width: 150,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 150,
                          width: 150,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Time and read status below image
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (isFromMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead 
                              ? Colors.blue 
                              : Colors.grey.shade400,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    // Validate image URL
    final hasValidImageUrl = message.senderImageUrl != null && 
        message.senderImageUrl!.isNotEmpty &&
        (message.senderImageUrl!.startsWith('http://') || 
         message.senderImageUrl!.startsWith('https://'));
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.blue.shade100,
      backgroundImage: hasValidImageUrl
          ? NetworkImage(message.senderImageUrl!)
          : null,
      child: !hasValidImageUrl
          ? Text(
              message.senderName?.isNotEmpty == true
                  ? message.senderName![0].toUpperCase()
                  : 'S',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            )
          : null,
    );
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: message.imageUrl!,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}
