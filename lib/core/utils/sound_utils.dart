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
/// - Ascending patterns = Positive feedback (success, rewards)
/// - Descending patterns = Negative feedback (errors, warnings)
/// - Short duration = Low priority (info, confirm)
/// - Long duration = High priority (errors, important alerts)
/// - Rich patterns = Rewarding (payment, achievements)
/// - Simple patterns = Subtle (info, minor updates)
class SoundUtils {
  
  // Sound pattern configurations based on notification importance
  static const Map<SoundType, _SoundConfig> _soundConfigs = {
    SoundType.success: _SoundConfig(
      pattern: [100, 80, 60], // Ascending rhythm (fast to slow)
      hapticType: _HapticType.light,
      description: 'Ascending powerup - positive feedback',
    ),
    SoundType.info: _SoundConfig(
      pattern: [50], // Single short blip
      hapticType: _HapticType.selection,
      description: 'Gentle blip - non-intrusive',
    ),
    SoundType.warning: _SoundConfig(
      pattern: [120, 120], // Double equal beeps
      hapticType: _HapticType.medium,
      description: 'Clear double-beep alert',
    ),
    SoundType.error: _SoundConfig(
      pattern: [150, 100, 80], // Descending urgent pattern
      hapticType: _HapticType.heavy,
      description: 'Harsh descending buzz - critical',
    ),
    SoundType.paymentSuccess: _SoundConfig(
      pattern: [80, 60, 50, 40], // Cascading reward pattern
      hapticType: _HapticType.heavy,
      description: 'Rich coin collect - rewarding',
    ),
    SoundType.newIssue: _SoundConfig(
      pattern: [100, 200, 100], // Bell-like ring
      hapticType: _HapticType.medium,
      description: 'Crisp notification bell',
    ),
    SoundType.sealAssignment: _SoundConfig(
      pattern: [120, 180, 120], // Important attention pattern
      hapticType: _HapticType.medium,
      description: 'Important seal assignment alert',
    ),
    SoundType.damageResolved: _SoundConfig(
      pattern: [80, 100], // Confirmation pattern
      hapticType: _HapticType.light,
      description: 'Issue resolved confirmation',
    ),
    SoundType.orderRejectionResolved: _SoundConfig(
      pattern: [80, 100], // Confirmation pattern
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
        debugPrint('⚠️ [SoundUtils] Unknown sound type: $type');
        return;
      }
      
      debugPrint('🔊 [SoundUtils] Playing: ${config.description}');
      debugPrint('   Pattern: ${config.pattern} | Haptic: ${config.hapticType}');
      
      // Play haptic feedback first for immediate tactile response
      await _playHaptic(config.hapticType);
      
      // Play sound pattern
      await _playPattern(config.pattern);
      
      debugPrint('✅ [SoundUtils] Sound completed successfully');
    } catch (e) {
      debugPrint('❌ [SoundUtils] Error playing notification sound: $e');
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
