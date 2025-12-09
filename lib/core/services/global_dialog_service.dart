import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../utils/sound_utils.dart';
import '../../app/di/service_locator.dart';
import '../../app/app_routes.dart';
import '../../domain/repositories/issue_repository.dart';
import '../../domain/entities/order_detail.dart';
import '../../domain/entities/issue.dart';
import '../../presentation/features/delivery/widgets/report_seal_issue_bottom_sheet.dart';
import '../../presentation/features/delivery/widgets/confirm_seal_replacement_sheet.dart';
import './global_location_manager.dart';
import './navigation_state_service.dart';
import './notification_service.dart';

/// Enum for different notification dialog types
enum GlobalDialogType {
  returnPaymentSuccess,
  returnPaymentTimeout,
  sealAssignment,
  damageResolved,
  orderRejectionResolved,
  rerouteResolved,
}

/// Data class for pending notification
class PendingNotification {
  final GlobalDialogType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  PendingNotification({
    required this.type,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  PendingNotification copyWithRetry() {
    return PendingNotification(
      type: type,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount + 1,
    );
  }

  /// Check if notification is expired (older than 5 minutes)
  bool get isExpired =>
      DateTime.now().difference(createdAt).inMinutes > 5;

  /// Check if max retries reached
  bool get maxRetriesReached => retryCount >= 20; // 20 retries × 500ms = 10 seconds
}

/// Global Dialog Service - Shows dialogs from global context
/// Ensures dialogs are ALWAYS shown regardless of current screen
/// Uses pending queue to handle cases when context is not ready
class GlobalDialogService {
  static final GlobalDialogService _instance = GlobalDialogService._internal();
  factory GlobalDialogService() => _instance;
  GlobalDialogService._internal();

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _isInitialized = false;

  /// Pending notification queue - FIFO order
  final Queue<PendingNotification> _pendingQueue = Queue<PendingNotification>();

  /// Track if a dialog is currently showing to prevent overlaps
  bool _isDialogShowing = false;

  /// Track shown notification IDs to prevent duplicates
  final Set<String> _shownNotificationIds = {};

  /// Timer for processing pending queue
  Timer? _queueProcessorTimer;

  /// Stream controllers for notifying screens about events (for data refresh)
  final StreamController<Map<String, dynamic>> _returnPaymentSuccessController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get returnPaymentSuccessStream =>
      _returnPaymentSuccessController.stream;

  final StreamController<Map<String, dynamic>> _sealAssignmentController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get sealAssignmentStream =>
      _sealAssignmentController.stream;

  final StreamController<Map<String, dynamic>> _damageResolvedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get damageResolvedStream =>
      _damageResolvedController.stream;

  final StreamController<Map<String, dynamic>> _orderRejectionResolvedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get orderRejectionResolvedStream =>
      _orderRejectionResolvedController.stream;

  final StreamController<Map<String, dynamic>> _paymentTimeoutController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get paymentTimeoutStream =>
      _paymentTimeoutController.stream;

  final StreamController<Map<String, dynamic>> _rerouteResolvedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get rerouteResolvedStream =>
      _rerouteResolvedController.stream;

  /// Stream for triggering navigation screen refresh
  final StreamController<void> _refreshController =
      StreamController<void>.broadcast();
  Stream<void> get refreshStream => _refreshController.stream;

  /// Stream for seal confirm action (when user clicks confirm in seal assignment dialog)
  final StreamController<Map<String, dynamic>> _sealConfirmActionController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get sealConfirmActionStream =>
      _sealConfirmActionController.stream;

  /// Initialize with navigator key
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    if (_isInitialized) {
      print('⚠️ [GlobalDialogService] Already initialized');
      return;
    }

    print('🚀 [GlobalDialogService] Initializing...');
    _navigatorKey = navigatorKey;
    _isInitialized = true;

    // Start queue processor
    _startQueueProcessor();

    print('✅ [GlobalDialogService] Initialized successfully');
  }

  /// Start periodic queue processor
  void _startQueueProcessor() {
    _queueProcessorTimer?.cancel();
    _queueProcessorTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _processQueue(),
    );
  }

