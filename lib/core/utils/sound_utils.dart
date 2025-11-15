import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Sound types for different notifications
enum SoundType {
  success,
  info,
  warning,
  error,
  newIssue,
  sealAssignment,
  damageResolved,
  orderRejectionResolved,
  paymentSuccess,
}

/// Sound utility class for playing notification sounds
class SoundUtils {
  static const MethodChannel _channel = MethodChannel('sound_utils');

  /// Play notification sound based on type
  static Future<void> playNotificationSound(SoundType type, {double volume = 0.7}) async {
    try {
      debugPrint('🔊 [SoundUtils] Playing notification sound: $type');
      
      // Use system sounds + haptic feedback for different notification types
      switch (type) {
        case SoundType.success:
        case SoundType.damageResolved:
        case SoundType.orderRejectionResolved:
          debugPrint('🔊 [SoundUtils] Playing single system click + light haptic');
          await SystemSound.play(SystemSoundType.click);
          await HapticFeedback.lightImpact();
          break;
        case SoundType.paymentSuccess:
          // Play multiple success beeps + heavy haptic for payment confirmation
          debugPrint('🔊 [SoundUtils] Playing 2 beeps + heavy haptic for payment success');
          await HapticFeedback.heavyImpact();
          await _playMultipleBeeps(2, 300);
          break;
        case SoundType.info:
          debugPrint('🔊 [SoundUtils] Playing info sound + selection haptic');
          await SystemSound.play(SystemSoundType.click);
          await HapticFeedback.selectionClick();
          break;
        case SoundType.warning:
        case SoundType.newIssue:
        case SoundType.sealAssignment:
          // Play multiple beeps + medium haptic for important notifications
          debugPrint('🔊 [SoundUtils] Playing 2 beeps + medium haptic for warning/issue');
          await HapticFeedback.mediumImpact();
          await _playMultipleBeeps(2, 200);
          break;
        case SoundType.error:
          debugPrint('🔊 [SoundUtils] Playing 3 beeps + vibrate for error');
          await HapticFeedback.vibrate();
          await _playMultipleBeeps(3, 150);
          break;
      }
      
      debugPrint('✅ [SoundUtils] Sound played successfully');
    } catch (e) {
      debugPrint('❌ [SoundUtils] Error playing notification sound: $e');
    }
  }

  /// Play multiple system beeps with interval
  static Future<void> _playMultipleBeeps(int count, int intervalMs) async {
    for (int i = 0; i < count; i++) {
      await SystemSound.play(SystemSoundType.click);
      if (i < count - 1) {
        await Future.delayed(Duration(milliseconds: intervalMs));
      }
    }
  }

  /// Play success sound
  static Future<void> playSuccessSound() async {
    await playNotificationSound(SoundType.success);
  }

  /// Play warning sound
  static Future<void> playWarningSound() async {
    await playNotificationSound(SoundType.warning);
  }

  /// Play error sound
  static Future<void> playErrorSound() async {
    await playNotificationSound(SoundType.error);
  }

  /// Play sound for new issue notifications
  static Future<void> playNewIssueSound() async {
    await playNotificationSound(SoundType.newIssue);
  }

  /// Play sound for seal assignment notifications
  static Future<void> playSealAssignmentSound() async {
    await playNotificationSound(SoundType.sealAssignment);
  }

  /// Play sound for damage resolved notifications
  static Future<void> playDamageResolvedSound() async {
    await playNotificationSound(SoundType.damageResolved);
  }

  /// Play sound for order rejection resolved notifications
  static Future<void> playOrderRejectionResolvedSound() async {
    await playNotificationSound(SoundType.orderRejectionResolved);
  }

  /// Play sound for payment success notifications
  static Future<void> playPaymentSuccessSound() async {
    await playNotificationSound(SoundType.paymentSuccess);
  }
}
