import 'package:flutter/material.dart';
import 'package:capstone_mobile/data/datasources/notification_websocket_datasource.dart';
import 'package:capstone_mobile/presentation/widgets/common/seal_assignment_notification_dialog.dart';

/// Provider for managing real-time notifications
/// Handles WebSocket connection and displays notification dialogs
class NotificationProvider extends ChangeNotifier {
  final NotificationWebSocketDataSource _dataSource;
  final BuildContext context;
  
  String? _currentDriverId;
  bool _isConnected = false;

  NotificationProvider({
    required this.context,
    NotificationWebSocketDataSource? dataSource,
  }) : _dataSource = dataSource ?? NotificationWebSocketDataSource() {
    _listenToNotifications();
  }

  bool get isConnected => _isConnected;

  /// Connect to WebSocket with driver ID
  Future<void> connect(String driverId) async {
    if (_currentDriverId == driverId && _isConnected) {
      print('✅ Already connected for driver: $driverId');
      return;
    }

    _currentDriverId = driverId;
    await _dataSource.connect(driverId);
    _isConnected = _dataSource.isConnected;
    notifyListeners();
  }

  /// Listen to notification stream
  void _listenToNotifications() {
    _dataSource.notificationStream.listen((notification) {
      _handleNotification(notification);
    });
  }

  /// Handle incoming notification
  void _handleNotification(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    
    switch (type) {
      case 'SEAL_ASSIGNMENT':
        _showSealAssignmentNotification(notification);
        break;
      default:
        print('⚠️ Unknown notification type: $type');
    }
  }

  /// Show seal assignment notification dialog
  void _showSealAssignmentNotification(Map<String, dynamic> notification) {
    final issue = notification['issue'] as Map<String, dynamic>?;
    
    if (issue == null) {
      print('❌ Missing issue data in notification');
      return;
    }

    // Extract seal codes from issue
    final oldSeal = issue['oldSeal'] as Map<String, dynamic>?;
    final newSeal = issue['newSeal'] as Map<String, dynamic>?;
    final staff = issue['staff'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SealAssignmentNotificationDialog(
        title: notification['title'] ?? 'Thông báo',
        message: notification['message'] ?? '',
        issueId: issue['id'] ?? '',
        newSealCode: newSeal?['sealCode'] ?? 'N/A',
        oldSealCode: oldSeal?['sealCode'] ?? 'N/A',
        staffName: staff?['fullName'] ?? 'N/A',
      ),
    );

    // Play notification sound (optional)
    // You can add sound/vibration here
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _dataSource.disconnect();
    _isConnected = false;
    _currentDriverId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _dataSource.dispose();
    super.dispose();
  }
}