  /// Process pending notification queue
  void _processQueue() {
    if (_pendingQueue.isEmpty) return;
    if (_isDialogShowing) {
      print('⏳ [GlobalDialogService] Dialog showing, waiting...');
      return;
    }

    final context = _navigatorKey?.currentContext;
    if (context == null) {
      print('⏳ [GlobalDialogService] Context not ready, waiting...');
      return;
    }

    // Get next notification from queue
    final notification = _pendingQueue.removeFirst();

    // Check if expired
    if (notification.isExpired) {
      print('⚠️ [GlobalDialogService] Notification expired, skipping: ${notification.type}');
      // Process next in queue
      if (_pendingQueue.isNotEmpty) {
        _processQueue();
      }
      return;
    }

    // Show dialog
    print('🎯 [GlobalDialogService] Processing notification: ${notification.type}');
    _showDialogForNotification(context, notification);
  }

  /// Get unique notification ID
  String _getNotificationId(GlobalDialogType type, Map<String, dynamic> data) {
    final timestamp = data['timestamp'] ?? DateTime.now().toIso8601String();
    switch (type) {
      case GlobalDialogType.returnPaymentSuccess:
        return 'return-payment-${data['issueId']}-$timestamp';
      case GlobalDialogType.returnPaymentTimeout:
        return 'payment-timeout-${data['issueId']}-$timestamp';
      case GlobalDialogType.sealAssignment:
        return 'seal-assignment-${data['issueId']}-$timestamp';
      case GlobalDialogType.damageResolved:
        final issue = data['issue'] as Map<String, dynamic>?;
        return 'damage-resolved-${issue?['id']}-$timestamp';
      case GlobalDialogType.orderRejectionResolved:
        final issue = data['issue'] as Map<String, dynamic>?;
        return 'order-rejection-resolved-${issue?['id']}-$timestamp';
      case GlobalDialogType.rerouteResolved:
        return 'reroute-resolved-${data['issueId']}-$timestamp';
    }
  }

  /// Check if notification was already shown
  bool _wasAlreadyShown(GlobalDialogType type, Map<String, dynamic> data) {
    final id = _getNotificationId(type, data);
    return _shownNotificationIds.contains(id);
  }

  /// Mark notification as shown
  void _markAsShown(GlobalDialogType type, Map<String, dynamic> data) {
    final id = _getNotificationId(type, data);
    _shownNotificationIds.add(id);

    // Keep only last 50 IDs to prevent memory leak
    if (_shownNotificationIds.length > 50) {
      final toRemove = _shownNotificationIds.take(
        _shownNotificationIds.length - 50,
      ).toList();
      _shownNotificationIds.removeAll(toRemove);
    }
  }

  /// Show dialog for notification type
  void _showDialogForNotification(
    BuildContext context,
    PendingNotification notification,
  ) {
    switch (notification.type) {
      case GlobalDialogType.returnPaymentSuccess:
        _showReturnPaymentSuccessDialog(context, notification.data);
        break;
      case GlobalDialogType.returnPaymentTimeout:
        _showReturnPaymentTimeoutDialog(context, notification.data);
        break;
      case GlobalDialogType.sealAssignment:
        _showSealAssignmentDialog(context, notification.data);
        break;
      case GlobalDialogType.damageResolved:
        _showDamageResolvedDialog(context, notification.data);
        break;
      case GlobalDialogType.orderRejectionResolved:
        _showOrderRejectionResolvedDialog(context, notification.data);
        break;
      case GlobalDialogType.rerouteResolved:
        _showRerouteResolvedDialog(context, notification.data);
        break;
    }
  }

  // ============= PUBLIC METHODS FOR NOTIFICATION SERVICE =============

