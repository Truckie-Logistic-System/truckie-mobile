import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_mobile/presentation/features/notification/viewmodels/notification_viewmodel.dart';
import 'package:capstone_mobile/presentation/theme/app_colors.dart';

class NotificationBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showBadge;
  final Color? badgeColor;
  final Color? iconColor;
  final double size;

  const NotificationBadge({
    Key? key,
    this.onTap,
    this.showBadge = true,
    this.badgeColor,
    this.iconColor,
    this.size = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, viewModel, child) {
        final unreadCount = viewModel.unreadCount;
        final hasHighPriority = viewModel.highPriorityNotifications.isNotEmpty;

        return GestureDetector(
          onTap: onTap ?? () => _navigateToNotifications(context),
          child: Container(
            width: size + 16,
            height: size + 16,
            child: Stack(
              children: [
                // Notification icon
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.notifications_outlined,
                    size: size,
                    color: iconColor ?? Colors.white,
                  ),
                ),
                
                // Badge for unread count
                if (showBadge && unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _buildBadge(unreadCount, hasHighPriority),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(int unreadCount, bool hasHighPriority) {
    Color badgeBgColor = badgeColor ?? AppColors.primary;
    
    // Use red for high priority notifications
    if (hasHighPriority) {
      badgeBgColor = Colors.red;
    }

    return Container(
      height: 16,
      constraints: const BoxConstraints(minWidth: 16),
      decoration: BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),
      child: Center(
        child: unreadCount > 99
            ? const Text(
                '99+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.pushNamed(context, '/notifications');
  }
}

/// Floating notification button for quick access
class FloatingNotificationButton extends StatelessWidget {
  final VoidCallback? onTap;

  const FloatingNotificationButton({
    Key? key,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, viewModel, child) {
        final unreadCount = viewModel.unreadCount;
        final hasHighPriority = viewModel.highPriorityNotifications.isNotEmpty;

        return FloatingActionButton.extended(
          onPressed: onTap ?? () => _navigateToNotifications(context),
          backgroundColor: hasHighPriority ? Colors.red : AppColors.primary,
          icon: Stack(
            children: [
              const Icon(Icons.notifications),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: hasHighPriority ? Colors.red : AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '9+' : unreadCount.toString(),
                        style: TextStyle(
                          color: hasHighPriority ? Colors.red : AppColors.primary,
                          fontSize: 6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          label: const Text('Thông báo'),
        );
      },
    );
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.pushNamed(context, '/notifications');
  }
}

/// Compact notification badge for app bar
class CompactNotificationBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showBadge;

  const CompactNotificationBadge({
    Key? key,
    this.onTap,
    this.showBadge = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, viewModel, child) {
        final unreadCount = viewModel.unreadCount;
        final hasHighPriority = viewModel.highPriorityNotifications.isNotEmpty;

        return IconButton(
          onPressed: onTap ?? () => _navigateToNotifications(context),
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined),
              if (showBadge && unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: hasHighPriority ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasHighPriority ? Colors.white : Colors.red,
                        width: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.pushNamed(context, '/notifications');
  }
}

/// Notification count widget for dashboard
class NotificationCountWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final bool showIcon;

  const NotificationCountWidget({
    Key? key,
    this.onTap,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationViewModel>(
      builder: (context, viewModel, child) {
        final unreadCount = viewModel.unreadCount;
        final totalCount = viewModel.totalCount;
        final hasHighPriority = viewModel.highPriorityNotifications.isNotEmpty;

        return GestureDetector(
          onTap: onTap ?? () => _navigateToNotifications(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
              border: hasHighPriority
                  ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: 2)
                  : null,
            ),
            child: Column(
              children: [
                if (showIcon) ...[
                  Icon(
                    Icons.notifications_outlined,
                    size: 32,
                    color: hasHighPriority ? Colors.red : AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  unreadCount.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: hasHighPriority ? Colors.red : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Thông báo mới',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (totalCount > unreadCount) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$totalCount tổng cộng',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.pushNamed(context, '/notifications');
  }
}
