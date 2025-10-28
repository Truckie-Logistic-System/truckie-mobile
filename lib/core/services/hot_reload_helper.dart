import 'package:flutter/foundation.dart';
import '../../app/di/service_locator.dart';

/// Helper class to handle hot reload issues
class HotReloadHelper {
  /// Reset all singletons that might cause issues during hot reload
  static void resetProblematicInstances() {
    try {
      // Reset AuthViewModel using dynamic to avoid presentation layer dependency
      try {
        final authViewModel = getIt.get(instanceName: 'AuthViewModel');
        // AuthViewModel reset is not needed - handled by service locator
        debugPrint('ℹ️ AuthViewModel managed by service locator');
      } catch (e) {
        debugPrint('AuthViewModel not available for reset: $e');
      }

      // debugPrint('Successfully reset instances for hot reload');
    } catch (e) {
      debugPrint('Error resetting instances for hot reload: $e');
    }
  }
}