  /// Handle return payment success notification
  void handleReturnPaymentSuccess(Map<String, dynamic> data) {
    print('🔔 [GlobalDialogService] handleReturnPaymentSuccess called');
    print('   Data: $data');

    // Check for duplicates
    if (_wasAlreadyShown(GlobalDialogType.returnPaymentSuccess, data)) {
      print('⚠️ [GlobalDialogService] Return payment notification already shown');
      return;
    }

    // Play success sound immediately
    SoundUtils.playPaymentSuccessSound();

    // Add to queue
    _pendingQueue.add(PendingNotification(
      type: GlobalDialogType.returnPaymentSuccess,
      data: data,
    ));

    print('📥 [GlobalDialogService] Added to queue, queue size: ${_pendingQueue.length}');

    // Emit to stream for screens that need to refresh data
    _returnPaymentSuccessController.add(data);

    // Trigger refresh
    _refreshController.add(null);

    // Try to process immediately
    _processQueue();
  }

  /// Handle return payment timeout notification
  void handleReturnPaymentTimeout(Map<String, dynamic> data) {
    print('🔔 [GlobalDialogService] handleReturnPaymentTimeout called');

    if (_wasAlreadyShown(GlobalDialogType.returnPaymentTimeout, data)) {
      print('⚠️ [GlobalDialogService] Payment timeout notification already shown');
      return;
    }

    // Play warning sound
    SoundUtils.playWarningSound();

    _pendingQueue.add(PendingNotification(
      type: GlobalDialogType.returnPaymentTimeout,
      data: data,
    ));

    _paymentTimeoutController.add(data);
    _refreshController.add(null);
    _processQueue();
  }

  /// Handle seal assignment notification
  void handleSealAssignment(Map<String, dynamic> data) {
    print('🔔 [GlobalDialogService] handleSealAssignment called');
    print('   Data: $data');

    if (_wasAlreadyShown(GlobalDialogType.sealAssignment, data)) {
      print('⚠️ [GlobalDialogService] Seal assignment notification already shown');
      return;
    }

    // Play seal assignment sound
    SoundUtils.playSealAssignmentSound();

    _pendingQueue.add(PendingNotification(
      type: GlobalDialogType.sealAssignment,
      data: data,
    ));

    _sealAssignmentController.add(data);
    _refreshController.add(null);
    _processQueue();
  }

  /// Handle damage resolved notification
  void handleDamageResolved(Map<String, dynamic> data) {
    print('🔔 [GlobalDialogService] handleDamageResolved called');

    if (_wasAlreadyShown(GlobalDialogType.damageResolved, data)) {
      print('⚠️ [GlobalDialogService] Damage resolved notification already shown');
      return;
    }

    SoundUtils.playDamageResolvedSound();

    _pendingQueue.add(PendingNotification(
      type: GlobalDialogType.damageResolved,
      data: data,
    ));

    _damageResolvedController.add(data);
    _refreshController.add(null);
    _processQueue();
  }

  /// Handle order rejection resolved notification
  void handleOrderRejectionResolved(Map<String, dynamic> data) {
    print('🔔 [GlobalDialogService] handleOrderRejectionResolved called');

    if (_wasAlreadyShown(GlobalDialogType.orderRejectionResolved, data)) {
      print('⚠️ [GlobalDialogService] Order rejection resolved notification already shown');
      return;
    }

    SoundUtils.playOrderRejectionResolvedSound();

    _pendingQueue.add(PendingNotification(
      type: GlobalDialogType.orderRejectionResolved,
      data: data,
    ));

    _orderRejectionResolvedController.add(data);
    _refreshController.add(null);
    _processQueue();
  }

  /// Handle reroute resolved notification
  void handleRerouteResolved(Map<String, dynamic> data) {
    print('🔔 [GlobalDialogService] handleRerouteResolved called');

    if (_wasAlreadyShown(GlobalDialogType.rerouteResolved, data)) {
      print('⚠️ [GlobalDialogService] Reroute resolved notification already shown');
      return;
    }

    SoundUtils.playOrderRejectionResolvedSound();

    _pendingQueue.add(PendingNotification(
      type: GlobalDialogType.rerouteResolved,
      data: data,
    ));

    _rerouteResolvedController.add(data);
    _refreshController.add(null);
    _processQueue();
  }

