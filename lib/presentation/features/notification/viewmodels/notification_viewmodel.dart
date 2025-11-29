import 'package:flutter/foundation.dart';
import 'package:capstone_mobile/domain/entities/notification.dart';
import 'package:capstone_mobile/domain/usecases/notification/get_notifications_usecase.dart';
import 'package:capstone_mobile/domain/usecases/notification/mark_notification_read_usecase.dart';
import 'package:capstone_mobile/domain/usecases/notification/get_notification_stats_usecase.dart';

enum NotificationStatus { initial, loading, loaded, error }

class NotificationViewModel extends ChangeNotifier {
  final GetNotificationsUseCase getNotificationsUseCase;
  final MarkNotificationReadUseCase markNotificationReadUseCase;
  final GetNotificationStatsUseCase getNotificationStatsUseCase;

  NotificationViewModel({
    required this.getNotificationsUseCase,
    required this.markNotificationReadUseCase,
    required this.getNotificationStatsUseCase,
  });

  // State
  NotificationStatus _status = NotificationStatus.initial;
  List<Notification> _notifications = [];
  String? _errorMessage;
  int _unreadCount = 0;
  int _totalCount = 0;
  Map<NotificationType, int> _countByType = {};
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;

  // Filters
  bool _unreadOnly = false;
  NotificationType? _selectedType;

  // Getters
  NotificationStatus get status => _status;
  List<Notification> get notifications => _notifications;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;
  int get totalCount => _totalCount;
  Map<NotificationType, int> get countByType => _countByType;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get unreadOnly => _unreadOnly;
  NotificationType? get selectedType => _selectedType;

  List<Notification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  List<Notification> get highPriorityNotifications =>
      _notifications.where((n) => n.notificationType.isHighPriority).toList();

  /// Initialize the viewmodel
  /// Set [showLoading] to false to skip showing loading animation on initial load
  Future<void> initialize({bool showLoading = false}) async {
    if (showLoading) {
      _status = NotificationStatus.loading;
    }
    _currentPage = 0;
    _hasMore = true;
    if (showLoading) {
      notifyListeners();
    }

    await _loadNotifications(refresh: true, silent: !showLoading);
    await _loadNotificationStats();
  }

  /// Load notifications with pagination
  Future<void> _loadNotifications({bool refresh = false, bool silent = false}) async {
    if (refresh) {
      _currentPage = 0;
      _notifications.clear();
      _hasMore = true;
    }

    if (!_hasMore) return;

    final result = await getNotificationsUseCase.call(
      GetNotificationsParams(
        page: _currentPage,
        size: _pageSize,
        unreadOnly: _unreadOnly,
        type: _selectedType,
      ),
    );

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        if (!silent) {
          _status = NotificationStatus.error;
        }
        notifyListeners();
      },
      (newNotifications) {
        if (refresh) {
          _notifications = newNotifications;
        } else {
          _notifications.addAll(newNotifications);
        }

        _hasMore = newNotifications.length == _pageSize;
        _currentPage++;
        // Always update status to loaded, silent only controls skipping loading state
        _status = NotificationStatus.loaded;
        _errorMessage = null;
        notifyListeners();
      },
    );
  }

  /// Load notification statistics
  Future<void> _loadNotificationStats() async {
    final result = await getNotificationStatsUseCase.call();
    result.fold(
      (failure) {
        debugPrint('Failed to load notification stats: ${failure.message}');
      },
      (stats) {
        _unreadCount = stats.unreadCount;
        _totalCount = stats.totalCount;
        _countByType = stats.countByType;
        notifyListeners();
      },
    );
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    await _loadNotifications();

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Refresh notifications
  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      _status = NotificationStatus.loading;
      notifyListeners();
    }
    
    await _loadNotifications(refresh: true, silent: silent);
    await _loadNotificationStats();
  }

  /// Mark notification as read
  /// Uses optimistic update pattern for instant UI feedback
  Future<void> markAsRead(String notificationId) async {
    // Optimistic update - update UI immediately before API call
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
      notifyListeners();
    }

    // Call API in background
    final result = await markNotificationReadUseCase.call(
      MarkNotificationReadParams(notificationId: notificationId),
    );

    result.fold(
      (failure) {
        // Revert optimistic update on error
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: false);
          _unreadCount++;
          notifyListeners();
        }
        _errorMessage = failure.message;
        debugPrint('❌ Failed to mark notification as read: ${failure.message}');
      },
      (_) {
        // Success - UI already updated, nothing to do
        debugPrint('✅ Notification marked as read: $notificationId');
      },
    );
  }

  /// Mark all notifications as read
  /// Uses optimistic update pattern - instant UI feedback without loading spinner
  Future<void> markAllAsRead() async {
    // Store old state for potential revert
    final oldNotifications = List<Notification>.from(_notifications);
    final oldUnreadCount = _unreadCount;

    // Optimistic update - update UI immediately (NO loading spinner)
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _unreadCount = 0;
    notifyListeners();

    // Call API in background
    final result = await markNotificationReadUseCase.callMarkAllAsRead();

    result.fold(
      (failure) {
        // Revert optimistic update on error
        _notifications = oldNotifications;
        _unreadCount = oldUnreadCount;
        _errorMessage = failure.message;
        notifyListeners();
        debugPrint('❌ Failed to mark all notifications as read: ${failure.message}');
      },
      (_) {
        // Success - UI already updated
        debugPrint('✅ All notifications marked as read');
      },
    );
  }

  /// Add new notification (for WebSocket real-time updates)
  void addNotification(Notification notification) {
    _notifications.insert(0, notification);

    if (!notification.isRead) {
      _unreadCount++;
      _totalCount++;

      // Update count by type
      _countByType[notification.notificationType] =
          (_countByType[notification.notificationType] ?? 0) + 1;
    }

    notifyListeners();
  }

  /// Update existing notification (for status changes)
  void updateNotification(Notification updatedNotification) {
    final index = _notifications.indexWhere(
      (n) => n.id == updatedNotification.id,
    );
    if (index != -1) {
      final oldNotification = _notifications[index];
      _notifications[index] = updatedNotification;

      // Update unread count if needed
      if (!oldNotification.isRead && updatedNotification.isRead) {
        _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
      } else if (oldNotification.isRead && !updatedNotification.isRead) {
        _unreadCount++;
      }

      notifyListeners();
    }
  }

  /// Set filters
  void setFilters({bool? unreadOnly, NotificationType? type}) {
    if (unreadOnly != null) _unreadOnly = unreadOnly!;
    if (type != null) _selectedType = type;
    notifyListeners();
    refresh();
  }

  /// Clear filters
  void clearFilters() {
    _unreadOnly = false;
    _selectedType = null;
    notifyListeners();
    refresh();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
