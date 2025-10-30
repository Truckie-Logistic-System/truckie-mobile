import 'package:flutter/foundation.dart';
import '../../app/di/service_locator.dart';

/// Helper class to handle hot reload issues
class HotReloadHelper {
  /// Reset all singletons that might cause issues during hot reload
  static void resetProblematicInstances() {
    try {
      // AuthViewModel is managed by service locator as LazySingleton
      // No need to reset it manually - it will be recreated on demand
      debugPrint('ℹ️ Service locator will manage AuthViewModel lifecycle');
    } catch (e) {
      debugPrint('Error resetting instances for hot reload: $e');
    }
  }
}