  /// Trigger refresh for navigation screen
  void triggerRefresh() {
    _refreshController.add(null);
  }

  // ============= DIALOG IMPLEMENTATIONS =============

  /// Show return payment success dialog
  Future<void> _showReturnPaymentSuccessDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    _isDialogShowing = true;
    _markAsShown(GlobalDialogType.returnPaymentSuccess, data);

    final vehicleAssignmentId = data['vehicleAssignmentId'] as String?;

    print('🎯 [GlobalDialogService] Showing return payment success dialog');
    print('   Vehicle Assignment ID: $vehicleAssignmentId');

    // Pre-fetch seal data for instant display
    List<VehicleSeal>? preFetchedSeals;
    if (vehicleAssignmentId != null) {
      try {
        final issueRepository = getIt<IssueRepository>();
        final inUseSealData = await issueRepository.getInUseSeal(vehicleAssignmentId);
        if (inUseSealData != null && inUseSealData is Map<String, dynamic>) {
          preFetchedSeals = [
            VehicleSeal(
              id: inUseSealData['id'] ?? '',
              description: inUseSealData['description'] ?? '',
              sealDate: inUseSealData['sealDate'] != null
                  ? DateTime.parse(inUseSealData['sealDate'])
                  : DateTime.now(),
              status: inUseSealData['status'] ?? 'IN_USE',
              sealCode: inUseSealData['sealCode'] ?? '',
              sealAttachedImage: inUseSealData['sealAttachedImage'],
            ),
          ];
          print('✅ [GlobalDialogService] Seal data pre-fetched');
        }
      } catch (e) {
        print('⚠️ [GlobalDialogService] Failed to pre-fetch seal: $e');
      }
    }

