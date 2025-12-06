import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/services/http_client_interface.dart';
import '../../core/services/token_storage_service.dart';
import '../models/chat_model.dart';

/// Remote data source for chat operations
class ChatRemoteDataSource {
  final IHttpClient apiClient;
  final String baseUrl;
  final TokenStorageService tokenStorage;

  ChatRemoteDataSource({
    required this.apiClient,
    required this.baseUrl,
    required this.tokenStorage,
  });

  /// Create or get driver conversation
  Future<ChatConversationModel> getOrCreateDriverConversation(
    String driverId, {
    String? vehicleAssignmentId,
  }) async {
    String endpoint = '/user-chat/driver/conversations?driverId=$driverId';
    if (vehicleAssignmentId != null) {
      endpoint += '&vehicleAssignmentId=$vehicleAssignmentId';
    }

    final response = await apiClient.post(endpoint);
    return ChatConversationModel.fromJson(response.data);
  }

  /// Get conversation by ID
  Future<ChatConversationModel> getConversation(String conversationId) async {
    final response =
        await apiClient.get('/user-chat/conversations/$conversationId');
    return ChatConversationModel.fromJson(response.data);
  }

  /// Get messages for a conversation with pagination
  Future<ChatMessagesPageModel> getMessages(
    String conversationId, {
    int page = 0,
    int size = 50,
  }) async {
    final response = await apiClient.get(
      '/user-chat/conversations/$conversationId/messages',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
    return ChatMessagesPageModel.fromJson(response.data);
  }

  /// Send a message
  Future<ChatMessageModel> sendMessage(SendMessageRequest request) async {
    final response = await apiClient.post(
      '/user-chat/conversations/${request.conversationId}/messages',
      data: request.toJson(),
    );
    return ChatMessageModel.fromJson(response.data);
  }
  
  /// Mark messages as read for driver
  Future<void> markAsRead(String conversationId) async {
    await apiClient.put(
      '/user-chat/driver/conversations/$conversationId/read',
    );
  }

  /// Upload chat image
  Future<String> uploadImage(File file, String conversationId) async {
    final uri = Uri.parse('$baseUrl/user-chat/upload-image');
    final token = tokenStorage.getAccessToken();

    final request = http.MultipartRequest('POST', uri);
    request.fields['conversationId'] = conversationId;
    
    // Add authorization header
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final mimeType = _getMimeType(file.path);
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: MediaType.parse(mimeType),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    } else {
      throw Exception('Failed to upload image: ${response.body}');
    }
  }

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
