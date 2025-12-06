import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/order_with_details.dart';
import '../../../../domain/entities/order_detail.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/services/global_location_manager.dart';
import '../../../../core/services/navigation_state_service.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../../../app/di/service_locator.dart';
import '../../../../data/datasources/api_client.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/common_widgets/skeleton_loader.dart';
import '../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../presentation/features/orders/viewmodels/order_detail_viewmodel.dart';
import '../../../../presentation/utils/driver_role_checker.dart';
import '../viewmodels/navigation_viewmodel.dart';
import '../widgets/map/image_based_3d_truck_marker.dart';
import '../widgets/map/vehicle_navigation_marker.dart';
import '../widgets/map/static_vehicle_marker.dart';
import '../widgets/issue_type_selection_bottom_sheet.dart';
import '../widgets/report_seal_issue_bottom_sheet.dart';
import '../../../../core/services/vietmap_service.dart';
import '../widgets/pending_seal_replacement_banner.dart';
import '../widgets/confirm_seal_replacement_sheet.dart';
import '../widgets/fuel_invoice_upload_sheet.dart';
import '../../../../domain/entities/issue.dart';
import '../../../../domain/repositories/issue_repository.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/chat_notification_service.dart';
import '../../../../data/datasources/vehicle_fuel_consumption_data_source.dart';
import '../../chat/chat_screen.dart';
import 'dart:io';

class NavigationScreen extends StatefulWidget {
  final String? orderId;
  final bool isSimulationMode;
  final bool autoResume; // Flag to auto-resume simulation after mount

  const NavigationScreen({
    super.key,
    this.orderId,
    this.isSimulationMode = false,
    this.autoResume = false,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with WidgetsBindingObserver, RouteAware {
  late final NavigationViewModel _viewModel;
  late final GlobalLocationManager _globalLocationManager;
  late final AuthViewModel _authViewModel;

  VietmapController? _mapController;
  String? _mapStyle;
  bool _isMapReady = false;
  bool _isMapInitialized = false;
  bool _isLoadingMapStyle = true;

  // ✅ Unified loading state - ensures ALL components are ready before showing UI
  bool get _isFullyReady =>
      !_isInitializing &&
      !_isLoadingMapStyle &&
      _isMapReady &&
      _isMapInitialized &&
      _initializationError == null;
  bool _isFollowingUser = true;
  bool _isConnectingWebSocket = false;
  bool _isSimulating = false;
  bool _isOffRouteSimulated = false;
  bool _isTripComplete = false;
  bool _isDisposing = false; // Track disposal state to prevent map operations

  // Simulation controls (only used in simulation mode)
  double _simulationSpeed = 1.0;
  bool _isPaused = false;
  
  // Off-route simulation (for testing off-route detection)
  // Offset perpendicular to route direction (in meters) - guaranteed to be off-route
  static const double _offRouteDistanceMeters = 200.0; // 200m perpendicular offset (> 100m threshold)

  int _cameraUpdateCounter = 0;
  final int _cameraUpdateFrequency = 1; // Update camera every frame

  // Biến để theo dõi chế độ 3D
  bool _is3DMode = true;

  // Camera throttling for ultra-fast performance (moveCamera)
  DateTime? _lastCameraUpdate;
  static const _cameraThrottleMs =
      16; // 60 FPS - fastest possible with moveCamera
  
  // Camera lock to prevent jumping during off-route testing
  bool _isCameraLocked = false;

  // Pending seal replacements
  List<Issue> _pendingSealReplacements = [];
  bool _isLoadingPendingSeals = false;

  // Refresh stream subscription
  StreamSubscription<void>? _refreshSubscription;

  // Map loading timeout mechanism
  Timer? _mapLoadingTimeoutTimer;
  static const Duration _mapLoadingTimeout = Duration(seconds: 30);

  // Seal bottom sheet stream subscription
  StreamSubscription<String>? _sealBottomSheetSubscription;

  // Return payment success stream subscription
  StreamSubscription<Map<String, dynamic>>? _returnPaymentSubscription;

  // Track if return payment dialog is showing to prevent duplicates
  bool _isReturnPaymentDialogShowing = false;

  // ✅ NEW: Stream subscriptions for notification dialogs (4 only - seal assignment handled by OrderDetailScreen)
  StreamSubscription<Map<String, dynamic>>? _damageResolvedSubscription;
  StreamSubscription<Map<String, dynamic>>? _orderRejectionResolvedSubscription;
  StreamSubscription<Map<String, dynamic>>? _paymentTimeoutSubscription;
  StreamSubscription<Map<String, dynamic>>? _rerouteResolvedSubscription;

  // Track dialog showing states to prevent duplicates (4 only)
  bool _isDamageResolvedDialogShowing = false;
  bool _isOrderRejectionResolvedDialogShowing = false;
  bool _isPaymentTimeoutDialogShowing = false;
  bool _isRerouteResolvedDialogShowing = false;

  // Fuel consumption state
  String? _fuelConsumptionId;
  bool _isLoadingFuelConsumption = false;

  // Order loading state to prevent duplicate calls
  bool _isLoadingOrder = false;

  // Data readiness state - true when order details loaded and route parsed successfully
  bool _isDataReady = false;

  // Retry tracking for load order details
  int _loadOrderRetryCount = 0;
  static const int _maxLoadOrderRetries = 3;

  // ✅ CRITICAL: Initial loading state - true until order loads successfully for the first time
  bool _isInitializing = true;
  String? _initializationError;

  // Custom marker for current location
  Symbol? _currentLocationMarker;
  
  // Circle to indicate off-route status
  Circle? _offRouteCircle;

  // Waypoint markers list
  List<Marker> _waypointMarkers = [];

  // Throttle _drawRoutes to prevent buffer overflow
  DateTime? _lastDrawRoutesTime;
  static const _drawRoutesThrottleDuration = Duration(milliseconds: 500);

  // Removed didChangeDependencies - using Navigator result pattern instead

  @override
  void initState() {
    super.initState();

    _viewModel = getIt<NavigationViewModel>();
    _globalLocationManager = getIt<GlobalLocationManager>();
    _authViewModel = getIt<AuthViewModel>();

    // Register observers
    WidgetsBinding.instance.addObserver(this);

    // Register this screen with GlobalLocationManager
    _globalLocationManager.registerScreen('NavigationScreen');

    _loadMapStyle();

    // NOTE: Timeout mechanism disabled - map renders asynchronously without blocking UI
    // _startMapLoadingTimeout();

    // 🆕 Subscribe to refresh stream from NotificationService
    final notificationService = getIt<NotificationService>();
    _refreshSubscription = notificationService.refreshStream.listen((_) async {
      // 🔄 CRITICAL: Preserve current segment index before reload (for reroute)
      final previousSegmentIndex = _viewModel.currentSegmentIndex;
      final wasSimulating = _isSimulating;

      print(
        '🔄 Refreshing route - Previous segment: $previousSegmentIndex, Was simulating: $wasSimulating',
      );

      // 🆕 Fetch latest order to get newest journey history (for return routes, reroutes)
      await _loadOrderDetails();

      // 🎯 CRITICAL: Restore current segment index after reload
      if (previousSegmentIndex < _viewModel.routeSegments.length) {
        _viewModel.setCurrentSegmentIndex(previousSegmentIndex);
        print('✅ Restored segment index: $previousSegmentIndex');
      } else {
        print(
          '⚠️ Previous segment index $previousSegmentIndex out of bounds, keeping current: ${_viewModel.currentSegmentIndex}',
        );
      }

      // Re-draw routes with new journey data
      if (_viewModel.routeSegments.isNotEmpty && _isMapReady) {
        _drawRoutes();
      }

      // Fetch pending seal replacements
      await _fetchPendingSealReplacements();
      // Auto-resume simulation if no pending seals
      if (_pendingSealReplacements.isEmpty &&
          widget.isSimulationMode &&
          wasSimulating) {
        print(
          '🔄 Auto-resuming simulation at segment ${_viewModel.currentSegmentIndex}',
        );
        _autoResumeSimulation();
      } else {}
    });

    // 🆕 Subscribe to seal bottom sheet stream from NotificationService
    // Pattern 2: Action-required notification
    _sealBottomSheetSubscription = notificationService.showSealBottomSheetStream
        .listen((issueId) async {
          // Fetch pending seals to get the issue details
          await _fetchPendingSealReplacements();

          // Find the issue in pending list
          Issue? issue;
          try {
            issue = _pendingSealReplacements.firstWhere((i) => i.id == issueId);
          } catch (e) {
            // Issue not found in list
            issue = null;
          }

          if (issue != null) {
            // Show bottom sheet for seal confirmation
            _showConfirmSealSheet(issue);
          } else {}
        });

    // 🆕 Subscribe to return payment success stream from NotificationService
    // Pattern: Info notification with action required
    _returnPaymentSubscription = notificationService.returnPaymentSuccessStream.listen((
      data,
    ) async {
      if (!mounted) return;

      // CRITICAL: Prevent duplicate dialogs
      if (_isReturnPaymentDialogShowing) {
        print('⚠️ Return payment dialog already showing, skipping duplicate');
        return;
      }

      final vehicleAssignmentId = data['vehicleAssignmentId'] as String?;

      // Set flag before showing dialog
      _isReturnPaymentDialogShowing = true;

      // ✅ OPTIMIZATION: Pre-fetch seal data BEFORE showing dialog
      // This eliminates waiting time when user clicks button
      print('🚀 Pre-fetching seal data for instant display...');
      List<VehicleSeal>? preFetchedSeals;
      try {
        final issueRepository = getIt<IssueRepository>();
        final inUseSealData = await issueRepository.getInUseSeal(
          vehicleAssignmentId!,
        );
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
          print('✅ Seal data pre-fetched successfully');
        } else {
          print('⚠️ No seal data available');
        }
      } catch (e) {
        print('⚠️ Failed to pre-fetch seal data: $e');
        preFetchedSeals = null;
      }

      if (!mounted) return;

      // Show return payment success dialog with proper context
      await showDialog(
        context: context, // ✅ Use screen context with Provider access
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon for seal removal
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
              // Title
              const Text(
                'Yêu cầu báo cáo seal',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Message
              const Text(
                'Khách hàng đã thanh toán. Vui lòng báo cáo seal đã bị gỡ lên hệ thống để chuẩn bị trả hàng.',
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
                onPressed: () async {
                  print('🔘 Return payment dialog button clicked');

                  // ✅ CRITICAL: Capture context BEFORE any async operations
                  final navigatorContext = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  // Close dialog immediately
                  navigatorContext.pop();
                  print('✅ Dialog closed, preparing to show seal report...');

                  // ✅ Use unawaited future to avoid blocking and use captured state
                  _handleReturnPaymentSealReport(
                    vehicleAssignmentId: vehicleAssignmentId,
                    scaffoldMessenger: scaffoldMessenger,
                    preFetchedSeals:
                        preFetchedSeals, // Pass pre-fetched data for instant display
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
      ).whenComplete(() {
        // Reset flag when dialog is dismissed (by user action or completion)
        _isReturnPaymentDialogShowing = false;
        print('✅ Return payment dialog dismissed, flag reset');
      });
    });

    // ❌ REMOVED: Seal assignment listener moved to OrderDetailScreen exclusively
    // OrderDetailScreen now handles full flow: notification → confirm seal sheet → upload photo → navigate here with auto-resume
    // This prevents duplicate dialogs and provides better UX with single unified flow

    // ✅ NEW: Subscribe to damage resolved stream
    _damageResolvedSubscription = notificationService.damageResolvedStream
        .listen((data) async {
          if (!mounted || _isDamageResolvedDialogShowing) return;

          _isDamageResolvedDialogShowing = true;
          final isOnNavigationScreen =
              data['isOnNavigationScreen'] as bool? ?? false;

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                      Icons.check_circle_outline,
                      color: Colors.green.shade600,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Sự cố đã được xử lý. Bạn có thể tiếp tục hành trình.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (!isOnNavigationScreen) {
                        final navigationStateService =
                            getIt<NavigationStateService>();
                        final savedOrderId = navigationStateService
                            .getActiveOrderId();
                        if (savedOrderId != null) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.navigation,
                            arguments: {
                              'orderId': savedOrderId,
                              'isSimulationMode': widget.isSimulationMode,
                            },
                          );
                        } else {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.navigation,
                          );
                        }
                      } else {
                        notificationService.triggerNavigationScreenRefresh();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Xác nhận',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).whenComplete(() => _isDamageResolvedDialogShowing = false);
        });

    // ✅ NEW: Subscribe to order rejection resolved stream
    _orderRejectionResolvedSubscription = notificationService
        .orderRejectionResolvedStream
        .listen((data) async {
          if (!mounted || _isOrderRejectionResolvedDialogShowing) return;

          _isOrderRejectionResolvedDialogShowing = true;
          final isOnNavigationScreen =
              data['isOnNavigationScreen'] as bool? ?? false;

          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                      Icons.check_circle_outline,
                      color: Colors.green.shade600,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Yêu cầu trả hàng đã xử lý. Bạn có thể tiếp tục hành trình.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (!isOnNavigationScreen) {
                        final navigationStateService =
                            getIt<NavigationStateService>();
                        final savedOrderId = navigationStateService
                            .getActiveOrderId();
                        if (savedOrderId != null) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.navigation,
                            arguments: {
                              'orderId': savedOrderId,
                              'isSimulationMode': widget.isSimulationMode,
                            },
                          );
                        } else {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.navigation,
                          );
                        }
                      } else {
                        notificationService.triggerNavigationScreenRefresh();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Xác nhận',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).whenComplete(() => _isOrderRejectionResolvedDialogShowing = false);
        });

    // ✅ NEW: Subscribe to payment timeout stream
    _paymentTimeoutSubscription = notificationService.paymentTimeoutStream.listen((
      data,
    ) async {
      if (!mounted || _isPaymentTimeoutDialogShowing) return;

      _isPaymentTimeoutDialogShowing = true;
      final isOnNavigationScreen =
          data['isOnNavigationScreen'] as bool? ?? false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade600,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Khách hàng không thanh toán cước trả hàng. Bạn có thể quay về đơn vị vận chuyển.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (isOnNavigationScreen) {
                      notificationService.triggerNavigationScreenRefresh();
                    } else {
                      final navigationStateService =
                          getIt<NavigationStateService>();
                      final savedOrderId = navigationStateService
                          .getActiveOrderId();
                      if (savedOrderId != null) {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.navigation,
                          arguments: {
                            'orderId': savedOrderId,
                            'isSimulationMode': widget.isSimulationMode,
                          },
                        );
                      } else {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.navigation,
                        );
                      }
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ).whenComplete(() => _isPaymentTimeoutDialogShowing = false);
    });

    // ✅ NEW: Subscribe to reroute resolved stream
    _rerouteResolvedSubscription = notificationService.rerouteResolvedStream.listen(
      (data) async {
        if (!mounted || _isRerouteResolvedDialogShowing) return;

        _isRerouteResolvedDialogShowing = true;
        final issueId = data['issueId'] as String?;
        final orderId = data['orderId'] as String?;
        final isOnNavigationScreen =
            data['isOnNavigationScreen'] as bool? ?? false;

        print('🛣️ Reroute resolved notification received');
        print('   Issue ID: $issueId');
        print('   Order ID: $orderId');
        print('   Is on navigation screen: $isOnNavigationScreen');

        // 🚨 CRITICAL FIX: Fetch new route FIRST, then show success dialog
        // Pattern 1: Info-only notification (like damage resolved)
        // Flow: Fetch order → Re-render map → Auto resume → Show success dialog
        print('🔄 Fetching new route and resuming BEFORE showing dialog...');

        try {
          // Fetch new route and auto resume
          await _fetchNewRouteAndAutoResume();

          // Only show dialog AFTER successfully fetched and resumed
          if (!mounted) return;

          // 🚨 Try to pop waiting dialog if exists
          try {
            Navigator.of(context, rootNavigator: false).pop();
            await Future.delayed(const Duration(milliseconds: 100));
            print('   ✅ Dismissed waiting dialog');
          } catch (e) {
            print('   ℹ️ No waiting dialog to dismiss');
          }

          // Show success dialog - already resumed!
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Đã cập nhật lộ trình mới',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lộ trình mới đã được tải và hệ thống đã tự động tiếp tục.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Just dismiss
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        } catch (e) {
          print('❌ Error in reroute resolved flow: $e');
          // Show error dialog
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Lỗi'),
                content: Text('Không thể tải lộ trình mới: $e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            );
          }
        } finally {
          _isRerouteResolvedDialogShowing = false;
        }
      },
    );

    // Check if viewModel is already simulating (returning to active simulation)
    // Only set _isSimulating if viewModel confirms it's running
    if (_viewModel.isSimulating && widget.isSimulationMode) {
      _isSimulating = true;

      // CRITICAL: Check and resume immediately if already have route segments
      // Don't wait for _loadOrderDetails() which might be slow or fail
      if (_viewModel.routeSegments.isNotEmpty) {
        _checkAndResumeAfterAction();
      }
    } else {}

    // ✅ CRITICAL: Load order details FIRST before showing UI
    // Block all UI rendering until this completes successfully
    _initializeScreen();
  }

