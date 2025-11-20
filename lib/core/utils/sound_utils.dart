import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Sound types for different notifications
/// Each type has unique sound pattern and haptic feedback
enum SoundType {
  /// Ascending powerup sound - positive feedback
  success,
  
  /// Gentle blip - non-intrusive info
  info,
  
  /// Alert beep pattern - attention needed
  warning,
  
  /// Harsh descending pattern - critical error
  error,
  
  /// Notification bell - new issue alert
  newIssue,
  
  /// Important alert - seal assignment
  sealAssignment,
  
  /// Resolved confirmation - issue fixed
  damageResolved,
  
  /// Resolved confirmation - rejection handled
  orderRejectionResolved,
  
  /// Rewarding sound - payment received
  paymentSuccess,
}

/// Sound utility class for playing notification sounds
/// 
/// Design Principles:
/// - Single tone = Subtle confirmation (success, info)
/// - Double tone = Important notification (warning, payment)
/// - Very short intervals = Quick, crisp feedback
/// - Light haptic = Professional, non-intrusive
/// - Minimal patterns = Clean business app feel
class SoundUtils {
  
  // Sound pattern configurations - Professional, subtle tones
  static const Map<SoundType, _SoundConfig> _soundConfigs = {
    SoundType.success: _SoundConfig(
      pattern: [60], // Single crisp confirmation
      hapticType: _HapticType.light,
      description: 'Subtle positive confirmation',
    ),
    SoundType.info: _SoundConfig(
      pattern: [40], // Very short blip
      hapticType: _HapticType.selection,
      description: 'Gentle notification blip',
    ),
    SoundType.warning: _SoundConfig(
      pattern: [80, 80], // Two clear tones
      hapticType: _HapticType.light,
      description: 'Gentle but clear alert',
    ),
    SoundType.error: _SoundConfig(
      pattern: [100, 80], // Brief urgent pattern
      hapticType: _HapticType.medium,
      description: 'Clear attention tone',
    ),
    SoundType.paymentSuccess: _SoundConfig(
      pattern: [70, 50], // Pleasant double chime
      hapticType: _HapticType.light,
      description: 'Pleasant confirmation chime',
    ),
    SoundType.newIssue: _SoundConfig(
      pattern: [90, 120], // Soft notification
      hapticType: _HapticType.light,
      description: 'Soft notification ping',
    ),
    SoundType.sealAssignment: _SoundConfig(
      pattern: [100, 100], // Clear double tone
      hapticType: _HapticType.light,
      description: 'Important notification tone',
    ),
    SoundType.damageResolved: _SoundConfig(
      pattern: [60], // Single confirmation
      hapticType: _HapticType.light,
      description: 'Issue resolved confirmation',
    ),
    SoundType.orderRejectionResolved: _SoundConfig(
      pattern: [60], // Single confirmation
      hapticType: _HapticType.light,
      description: 'Rejection resolved confirmation',
    ),
  };

  /// Play notification sound based on type with rich patterns
  /// 
  /// Each sound type has:
  /// - Unique timing pattern (ascending/descending/stable)
  /// - Specific haptic feedback intensity
  /// - Duration optimized for priority level
  static Future<void> playNotificationSound(SoundType type, {double volume = 0.7}) async {
    try {
      final config = _soundConfigs[type];
      if (config == null) {
        return;
      }
      // Play haptic feedback first for immediate tactile response
      await _playHaptic(config.hapticType);
      
      // Play sound pattern
      await _playPattern(config.pattern);
    } catch (e) {
    }
  }

  /// Play sound pattern with dynamic timing
  /// Pattern array defines intervals between beeps in milliseconds
  /// Shorter intervals = faster rhythm = more urgent
  /// Longer intervals = slower rhythm = calmer
  static Future<void> _playPattern(List<int> pattern) async {
    for (int i = 0; i < pattern.length; i++) {
      // Play system click sound
      await SystemSound.play(SystemSoundType.click);
      
      // Wait for specified interval before next beep
      if (i < pattern.length - 1) {
        await Future.delayed(Duration(milliseconds: pattern[i]));
      }
    }
  }
  
  /// Play haptic feedback based on type
  static Future<void> _playHaptic(_HapticType type) async {
    switch (type) {
      case _HapticType.light:
        await HapticFeedback.lightImpact();
        break;
      case _HapticType.medium:
        await HapticFeedback.mediumImpact();
        break;
      case _HapticType.heavy:
        await HapticFeedback.heavyImpact();
        break;
      case _HapticType.selection:
        await HapticFeedback.selectionClick();
        break;
      case _HapticType.vibrate:
        await HapticFeedback.vibrate();
        break;
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

/// Internal configuration for sound patterns
class _SoundConfig {
  final List<int> pattern;
  final _HapticType hapticType;
  final String description;
  
  const _SoundConfig({
    required this.pattern,
    required this.hapticType,
    required this.description,
  });
}

/// Internal haptic feedback types
enum _HapticType {
  light,
  medium,
  heavy,
  selection,
  vibrate,
}
