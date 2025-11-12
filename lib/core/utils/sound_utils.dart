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
}

/// Sound utility class for playing notification sounds
class SoundUtils {
  static const MethodChannel _channel = MethodChannel('sound_utils');

  /// Play notification sound based on type
  static Future<void> playNotificationSound(SoundType type, {double volume = 0.7}) async {
    try {
      // Use system sounds for different notification types
      switch (type) {
        case SoundType.success:
        case SoundType.damageResolved:
        case SoundType.orderRejectionResolved:
          await SystemSound.play(SystemSoundType.click);
          break;
        case SoundType.info:
          await SystemSound.play(SystemSoundType.click);
          break;
        case SoundType.warning:
        case SoundType.newIssue:
        case SoundType.sealAssignment:
          // Play multiple beeps for important notifications
          await _playMultipleBeeps(2, 200);
          break;
        case SoundType.error:
          await _playMultipleBeeps(3, 150);
          break;
      }
    } catch (e) {
      debugPrint('❌ Error playing notification sound: $e');
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
}