    // Dismiss any existing waiting dialog
    try {
      Navigator.of(context, rootNavigator: true).pop();
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (_) {}

    if (!context.mounted) {
      _isDialogShowing = false;
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_open_rounded,
                color: Colors.orange.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Yêu cầu báo cáo seal',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Khách hàng đã thanh toán cước trả hàng. Vui lòng báo cáo seal đã bị gỡ lên hệ thống để chuẩn bị trả hàng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Open seal report bottom sheet
                _openSealReportBottomSheet(
                  context,
                  vehicleAssignmentId,
                  preFetchedSeals,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Báo cáo seal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );

    _isDialogShowing = false;
    print('✅ [GlobalDialogService] Return payment dialog dismissed');
  }

  /// Open seal report bottom sheet
  Future<void> _openSealReportBottomSheet(
    BuildContext context,
    String? vehicleAssignmentId,
    List<VehicleSeal>? preFetchedSeals,
  ) async {
    if (vehicleAssignmentId == null) {
      print('⚠️ [GlobalDialogService] No vehicle assignment ID for seal report');
      return;
    }

    List<VehicleSeal> seals = preFetchedSeals ?? [];

    // Fetch seals if not pre-fetched
    if (seals.isEmpty) {
      try {
        final issueRepository = getIt<IssueRepository>();
        final inUseSealData = await issueRepository.getInUseSeal(vehicleAssignmentId);
        if (inUseSealData != null && inUseSealData is Map<String, dynamic>) {
          seals = [
            VehicleSeal(
              id: inUseSealData['id'] ?? '',
              description: inUseSealData['description'] ?? '',
              sealDate: inUseSealData['sealDate'] != null
                  ? DateTime.parse(inUseSealData['sealDate'])
                  : DateTime.now(),
              status: inUseSealData['status'] ?? 'IN_USE',
              sealCode: inUseSealData['sealCode'] ?? '',
              sealAttachedImage: inUseSealData['sealAttachedImage'],
            ),
          ];
        }
      } catch (e) {
        print('⚠️ [GlobalDialogService] Failed to fetch seal: $e');
      }
    }

    if (seals.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy seal nào đang sử dụng'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // ✅ Get current location from GlobalLocationManager
    double? currentLatitude;
    double? currentLongitude;
    try {
      final locationManager = getIt<GlobalLocationManager>();
      currentLatitude = locationManager.currentLatitude;
      currentLongitude = locationManager.currentLongitude;
      if (currentLatitude != null && currentLongitude != null) {
        print('📍 [GlobalDialogService] Got location for seal report: $currentLatitude, $currentLongitude');
      } else {
        print('⚠️ [GlobalDialogService] No current location available for seal report');
      }
    } catch (e) {
      print('⚠️ [GlobalDialogService] Failed to get location: $e');
    }

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => ReportSealIssueBottomSheet(
        vehicleAssignmentId: vehicleAssignmentId,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        availableSeals: seals,
      ),
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔓 Đã báo cáo seal bị gỡ. Vui lòng chờ staff gán seal mới...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      _refreshController.add(null);
    }
  }

  /// Show return payment timeout dialog
  Future<void> _showReturnPaymentTimeoutDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    _isDialogShowing = true;
    _markAsShown(GlobalDialogType.returnPaymentTimeout, data);

    print('🎯 [GlobalDialogService] Showing payment timeout dialog');

    // Dismiss any existing waiting dialog first
    try {
      Navigator.of(context, rootNavigator: true).pop();
      await Future.delayed(const Duration(milliseconds: 100));
      print('   ✅ Dismissed waiting dialog');
    } catch (_) {
      print('   ℹ️ No waiting dialog to dismiss');
    }

    if (!context.mounted) {
      _isDialogShowing = false;
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.timer_off_rounded,
                color: Colors.red.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hết thời gian thanh toán',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Khách hàng đã hết hạn thanh toán cước trả hàng. Vui lòng tiếp tục theo lộ trình ban đầu về carrier. Các kiện hàng bị từ chối sẽ được hủy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Đã hiểu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );

    _isDialogShowing = false;
  }

  /// Show seal assignment dialog
  Future<void> _showSealAssignmentDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    _isDialogShowing = true;
    _markAsShown(GlobalDialogType.sealAssignment, data);

    final issueId = data['issueId'] as String?;
    final oldSeal = data['oldSeal'] as Map<String, dynamic>?;
    final newSeal = data['newSeal'] as Map<String, dynamic>?;
    final staff = data['staff'] as Map<String, dynamic>?;

    print('🎯 [GlobalDialogService] Showing seal assignment dialog');
    print('   Issue ID: $issueId');
    print('   Old Seal: ${oldSeal?['sealCode']}');
    print('   New Seal: ${newSeal?['sealCode']}');

    // Dismiss any existing waiting dialog first
    try {
      Navigator.of(context, rootNavigator: true).pop();
      await Future.delayed(const Duration(milliseconds: 100));
      print('   ✅ Dismissed waiting dialog');
    } catch (_) {
      print('   ℹ️ No waiting dialog to dismiss');
    }

    if (!context.mounted) {
      _isDialogShowing = false;
      return;
    }

    // Check if currently on NavigationScreen using GlobalLocationManager rather than ModalRoute,
    // because the global navigator context may not reflect the inner navigation route name.
    bool isOnNavigationScreen = false;
    String? currentScreenName;
    try {
      final globalLocationManager = getIt<GlobalLocationManager>();
      currentScreenName = globalLocationManager.currentScreen;
      isOnNavigationScreen = currentScreenName == 'NavigationScreen';
    } catch (e) {
      // Fallback: if GlobalLocationManager is not available for some reason,
      // keep isOnNavigationScreen as false so we take the safe generic path.
      print('⚠️ [GlobalDialogService] Failed to read currentScreen from GlobalLocationManager: $e');
    }

    print('   📍 currentScreen: $currentScreenName, isOnNavigationScreen: $isOnNavigationScreen');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                color: Colors.green.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Seal mới đã được gán',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (staff != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nhân viên: ${staff['fullName'] ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            if (oldSeal != null)
              _buildSealInfoRow('Seal cũ:', oldSeal['sealCode'] ?? 'N/A', Colors.red),
            if (newSeal != null)
              _buildSealInfoRow('Seal mới:', newSeal['sealCode'] ?? 'N/A', Colors.green),
            const SizedBox(height: 12),
            const Text(
              'Vui lòng gắn seal mới và chụp ảnh xác nhận để tiếp tục hành trình.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                
                // ✅ CRITICAL: Handle differently based on current screen
                if (isOnNavigationScreen) {
                  // If on NavigationScreen, emit event for NavigationScreen to handle
                  // NavigationScreen will open confirm seal bottom sheet and handle auto-resume
                  _sealConfirmActionController.add({
                    'issueId': issueId,
                    'oldSeal': oldSeal,
                    'newSeal': newSeal,
                    'staff': staff,
                  });
                  print('📢 [GlobalDialogService] Seal confirm action emitted (NavigationScreen will handle)');
                } else {
                  // If NOT on NavigationScreen (e.g., IssueReportScreen), 
                  // GlobalDialogService handles confirm seal sheet directly
                  // and then navigates to NavigationScreen
                  _handleConfirmSealFromOtherScreen(
                    context,
                    issueId,
                    oldSeal,
                    newSeal,
                    staff,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Xác nhận seal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );

    _isDialogShowing = false;
  }

  /// Handle confirm seal from screens other than NavigationScreen (e.g., IssueReportScreen)
  /// This method shows confirm seal bottom sheet and then navigates to NavigationScreen
  Future<void> _handleConfirmSealFromOtherScreen(
    BuildContext context,
    String? issueId,
    Map<String, dynamic>? oldSeal,
    Map<String, dynamic>? newSeal,
    Map<String, dynamic>? staff,
  ) async {
    print('🔧 [GlobalDialogService] Handling confirm seal from other screen');
    
    if (issueId == null || oldSeal == null || newSeal == null) {
      print('⚠️ [GlobalDialogService] Missing seal data');
      return;
    }

    if (!context.mounted) return;

    // Build Issue object
    final issue = Issue(
      id: issueId,
      description: 'Seal replacement',
      status: IssueStatus.inProgress,
      issueCategory: IssueCategory.sealReplacement,
      oldSeal: Seal.fromJson(oldSeal),
      newSeal: Seal.fromJson(newSeal),
      staffId: staff?['id'] as String?,
    );

    // Show confirm seal replacement bottom sheet
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ConfirmSealReplacementSheet(
        issue: issue,
        onConfirm: (imageBase64) async {
          try {
            final issueRepository = getIt<IssueRepository>();
            await issueRepository.confirmSealReplacement(
              issueId: issue.id,
              newSealAttachedImage: imageBase64,
            );
            print('✅ [GlobalDialogService] Seal confirmation API call successful');
            return;
          } catch (e) {
            print('❌ [GlobalDialogService] Seal confirmation failed: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e')),
              );
            }
            rethrow;
          }
        },
      ),
    );

    // After bottom sheet is closed, check result
    if (result == true && context.mounted) {
      print('✅ [GlobalDialogService] Seal confirmed from other screen, navigating to NavigationScreen');
      
      // Wait a bit for backend to update
      await Future.delayed(const Duration(milliseconds: 500));

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã xác nhận gắn seal mới thành công. Đang chuyển về màn hình điều hướng...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Trigger navigation screen refresh
      try {
        getIt<NotificationService>().triggerNavigationScreenRefresh();
      } catch (e) {
        print('⚠️ [GlobalDialogService] Failed to trigger refresh: $e');
      }

      // Get saved order ID for navigation
      String? orderId;
      try {
        final navigationStateService = getIt<NavigationStateService>();
        orderId = navigationStateService.getActiveOrderId();
      } catch (e) {
        print('⚠️ [GlobalDialogService] Failed to get active order ID: $e');
      }

      if (orderId != null && context.mounted) {
        // Small delay to let snackbar show
        await Future.delayed(const Duration(milliseconds: 300));

        // Navigate to NavigationScreen with auto-resume
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.navigation,
          (route) => route.settings.name == AppRoutes.home,
          arguments: {
            'orderId': orderId,
            'isSimulationMode': true,
            'autoResume': true,
          },
        );
        print('✅ [GlobalDialogService] Navigated to NavigationScreen with orderId: $orderId');
      } else {
        print('⚠️ [GlobalDialogService] No active order ID, cannot navigate to NavigationScreen');
      }
    }
  }

  Widget _buildSealInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show damage resolved dialog
  Future<void> _showDamageResolvedDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    _isDialogShowing = true;
    _markAsShown(GlobalDialogType.damageResolved, data);

    final issue = data['issue'] as Map<String, dynamic>?;

    print('🎯 [GlobalDialogService] Showing damage resolved dialog');

    // Dismiss any existing waiting dialog first
    try {
      Navigator.of(context, rootNavigator: true).pop();
      await Future.delayed(const Duration(milliseconds: 100));
      print('   ✅ Dismissed waiting dialog');
    } catch (_) {
      print('   ℹ️ No waiting dialog to dismiss');
    }

    if (!context.mounted) {
      _isDialogShowing = false;
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sự cố đã được giải quyết',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sự cố hàng hóa bị hư hỏng đã được xử lý. Bạn có thể tiếp tục hành trình vận chuyển.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Tiếp tục hành trình',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );

    _isDialogShowing = false;
  }

  /// Show order rejection resolved dialog
  Future<void> _showOrderRejectionResolvedDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    _isDialogShowing = true;
    _markAsShown(GlobalDialogType.orderRejectionResolved, data);

    print('🎯 [GlobalDialogService] Showing order rejection resolved dialog');

    // Dismiss any existing waiting dialog first
    try {
      Navigator.of(context, rootNavigator: true).pop();
      await Future.delayed(const Duration(milliseconds: 100));
      print('   ✅ Dismissed waiting dialog');
    } catch (_) {
      print('   ℹ️ No waiting dialog to dismiss');
    }

    if (!context.mounted) {
      _isDialogShowing = false;
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sự cố từ chối đã xử lý',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sự cố khách hàng từ chối nhận hàng đã được xử lý. Bạn có thể tiếp tục hành trình.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Tiếp tục hành trình',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );

    _isDialogShowing = false;
  }

  /// Show reroute resolved dialog
  Future<void> _showRerouteResolvedDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    _isDialogShowing = true;
    _markAsShown(GlobalDialogType.rerouteResolved, data);

    print('🎯 [GlobalDialogService] Showing reroute resolved dialog');

    // Dismiss any existing waiting dialog first
    try {
      Navigator.of(context, rootNavigator: true).pop();
      await Future.delayed(const Duration(milliseconds: 100));
      print('   ✅ Dismissed waiting dialog');
    } catch (_) {
      print('   ℹ️ No waiting dialog to dismiss');
    }

    if (!context.mounted) {
      _isDialogShowing = false;
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.route_rounded,
                color: Colors.blue.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lộ trình mới đã sẵn sàng',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nhân viên đã tạo lộ trình mới tránh khu vực gặp sự cố. Vui lòng tiếp tục theo tuyến đường mới.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Xem lộ trình mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );

    _isDialogShowing = false;
  }

  /// Dispose resources
  void dispose() {
    _queueProcessorTimer?.cancel();
    _returnPaymentSuccessController.close();
    _sealAssignmentController.close();
    _sealConfirmActionController.close();
    _damageResolvedController.close();
    _orderRejectionResolvedController.close();
    _paymentTimeoutController.close();
    _rerouteResolvedController.close();
    _refreshController.close();
    _pendingQueue.clear();
    _shownNotificationIds.clear();
  }
}
