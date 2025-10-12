import 'package:flutter/foundation.dart';
import '../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import 'service_locator.dart';

/// Helper class to handle hot reload issues
class HotReloadHelper {
  /// Reset all singletons that might cause issues during hot reload
  static void resetProblematicInstances() {
    try {
      // Reset AuthViewModel static instance
      AuthViewModel.resetInstance();

      // Reset the AuthViewModel in GetIt
      if (getIt.isRegistered<AuthViewModel>()) {
        debugPrint('Resetting AuthViewModel in service locator');
        // For factory registrations, no need to reset
      }

      debugPrint('Successfully reset instances for hot reload');
    } catch (e) {
      debugPrint('Error resetting instances for hot reload: $e');
    }
  }
}
