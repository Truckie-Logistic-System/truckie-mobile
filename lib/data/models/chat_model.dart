/// Chat Models for Driver Chat with Staff
library;

class ChatConversationModel {
  final String id;
  final String conversationType;
  final String? initiatorId;
  final String initiatorType;
  final String? initiatorName;
  final String? initiatorImageUrl;
  final String? guestSessionId;
  final String? guestName;
  final String? currentOrderId;
  final String? currentOrderCode;
  final String? currentVehicleAssignmentId;
  final String? currentTrackingCode;
  final String status;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final DateTime createdAt;
  final DateTime? closedAt;

  ChatConversationModel({
    required this.id,
    required this.conversationType,
    this.initiatorId,
    required this.initiatorType,
    this.initiatorName,
    this.initiatorImageUrl,
    this.guestSessionId,
    this.guestName,
    this.currentOrderId,
    this.currentOrderCode,
    this.currentVehicleAssignmentId,
    this.currentTrackingCode,
    required this.status,
    required this.unreadCount,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.createdAt,
    this.closedAt,
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) {
    return ChatConversationModel(
      id: json['id'] ?? '',
      conversationType: json['conversationType'] ?? '',
      initiatorId: json['initiatorId'],
      initiatorType: json['initiatorType'] ?? '',
      initiatorName: json['initiatorName'],
      initiatorImageUrl: json['initiatorImageUrl'],
      guestSessionId: json['guestSessionId'],
      guestName: json['guestName'],
      currentOrderId: json['currentOrderId'],
      currentOrderCode: json['currentOrderCode'],
      currentVehicleAssignmentId: json['currentVehicleAssignmentId'],
      currentTrackingCode: json['currentTrackingCode'],
      status: json['status'] ?? 'ACTIVE',
      unreadCount: json['unreadCount'] ?? 0,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null,
      lastMessagePreview: json['lastMessagePreview'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      closedAt:
          json['closedAt'] != null ? DateTime.parse(json['closedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationType': conversationType,
      'initiatorId': initiatorId,
      'initiatorType': initiatorType,
      'initiatorName': initiatorName,
      'initiatorImageUrl': initiatorImageUrl,
      'guestSessionId': guestSessionId,
      'guestName': guestName,
      'currentOrderId': currentOrderId,
      'currentOrderCode': currentOrderCode,
      'currentVehicleAssignmentId': currentVehicleAssignmentId,
      'currentTrackingCode': currentTrackingCode,
      'status': status,
      'unreadCount': unreadCount,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'lastMessagePreview': lastMessagePreview,
      'createdAt': createdAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
    };
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String? senderId;
  final String senderType;
  final String? senderName;
  final String? senderImageUrl;
  final String content;
  final String messageType;
  final String? imageUrl;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    this.senderId,
    required this.senderType,
    this.senderName,
    this.senderImageUrl,
    required this.content,
    required this.messageType,
    this.imageUrl,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'],
      senderType: json['senderType'] ?? 'GUEST',
      senderName: json['senderName'],
      senderImageUrl: json['senderImageUrl'],
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? 'TEXT',
      imageUrl: json['imageUrl'],
      isRead: json['isRead'] ?? false,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'content': content,
      'messageType': messageType,
      'imageUrl': imageUrl,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool get isFromDriver => senderType == 'DRIVER';
  bool get isFromStaff => senderType == 'STAFF';
  bool get isSystem => senderType == 'SYSTEM';
  bool get isImage => messageType == 'IMAGE';
}

class ChatMessagesPageModel {
  final List<ChatMessageModel> messages;
  final String? lastMessageId;
  final bool hasMore;
  final int totalCount;

  ChatMessagesPageModel({
    required this.messages,
    this.lastMessageId,
    required this.hasMore,
    required this.totalCount,
  });

  factory ChatMessagesPageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessagesPageModel(
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessageId: json['lastMessageId'],
      hasMore: json['hasMore'] ?? false,
      totalCount: json['totalCount'] ?? 0,
    );
  }
}

class SendMessageRequest {
  final String conversationId;
  final String? senderId;
  final String? senderName;
  final String content;
  final String messageType;
  final String? imageUrl;

  SendMessageRequest({
    required this.conversationId,
    this.senderId,
    this.senderName,
    required this.content,
    this.messageType = 'TEXT',
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'messageType': messageType,
      'imageUrl': imageUrl,
    };
  }
}
