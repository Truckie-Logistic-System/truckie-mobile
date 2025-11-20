import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';

/// Debug overlay to test WebSocket connection status
class DebugOverlay extends StatelessWidget {
  const DebugOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      right: 20,
      child: FloatingActionButton(
        heroTag: 'debug_ws',
        mini: true,
        backgroundColor: Colors.purple,
        onPressed: () {
          // Check connection status
          NotificationService().checkConnectionStatus();
          
          // Show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔍 Check logs for connection status'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: const Icon(Icons.bug_report, color: Colors.white),
      ),
    );
  }
}
