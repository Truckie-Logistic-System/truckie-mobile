import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_mobile/presentation/features/notification/viewmodels/notification_viewmodel.dart';
import 'package:capstone_mobile/domain/entities/notification.dart' as entities;
import 'package:capstone_mobile/presentation/theme/app_colors.dart';
import 'package:capstone_mobile/presentation/features/notification/screens/notification_detail_screen.dart';
import 'package:capstone_mobile/presentation/common_widgets/skeleton_loader.dart';
import 'package:capstone_mobile/core/services/notification_service.dart';
import 'package:intl/intl.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({Key? key}) : super(key: key);

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize notifications when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<NotificationViewModel>();
      viewModel.initialize();
      
      // Subscribe to WebSocket for real-time updates (silent reload)
      _subscribeToWebSocket(viewModel);
    });
  }

  /// Subscribe to WebSocket notifications for real-time updates
  void _subscribeToWebSocket(NotificationViewModel viewModel) {
    final notificationService = NotificationService();
    
    _notificationSubscription = notificationService.notificationStream.listen(
      (notification) {
        debugPrint('🔔 [NotificationListScreen] New notification received via WebSocket');
        // Silent refresh - no loading spinner, just update the list
        viewModel.refresh(silent: true);
      },
      onError: (error) {
        debugPrint('❌ [NotificationListScreen] WebSocket error: $error');
      },
    );
    
    debugPrint('✅ [NotificationListScreen] Subscribed to WebSocket notifications');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationViewModel>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Thông báo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          Consumer<NotificationViewModel>(
            builder: (context, viewModel, child) {
              if (viewModel.unreadCount > 0) {
                return IconButton(
                  onPressed: viewModel.markAllAsRead,
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  tooltip: 'Đánh dấu tất cả đã đọc',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleFilterMenu,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('Tất cả')),
              const PopupMenuItem(value: 'unread', child: Text('Chưa đọc')),
              const PopupMenuItem(
                value: 'high_priority',
                child: Text('Ưu tiên cao'),
              ),
              const PopupMenuItem(
                value: 'seal_replacement',
                child: Text('Thay thế seal'),
              ),
              const PopupMenuItem(value: 'payment', child: Text('Thanh toán')),
              const PopupMenuItem(
                value: 'clear_filters',
                child: Text('Xóa bộ lọc'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<NotificationViewModel>(
        builder: (context, viewModel, child) {
          switch (viewModel.status) {
            case NotificationStatus.loading:
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    SkeletonLoader(height: 24, width: 150),
                    SizedBox(height: 16),
                    SkeletonLoader(height: 80),
                    SizedBox(height: 12),
                    SkeletonLoader(height: 80),
                    SizedBox(height: 12),
                    SkeletonLoader(height: 80),
                  ],
                ),
              );

            case NotificationStatus.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      viewModel.errorMessage ?? 'Đã xảy ra lỗi',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => viewModel.refresh(),
                      child: Text('Thử lại'),
                    ),
                  ],
                ),
              );

            case NotificationStatus.loaded:
            case NotificationStatus.initial:
              return _buildNotificationList(viewModel);
          }
        },
      ),
    );
  }

  Widget _buildNotificationList(NotificationViewModel viewModel) {
    if (viewModel.notifications.isEmpty) {
      return _buildEmptyState(viewModel);
    }

    return RefreshIndicator(
      onRefresh: () async => await viewModel.refresh(),
      child: Column(
        children: [
          _buildStatsHeader(viewModel),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  viewModel.notifications.length +
                  (viewModel.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == viewModel.notifications.length) {
                  return _buildLoadingMoreIndicator();
                }

                final notification = viewModel.notifications[index];
                return _buildNotificationItem(notification, viewModel);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(NotificationViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Tổng cộng',
            viewModel.totalCount.toString(),
            Colors.blue,
          ),
          _buildStatItem(
            'Chưa đọc',
            viewModel.unreadCount.toString(),
            Colors.red,
          ),
          _buildStatItem(
            'Ưu tiên cao',
            viewModel.highPriorityNotifications.length.toString(),
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildEmptyState(NotificationViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Không có thông báo nào',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Các thông báo mới sẽ xuất hiện ở đây',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: viewModel.refresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Làm mới'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    entities.Notification notification,
    NotificationViewModel viewModel,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[200]! : Colors.blue[200]!,
          width: notification.isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (!notification.isRead) {
              viewModel.markAsRead(notification.id);
            }
            _showNotificationDetail(notification);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationIcon(notification),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                color: notification.isRead
                                    ? Colors.black87
                                    : Colors.blue[900],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: notification.isRead
                              ? Colors.grey[600]
                              : Colors.grey[700],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildNotificationTypeBadge(notification),
                          const Spacer(),
                          Text(
                            _formatTime(notification.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(entities.Notification notification) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getNotificationTypeColor(notification).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          notification.notificationType.icon,
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildNotificationTypeBadge(entities.Notification notification) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getNotificationTypeColor(notification).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        notification.notificationType.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _getNotificationTypeColor(notification),
        ),
      ),
    );
  }

  Color _getNotificationTypeColor(entities.Notification notification) {
    if (notification.notificationType.isHighPriority) {
      return Colors.red;
    } else if (notification.notificationType.isMediumPriority) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }

  Widget _buildLoadingMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  void _handleFilterMenu(String value) {
    final viewModel = context.read<NotificationViewModel>();

    switch (value) {
      case 'all':
        viewModel.setFilters(unreadOnly: false, type: null);
        break;
      case 'unread':
        viewModel.setFilters(unreadOnly: true, type: null);
        break;
      case 'high_priority':
        viewModel.setFilters(
          unreadOnly: false,
          type:
              entities.NotificationType.sealReplacement, // Filter high priority
        );
        break;
      case 'seal_replacement':
        viewModel.setFilters(
          unreadOnly: false,
          type: entities.NotificationType.sealReplacement,
        );
        break;
      case 'payment_success':
        viewModel.setFilters(
          unreadOnly: false,
          type: entities.NotificationType.paymentSuccess,
        );
        break;
      case 'clear_filters':
        viewModel.clearFilters();
        break;
    }
  }

  void _showNotificationDetail(entities.Notification notification) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            NotificationDetailScreen(notificationId: notification.id),
      ),
    );
  }

  Widget _buildNotificationDetailSheet_REMOVED(
    entities.Notification notification,
  ) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildNotificationIcon(notification),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildNotificationTypeBadge(notification),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nội dung',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notification.description,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  if (notification.relatedOrderId != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Mã đơn hàng: ${notification.relatedOrderId}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Thời gian: ${_formatTime(notification.createdAt)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<NotificationViewModel>().markAsRead(
                          notification.id,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Đánh dấu đã đọc'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