  /// ✅ CRITICAL: Initialize screen by loading order data FIRST
  /// All UI will be blocked with loading screen until this succeeds
  Future<void> _initializeScreen() async {
    try {
      print('🚀 Initializing navigation screen...');

      // 1️⃣ Load order details with retry (BLOCKING)
      await _loadOrderDetails();

      // 2️⃣ Check if order loaded successfully
      if (!_isDataReady) {
        throw Exception('Không thể tải thông tin đơn hàng sau khi retry');
      }

      print('✅ Order loaded successfully, showing UI...');

      // 3️⃣ Mark initialization as complete
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initializationError = null;
        });
      }

      // 4️⃣ After UI shown, load non-critical data
      if (mounted) {
        // ✅ CRITICAL: Set correct segment BEFORE any resume logic
        // This prevents race condition where old segment triggers completion dialog
        if (widget.autoResume && _viewModel.routeSegments.isNotEmpty) {
          print('🎯 [CRITICAL] Setting return segment START');
          print('   Current segment (old): ${_viewModel.currentSegmentIndex}');
          print('   Journey type: ${_viewModel.currentJourneyType}');
          print('   Total segments: ${_viewModel.routeSegments.length}');

          // Journey structure:
          // STANDARD (3 segments): 0: Carrier→Pickup, 1: Pickup→Delivery, 2: Delivery→Carrier
          // RETURN (4 segments): 0: Carrier→Pickup, 1: Pickup→Delivery, 2: Delivery→Pickup, 3: Pickup→Carrier
          // REROUTE: Can be based on STANDARD or RETURN, flexible segment count

          int returnSegmentIndex;
          final segmentCount = _viewModel.routeSegments.length;

          if (_viewModel.currentJourneyType == 'RETURN') {
            // RETURN journey: segment 2 is always return start (Delivery → Pickup)
            returnSegmentIndex = 2;
            print('   ✅ RETURN journey detected: Setting to segment 2 (fixed)');
          } else if (_viewModel.currentJourneyType == 'REROUTE') {
            // REROUTE: Flexible, could be based on STANDARD (3 seg) or RETURN (4+ seg)
            if (segmentCount >= 4) {
              // Reroute after return: segment 2+ is rerouted return journey
              returnSegmentIndex = 2;
              print(
                '   ✅ REROUTE (return-based) detected: Setting to segment 2',
              );
            } else {
              // Reroute on standard journey: use last segment
              returnSegmentIndex = segmentCount - 1;
              print(
                '   ✅ REROUTE (standard-based) detected: Setting to last segment',
              );
            }
          } else {
            // STANDARD or unknown: use last segment
            returnSegmentIndex = segmentCount - 1;
            print('   ⚠️ STANDARD/Unknown journey: Setting to last segment');
          }

          print('   Target segment: $returnSegmentIndex');

          // Set segment immediately to prevent any logic from using old segment
          _viewModel.setCurrentSegmentIndex(returnSegmentIndex);

          print(
            '   ✅ Segment set! New index: ${_viewModel.currentSegmentIndex}',
          );
        }

        // Precache truck marker images
        _precacheTruckImages();

        // Fetch pending seal replacements
        _fetchPendingSealReplacements();

        // Check if we need to auto-resume simulation (ONLY if not using autoResume flag)
        // Priority: autoResume flag takes precedence over normal resume logic
        if (!widget.autoResume &&
            _viewModel.routeSegments.isNotEmpty &&
            _viewModel.isSimulating &&
            !_isSimulating) {
          print('🔄 Normal resume: Checking and resuming after action...');
          _checkAndResumeAfterAction();
        }

        // ✅ Auto-resume simulation if flag is set (from OrderDetailScreen seal confirmation)
        if (widget.autoResume && widget.isSimulationMode && !_isSimulating) {
          print(
            '🚀 [NavScreen] Auto-resuming simulation after seal confirmation...',
          );

          // Segment already set above, now just verify and prepare UI
          if (_viewModel.routeSegments.isNotEmpty) {
            print(
              '📍 Route segments loaded: ${_viewModel.routeSegments.length}',
            );
            print(
              '📍 Current segment index: ${_viewModel.currentSegmentIndex}',
            );
            print('📍 Journey type: ${_viewModel.currentJourneyType}');

            // Debug: Print segment names
            for (int i = 0; i < _viewModel.routeSegments.length; i++) {
              final marker = i == _viewModel.currentSegmentIndex ? '👉' : '  ';
              print(
                '   $marker Segment $i: ${_viewModel.routeSegments[i].name} (${_viewModel.routeSegments[i].points.length} points)',
              );
            }

            // ✅ CRITICAL: Ensure everything is ready before auto-resume
            if (mounted) {
              // Step 1: Update UI state
              setState(() {
                print(
                  '🎨 Step 1: UI state updated with segment index: ${_viewModel.currentSegmentIndex}',
                );
              });

              // Step 2: Wait for UI to render
              await Future.delayed(const Duration(milliseconds: 300));

              // Step 3: Redraw routes with new active segment
              if (_isMapReady && _viewModel.routeSegments.isNotEmpty) {
                print(
                  '🎨 Step 2: Redrawing routes for segment: ${_viewModel.getCurrentSegmentName()}',
                );
                _drawRoutes();
              }

              // Step 4: Wait for routes to render on map
              await Future.delayed(const Duration(milliseconds: 500));

              // Step 5: Verify everything is ready (segment already set above, just check location)
              if (mounted && _viewModel.currentLocation != null) {
                print('✅ Step 3: Everything ready!');
                print('   - Segment index: ${_viewModel.currentSegmentIndex}');
                print(
                  '   - Segment name: ${_viewModel.getCurrentSegmentName()}',
                );
                print('   - Current location: ${_viewModel.currentLocation}');
                print('   - Map ready: $_isMapReady');

                // Step 6: Focus camera to new location (return segment start)
                if (_mapController != null &&
                    _viewModel.currentLocation != null) {
                  print(
                    '📸 Step 3.5: Focusing camera to return segment start...',
                  );
                  await _setCameraToNavigationMode(_viewModel.currentLocation!);
                  await Future.delayed(const Duration(milliseconds: 300));
                }

                // Step 7: NOW safe to auto-resume
                await Future.delayed(const Duration(milliseconds: 300));
                if (mounted) {
                  print('🎬 Step 4: Starting auto-resume simulation...');
                  _autoResumeSimulation();
                }
              } else {
                print('❌ Verification failed - aborting auto-resume');
              }
            }
          } else {
            print('❌ ERROR: No route segments loaded!');
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Failed to initialize screen: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initializationError =
              'Không thể tải thông tin lộ trình. ${e.toString()}';
        });
      }
    }
  }

  /// Precache truck marker images để giảm decode time
  Future<void> _precacheTruckImages() async {
    if (!mounted) return;

    final truckImagePaths = [
      'assets/icons/truck_marker_icon/truck_north.png',
      'assets/icons/truck_marker_icon/truck_northeast.png',
      'assets/icons/truck_marker_icon/truck_east.png',
      'assets/icons/truck_marker_icon/truck_southeast.png',
      'assets/icons/truck_marker_icon/truck_south.png',
      'assets/icons/truck_marker_icon/truck_southwest.png',
      'assets/icons/truck_marker_icon/truck_west.png',
      'assets/icons/truck_marker_icon/truck_northwest.png',
    ];

    try {
      for (final imagePath in truckImagePaths) {
        await precacheImage(AssetImage(imagePath), context);
      }
    } catch (e) {
      // Non-critical, continue anyway
    }
  }

  /// Fetch pending seal replacements for current vehicle assignment
  Future<void> _fetchPendingSealReplacements() async {
    if (_viewModel.vehicleAssignmentId == null ||
        _viewModel.vehicleAssignmentId!.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingPendingSeals = true;
    });

    try {
      final issueRepository = getIt<IssueRepository>();
      final vehicleAssignmentId = _viewModel.vehicleAssignmentId!;
      final pendingIssues = await issueRepository.getPendingSealReplacements(
        vehicleAssignmentId,
      );

      setState(() {
        _pendingSealReplacements = pendingIssues;
        _isLoadingPendingSeals = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPendingSeals = false;
      });
    }
  }

  /// Fetch fuel consumption ID by vehicle assignment
  Future<void> _fetchFuelConsumptionId() async {
    if (_viewModel.vehicleAssignmentId == null ||
        _viewModel.vehicleAssignmentId!.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingFuelConsumption = true;
    });

    try {
      final dataSource = getIt<VehicleFuelConsumptionDataSource>();
      final result = await dataSource.getByVehicleAssignmentId(
        _viewModel.vehicleAssignmentId!,
      );

      result.fold(
        (failure) {
          setState(() {
            _isLoadingFuelConsumption = false;
          });

          // Show user-friendly message if no fuel consumption record found
          if (failure.message.contains('Chưa có bản ghi tiêu thụ nhiên liệu')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Chưa có bản ghi tiêu thụ nhiên liệu. Vui lòng tạo bản ghi trước khi upload hóa đơn.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        },
        (response) {
          if (response['success'] == true && response['data'] != null) {
            setState(() {
              _fuelConsumptionId = response['data']['id'];
              _isLoadingFuelConsumption = false;
            });
          } else {
            setState(() {
              _isLoadingFuelConsumption = false;
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _isLoadingFuelConsumption = false;
      });
    }
  }

  /// Show fuel invoice upload bottom sheet
  /// CRITICAL: Fetch fuel consumption ID on-demand when user clicks button
  Future<void> _showFuelInvoiceUploadSheet() async {
    // Show loading dialog while checking API
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Đang kiểm tra thông tin nhiên liệu...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      // Fetch fuel consumption ID from API
      await _fetchFuelConsumptionId();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Check if we got the ID
      if (_fuelConsumptionId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Chưa có bản ghi tiêu thụ nhiên liệu. Vui lòng thử lại sau.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Show the upload form
      if (!mounted) return;
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FuelInvoiceUploadSheet(
        fuelConsumptionId: _fuelConsumptionId!,
        onConfirm: (imageFile) async {
          try {
            final dataSource = getIt<VehicleFuelConsumptionDataSource>();
            final result = await dataSource.updateInvoiceImage(
              fuelConsumptionId: _fuelConsumptionId!,
              invoiceImage: imageFile,
            );

            result.fold(
              (failure) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: ${failure.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              (success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Đã upload hóa đơn xăng thành công'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
              );
            }
            rethrow;
          }
        },
      ),
    );
  }

  /// Handle return payment seal report flow với proper error handling
  /// CRITICAL: Separated method to avoid context issues after hot restart
  /// OPTIMIZATION: Uses pre-fetched seal data for instant display
  Future<void> _handleReturnPaymentSealReport({
    required String? vehicleAssignmentId,
    required ScaffoldMessengerState scaffoldMessenger,
    List<VehicleSeal>? preFetchedSeals,
  }) async {
    try {
      // ✅ OPTIMIZATION: Reduced delay from 300ms → 100ms since data is pre-fetched
      await Future.delayed(const Duration(milliseconds: 100));

      // ✅ CRITICAL: Check mounted state BEFORE any context operations
      if (!mounted) {
        print('⚠️ Widget not mounted after delay');
        return;
      }

      // Validate vehicleAssignmentId
      if (vehicleAssignmentId == null || vehicleAssignmentId.isEmpty) {
        print('❌ No vehicle assignment ID');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy thông tin phân công xe'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // ✅ OPTIMIZATION: Use pre-fetched data if available, fallback to API call
      List<VehicleSeal> activeSeals = [];

      if (preFetchedSeals != null && preFetchedSeals.isNotEmpty) {
        print('⚡ Using pre-fetched seal data (instant!)');
        activeSeals = preFetchedSeals;
      } else {
        print('📡 Pre-fetch failed, fetching seal data now...');

        // Fallback: Get IN_USE seal via API
        final issueRepository = getIt<IssueRepository>();
        final inUseSealData = await issueRepository.getInUseSeal(
          vehicleAssignmentId,
        );

        print(
          '📦 Seal data received: ${inUseSealData != null ? "yes" : "null"}',
        );

        // Check mounted again after async call
        if (!mounted) {
          print('⚠️ Widget unmounted after API call');
          return;
        }

        if (inUseSealData == null) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy seal nào đang sử dụng'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Parse seal data
        if (inUseSealData is Map<String, dynamic>) {
          activeSeals.add(
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
          );
        }
      }

      if (activeSeals.isEmpty) {
        print('⚠️ Active seals list is empty');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Không có seal nào để báo cáo'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Final mounted check before showing bottom sheet
      if (!mounted) {
        print('⚠️ Widget unmounted before showing bottom sheet');
        return;
      }

      print('📝 Opening seal removal report bottom sheet...');

      // ✅ Use current context (guaranteed to be valid if mounted)
      final result = await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => ReportSealIssueBottomSheet(
          vehicleAssignmentId: vehicleAssignmentId,
          currentLatitude: _viewModel.currentLocation?.latitude,
          currentLongitude: _viewModel.currentLocation?.longitude,
          availableSeals: activeSeals,
        ),
      );

      print('📝 Seal report result: $result');

      // Check mounted after bottom sheet closes
      if (!mounted) {
        print('⚠️ Widget unmounted after bottom sheet');
        return;
      }

      // After reporting seal, trigger refresh
      if (result != null) {
        print('✅ Seal reported, refreshing data...');
        await _loadOrderDetails();
        await _fetchPendingSealReplacements();

        // ❌ REMOVED: Don't auto-resume here - causes duplicate simulation conflict
        // Auto-resume will happen ONLY after driver confirms new seal and navigates back
        // from OrderDetailScreen with autoResume flag
        print(
          '⏸️ Waiting for driver to confirm new seal assignment before resuming...',
        );
      } else {
        print('⚠️ No result from seal report');
      }
    } catch (e, stackTrace) {
      print('❌ Error in return payment seal report flow: $e');
      print('📍 Stack trace: $stackTrace');

      // Only show error if still mounted
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi khi báo cáo seal: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Show confirm seal replacement bottom sheet
  void _showConfirmSealSheet(Issue issue) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConfirmSealReplacementSheet(
        issue: issue,
        onConfirm: (imageBase64) async {
          try {
            final issueRepository = getIt<IssueRepository>();
            await issueRepository.confirmSealReplacement(
              issueId: issue.id,
              newSealAttachedImage: imageBase64,
            );
            // Return success to close bottom sheet and handle UI updates outside
            return;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
            }
            rethrow;
          }
        },
      ),
    );

    // After bottom sheet is closed, check result before refreshing and showing success
    if (mounted && result == true) {
      // Wait a bit for backend to update issue status
      await Future.delayed(const Duration(milliseconds: 500));

      // Refresh pending list
      await _fetchPendingSealReplacements();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã xác nhận gắn seal mới thành công'),
          backgroundColor: Colors.green,
        ),
      );
      _autoResumeSimulation();
    } else {}
  }

  // Check if we need to resume simulation after action confirmation
  void _checkAndResumeAfterAction() {
    // CRITICAL: If ViewModel is simulating but screen state is not, sync immediately
    // This happens when NavigationScreen is recreated after action confirmation
    if (_viewModel.isSimulating && !_isSimulating) {
      _isSimulating = true;
      _isPaused = false; // ViewModel is actively simulating, so NOT paused

      // IMPORTANT: Ensure timer is reset before resuming
      // This handles case where timer might still be active from previous session
      _viewModel.pauseSimulation(); // Cancel any existing timer

      // Reset _isSimulating flag so startSimulation can be called
      _viewModel.resetSimulationFlag();

      // CRITICAL: Re-register callbacks since NavigationScreen was recreated
      // This ensures location updates and segment completion are handled properly
      _viewModel.startSimulation(
        onLocationUpdate: (location, bearing) {
          // CRITICAL: Update viewModel's current location with simulated location
          _viewModel.currentLocation = location;

          // Update custom location marker (offset is applied inside the function)
          _updateLocationMarker(location, bearing);

          // Update camera to follow vehicle (offset is applied inside the function)
          if (_isFollowingUser) {
            print('🎥 [CALL_SITE: simulation_callback] Calling _setCameraToNavigationMode');
            _setCameraToNavigationMode(location);
          }

          // Send location update via GlobalLocationManager with speed and segment
          // Apply perpendicular off-route offset for API when simulation is active
          final sendLocation = _calculateOffRoutePosition(location, bearing);
          _globalLocationManager.sendLocationUpdate(
            sendLocation.latitude,
            sendLocation.longitude,
            bearing: bearing,
            speed: _viewModel.currentSpeed,
            segmentIndex: _viewModel.currentSegmentIndex,
          );

          // Rebuild UI to update speed display
          if (mounted) {
            setState(() {});
          }
        },
        onSegmentComplete: (segmentIndex, isLastSegment) {
          // Pause simulation when reaching any waypoint
          _pauseSimulation();
          _drawRoutes();

          if (isLastSegment) {
            // Reached final destination (Carrier)
            _showCompletionMessage();
          } else if (segmentIndex == 0) {
            // Completed segment 0: Reached Pickup location
            _showPickupMessage();
          } else if (segmentIndex == 1) {
            // Completed segment 1: Reached Delivery location
            _showDeliveryMessage();
          }
        },
        simulationSpeed: _viewModel.currentSimulationSpeed,
      );
      return; // Exit early since we've already handled the resume
    }

    // If in simulation mode and paused (user manually paused), auto-resume
    if (widget.isSimulationMode && _isSimulating && _isPaused) {
      // Check if we're at the end of a segment (just completed an action)
      final currentSegment =
          _viewModel.routeSegments.isNotEmpty &&
              _viewModel.currentSegmentIndex < _viewModel.routeSegments.length
          ? _viewModel.routeSegments[_viewModel.currentSegmentIndex]
          : null;

      if (currentSegment != null &&
          _viewModel.currentLocation != null &&
          currentSegment.points.isNotEmpty) {
        final lastPoint = currentSegment.points.last;
        final isAtEndOfSegment = _viewModel.currentLocation == lastPoint;

        if (isAtEndOfSegment) {
          _viewModel.moveToNextSegmentManually();
        }
      }

      // Delay to ensure UI is ready and map is loaded
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (mounted && _isPaused) {
          // Focus camera first
          if (_viewModel.currentLocation != null && _mapController != null) {
            await _setCameraToNavigationMode(_viewModel.currentLocation!);
            await Future.delayed(const Duration(milliseconds: 300));
          }

          // Then resume
          _resumeSimulation();
        }
      });
    }
  }

  @override
  VehicleAssignment? _getVehicleAssignmentFromOrderDetail(
    OrderWithDetails order,
  ) {
    if (order.orderDetails.isEmpty || order.vehicleAssignments.isEmpty) {
      return null;
    }

    // Get current user phone number
    final currentUserPhone = _authViewModel.driver?.userResponse.phoneNumber;
    if (currentUserPhone == null || currentUserPhone.isEmpty) {
      return null;
    }
    // Find vehicle assignment where current user is primary driver
    try {
      final result = order.vehicleAssignments.firstWhere((va) {
        if (va.primaryDriver == null) {
          return false;
        }
        final match =
            currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
        return match;
      });
      return result;
    } catch (e) {
      // Fallback to first vehicle assignment if not found
      if (order.vehicleAssignments.isNotEmpty) {
        return order.vehicleAssignments.first;
      }
      return null;
    }
  }

  /// Fetch new route and AUTO resume simulation after reroute
  /// Staff has created new journey, fetch latest active journey and render on map
  /// CRITICAL: Maintain current position and segment, don't reset to start/end
  /// Pattern: Simple like seal replacement - fetch → restore position → auto resume
  Future<void> _fetchNewRouteAndAutoResume() async {
    try {
      print('🔄 Fetching new rerouted journey...');

      // 🎯 CRITICAL: Save current state BEFORE fetching new route
      final wasSimulating = _isSimulating;
      final previousSegmentIndex = _viewModel.currentSegmentIndex;
      final previousLocation = _viewModel.currentLocation;
      final previousSpeed = _viewModel.currentSpeed;

      print('   📍 Current state before fetch:');
      print('      Was simulating: $wasSimulating');
      print('      Segment index: $previousSegmentIndex');
      print(
        '      Location: ${previousLocation?.latitude}, ${previousLocation?.longitude}',
      );
      print('      Speed: $previousSpeed km/h');

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Đang tải lộ trình mới...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Fetch order to get latest journey history
      final orderId = widget.orderId ?? _viewModel.orderWithDetails?.id;
      if (orderId == null) {
        throw Exception('Không tìm thấy ID đơn hàng');
      }

      print('   Fetching order: $orderId');

      // Update order in viewModel first
      await _viewModel.getOrderDetails(orderId);

      // Parse route from updated order
      if (_viewModel.orderWithDetails != null) {
        _viewModel.parseRouteFromOrder(_viewModel.orderWithDetails!);

        // Redraw routes on map
        if (_viewModel.routeSegments.isNotEmpty) {
          _drawRoutes();
        }
      }

      print('✅ New route rendered successfully');
      print('   📍 New route segments: ${_viewModel.routeSegments.length}');

      // 🎯 CRITICAL: Restore previous position and segment
      // Don't reset to start/end - maintain current location like seal replacement flow
      if (previousLocation != null && previousSegmentIndex >= 0) {
        // Keep current segment index if still valid
        if (previousSegmentIndex < _viewModel.routeSegments.length) {
          _viewModel.currentSegmentIndex = previousSegmentIndex;
          print('   ✅ Maintained segment index: $previousSegmentIndex');
        } else {
          // If previous segment no longer exists (route changed significantly),
          // stay at first segment instead of jumping to end
          _viewModel.currentSegmentIndex = 0;
          print(
            '   ⚠️ Previous segment no longer exists, staying at segment 0',
          );
        }

        // 🚨 CRITICAL FIX: Use restoreSimulationPosition() instead of direct assignment
        // This ensures _currentPointIndices is properly set for the new route
        // Direct assignment causes bug where old _currentPointIndices makes simulation jump to wrong segment
        _viewModel.restoreSimulationPosition(
          segmentIndex: _viewModel.currentSegmentIndex,
          latitude: previousLocation.latitude,
          longitude: previousLocation.longitude,
          bearing: _viewModel.currentBearing,
        );
        _viewModel.currentSpeed = previousSpeed;

        print('   ✅ Restored position using restoreSimulationPosition()');
        print('   ✅ Segment: ${_viewModel.currentSegmentIndex}');
        print(
          '   ✅ Location: ${previousLocation.latitude}, ${previousLocation.longitude}',
        );

        // 🚨 CRITICAL: Save restored state immediately so _startSimulation() won't overwrite
        // Otherwise NavigationStateService has old position from previous session
        _globalLocationManager.sendLocationUpdate(
          previousLocation.latitude,
          previousLocation.longitude,
          bearing: _viewModel.currentBearing,
          speed: previousSpeed,
          segmentIndex: _viewModel.currentSegmentIndex,
        );
        print('   ✅ Saved restored state to prevent overwrite');
      }

      // Update UI
      if (mounted) {
        setState(() {
          _isDataReady = true;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật lộ trình mới'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // 🚀 AUTO-RESUME simulation if was running
        if (wasSimulating) {
          print(
            '🔄 Auto-resuming simulation with new route from current position...',
          );
          print('   Previous segment: $previousSegmentIndex');
          print('   Current segment: ${_viewModel.currentSegmentIndex}');

          // Wait for UI to update
          await Future.delayed(const Duration(milliseconds: 300));

          // Simple pattern like seal replacement: just start simulation!
          // Position and segment already restored above
          if (_isPaused) {
            print('   Simulation was paused, resuming...');
            _resumeSimulation();
          } else if (!_viewModel.isSimulating) {
            print(
              '   Simulation not running, starting with restored position...',
            );
            // 🚨 CRITICAL: Pass shouldRestore: true to use saved state (position we just saved above)
            // Without this, _startSimulation() uses first point of new route!
            _startSimulation(shouldRestore: true);
          } else {
            print('   Simulation already running, no action needed');
          }
        }
      }
    } catch (e) {
      print('❌ Error fetching new route: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải lộ trình mới: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // App going to background - simulation continues in background
      // Save current state immediately for safety
      if (_isSimulating && _viewModel.currentLocation != null) {
        _globalLocationManager.sendLocationUpdate(
          _viewModel.currentLocation!.latitude,
          _viewModel.currentLocation!.longitude,
          bearing: _viewModel.currentBearing,
          speed: _viewModel.currentSpeed,
          segmentIndex: _viewModel.currentSegmentIndex,
        );
      }
    } else if (state == AppLifecycleState.resumed && mounted) {
      // Refresh pending seals
      _fetchPendingSealReplacements();

      // REMOVED: Refresh fuel consumption in background
      // Will be fetched on-demand when user clicks button

      // Check if simulation should be running
      if (widget.isSimulationMode && _viewModel.isSimulating) {
        // Update camera to current position
        if (_viewModel.currentLocation != null && _mapController != null) {
          // Offset is applied inside _setCameraToNavigationMode
          _setCameraToNavigationMode(_viewModel.currentLocation!);
        }

        // Update marker (offset is applied inside _updateLocationMarker)
        if (_viewModel.currentLocation != null) {
          _updateLocationMarker(
            _viewModel.currentLocation!,
            _viewModel.currentBearing,
          );
        }

        // Simulation timer should still be running unless explicitly paused
        // No need to restart - it continues in background
      } else if (widget.isSimulationMode &&
          !_viewModel.isSimulating &&
          _globalLocationManager.isGlobalTrackingActive) {
        // ViewModel lost simulation state but GlobalLocationManager is tracking
        _checkAndResumeAfterAction();
      }
    } else if (state == AppLifecycleState.inactive) {
      // App is transitioning (e.g., during navigation or receiving a call)
    } else if (state == AppLifecycleState.detached) {
      // App is being terminated
    }
  }

  @override
  void dispose() {
    // CRITICAL: Set disposing flag FIRST to prevent any NEW map operations
    _isDisposing = true;

    // ⚠️ IMPORTANT: DO NOT clean up map resources in dispose!
    // Reasons:
    // 1. Map controller will be automatically destroyed when screen disposes
    // 2. Async cleanup operations cause race conditions with new screen initialization
    // 3. NavigationScreen creates new map instance each time, no reuse needed
    // 4. Style loading state makes cleanup timing unpredictable
    //
    // Let Flutter handle map cleanup automatically when widget tree is destroyed.
    // Remove observers
    WidgetsBinding.instance.removeObserver(this);

    // 🆕 Dispose refresh subscription
    _refreshSubscription?.cancel();

    // 🆕 Dispose seal bottom sheet subscription
    _sealBottomSheetSubscription?.cancel();

    // 🆕 Dispose return payment subscription
    _returnPaymentSubscription?.cancel();

    // ✅ NEW: Dispose notification dialog subscriptions (4 only)
    _damageResolvedSubscription?.cancel();
    _orderRejectionResolvedSubscription?.cancel();
    _paymentTimeoutSubscription?.cancel();
    _rerouteResolvedSubscription?.cancel();

    // 🆕 Dispose map loading timeout timer
    _mapLoadingTimeoutTimer?.cancel();
    _mapLoadingTimeoutTimer = null;

    // Unregister this screen from GlobalLocationManager
    _globalLocationManager.unregisterScreen('NavigationScreen');

    // IMPORTANT: Don't stop tracking when just navigating away
    // Only stop when explicitly requested (trip complete, cancel, etc.)
    // This allows user to go back to order detail and return to navigation
    // Simulation continues in background via GlobalLocationManager

    // Only stop if trip is complete
    if (_isTripComplete) {
      _globalLocationManager.stopGlobalTracking(reason: 'Trip completed');
      _viewModel.resetNavigation();
    } else {
      // Save current state one last time before dispose
      if (_isSimulating && _viewModel.currentLocation != null) {
        _globalLocationManager.sendLocationUpdate(
          _viewModel.currentLocation!.latitude,
          _viewModel.currentLocation!.longitude,
          bearing: _viewModel.currentBearing,
          speed: _viewModel.currentSpeed,
          segmentIndex: _viewModel.currentSegmentIndex,
        );
      }
    }
    super.dispose();
  }

  /// Load VietMap style with 2-layer caching:
  /// 1. Memory cache (fast)
  /// 2. SharedPreferences cache (persistent, 7 days)
  /// 3. API call (fallback)
  /// 4. Local asset (last resort)
  Future<void> _loadMapStyle() async {
    print('🗺️ [MapStyle] Starting to load map style...');
    setState(() {
      _isLoadingMapStyle = true;
    });

    try {
      print('   🔍 [MapStyle] Fetching style from VietMapService...');
      final vietMapService = getIt<VietMapService>();

      // Try cache first (memory or SharedPreferences), then API
      final styleUrl = await vietMapService.getMobileStyleUrl();
      print(
        '   ✅ [MapStyle] Style URL loaded: ${styleUrl.substring(0, 50)}...',
      );
      setState(() {
        _mapStyle = styleUrl; // Store URL, SDK handles loading
        _isLoadingMapStyle = false;
      });
      print('   ✅ [MapStyle] Map style loading complete');
    } catch (e) {
      print('   ⚠️ [MapStyle] VietMapService failed: $e');
      // Fallback 1: Try local asset file
      try {
        print('   🔄 [MapStyle] Trying local asset fallback...');
        final style = await DefaultAssetBundle.of(
          context,
        ).loadString('assets/map_style/vietmap_style.json');
        print('   ✅ [MapStyle] Local asset loaded (${style.length} chars)');
        setState(() {
          _mapStyle = style;
          _isLoadingMapStyle = false;
        });
      } catch (assetError) {
        print('   ❌ [MapStyle] Local asset also failed: $assetError');
        setState(() {
          _isLoadingMapStyle = false;
        });
      }
    }
  }

  /// Start timeout mechanism for map loading
  void _startMapLoadingTimeout() {
    print(
      '⏱️ [MapTimeout] Starting ${_mapLoadingTimeout.inSeconds}s timeout for map loading...',
    );

    _mapLoadingTimeoutTimer = Timer(_mapLoadingTimeout, () {
      if (!mounted || _isFullyReady) return;

      print('⚠️ [MapTimeout] Map loading timeout reached!');
      print('   📊 Final state:');
      print('      - Initializing: $_isInitializing');
      print('      - Loading style: $_isLoadingMapStyle');
      print('      - Map ready: $_isMapReady');
      print('      - Map initialized: $_isMapInitialized');
      print('      - Map controller: ${_mapController != null}');

      // Cancel timeout timer
      _mapLoadingTimeoutTimer?.cancel();
      _mapLoadingTimeoutTimer = null;

      // Show timeout error
      if (mounted) {
        setState(() {
          _initializationError =
              'Bản đồ không tải được sau ${_mapLoadingTimeout.inSeconds} giây. Vui lòng kiểm tra kết nối mạng và thử lại.';
        });
      }
    });
  }

  /// Cancel timeout mechanism when map is ready
  void _cancelMapLoadingTimeout() {
    if (_mapLoadingTimeoutTimer != null) {
      print('✅ [MapTimeout] Map loaded successfully, cancelling timeout');
      _mapLoadingTimeoutTimer!.cancel();
      _mapLoadingTimeoutTimer = null;
    }
  }

  String _getMapStyleString() {
    // Return style URL or JSON
    if (_mapStyle != null) {
      // Check if it's a URL (from VietMapService cache)
      if (_mapStyle!.startsWith('http')) {
        //
        return _mapStyle!; // SDK handles URL loading automatically
      }

      // Otherwise, it's JSON (from local asset) - need to parse and modify
      try {
        final dynamic styleJson = json.decode(_mapStyle!);

        // Kiểm tra và đảm bảo cấu hình font chính xác
        if (styleJson is Map && styleJson.containsKey('layers')) {
          final layers = styleJson['layers'];
          if (layers is List) {
            for (var i = 0; i < layers.length; i++) {
              final layer = layers[i];
              // Xử lý các lớp có text-font
              if (layer is Map) {
                // Kiểm tra layout nếu có
                if (layer.containsKey('layout') && layer['layout'] is Map) {
                  final layout = layer['layout'];
                  if (layout.containsKey('text-font')) {
                    // Đảm bảo text-font là một mảng literal
                    layout['text-font'] = [
                      'Roboto Regular',
                      'Arial Unicode MS Regular',
                    ];
                  }
                }

                // Xử lý paint nếu có
                if (layer.containsKey('paint') && layer['paint'] is Map) {
                  final paint = layer['paint'];
                  if (paint.containsKey('text-font')) {
                    // Đảm bảo text-font là một mảng literal
                    paint['text-font'] = [
                      'Roboto Regular',
                      'Arial Unicode MS Regular',
                    ];
                  }
                }

                // Xử lý trực tiếp nếu có
                if (layer.containsKey('text-font')) {
                  layer['text-font'] = [
                    'Roboto Regular',
                    'Arial Unicode MS Regular',
                  ];
                }
              }
            }
          }

          // Thêm font vào style nếu chưa có
          if (!styleJson.containsKey('glyphs')) {
            styleJson['glyphs'] =
                'https://maps.vietmap.vn/api/fonts/{fontstack}/{range}.pbf';
          }

          // Thêm background layer để tránh mảng đen
          if (layers is List) {
            bool hasBackgroundLayer = false;
            for (var layer in layers) {
              if (layer is Map && layer['id'] == 'background') {
                hasBackgroundLayer = true;
                if (layer.containsKey('paint') && layer['paint'] is Map) {
                  layer['paint']['background-color'] = '#ffffff';
                }
                break;
              }
            }

            if (!hasBackgroundLayer) {
              layers.insert(0, {
                'id': 'background',
                'type': 'background',
                'paint': {'background-color': '#ffffff'},
              });
            }
          }
        }

        // Trả về style đã được chỉnh sửa
        return json.encode(styleJson);
      } catch (e) {
        return _mapStyle!; // Trả về style gốc nếu có lỗi khi parse
      }
    }

    // Fallback style nếu chưa tải được từ API - sử dụng style raster đơn giản
    return '''
    {
      "version": 8,
      "sources": {
        "raster_vm": {
          "type": "raster",
          "tiles": [
            "https://maps.vietmap.vn/tm/{z}/{x}/{y}@2x.png?apikey=df5d9a3fffec4d07c7e3710bd0caf8181945d446509a3d42"
          ],
          "tileSize": 256,
          "attribution": "Vietmap@copyright"
        }
      },
      "layers": [
        {
          "id": "background",
          "type": "background",
          "paint": {
            "background-color": "#ffffff"
          }
        },
        {
          "id": "layer_raster_vm",
          "type": "raster",
          "source": "raster_vm",
          "minzoom": 0,
          "maxzoom": 17
        }
      ]
    }
    ''';
  }

  /// Load order details với retry logic
  /// Retry max 3 lần với exponential backoff (1s, 2s, 4s)
  /// Chỉ show error message khi tất cả retry attempts fail
  Future<void> _loadOrderDetails({bool isRetry = false}) async {
    // CRITICAL: Prevent duplicate API calls
    if (_isLoadingOrder) {
      return;
    }

    // Reset retry count nếu đây không phải retry call
    if (!isRetry) {
      _loadOrderRetryCount = 0;
    }

    setState(() {
      _isLoadingOrder = true;
      _isDataReady = false; // Reset data ready state
    });

    try {
      // Get orderId - if null, use existing order from viewModel
      String? targetOrderId = widget.orderId;

      if (targetOrderId == null) {
        // If viewModel already has order, reload it
        if (_viewModel.orderWithDetails != null) {
          targetOrderId = _viewModel.orderWithDetails!.id;
        } else {
          setState(() {
            _isLoadingOrder = false;
            _isDataReady = false;
          });
          return;
        }
      }

      print(
        '📡 Loading order details (attempt ${_loadOrderRetryCount + 1}/$_maxLoadOrderRetries)...',
      );

      // Tải dữ liệu order từ API
      await _viewModel.getOrderDetails(targetOrderId);

      if (_viewModel.orderWithDetails != null) {
        _viewModel.parseRouteFromOrder(_viewModel.orderWithDetails!);

        // ✅ CRITICAL: Check if route parsing was successful
        if (_viewModel.routeSegments.isNotEmpty &&
            _viewModel.vehicleAssignmentId != null &&
            _viewModel.vehicleAssignmentId!.isNotEmpty) {
          setState(() {
            _isDataReady = true; // Data is ready
          });
          print(
            '✅ Order details loaded successfully, route ready with ${_viewModel.routeSegments.length} segments',
          );
          // Reset retry count on success
          _loadOrderRetryCount = 0;
        } else {
          // Route parsing failed - retry nếu chưa hết lần
          print(
            '⚠️ Route parsing failed, segments: ${_viewModel.routeSegments.length}, vehicleAssignmentId: ${_viewModel.vehicleAssignmentId}',
          );
          await _handleLoadOrderFailure(
            errorMessage: _viewModel.errorMessage.isNotEmpty
                ? _viewModel.errorMessage
                : 'Lộ trình chưa sẵn sàng',
            isParsingError: true,
          );
        }
      } else {
        // Order null - retry nếu chưa hết lần
        print('⚠️ Order details null');
        await _handleLoadOrderFailure(
          errorMessage: 'Không thể tải thông tin đơn hàng',
          isParsingError: false,
        );
      }
    } catch (e) {
      // Exception - retry nếu chưa hết lần
      print('❌ Exception loading order: $e');
      await _handleLoadOrderFailure(
        errorMessage: 'Lỗi kết nối: $e',
        isParsingError: false,
      );
    } finally {
      setState(() {
        _isLoadingOrder = false;
      });
    }
  }

  /// Handle load order failure với retry logic
  Future<void> _handleLoadOrderFailure({
    required String errorMessage,
    required bool isParsingError,
  }) async {
    setState(() {
      _isDataReady = false;
    });

    // Kiểm tra xem có thể retry không
    if (_loadOrderRetryCount < _maxLoadOrderRetries) {
      _loadOrderRetryCount++;

      // Exponential backoff: 1s, 2s, 4s
      final delaySeconds = (1 << (_loadOrderRetryCount - 1)); // 2^(n-1)

      print(
        '⏳ Retrying in ${delaySeconds}s... (attempt ${_loadOrderRetryCount + 1}/$_maxLoadOrderRetries)',
      );

      // Show retry notification ONLY if not initializing (có loading screen rồi)
      if (mounted && !_isInitializing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đang thử lại... (lần ${_loadOrderRetryCount + 1}/$_maxLoadOrderRetries)',
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: delaySeconds),
          ),
        );
      }

      // Đợi trước khi retry
      await Future.delayed(Duration(seconds: delaySeconds));

      // Retry
      if (mounted) {
        await _loadOrderDetails(isRetry: true);
      }
    } else {
      // Đã hết retry attempts - show error cho user
      print('❌ All retry attempts exhausted, showing error to user');
      _loadOrderRetryCount = 0; // Reset counter

      // ✅ CRITICAL: If initializing, don't show snackbar (error screen sẽ hiển thị)
      // If not initializing (reload sau khi đã vào screen), show snackbar
      if (mounted && !_isInitializing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage.isNotEmpty
                  ? errorMessage
                  : 'Không thể tải thông tin lộ trình. Vui lòng kiểm tra kết nối và thử lại.',
            ),
            backgroundColor: isParsingError ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: () {
                _loadOrderDetails();
              },
            ),
          ),
        );
      }
    }
  }

  void _onMapCreated(VietmapController controller) {
    print('🗺️ [MapCallback] onMapCreated called');
    _mapController = controller;
  }

  void _onMapRendered() {
    print('🗺️ [MapCallback] onMapRendered called');
    setState(() {
      _isMapReady = true;
    });

    // CRITICAL: Draw routes now that map is ready
    // This handles case where _onStyleLoaded() was called before _onMapRendered()
    if (_viewModel.routeSegments.isNotEmpty) {
      print('   🎨 Drawing routes from onMapRendered callback...');
      _drawRoutes();
    }
  }

  /// Check if map operations are safe to perform
  bool get _isMapOperationSafe {
    return !_isDisposing &&
        _mapController != null &&
        _isMapReady &&
        !_isLoadingMapStyle;
  }

  void _onStyleLoaded() {
    print('🗺️ [MapCallback] onStyleLoaded called');
    setState(() {
      _isMapInitialized = true;
    });

    // Đảm bảo đã tải xong dữ liệu order trước khi vẽ route
    if (_viewModel.routeSegments.isEmpty) {
      print('   📍 Route segments empty, loading order details...');
      _loadOrderDetails().then((_) {
        if (_viewModel.routeSegments.isNotEmpty) {
          // CRITICAL: Draw immediately on first load WITHOUT clearFirst
          // Reason: NavigationScreen is NEW, map is EMPTY, no need to clear
          // clearFirst adds 800ms delay which can cause timing issues
          _drawRoutes(); // Draw immediately, no delay!

          // Đặt camera vào vị trí thích hợp
          if (_viewModel.routeSegments[0].points.isNotEmpty) {
            _setCameraToNavigationMode(
              _viewModel.routeSegments[0].points.first,
            );
          }

          // Check if we should auto-restore simulation from saved state
          final stateService = getIt<NavigationStateService>();
          final savedState = stateService.getSavedNavigationState();
          final shouldAutoRestore =
              savedState != null &&
              savedState.orderId == widget.orderId &&
              savedState.isSimulationMode &&
              widget.isSimulationMode;

          // Start real tracking or simulation based on mode
          // Priority: Check simulation mode first
          if (widget.isSimulationMode && !_isSimulating) {
            if (shouldAutoRestore) {
              // Auto-start simulation WITH restore
              _startSimulation(shouldRestore: true);
            } else {
              // Show dialog for new simulation
              _showSimulationDialog();
            }
          } else if (!widget.isSimulationMode &&
              !_globalLocationManager.isGlobalTrackingActive) {
            _startRealTimeNavigation();
          } else if (_isSimulating) {
            // Resume existing simulation
            _resumeSimulation();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Không thể tải thông tin lộ trình. Vui lòng kiểm tra lại thông tin đơn hàng.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Quay lại',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          );

          // Quay lại màn hình trước sau 5 giây
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      });
    } else {
      // CRITICAL: Draw immediately WITHOUT clearFirst
      // Reason: NavigationScreen is NEW, map is EMPTY, no need to clear
      // Delay can cause routes not to show when navigating back
      _drawRoutes(); // Draw immediately, no delay!

      // Đặt camera vào vị trí thích hợp
      // Use current location if available, otherwise use first point
      if (_viewModel.currentLocation != null) {
        _setCameraToNavigationMode(_viewModel.currentLocation!);
      } else if (_viewModel.routeSegments[0].points.isNotEmpty) {
        _setCameraToNavigationMode(_viewModel.routeSegments[0].points.first);
      }

      // Check if we should auto-restore simulation from saved state
      final stateService = getIt<NavigationStateService>();
      final savedState = stateService.getSavedNavigationState();
      final shouldAutoRestore =
          savedState != null &&
          savedState.orderId == widget.orderId &&
          savedState.isSimulationMode &&
          widget.isSimulationMode;

      // Start real tracking or simulation based on mode
      // Priority: Check simulation mode first, then check existing connections
      if (widget.isSimulationMode && !_isSimulating) {
        if (shouldAutoRestore) {
          // Auto-start simulation WITH restore
          _startSimulation(shouldRestore: true);
        } else {
          // Show dialog for new simulation
          _showSimulationDialog();
        }
      } else if (!widget.isSimulationMode &&
          !_globalLocationManager.isGlobalTrackingActive) {
        _startRealTimeNavigation();
      } else if (_isSimulating && _isPaused) {
        // Auto-resume simulation after action (no dialog needed)
        _resumeSimulation();
      } else if (_isSimulating) {
        // Resume existing simulation
        _resumeSimulation();
      } else if (_globalLocationManager.isGlobalTrackingActive) {
        // WebSocket is connected, just update camera
        if (_viewModel.currentLocation != null) {
          _setCameraToNavigationMode(_viewModel.currentLocation!);
        }
      } else {}
    }
  }

  CameraPosition _getInitialCameraPosition() {
    if (_viewModel.routeSegments.isNotEmpty &&
        _viewModel.routeSegments[0].points.isNotEmpty) {
      final firstPoint = _viewModel.routeSegments[0].points.first;
      return CameraPosition(target: firstPoint, zoom: 15.0);
    }

    // Default to Ho Chi Minh City
    return const CameraPosition(
      target: LatLng(10.762317, 106.654551),
      zoom: 13.0,
    );
  }

  Future<void> _startRealTimeNavigation() async {
    if (_viewModel.routeSegments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có dữ liệu lộ trình'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _startLocationTracking();
  }

  Future<bool> _startLocationTracking() async {
    if (_isConnectingWebSocket) return false;

    setState(() {
      _isConnectingWebSocket = true;
    });

    // Show progressive loading dialog với timeout protection
    final progressNotifier = ValueNotifier<String>('Đang khởi động...');
    bool dialogDismissed = false;

    // CRITICAL: Timeout timer to prevent dialog stuck forever
    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!dialogDismissed && mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
          dialogDismissed = true;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Kết nối WebSocket mất nhiều thời gian. Đang thử lại...',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {}
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: progressNotifier,
        builder: (context, message, child) => AlertDialog(
          title: const Text('Đang kết nối'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // CRITICAL: Nếu là simulation mode và tracking đã active
      // KHÔNG stop WebSocket, chỉ switch sang simulation mode
      if (widget.isSimulationMode &&
          _globalLocationManager.isGlobalTrackingActive) {
        // Check if it's the same order
        if (_globalLocationManager.currentOrderId == widget.orderId) {
          // Just register this screen, don't restart tracking
          // CRITICAL: Only register if this is the primary driver
          if (_globalLocationManager.isPrimaryDriver) {
            _globalLocationManager.registerScreen(
              'NavigationScreen',
              onLocationUpdate: (data) {
                final isPrimary = _globalLocationManager.isPrimaryDriver;

                //

                final lat = data['latitude'] as double?;
                final lng = data['longitude'] as double?;

                if (lat != null && lng != null) {
                  final location = LatLng(lat, lng);

                  // Update viewModel's current location ONLY if not simulating
                  // When simulating, viewModel.currentLocation should use simulated location
                  if (!_viewModel.isSimulating) {
                    _viewModel.currentLocation = location;
                  }

                  if (_isFollowingUser && mounted) {
                    _setCameraToNavigationMode(location);
                  }
                }
              },
              onError: (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi tracking: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            );
          } else {}

          // Close loading dialog and return success
          timeoutTimer.cancel(); // Cancel timeout timer
          if (!dialogDismissed && mounted) {
            try {
              Navigator.of(context, rootNavigator: true).pop();
              dialogDismissed = true;
            } catch (e) {}
            setState(() {
              _isConnectingWebSocket = false;
            });
          }
          return true;
        }
      }

      // Update progress
      progressNotifier.value = 'Xác thực thông tin tài xế...';

      // Xác định driver role từ vehicle assignment hiện tại (không phải từ order chung)
      // CRITICAL: Với multi-trip orders, cần check xem user có phải là primary driver của CHUYẾN HIỆN TẠI
      bool isPrimaryDriver = true; // Default
      if (_viewModel.orderWithDetails != null &&
          _viewModel.vehicleAssignmentId != null) {
        // Find the vehicle assignment for current trip
        final currentVehicleAssignment = _viewModel
            .orderWithDetails!
            .vehicleAssignments
            .cast<VehicleAssignment?>()
            .firstWhere(
              (va) => va?.id == _viewModel.vehicleAssignmentId,
              orElse: () => null,
            );

        if (currentVehicleAssignment != null) {
          // Check if current user is primary driver of THIS vehicle assignment
          final currentUserPhone =
              _authViewModel.driver?.userResponse.phoneNumber;
          if (currentUserPhone != null &&
              currentVehicleAssignment.primaryDriver != null) {
            isPrimaryDriver =
                currentUserPhone.trim() ==
                currentVehicleAssignment.primaryDriver!.phoneNumber.trim();
          }
        }
      }

      // Update progress
      progressNotifier.value = 'Đang kết nối tới máy chủ...';

      // Use GlobalLocationManager instead of direct IntegratedLocationService
      // Get JWT token from TokenStorageService (always has the latest token after refresh)
      final tokenStorage = getIt<TokenStorageService>();
      final jwtToken = tokenStorage.getAccessToken();

      // Get orderId - use widget.orderId or fallback to orderWithDetails
      final String? targetOrderId =
          widget.orderId ?? _viewModel.orderWithDetails?.id;

      if (targetOrderId == null) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          setState(() {
            _isConnectingWebSocket = false;
          });
        }
        return false;
      }

      // Small delay to allow UI to update
      await Future.delayed(const Duration(milliseconds: 100));

      final success = await _globalLocationManager.startGlobalTracking(
        orderId: targetOrderId,
        vehicleId: _viewModel.currentVehicleId,
        licensePlateNumber: _viewModel.currentLicensePlateNumber,
        jwtToken: jwtToken,
        initiatingScreen: 'NavigationScreen',
        isPrimaryDriver: isPrimaryDriver,
        isSimulationMode:
            widget.isSimulationMode, // CRITICAL: Tắt GPS thật trong simulation
      );

      if (success) {
        // Register callbacks for location updates
        // CRITICAL: Only register if this is the primary driver
        // This prevents secondary drivers from receiving location updates
        // which would cause camera to focus on wrong vehicle in multi-trip orders
        if (isPrimaryDriver) {
          _globalLocationManager.registerScreen(
            'NavigationScreen',
            onLocationUpdate: (data) {
              final isPrimary = _globalLocationManager.isPrimaryDriver;
              final vehicleIdInData = data['vehicleId']?.toString();
              final expectedVehicleId = _viewModel.currentVehicleId;
              // CRITICAL: Extra safety check - verify vehicle ID matches
              if (vehicleIdInData != null &&
                  expectedVehicleId != null &&
                  vehicleIdInData != expectedVehicleId) {
                return; // STOP - don't update camera
              }

              // Update current location in viewModel
              final lat = data['latitude'] as double?;
              final lng = data['longitude'] as double?;

              if (lat != null && lng != null) {
                final location = LatLng(lat, lng);

                // Update viewModel's current location ONLY if not simulating
                // When simulating, viewModel.currentLocation should use simulated location
                if (!_viewModel.isSimulating) {
                  _viewModel.currentLocation = location;
                }

                // Update camera if following user
                if (_isFollowingUser && mounted) {
                  _setCameraToNavigationMode(location);
                } else {}
              }
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi tracking: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          );
        } else {}
      }

      // Close loading dialog
      timeoutTimer.cancel(); // Cancel timeout timer
      if (!dialogDismissed && mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
          dialogDismissed = true;
        } catch (e) {}
      }

      if (success) {
        // Listen to tracking statistics from GlobalLocationManager
        // _globalLocationManager.globalStatsStream.listen((stats) {
        //
        //
        //
        //
        //
        //
        // });

        if (mounted) {
          final isPrimary = _globalLocationManager.isPrimaryDriver;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPrimary
                    ? '✅ Location tracking started (Primary Driver)'
                    : '✅ Tracking initialized (Secondary Driver - No WebSocket)',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể khởi động location tracking'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _isConnectingWebSocket = false;
        });
      }

      return success;
    } catch (e) {
      // Close loading dialog
      timeoutTimer.cancel(); // Cancel timeout timer
      if (!dialogDismissed && mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
          dialogDismissed = true;
        } catch (e2) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kết nối: $e'),
            backgroundColor: Colors.red,
          ),
        );

        setState(() {
          _isConnectingWebSocket = false;
        });
      }

      return false;
    }
  }

  /// Stop location tracking
  /// ⚠️ CRITICAL: Only call this when trip is COMPLETE
  /// Do NOT call when:
  /// - Navigating back to order detail
  /// - Switching between real-time and simulation
  /// - Pausing navigation
  /// WebSocket must stay alive until trip is finished!
  Future<void> _stopLocationTracking() async {
    // Stop global location tracking
    await _globalLocationManager.stopGlobalTracking(
      reason: 'Trip completed from NavigationScreen',
    );
  }

  void _drawRoutes({bool clearFirst = false}) {
    if (_isDisposing ||
        _mapController == null ||
        _viewModel.routeSegments.isEmpty) {
      return;
    }

    // Throttle to prevent excessive redrawing and buffer overflow
    final now = DateTime.now();
    if (_lastDrawRoutesTime != null &&
        now.difference(_lastDrawRoutesTime!) < _drawRoutesThrottleDuration) {
      return;
    }
    _lastDrawRoutesTime = now;

    // If need to clear first, wait for clear to complete before drawing
    if (clearFirst) {
      _clearMapElementsWithDelay();
      // Wait for clear to complete (300ms) + extra buffer (200ms)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _isDisposing) return;
        _drawRoutesInternal();
      });
    } else {
      // Draw immediately without clearing
      _drawRoutesInternal();
    }
  }

  void _drawRoutesInternal() async {
    // CRITICAL: Check map ready state before drawing polylines
    // Polylines require map tiles to be loaded, unlike widget-based markers
    if (_isDisposing ||
        _mapController == null ||
        _viewModel.routeSegments.isEmpty ||
        !_isMapReady) {
      return;
    }
    // Clear previous waypoint markers
    _waypointMarkers.clear();

    // 🔥 XÓA TẤT CẢ POLYLINES CŨ trước khi vẽ line mới
    // Điều này đảm bảo chỉ line của segment hiện tại được hiển thị
    try {
      await _mapController!.clearPolylines();
    } catch (e) {}

    // 🎯 CHỈ VẼ SEGMENT HIỆN TẠI - để driver tập trung vào đoạn đường đang đi
    final currentIndex = _viewModel.currentSegmentIndex;

    // Validate segment index
    if (currentIndex < 0 || currentIndex >= _viewModel.routeSegments.length) {
      return;
    }

    final currentSegment = _viewModel.routeSegments[currentIndex];

    // Tối ưu hóa: giảm số điểm cần vẽ nếu quá nhiều
    List<LatLng> optimizedPoints = currentSegment.points;
    if (currentSegment.points.length > 100) {
      optimizedPoints = _simplifyRoute(currentSegment.points);
    }

    // Draw line ONLY for current segment
    _mapController!.addPolyline(
      PolylineOptions(
        geometry: optimizedPoints,
        polylineColor: AppColors.primary, // Màu xanh dương cho route hiện tại
        polylineWidth: 8.0, // Độ dày dễ nhìn
        polylineOpacity: 1.0, // Đầy đủ opacity
      ),
    );

    // Draw waypoint markers ONLY for current segment
    if (optimizedPoints.isNotEmpty) {
      // Get journey type to determine correct labels
      final journeyType = _viewModel.currentJourneyType;

      // Start point marker
      Color startPointColor;
      IconData startPointIcon;
      String startLabel;

      if (journeyType == 'RETURN') {
        // RETURN journey structure: Delivery → Return Pickup → Carrier
        if (currentIndex == 0) {
          // From delivery point
          startPointColor = Colors.red;
          startPointIcon = Icons.local_shipping;
          startLabel = 'Giao hàng';
        } else if (currentIndex == 1) {
          // From return pickup point
          startPointColor = Colors.green;
          startPointIcon = Icons.inventory_2;
          startLabel = 'Trả hàng';
        } else {
          // Fallback
          startPointColor = Colors.blue;
          startPointIcon = Icons.location_on;
          startLabel = 'Điểm trước';
        }
      } else {
        // STANDARD or REROUTE journey: Carrier → Pickup → Delivery → Carrier
        if (currentIndex == 0) {
          // First segment: from Carrier
          startPointColor = Colors.orange;
          startPointIcon = Icons.warehouse;
          startLabel = 'Đơn vị vận chuyển';
        } else {
          // Subsequent segments: from previous delivery/pickup
          startPointColor = Colors.blue;
          startPointIcon = Icons.location_on;
          startLabel = 'Điểm trước';
        }
      }

      _waypointMarkers.add(
        Marker(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: startPointColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(startPointIcon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: startPointColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  startLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          latLng: optimizedPoints.first,
        ),
      );

      // End point marker
      Color endPointColor;
      IconData endPointIcon;
      String endLabel;

      if (journeyType == 'RETURN') {
        // RETURN journey structure: Delivery → Return Pickup → Carrier
        if (currentIndex == 0) {
          // To return pickup point (where goods were picked up originally)
          endPointColor = Colors.green;
          endPointIcon = Icons.inventory_2;
          endLabel = 'Trả hàng';
        } else if (currentIndex == _viewModel.routeSegments.length - 1) {
          // Back to carrier
          endPointColor = Colors.orange;
          endPointIcon = Icons.warehouse;
          endLabel = 'Đơn vị vận chuyển';
        } else {
          // Fallback
          endPointColor = Colors.blue;
          endPointIcon = Icons.location_on;
          endLabel = 'Điểm đến';
        }
      } else {
        // STANDARD or REROUTE journey: Carrier → Pickup → Delivery → Carrier
        if (currentIndex == 0) {
          // Segment 0: Pickup point
          endPointColor = Colors.green;
          endPointIcon = Icons.inventory_2;
          endLabel = 'Lấy hàng';
        } else if (currentIndex == _viewModel.routeSegments.length - 1) {
          // Last segment: Back to Carrier
          endPointColor = Colors.orange;
          endPointIcon = Icons.warehouse;
          endLabel = 'Đơn vị vận chuyển';
        } else {
          // Middle segments: Delivery point
          endPointColor = Colors.red;
          endPointIcon = Icons.local_shipping;
          endLabel = 'Giao hàng';
        }
      }

      _waypointMarkers.add(
        Marker(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: endPointColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(endPointIcon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: endPointColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  endLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          latLng: optimizedPoints.last,
        ),
      );
    }

    // If not following user, fit map to show CURRENT segment points
    if (!_isFollowingUser &&
        optimizedPoints.length > 1 &&
        _isMapOperationSafe) {
      double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;

      for (final point in optimizedPoints) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        maxLng = max(maxLng, point.longitude);
      }

      // Add padding for better visibility
      final latPadding = (maxLat - minLat) * 0.1; // 10% padding
      final lngPadding = (maxLng - minLng) * 0.1;

      // Skip camera update if locked (during off-route testing)
      if (_isCameraLocked) {
        print('🎥 [fitRouteToScreen] SKIPPED - Camera locked for off-route testing');
        return;
      }
      
      print('🎥 [fitRouteToScreen] Animate camera to fit route bounds (off-route: $_isOffRouteSimulated)');
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - latPadding, minLng - lngPadding),
            northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
          ),
          left: 50,
          top: 50,
          right: 50,
          bottom: 50,
        ),
      );
    }
  }

  // Hàm đơn giản hóa route để giảm số điểm cần vẽ
  List<LatLng> _simplifyRoute(List<LatLng> points) {
    if (points.length <= 2) return points;

    // Thuật toán Douglas-Peucker đơn giản hóa
    // Chỉ giữ lại khoảng 1/3 số điểm
    List<LatLng> result = [];
    int step = (points.length / 30).ceil(); // Giữ khoảng 30 điểm
    step = max(1, step); // Đảm bảo step ít nhất là 1

    // Luôn giữ điểm đầu và điểm cuối
    result.add(points.first);

    // Thêm các điểm ở giữa theo step
    for (int i = step; i < points.length - 1; i += step) {
      result.add(points[i]);
    }

    // Thêm điểm cuối
    if (points.length > 1) {
      result.add(points.last);
    }

    return result;
  }

  void _updateCameraPosition(LatLng location, double? bearing) {
    // 🔒 BLOCK camera updates during off-route simulation to prevent jumping
    if (_isOffRouteSimulated) {
      print('🎥 [_updateCameraPosition] SKIPPED - Off-route simulation active');
      return;
    }
    
    if (!_isMapOperationSafe || !_isFollowingUser) return;

    _cameraUpdateCounter++;

    // Apply perpendicular off-route offset when simulation is active
    final actualLocation = _calculateOffRoutePosition(location, bearing);

    // Update camera position to follow user's location
    // Use moveCamera instead of animateCamera to avoid "chasing" effect
    // Camera moves instantly with marker, creating smooth tracking
    if (_cameraUpdateCounter % _cameraUpdateFrequency == 0) {
      print('🎥 [_updateCameraPosition] Moving camera to: ${actualLocation.latitude}, ${actualLocation.longitude} (off-route: $_isOffRouteSimulated)');
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: actualLocation,
            zoom: 16.0,
            bearing: bearing ?? 0.0,
            tilt: 45.0, // Góc nghiêng 3D
          ),
        ),
      );
    }
  }

  /// Calculate off-route position by offsetting perpendicular to the bearing direction
  /// This ensures the offset is always perpendicular to the route, guaranteeing off-route detection
  LatLng _calculateOffRoutePosition(LatLng position, double? bearing) {
    if (!_isOffRouteSimulated) return position;
    
    // Use current bearing or default to 0 (north)
    final double bearingDegrees = bearing ?? _viewModel.currentBearing ?? 0.0;
    
    // Offset perpendicular to bearing (90 degrees to the LEFT)
    // This ensures we're always off the route line on the left side
    final double perpendicularBearing = (bearingDegrees - 90 + 360) % 360;
    final double bearingRad = perpendicularBearing * pi / 180.0;
    
    // Convert meters to degrees (approximate: 1 degree ≈ 111,000 meters at equator)
    // Adjust for latitude to get more accurate offset
    final double metersPerDegreeLat = 111000.0;
    final double metersPerDegreeLng = 111000.0 * cos(position.latitude * pi / 180.0);
    
    final double latOffset = (_offRouteDistanceMeters * cos(bearingRad)) / metersPerDegreeLat;
    final double lngOffset = (_offRouteDistanceMeters * sin(bearingRad)) / metersPerDegreeLng;
    
    return LatLng(
      position.latitude + latOffset,
      position.longitude + lngOffset,
    );
  }

  /// Clear map elements with delay to avoid VietmapGL style loading issues
  /// Error: "Calling getSourceAs when a newer style is loading/has loaded"
  void _clearMapElementsWithDelay() {
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (_isDisposing || _mapController == null || _isLoadingMapStyle) return;

      try {
        await _mapController!.clearPolylines();
      } catch (e) {}

      try {
        await _mapController!.clearCircles();
        // Reset off-route circle reference
        _offRouteCircle = null;
      } catch (e) {}
    });
  }

  Future<void> _updateLocationMarker(LatLng location, double? bearing) async {
    if (_mapController == null) return;

    try {
      // Change marker icon when off-route simulation is active
      final markerIcon = _isOffRouteSimulated ? '⚠️' : '🚛';
      final markerSize = _isOffRouteSimulated ? 36.0 : 32.0;
      
      // Apply perpendicular off-route offset when simulation is active
      // This ensures marker is always off the route by a fixed distance
      final markerLocation = _calculateOffRoutePosition(location, bearing);
      
      // Update existing marker instead of remove/add to avoid buffer issues
      if (_currentLocationMarker != null) {
        await _mapController!.updateSymbol(
          _currentLocationMarker!,
          SymbolOptions(
            geometry: markerLocation, 
            textRotate: bearing ?? 0.0,
            textField: markerIcon,
            textSize: markerSize,
          ),
        );
      } else {
        // Create marker for the first time
        _currentLocationMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: markerLocation,
            textField: markerIcon,
            textSize: markerSize,
            textRotate: bearing ?? 0.0,
          ),
        );
      }
      
      // Update off-route circle with same offset location
      await _updateOffRouteCircle(markerLocation);
      
    } catch (e) {
      // If update fails, try to recreate
      try {
        if (_currentLocationMarker != null) {
          await _mapController!.removeSymbol(_currentLocationMarker!);
          _currentLocationMarker = null;
        }
        final markerIcon = _isOffRouteSimulated ? '⚠️' : '🚛';
        final markerSize = _isOffRouteSimulated ? 36.0 : 32.0;
        
        // Apply perpendicular off-route offset when simulation is active
        final markerLocation = _calculateOffRoutePosition(location, bearing);
            
        _currentLocationMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: markerLocation,
            textField: markerIcon,
            textSize: markerSize,
            textRotate: bearing ?? 0.0,
          ),
        );
        
        // Update off-route circle
        await _updateOffRouteCircle(markerLocation);
      } catch (e2) {}
    }
  }
  
  Future<void> _updateOffRouteCircle(LatLng location) async {
    if (_mapController == null) return;
    
    try {
      // Remove existing circle
      if (_offRouteCircle != null) {
        await _mapController!.removeCircle(_offRouteCircle!);
        _offRouteCircle = null;
      }
      
      // Add circle if off-route is simulated
      if (_isOffRouteSimulated) {
        _offRouteCircle = await _mapController!.addCircle(
          CircleOptions(
            geometry: location,
            circleRadius: 30.0, // 30 meters radius
            circleColor: Colors.red,
            circleOpacity: 0.3,
            circleStrokeColor: Colors.red,
            circleStrokeWidth: 2.0,
            circleStrokeOpacity: 0.8,
          ),
        );
      }
    } catch (e) {
      print('Error updating off-route circle: $e');
    }
  }

  void _updateLocationMarkerForOffRoute() {
    // Force update the location marker when off-route toggle changes
    if (_viewModel.currentLocation != null && _mapController != null) {
      _updateLocationMarker(_viewModel.currentLocation!, _viewModel.currentBearing);
    }
  }

  void _showSimulationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chế độ mô phỏng'),
        content: const Text('Bạn có muốn bắt đầu mô phỏng di chuyển xe không?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startSimulation();
            },
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }

  void _showResumeSimulationDialog() {
    // Get current segment name for context
    final currentSegment = _viewModel.getCurrentSegmentName();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tiếp tục mô phỏng'),
        content: Text(
          'Bạn đã hoàn thành xác nhận.\n\n'
          'Đoạn đường tiếp theo: $currentSegment\n\n'
          'Bạn có muốn tiếp tục mô phỏng di chuyển không?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Stay paused, user can manually resume later
            },
            child: const Text('Để sau'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resumeSimulation();
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
  }

  Future<void> _startSimulation({bool shouldRestore = false}) async {
    if (_isSimulating) {
      print('⚠️ Already simulating, skipping start');
      return;
    }

    print('🚀 Starting simulation (shouldRestore: $shouldRestore)...');

    // ============================================
    // PHASE 0: ENSURE DATA IS LOADED
    // ============================================
    print('🔍 Phase 0: Ensuring order data is loaded...');

    // If data is not ready and not currently loading, try loading now
    if (!_isDataReady && !_isLoadingOrder) {
      print('   ⚠️ Data not ready, loading order details...');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang tải thông tin lộ trình...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _loadOrderDetails();

      // Check again after loading
      if (!_isDataReady) {
        print('❌ Data still not ready after loading');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không thể tải thông tin lộ trình. Vui lòng kiểm tra kết nối và thử lại.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    // If still loading, wait
    if (_isLoadingOrder) {
      print('   ⏳ Waiting for order to finish loading...');
      // Wait max 10 seconds for loading to complete
      int waitCount = 0;
      while (_isLoadingOrder && waitCount < 100) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }

      if (_isLoadingOrder) {
        print('❌ Loading timeout');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thời gian tải dữ liệu quá lâu. Vui lòng thử lại.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    print('   ✓ Data is ready');

    // ============================================
    // PHASE 1: PRE-FLIGHT VALIDATION
    // ============================================
    print('✅ Phase 1: Pre-flight validation');

    // Validate route data
    if (_viewModel.routeSegments.isEmpty) {
      print('❌ No route segments available');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có dữ liệu lộ trình để mô phỏng'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    print('   ✓ Route segments: ${_viewModel.routeSegments.length}');

    // Validate vehicle assignment
    if (_viewModel.vehicleAssignmentId == null ||
        _viewModel.vehicleAssignmentId!.isEmpty) {
      print('❌ No vehicle assignment ID');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không tìm thấy thông tin phân công xe. Vui lòng liên hệ quản lý.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    print('   ✓ Vehicle assignment ID: ${_viewModel.vehicleAssignmentId}');

    // Validate order details
    if (_viewModel.orderWithDetails == null) {
      print('❌ No order details');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không có thông tin đơn hàng. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    print('   ✓ Order details loaded');

    // Reset any existing simulation in viewModel
    _viewModel.pauseSimulation();

    // If NOT restoring (manual start), clear old saved state to start fresh
    if (!shouldRestore) {
      final stateService = getIt<NavigationStateService>();
      stateService.clearNavigationState();
      print('   ✓ Cleared old navigation state');
    }

    // CRITICAL: Update simulation mode in GlobalLocationManager
    // This ensures saved state has correct simulation mode
    _globalLocationManager.updateSimulationMode(true);

    // Save updated state with simulation mode
    await _globalLocationManager.saveNavigationState();
    print('   ✓ Saved navigation state');

    // ============================================
    // PHASE 2: WEBSOCKET CONNECTION
    // ============================================
    print('📡 Phase 2: Establishing WebSocket connection');

    // Connect to WebSocket first (with simulation mode enabled)
    final connected = await _startLocationTracking();
    if (!connected) {
      print('❌ WebSocket connection failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể kết nối WebSocket cho mô phỏng'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    print('   ✓ WebSocket connected');

    // Wait for WebSocket connection to stabilize
    await Future.delayed(const Duration(milliseconds: 1000));
    print('   ✓ Connection stabilized');

    // ============================================
    // PHASE 3: MAP & ROUTES READINESS CHECK
    // ============================================
    print('🗺️ Phase 3: Verifying map and routes readiness');
    print('   📊 Map style loading: $_isLoadingMapStyle');
    print('   📊 Map ready: $_isMapReady');
    print('   📊 Map initialized: $_isMapInitialized');

    // Wait for map style to finish loading first (max 2 seconds)
    int styleWaitCount = 0;
    while (_isLoadingMapStyle && styleWaitCount < 20) {
      print('   ⏳ Waiting for map style... (attempt ${styleWaitCount + 1}/20)');
      await Future.delayed(const Duration(milliseconds: 100));
      styleWaitCount++;
    }

    if (_isLoadingMapStyle) {
      print(
        '   ⚠️ Map style still loading after timeout, proceeding anyway...',
      );
    } else {
      print('   ✓ Map style loaded');
    }

    // Wait for map to be ready (max 2 seconds) - NON-BLOCKING
    int waitCount = 0;
    while ((!_isMapReady || !_isMapInitialized) && waitCount < 20) {
      print('   ⏳ Waiting for map ready... (attempt ${waitCount + 1}/20)');
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    if (!_isMapReady || !_isMapInitialized) {
      print('   ⚠️ Map not fully ready, but proceeding with simulation...');
      // ✅ CRITICAL FIX: Don't block simulation - map will render asynchronously
      // Routes will be drawn when map becomes ready via _onStyleLoaded callback
    } else {
      print('   ✓ Map ready and initialized');
    }

    // Try to draw routes (will succeed if map is ready, otherwise skip)
    print('   🎨 Drawing routes...');
    if (_isMapReady && _isMapInitialized) {
      _drawRoutes();
    } else {
      print('   ⚠️ Skipping route drawing - will draw when map ready');
    }

    // Wait for routes to render
    await Future.delayed(const Duration(milliseconds: 300));
    print('   ✓ Routes drawn');

    // ============================================
    // PHASE 4: CAMERA & INITIAL POSITION
    // ============================================
    print('📷 Phase 4: Setting camera and initial position');

    // Get initial location (either restored or start of route)
    LatLng initialLocation;
    if (shouldRestore) {
      final stateService = getIt<NavigationStateService>();
      final savedState = stateService.getSavedNavigationState();

      if (savedState != null &&
          savedState.orderId == widget.orderId &&
          savedState.hasPosition &&
          savedState.currentLatitude != null &&
          savedState.currentLongitude != null) {
        initialLocation = LatLng(
          savedState.currentLatitude!,
          savedState.currentLongitude!,
        );
        print('   ✓ Using restored location: $initialLocation');
      } else {
        initialLocation = _viewModel.routeSegments[0].points.first;
        print(
          '   ⚠️ No valid saved state, using route start: $initialLocation',
        );
      }
    } else {
      initialLocation = _viewModel.routeSegments[0].points.first;
      print('   ✓ Using route start location: $initialLocation');
    }

    // Set camera to initial position
    if (_mapController != null) {
      print('   📸 Focusing camera...');
      await _setCameraToNavigationMode(initialLocation);
      await Future.delayed(const Duration(milliseconds: 300));
      print('   ✓ Camera focused');
    }

    // ============================================
    // PHASE 5: START SIMULATION
    // ============================================
    print('▶️ Phase 5: Starting actual simulation');

    setState(() {
      _isSimulating = true;
      _isPaused = false;
      _isFollowingUser = true; // Ensure following mode
    });

    print('✅ All pre-flight checks passed, starting simulation...');

    // Start the simulation
    _startActualSimulation(shouldRestore: shouldRestore);

    print('🎉 Simulation started successfully!');
  }

  void _startActualSimulation({required bool shouldRestore}) {
    // Only restore saved position if shouldRestore is true
    if (shouldRestore) {
      final stateService = getIt<NavigationStateService>();
      final savedState = stateService.getSavedNavigationState();

      if (savedState != null &&
          savedState.orderId == widget.orderId &&
          savedState.hasPosition) {
        // Restore position in viewModel with bearing
        if (savedState.currentSegmentIndex != null) {
          _viewModel.restoreSimulationPosition(
            segmentIndex: savedState.currentSegmentIndex!,
            latitude: savedState.currentLatitude!,
            longitude: savedState.currentLongitude!,
            bearing: savedState.currentBearing,
          );

          // Update marker with restored position
          _updateLocationMarker(
            _viewModel.currentLocation!,
            _viewModel.currentBearing,
          );

          // Update camera to restored position
          if (_isFollowingUser && _mapController != null) {
            _setCameraToNavigationMode(_viewModel.currentLocation!);
          }
        }
      } else {}
    } else {}

    // Ensure we're following the vehicle
    setState(() {
      _isFollowingUser = true;
    });

    // Start the simulation with callbacks
    _viewModel.startSimulation(
      onLocationUpdate: (location, bearing) {
        //

        // CRITICAL: Update viewModel's current location with simulated location
        // This ensures report incident uses simulated location, not GPS
        // print('🎥 [ASSIGNMENT: simulation_callback] Location update: ${location.latitude}, ${location.longitude}');
        _viewModel.currentLocation = location;

        // Update custom location marker (offset is applied inside the function)
        _updateLocationMarker(location, bearing);

        // Update camera to follow vehicle (offset is applied inside the function)
        if (_isFollowingUser) {
          _setCameraToNavigationMode(location);
        }

        // Send location update via GlobalLocationManager with speed and segment
        // Apply perpendicular off-route offset for API when simulation is active
        final sendLocation = _calculateOffRoutePosition(location, bearing);
        // print('🎥 [ASSIGNMENT: simulation_callback] Sending WebSocket location: ${sendLocation.latitude}, ${sendLocation.longitude}');
        
        _globalLocationManager.sendLocationUpdate(
          sendLocation.latitude,
          sendLocation.longitude,
          bearing: bearing,
          speed: _viewModel.currentSpeed, // Add current speed
          segmentIndex: _viewModel
              .currentSegmentIndex, // Add segment for position restore
        );

        // Check if near delivery point (3km) and update status
        _checkAndUpdateNearDelivery(location).ignore();

        // Rebuild UI to update speed display
        if (mounted) {
          setState(() {});
        }
      },
      onSegmentComplete: (segmentIndex, isLastSegment) {
        // Pause simulation when reaching any waypoint
        _pauseSimulation();
        _drawRoutes();

        if (isLastSegment) {
          // Reached final destination (Carrier)
          _showCompletionMessage();
        } else {
          // Determine action based on segment index and journey type
          final isReturnJourney = _viewModel.currentJourneyType == 'RETURN';
          final segment = _viewModel.routeSegments[segmentIndex];
          final segmentName = segment.name.toUpperCase();
          // Standard journey: Carrier -> Pickup -> Delivery -> Carrier (3 segments)
          // Return journey: Carrier -> Pickup -> Delivery -> Pickup -> Carrier (4 segments)

          if (isReturnJourney) {
            // Return journey segments:
            // Index 0: Carrier -> Pickup (initial pickup - already done)
            // Index 1: Pickup -> Delivery (delivery - already done)
            // Index 2: Delivery -> Pickup (return to pickup for return delivery)
            // Index 3: Pickup -> Carrier (final return to carrier)
            if (segmentIndex == 2) {
              // Reached pickup point to return packages
              _showReturnDeliveryMessage();
            } else {
              // Other segments in return journey - shouldn't happen but show pickup message as fallback
              _showPickupMessage();
            }
          } else {
            // Standard journey segments:
            // Index 0: Carrier -> Pickup (pickup goods)
            // Index 1: Pickup -> Delivery (deliver goods)
            // Index 2: Delivery -> Carrier (return to carrier)
            if (segmentIndex == 0) {
              // Reached pickup point to get packages
              _showPickupMessage();
            } else if (segmentIndex == 1) {
              // Reached delivery point
              _showDeliveryMessage();
            } else {
              // Other segments - shouldn't happen but show pickup message as fallback
              _showPickupMessage();
            }
          }
        }
      },
      simulationSpeed:
          _simulationSpeed * 0.5, // Giảm xuống 0.5 để đạt 30-60 km/h
    );
  }

  void _pauseSimulation() {
    if (!_isSimulating || _isPaused) {
      return;
    }

    setState(() {
      _isPaused = true;
    });
    _viewModel.pauseSimulation();

    // Rebuild UI to show speed = 0
    if (mounted) {
      setState(() {});
    }
  }

  void _autoResumeSimulation() async {
    // Auto resume simulation if it was paused and running
    if (_isPaused && _isSimulating && mounted) {
      _resumeSimulation();
      return;
    }

    // If simulation is in simulation mode but not actively running, restart it
    if (widget.isSimulationMode && !_viewModel.isSimulating && mounted) {
      _startSimulation();
      return;
    }
  }

  void _resumeSimulation() async {
    // If simulation is running and not paused, just continue
    if (_isSimulating && !_isPaused) {
      // Refocus camera on current position
      if (_viewModel.currentLocation != null) {
        _setCameraToNavigationMode(_viewModel.currentLocation!);
      }
      return;
    }

    if (!_isSimulating || !_isPaused) {
      return;
    }
    // Ensure global tracking is active
    if (!_globalLocationManager.isGlobalTrackingActive) {
      final connected = await _startLocationTracking();
      if (!connected) {
        return;
      }

      // Wait for WebSocket connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isPaused = false;
      _isFollowingUser = true;
    });
    _viewModel.resumeSimulation();

    // Wait a bit for map to be ready, then refocus camera
    await Future.delayed(const Duration(milliseconds: 300));

    // Refocus camera on current position with retry
    if (_viewModel.currentLocation != null && mounted) {
      // Try multiple times to ensure camera focuses
      for (int i = 0; i < 3; i++) {
        if (!mounted) break;

        await _setCameraToNavigationMode(_viewModel.currentLocation!);
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    }

    // Rebuild UI to show updated speed
    if (mounted) {
      setState(() {});
    }
  }

  void _resetSimulation() {
    // Reset UI state
    setState(() {
      _isSimulating = false;
      _isPaused = false;
    });

    // Reset viewModel (cancels timer, clears route data)
    _viewModel.resetNavigation();

    // Clear all polylines and symbols (including current position marker)
    _mapController?.clearLines();
    _mapController?.clearSymbols();

    // CRITICAL: Clear saved navigation state to start fresh
    final stateService = getIt<NavigationStateService>();
    stateService.clearNavigationState();
    // Update simulation mode to false in GlobalLocationManager
    _globalLocationManager.updateSimulationMode(false);

    // Re-parse route and redraw
    if (_viewModel.orderWithDetails != null) {
      _viewModel.parseRouteFromOrder(_viewModel.orderWithDetails!);
      _drawRoutes();

      // Focus camera back to starting position
      if (_viewModel.routeSegments.isNotEmpty &&
          _viewModel.routeSegments[0].points.isNotEmpty) {
        final startPoint = _viewModel.routeSegments[0].points.first;
        _setCameraToNavigationMode(startPoint);

        // Send location update to reset position on server
        _globalLocationManager.sendLocationUpdate(
          startPoint.latitude,
          startPoint.longitude,
          bearing: 0.0,
        );
      }
    }
  }

  void _jumpToNextSegment() async {
    // CRITICAL: Ensure simulation is running
    // If paused, resume it so next tick can detect completion
    if (_isSimulating && _isPaused) {
      _resumeSimulation();
      // Wait a bit for simulation to start
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // CRITICAL: Check if already at end of current segment
    // If yes, move to next segment first before jumping
    if (_viewModel.routeSegments.isNotEmpty &&
        _viewModel.currentSegmentIndex < _viewModel.routeSegments.length) {
      final currentSegment =
          _viewModel.routeSegments[_viewModel.currentSegmentIndex];
      if (currentSegment.points.isNotEmpty &&
          _viewModel.currentLocation != null) {
        final endPoint = currentSegment.points.last;
        final distanceToEnd = _calculateDistance(
          _viewModel.currentLocation!,
          endPoint,
        );

        // If already at end of segment (within 20m), move to next segment first
        if (distanceToEnd < 20 &&
            _viewModel.currentSegmentIndex <
                _viewModel.routeSegments.length - 1) {
          _viewModel.moveToNextSegmentManually();

          // Wait a moment for state update
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    // Check if jumping to delivery point (segment 1) and update status
    final isJumpingToDelivery = _viewModel.currentSegmentIndex == 1;

    // Jump to next segment in viewModel (await for status updates)
    await _viewModel.jumpToNextSegment();

    // CRITICAL: Update order status to ONGOING_DELIVERED when jumping to delivery
    if (isJumpingToDelivery && _viewModel.orderWithDetails != null) {
      final orderDetailViewModel = Provider.of<OrderDetailViewModel>(
        context,
        listen: false,
      );
      await orderDetailViewModel.updateOrderStatusToOngoingDelivered();
      _hasNotifiedNearDelivery =
          true; // Mark as notified to avoid duplicate updates
    } else {}

    // Update camera to new location
    if (_viewModel.currentLocation != null) {
      _updateLocationMarker(
        _viewModel.currentLocation!,
        _viewModel.currentBearing,
      );

      if (_isFollowingUser) {
        _setCameraToNavigationMode(_viewModel.currentLocation!);
      }

      // Send location update to server immediately after skip
      _globalLocationManager.sendLocationUpdate(
        _viewModel.currentLocation!.latitude,
        _viewModel.currentLocation!.longitude,
        bearing: _viewModel.currentBearing,
        speed: _viewModel.currentSpeed,
        segmentIndex: _viewModel.currentSegmentIndex,
      );
    }

    // Redraw routes to update current segment
    _drawRoutes();
    // Note: We don't manually trigger completion here.
    // The next simulation tick (or GPS check) will detect that we're at
    // the end of the segment and trigger onSegmentComplete naturally.
    // This ensures consistent behavior between simulation, GPS, and skip.
  }

  Widget _buildSpeedButton(String label, double speed) {
    final isSelected = _simulationSpeed == speed;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _simulationSpeed = speed;
        });
        if (_isSimulating && !_isPaused) {
          _viewModel.updateSimulationSpeed(_simulationSpeed * 0.5);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(60, 36),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _reportIncident() {
    // Get vehicle assignment ID from viewModel
    final vehicleAssignmentId = _viewModel.vehicleAssignmentId;

    if (vehicleAssignmentId == null || vehicleAssignmentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể báo cáo sự cố: Thiếu thông tin phương tiện'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show bottom sheet for issue type selection (faster UX)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IssueTypeSelectionBottomSheet(
        vehicleAssignmentId: vehicleAssignmentId,
        currentLocation: _viewModel.currentLocation,
        orderWithDetails: _viewModel.orderWithDetails,
        navigationViewModel: _viewModel,
      ),
    ).then((result) {
      if (result == true && mounted) {
        // Resume simulation if it was paused
        if (_isPaused && _isSimulating) {
          _resumeSimulation();
        }
      }
    });
  }

  /// Open chat screen for support
  void _openChatScreen() {
    // Mark messages as read when opening chat
    final chatService = Provider.of<ChatNotificationService>(context, listen: false);
    chatService.markAsRead();
    
    // Pause simulation if it's running
    if (_isSimulating && !_isPaused) {
      _pauseSimulation();
    }
    
    // Get order code and vehicle assignment ID from viewModel
    final orderCode = _viewModel.orderWithDetails?.orderCode;
    final vehicleAssignmentId = _viewModel.vehicleAssignmentId;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          trackingCode: orderCode,
          vehicleAssignmentId: vehicleAssignmentId,
        ),
      ),
    ).then((_) {
      // Auto-resume simulation when returning from chat screen
      if (mounted) {
        _autoResumeSimulation();
      }
    });
  }

  void _showPickupMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping,
                color: Colors.blue.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Đã đến điểm lấy hàng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // Message
            const Text(
              'Vui lòng chụp ảnh xác nhận hàng hóa và seal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog

                // Navigate to order detail and wait for result
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.orderDetail, arguments: widget.orderId);

                // If result is true, seal was confirmed - resume simulation
                if (result == true && mounted) {
                  if (_isPaused && _isSimulating) {
                    _resumeSimulation();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Xác nhận',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );
  }

  void _showReturnDeliveryMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_return,
                color: Colors.orange.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Đã đến điểm trả hàng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // Message
            const Text(
              'Vui lòng chụp ảnh xác nhận trả hàng.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog

                // Navigate to order detail and wait for result
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.orderDetail, arguments: widget.orderId);

                // If result is true, return delivery was confirmed - resume simulation
                if (result == true && mounted) {
                  if (_isPaused && _isSimulating) {
                    _resumeSimulation();
                  }
                }
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
                'Chụp ảnh xác nhận',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );
  }

  void _showGenericWaypointMessage(String endPointName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on,
                color: Colors.teal.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'Đã đến $endPointName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // Message
            Text(
              'Bạn đã đến $endPointName. Vui lòng xác nhận để tiếp tục.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog

                // Navigate to order detail and wait for result
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.orderDetail, arguments: widget.orderId);

                // If result is true, resume simulation
                if (result == true && mounted) {
                  if (_isPaused && _isSimulating) {
                    _resumeSimulation();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Xác nhận',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );
  }

  void _showDeliveryMessage() {
    // CRITICAL: Update order status to ONGOING_DELIVERED when showing delivery dialog
    // Fire and forget - don't wait for it to complete

    _updateOrderStatusOnDeliveryReached().then((_) {}).catchError((e) {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2,
                color: Colors.green.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Đã đến điểm giao hàng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // Message
            const Text(
              'Vui lòng chụp ảnh xác nhận giao hàng.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog

                // Navigate to order detail and wait for result
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.orderDetail, arguments: widget.orderId);

                // If result is true, delivery was confirmed - resume simulation
                if (result == true && mounted) {
                  if (_isPaused && _isSimulating) {
                    _resumeSimulation();
                  }
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
                'Chụp ảnh xác nhận',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );
  }

  /// Update order status to ONGOING_DELIVERED when reaching delivery point
  Future<void> _updateOrderStatusOnDeliveryReached() async {
    try {
      // Call ViewModel method to update status (respects MVVM architecture)
      await _viewModel.updateToOngoingDelivered();
      _hasNotifiedNearDelivery = true; // Mark as notified
    } catch (e) {}
  }

  Future<bool?> _showCompleteTripConfirmation() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hoàn thành'),
        content: const Text(
          'Bạn có chắc chắn đã giao hàng thành công?\n\n'
          'Sau khi xác nhận, chuyến xe sẽ được đánh dấu là hoàn thành.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _showCompletionMessage() {
    // Pause simulation but don't mark as complete yet
    // Driver needs to upload odometer end reading first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warehouse,
                color: Colors.purple.shade600,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Đã về đến đơn vị vận chuyển',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // Message
            const Text(
              'Vui lòng chụp ảnh đồng hồ công tơ mét cuối để hoàn thành chuyến xe.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog

                // Navigate to order detail to upload odometer
                // OrderDetailScreen will handle stopping tracking after upload
                Navigator.of(
                  context,
                ).pushNamed(AppRoutes.orderDetail, arguments: widget.orderId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Chụp ảnh đồng hồ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      ),
    );
  }

  // Track if we've already notified about near delivery
  bool _hasNotifiedNearDelivery = false;
  static const double _nearDeliveryThresholdKm = 3.0;

  /// Check if vehicle is near delivery point (within 3km) and update order status
  Future<void> _checkAndUpdateNearDelivery(LatLng currentLocation) async {
    // Only check if:
    // 1. Currently in segment 1 (going to delivery point)
    // 2. Haven't notified yet
    // 3. Have order details
    if (_viewModel.currentSegmentIndex != 1 ||
        _hasNotifiedNearDelivery ||
        _viewModel.orderWithDetails == null) {
      return;
    }

    // Get delivery point (last point of segment 1)
    if (_viewModel.routeSegments.length <= 1 ||
        _viewModel.routeSegments[1].points.isEmpty) {
      return;
    }

    final deliveryPoint = _viewModel.routeSegments[1].points.last;
    final distanceMeters = _calculateDistance(currentLocation, deliveryPoint);
    final distanceKm = distanceMeters / 1000;

    // If within 3km threshold, update order status
    if (distanceKm <= _nearDeliveryThresholdKm) {
      _hasNotifiedNearDelivery = true;

      // Call OrderDetailViewModel to update status
      final orderDetailViewModel = Provider.of<OrderDetailViewModel>(
        context,
        listen: false,
      );
      await orderDetailViewModel.updateOrderStatusToOngoingDelivered();
    }
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(LatLng start, LatLng end) {
    const earthRadius = 6371000; // meters
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLat = (end.latitude - start.latitude) * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // distance in meters
  }

  void _toggle3DMode() {
    setState(() {
      _is3DMode = !_is3DMode;
    });

    if (_viewModel.currentLocation != null) {
      _setCameraToNavigationMode(_viewModel.currentLocation!);
    }
  }

  /// North-Up Rotating Mode (Google Maps Style)
  /// - Map XOAY theo bearing (follow direction)
  /// - Marker counter-rotate để TĨNH (luôn hướng Bắc ↑)
  /// - Route line LUÔN THẲNG ĐỨNG (aligned với marker)
  /// - Camera offset theo hướng di chuyển
  /// - Throttles to 60 FPS for ultra-smooth performance
  Future<void> _setCameraToNavigationMode(LatLng position) async {
    if (!_isMapOperationSafe) return;

    // THROTTLE: Update camera every 16ms (60 FPS) for ultra-fast response
    // moveCamera is instant, so we can update at maximum frequency
    final now = DateTime.now();
    if (_lastCameraUpdate != null) {
      final elapsed = now.difference(_lastCameraUpdate!).inMilliseconds;
      if (elapsed < _cameraThrottleMs) {
        return; // Skip this update - too soon!
      }
    }
    _lastCameraUpdate = now;

    // Apply perpendicular off-route offset to camera position when simulation is active
    // This ensures camera follows the offset marker position, not the original route
    // print('🎥 [_setCameraToNavigationMode] INPUT position: ${position.latitude}, ${position.longitude} (off-route: $_isOffRouteSimulated)');
    
    // 🔒 GUARD: Detect if input position is already offset to prevent double-offset
    LatLng actualPosition;
    if (_isOffRouteSimulated && _viewModel.currentLocation != null) {
      // Calculate distance between input and current raw location
      final distance = _calculateDistance(position, _viewModel.currentLocation!);
      if (distance > 150) { // If input is >150m away from raw location, it's already offset
        // print('🎥 [_setCameraToNavigationMode] DETECTED pre-offset position (distance: ${distance.toStringAsFixed(1)}m), using directly');
        actualPosition = position;
      } else {
        // print('🎥 [_setCameraToNavigationMode] Applying offset (distance: ${distance.toStringAsFixed(1)}m from raw)');
        actualPosition = _calculateOffRoutePosition(position, _viewModel.currentBearing);
      }
    } else {
      actualPosition = _calculateOffRoutePosition(position, _viewModel.currentBearing);
    }
    
    // print('🎥 [_setCameraToNavigationMode] FINAL position: ${actualPosition.latitude}, ${actualPosition.longitude} (off-route: $_isOffRouteSimulated)');

    // Instant camera movement for absolute fastest response
    // moveCamera provides immediate positioning without any animation delay
    // 🔒 OFF-ROUTE SIMULATION MODE
    // Để tránh mọi hiện tượng camera "nhảy" sang vị trí lạ rồi quay lại,
    // khi đang bật giả lập off-route ta dùng cách focus camera ĐƠN GIẢN, ỔN ĐỊNH:
    // - Không dùng 3D forward offset
    // - Không xoay theo bearing, không tilt
    // - Chỉ bám đúng vị trí off-route (actualPosition)
    if (_isOffRouteSimulated) {
      try {
        await _mapController!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              // Zoom cố định, 2D, không xoay
              target: actualPosition,
              zoom: 17.5,
              bearing: 0.0,
              tilt: 0.0,
            ),
          ),
        );
      } catch (_) {}
      return;
    }

    // NORTH-UP ROTATING OFFSET (chỉ áp dụng khi KHÔNG test off-route):
    // - Map xoay theo bearing → route line thẳng đứng
    // - Camera offset về phía TRƯỚC (theo bearing)
    // - Marker ở bottom 1/3, counter-rotate để tĩnh
    LatLng cameraTarget = actualPosition;

    if (_is3DMode && _viewModel.currentBearing != null) {
      // Offset về phía TRƯỚC theo hướng bearing
      const double offsetMeters = 60;

      // Convert bearing to radians
      final double bearingRad = (_viewModel.currentBearing! * 3.14159) / 180.0;

      // Calculate offset in bearing direction - use actualPosition for on-route support
      final double latOffset = offsetMeters * 0.000009 * cos(bearingRad);
      final double lngOffset = offsetMeters * 0.000009 * sin(bearingRad);

      cameraTarget = LatLng(
        actualPosition.latitude + latOffset,
        actualPosition.longitude + lngOffset,
      );
    }

    if (_is3DMode) {
      // North-Up Rotating: Map xoay, route line thẳng đứng
      _mapController!
          .moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: cameraTarget,
                zoom: 17.5,
                bearing:
                    _viewModel.currentBearing ?? 0.0, // Map XOAY theo bearing
                tilt: 55.0,
              ),
            ),
          )
          .catchError((e) {});
    } else {
      // 2D Overview Mode - use actualPosition for off-route support
      _mapController!
          .moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: actualPosition,
                zoom: 15.0,
                bearing: 0.0,
                tilt: 0.0,
              ),
            ),
          )
          .catchError((e) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CRITICAL: Show loading/error screen until order loads successfully
    if (_isInitializing) {
      return _buildInitializingScreen();
    }

    if (_initializationError != null) {
      return _buildErrorScreen();
    }

    // ✅ SIMPLE: Show navigation UI immediately after order loads (like route detail screen)
    // Map will render asynchronously via callbacks - no need to block UI
    return WillPopScope(
      onWillPop: () async {
        // Use pushReplacement to go to OrderDetail
        // This keeps navigation stack clean and avoids splash screen
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.orderDetail,
          arguments: widget.orderId,
        );
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dẫn đường'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Use pushReplacement to go to OrderDetail
              Navigator.of(context).pushReplacementNamed(
                AppRoutes.orderDetail,
                arguments: widget.orderId,
              );
            },
          ),
          actions: [
            // Button to toggle following mode
            IconButton(
              icon: Icon(
                _isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed,
              ),
              onPressed: () {
                setState(() {
                  _isFollowingUser = !_isFollowingUser;
                  if (_isFollowingUser && _viewModel.currentLocation != null) {
                    _updateCameraPosition(
                      _viewModel.currentLocation!,
                      _viewModel.currentBearing,
                    );
                  }
                });
              },
              tooltip: _isFollowingUser ? 'Đang theo dõi' : 'Không theo dõi',
            ),
          ],
        ),
        body: Column(
          children: [
            // Route info panel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đoạn đường: ${_viewModel.getCurrentSegmentName()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tốc độ: ${_viewModel.currentSpeed.toStringAsFixed(1)} km/h',
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isSimulationMode)
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to simulation mode
                        Navigator.of(context).pushReplacementNamed(
                          AppRoutes.navigation,
                          arguments: {
                            'orderId': widget.orderId,
                            'isSimulationMode': true,
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: const Text('Mô phỏng'),
                    ),
                ],
              ),
            ),

            
            // 🆕 Pending Seal Replacement Banner
            if (_pendingSealReplacements.isNotEmpty)
              PendingSealReplacementBanner(
                issue: _pendingSealReplacements.first,
                onTap: () =>
                    _showConfirmSealSheet(_pendingSealReplacements.first),
              ),

            // Loading indicator cho pending seals
            // if (_isLoadingPendingSeals)
            //   Container(
            //     padding: const EdgeInsets.all(8),
            //     color: AppColors.primary.withOpacity(0.05),
            //     child: const Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         SizedBox(
            //           width: 16,
            //           height: 16,
            //           child: CircularProgressIndicator(strokeWidth: 2),
            //         ),
            //         SizedBox(width: 8),
            //         Text('Đang kiểm tra seal...'),
            //       ],
            //     ),
            //   ),

            // Loading indicator cho fuel consumption
            // if (_isLoadingFuelConsumption)
            //   Container(
            //     padding: const EdgeInsets.all(8),
            //     color: Colors.green.withOpacity(0.05),
            //     child: const Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [
            //         SizedBox(
            //           width: 16,
            //           height: 16,
            //           child: CircularProgressIndicator(strokeWidth: 2),
            //         ),
            //         SizedBox(width: 8),
            //         Text('Đang tải thông tin nhiên liệu...'),
            //       ],
            //     ),
            //   ),
            Expanded(
              child: Container(
                color: Colors.white,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ✅ CRITICAL FIX: Always build VietmapGL widget to ensure callbacks fire
                    // Remove guard condition that was preventing callbacks when map style failed
                    Builder(
                      builder: (context) {
                        // print('🗺️ [MapWidget] Building VietmapGL widget (style loading: $_isLoadingMapStyle)');
                        return SizedBox.expand(
                          child: VietmapGL(
                            styleString: _getMapStyleString(),
                            initialCameraPosition: _getInitialCameraPosition(),
                            myLocationEnabled: false,
                            myLocationTrackingMode:
                                MyLocationTrackingMode.values[0],
                            myLocationRenderMode:
                                MyLocationRenderMode.values[0],
                            trackCameraPosition: true,
                            onMapCreated: _onMapCreated,
                            onMapRenderedCallback: _onMapRendered,
                            onStyleLoadedCallback: _onStyleLoaded,
                            rotateGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            zoomGesturesEnabled: true,
                            doubleClickZoomEnabled: true,
                            cameraTargetBounds: CameraTargetBounds.unbounded,
                          ),
                        );
                      },
                    ),

                    // Waypoint markers (static locations - use MarkerLayer)
                    if (_mapController != null &&
                        _waypointMarkers.isNotEmpty &&
                        _isMapReady &&
                        _isMapInitialized)
                      MarkerLayer(
                        mapController: _mapController!,
                        markers: _waypointMarkers,
                        ignorePointer: true,
                      ),

                    // Vehicle marker - North-Up Rotating (TUYỆT ĐỐI TĨNH)
                    // Map xoay → marker counter-rotate → TĨNH + route line thẳng
                    // CRITICAL: Dùng Matrix4 transformation (NO animation, game engine approach)
                    if (_mapController != null &&
                        _viewModel.currentLocation != null &&
                        _isMapReady &&
                        _isMapInitialized)
                      Builder(
                        builder: (context) {
                          // Get ACTUAL camera bearing for exact counter-rotation
                          final actualBearing =
                              _mapController?.cameraPosition?.bearing ?? 0.0;

                          // CRITICAL: Matrix4 transformation - NO implicit animation
                          // This is the approach used in game engines and Google Maps SDK
                          // IMPORTANT: Counter-rotate in OPPOSITE direction (positive angle)
                          final counterRotationAngle =
                              actualBearing * 3.14159 / 180;
                          final transformMatrix = Matrix4.identity()
                            ..rotateZ(counterRotationAngle);

                          return StaticMarkerLayer(
                            mapController: _mapController!,
                            ignorePointer: true,
                            markers: [
                              StaticMarker(
                                width: 44,
                                height: 44,
                                bearing: 0, // StaticMarker không xoay
                                child: Transform(
                                  key: ValueKey(
                                    actualBearing,
                                  ), // Force rebuild on bearing change
                                  transform:
                                      transformMatrix, // Matrix4 - NO animation ✅
                                  alignment: Alignment.center,
                                  child: const StaticVehicleMarker(
                                    size: 44, // NO internal rotation ✅
                                  ),
                                ),
                                latLng: _calculateOffRoutePosition(
                                    _viewModel.currentLocation!, 
                                    _viewModel.currentBearing
                                  ),
                              ),
                            ],
                          );
                        },
                      ),

                    // Loading indicator
                    if (_isLoadingMapStyle)
                      const Center(child: CircularProgressIndicator()),

                    // Route info overlay
                    if (_viewModel.routeSegments.isNotEmpty)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                int i = 0;
                                i < _viewModel.routeSegments.length;
                                i++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color:
                                              i ==
                                                  _viewModel.currentSegmentIndex
                                              ? AppColors.primary
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _viewModel.routeSegments[i].name,
                                        style: TextStyle(
                                          fontWeight:
                                              i ==
                                                  _viewModel.currentSegmentIndex
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color:
                                              i ==
                                                  _viewModel.currentSegmentIndex
                                              ? AppColors.primary
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Action buttons
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        children: [
                          // Upload fuel invoice button
                          Tooltip(
                            message: 'Upload hóa đơn xăng',
                            child: FloatingActionButton(
                              onPressed: _showFuelInvoiceUploadSheet,
                              backgroundColor: Colors.green,
                              mini: true,
                              heroTag: 'fuel',
                              child: const Icon(
                                Icons.local_gas_station,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Report incident button
                          FloatingActionButton(
                            onPressed: _reportIncident,
                            backgroundColor: Colors.red,
                            mini: true,
                            heroTag: 'incident',
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Chat support button
                          Consumer<ChatNotificationService>(
                            builder: (context, chatService, child) {
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  FloatingActionButton(
                                    onPressed: _openChatScreen,
                                    backgroundColor: const Color(0xFF1565C0),
                                    mini: true,
                                    heroTag: 'chat',
                                    child: const Icon(
                                      Icons.chat,
                                      color: Colors.white,
                                    ),
                                  ),
                                  // Unread badge
                                  if (chatService.hasUnread)
                                    Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Center(
                                          child: Text(
                                            chatService.unreadCount > 9 
                                                ? '9+' 
                                                : chatService.unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          
                          // Off-route simulation toggle (for testing off-route detection)
                          FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                _isOffRouteSimulated = !_isOffRouteSimulated;
                                // Lock camera when off-route testing to prevent jumping
                                _isCameraLocked = _isOffRouteSimulated;
                              });
                              
                              // Update marker immediately when toggle changes
                              _updateLocationMarkerForOffRoute();
                              
                              print('🎥 [OffRouteToggle] Camera lock: $_isCameraLocked (off-route: $_isOffRouteSimulated)');
                              
                              if (_isOffRouteSimulated) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã BẬT giả lập lệch tuyến. Vị trí sẽ bị offset 200m vuông góc BÊN TRÁI route.',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã TẮT giả lập lệch tuyến. Vị trí trở về bình thường.',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            backgroundColor: _isOffRouteSimulated ? Colors.orange : Colors.grey,
                            mini: true,
                            heroTag: 'offroute',
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Simulation controls (only visible in simulation mode)
            if (widget.isSimulationMode)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đoạn đường hiện tại: ${_viewModel.getCurrentSegmentName()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Tốc độ:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildSpeedButton('x1', 1.0),
                              _buildSpeedButton('x2', 2.0),
                              _buildSpeedButton('x3', 3.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                                        const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            // ✅ CRITICAL: Only enable when data is ready and not loading
                            onPressed:
                                (!_isSimulating &&
                                    _isDataReady &&
                                    !_isLoadingOrder)
                                ? _startSimulation
                                : (_isSimulating
                                      ? (_isPaused
                                            ? _resumeSimulation
                                            : _pauseSimulation)
                                      : null), // Disable if data not ready
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey,
                              disabledForegroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Show loading spinner when loading order
                                if (_isLoadingOrder && !_isSimulating)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                else
                                  Icon(
                                    !_isSimulating
                                        ? Icons.play_arrow
                                        : (_isPaused
                                              ? Icons.play_arrow
                                              : Icons.pause),
                                    size: 20,
                                  ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _isLoadingOrder && !_isSimulating
                                        ? (_loadOrderRetryCount > 0
                                              ? 'Thử lại ${_loadOrderRetryCount + 1}/$_maxLoadOrderRetries'
                                              : 'Đang tải...')
                                        : (!_isSimulating
                                              ? (!_isDataReady
                                                    ? 'Chưa sẵn sàng'
                                                    : 'Bắt đầu')
                                              : (_isPaused
                                                    ? 'Tiếp tục'
                                                    : 'Tạm dừng')),
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isSimulating) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _jumpToNextSegment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.skip_next, size: 20),
                                  SizedBox(width: 4),
                                  Text('Skip', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _resetSimulation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, size: 20),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Đặt lại',
                                    style: TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  /// Build initializing screen với loading indicator
  Widget _buildInitializingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đang tải'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Hide back button while loading
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SkeletonLoader(height: 60, width: 60, borderRadius: 30),
                  SizedBox(height: 24),
                  SkeletonLoader(height: 20, width: 200),
                  SizedBox(height: 12),
                  SkeletonLoader(height: 16, width: 150),
                  SizedBox(height: 32),
                  SkeletonLoader(height: 16, width: 180),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build map loading screen with detailed progress indicators
  Widget _buildMapLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đang tải bản đồ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Hide back button while loading
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Đang khởi tạo bản đồ dẫn đường...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),

            // Progress indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  _buildProgressItem(
                    'Tải style bản đồ',
                    !_isLoadingMapStyle,
                    Icons.map,
                  ),
                  _buildProgressItem(
                    'Khởi tạo map widget',
                    _mapController != null,
                    Icons.map_outlined,
                  ),
                  _buildProgressItem(
                    'Render bản đồ',
                    _isMapReady,
                    Icons.visibility,
                  ),
                  _buildProgressItem(
                    'Tải style hoàn tất',
                    _isMapInitialized,
                    Icons.check_circle,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Vui lòng đợi trong giây lát. Bản đồ cần thời gian để tải và khởi tạo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String label, bool isCompleted, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : icon,
            color: isCompleted ? Colors.green : Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isCompleted ? Colors.black87 : Colors.grey[600],
                fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error screen với retry button
  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lỗi tải dữ liệu'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.orderDetail,
              arguments: widget.orderId,
            );
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
              const SizedBox(height: 24),
              const Text(
                'Không thể tải thông tin lộ trình',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _initializationError ?? 'Đã xảy ra lỗi không xác định',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Retry button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isInitializing = true;
                      _initializationError = null;
                      _loadOrderRetryCount = 0; // Reset retry count
                    });
                    _initializeScreen();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Back button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed(
                      AppRoutes.orderDetail,
                      arguments: widget.orderId,
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay lại'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
