import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/notification_viewmodel.dart';
import '../../../theme/app_colors.dart';

class AnimatedBellIcon extends StatefulWidget {
  final bool isSelected;
  final double size;
  final Color? color;

  const AnimatedBellIcon({
    Key? key,
    required this.isSelected,
    this.size = 24.0,
    this.color,
  }) : super(key: key);

  @override
  State<AnimatedBellIcon> createState() => _AnimatedBellIconState();
}

class _AnimatedBellIconState extends State<AnimatedBellIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;
  
  int _previousUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Create shake animation: rotate left and right multiple times
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const ShakeCurve(),
    ));

    // Listen to notification changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToNotifications();
    });
  }

  void _listenToNotifications() {
    final notificationViewModel = Provider.of<NotificationViewModel>(context, listen: false);
    
    // Initialize previous count
    _previousUnreadCount = notificationViewModel.unreadCount;
    
    // Listen to changes
    notificationViewModel.addListener(_onNotificationChanged);
  }

  void _onNotificationChanged() {
    final notificationViewModel = Provider.of<NotificationViewModel>(context, listen: false);
    final currentUnreadCount = notificationViewModel.unreadCount;
    
    // Only shake when unread count increases (new notification arrives)
    if (currentUnreadCount > _previousUnreadCount) {
      _triggerShakeAnimation();
    }
    
    _previousUnreadCount = currentUnreadCount;
  }

  void _triggerShakeAnimation() {
    if (_animationController.isCompleted || _animationController.isDismissed) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    final notificationViewModel = Provider.of<NotificationViewModel>(context, listen: false);
    notificationViewModel.removeListener(_onNotificationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, viewModel, child) {
        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _shakeAnimation.value,
              child: Icon(
                Icons.notifications,
                size: widget.size,
                color: widget.color ?? 
                    (widget.isSelected ? AppColors.primary : AppColors.textSecondary),
              ),
            );
          },
        );
      },
    );
  }
}

/// Custom curve for shake animation
class ShakeCurve extends Curve {
  const ShakeCurve();

  @override
  double transform(double t) {
    // Create shake effect: -15° to +15° to -15° to +15° to 0°
    if (t < 0.2) {
      return -15 * (t / 0.2) * (pi / 180); // 0 to -15°
    } else if (t < 0.4) {
      return -15 * (1 - (t - 0.2) / 0.2) * (pi / 180) + 15 * ((t - 0.2) / 0.2) * (pi / 180); // -15° to +15°
    } else if (t < 0.6) {
      return 15 * (1 - (t - 0.4) / 0.2) * (pi / 180) - 15 * ((t - 0.4) / 0.2) * (pi / 180); // +15° to -15°
    } else if (t < 0.8) {
      return -15 * (1 - (t - 0.6) / 0.2) * (pi / 180) + 15 * ((t - 0.6) / 0.2) * (pi / 180); // -15° to +15°
    } else {
      return 15 * (1 - (t - 0.8) / 0.2) * (pi / 180); // +15° to 0°
    }
  }
}
