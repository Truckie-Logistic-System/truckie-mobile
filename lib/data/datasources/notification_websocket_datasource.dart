import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:capstone_mobile/core/constants/api_constants.dart';

/// WebSocket DataSource for receiving real-time notifications
/// Connects to backend WebSocket endpoint and listens for driver notifications
class NotificationWebSocketDataSource {
  StompClient? _stompClient;
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  bool get isConnected => _stompClient?.connected ?? false;

  /// Connect to WebSocket with driver ID
  Future<void> connect(String driverId) async {
    if (_stompClient?.connected ?? false) {
      print('✅ WebSocket already connected');
      return;
    }

    print('🔌 Connecting to notification WebSocket for driver: $driverId');

    _stompClient = StompClient(
      config: StompConfig(
        url: '${ApiConstants.wsBaseUrl}${ApiConstants.wsVehicleTrackingEndpoint}',
        onConnect: (StompFrame frame) {
          print('✅ Notification WebSocket connected');
          _subscribeToDriverNotifications(driverId);
        },
        onWebSocketError: (dynamic error) {
          print('❌ WebSocket error: $error');
        },
        onStompError: (StompFrame frame) {
          print('❌ STOMP error: ${frame.body}');
        },
        onDisconnect: (StompFrame frame) {
          print('🔌 Notification WebSocket disconnected');
        },
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
      ),
    );

    _stompClient!.activate();
  }

  /// Subscribe to driver-specific notification topic
  void _subscribeToDriverNotifications(String driverId) {
    final topic = '/topic/driver/$driverId/notifications';
    print('📡 Subscribing to: $topic');

    _stompClient!.subscribe(
      destination: topic,
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            final notification = jsonDecode(frame.body!);
            print('📲 Received notification: ${notification['type']}');
            _notificationController.add(notification);
          } catch (e) {
            print('❌ Error parsing notification: $e');
          }
        }
      },
    );
  }

  /// Disconnect from WebSocket
  void disconnect() {
    if (_stompClient?.connected ?? false) {
      print('🔌 Disconnecting notification WebSocket');
      _stompClient!.deactivate();
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
