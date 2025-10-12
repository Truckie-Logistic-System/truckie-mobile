import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'enhanced_location_tracking_service.dart';

/// Background Location Service cho Android
/// Sử dụng Foreground Service để tracking khi app ở background
class BackgroundLocationService {
  static const String _taskName = 'background_location_tracking';
  static const String _notificationChannelId = 'location_tracking_channel';
  static const String _notificationChannelName = 'Location Tracking';
  static const int _notificationId = 1001;
  
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _isRunning = false;
  static Timer? _locationTimer;
  static EnhancedLocationTrackingService? _trackingService;
  static String? _currentVehicleId;
  static String? _currentLicensePlate;
  
  static bool get isRunning => _isRunning;

  /// Initialize background service
  static Future<void> initialize() async {
    try {
      // Initialize AndroidAlarmManager as WorkManager alternative
      await AndroidAlarmManager.initialize();

      // Initialize notifications
      await _initializeNotifications();
      
      debugPrint('✅ BackgroundLocationService initialized with AndroidAlarmManager');
    } catch (e) {
      debugPrint('❌ Failed to initialize BackgroundLocationService: $e');
      // Don't rethrow, just log the error for compatibility
    }
  }

  /// Start background location tracking
  static Future<bool> startBackgroundTracking({
    required String vehicleId,
    required String licensePlateNumber,
    String? jwtToken,
  }) async {
    if (_isRunning) {
      debugPrint('⚠️ Background tracking already running');
      return true;
    }

    try {
      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission denied');
        return false;
      }

      _currentVehicleId = vehicleId;
      _currentLicensePlate = licensePlateNumber;

      // Show persistent notification
      await _showTrackingNotification();

      // Start periodic background task with AndroidAlarmManager
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15), // Every 15 minutes
        1001, // Unique ID
        _backgroundLocationCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: {
          'vehicleId': vehicleId,
          'licensePlateNumber': licensePlateNumber,
          'jwtToken': jwtToken,
        },
      );

      // Also start immediate tracking for foreground
      await _startImmediateTracking(vehicleId, licensePlateNumber, jwtToken);

      _isRunning = true;
      debugPrint('✅ Background location tracking started');
      return true;
      
    } catch (e) {
      debugPrint('❌ Failed to start background tracking: $e');
      return false;
    }
  }

  /// Start immediate location tracking (for when app is in foreground)
  static Future<void> _startImmediateTracking(
    String vehicleId,
    String licensePlateNumber,
    String? jwtToken,
  ) async {
    try {
      // Initialize tracking service if needed
      _trackingService ??= EnhancedLocationTrackingService();
      
      // Start enhanced tracking
      final success = await _trackingService!.startTracking(
        vehicleId: vehicleId,
        licensePlateNumber: licensePlateNumber,
        jwtToken: jwtToken,
        onError: (error) {
          debugPrint('❌ Background tracking error: $error');
        },
      );

      if (success) {
        // Start location updates timer
        _locationTimer?.cancel();
        _locationTimer = Timer.periodic(
          const Duration(seconds: 10), // More frequent when in foreground
          (_) => _getCurrentLocationAndSend(),
        );
        
        debugPrint('✅ Immediate tracking started');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to start immediate tracking: $e');
    }
  }

  /// Get current location and send via tracking service
  static Future<void> _getCurrentLocationAndSend() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      await _trackingService?.sendPosition(position);
      
      // Update notification with current location (optional)
      await _updateTrackingNotification(
        'Tracking: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      );
      
    } catch (e) {
      debugPrint('❌ Failed to get current location: $e');
    }
  }

  /// Stop background location tracking
  static Future<void> stopBackgroundTracking() async {
    if (!_isRunning) {
      debugPrint('⚠️ Background tracking not running');
      return;
    }

    try {
      // Cancel AndroidAlarmManager task
      await AndroidAlarmManager.cancel(1001);
      
      // Stop immediate tracking
      _locationTimer?.cancel();
      _locationTimer = null;
      
      // Stop tracking service
      await _trackingService?.stopTracking();
      _trackingService = null;
      
      // Cancel notification
      await _notifications.cancel(_notificationId);
      
      _isRunning = false;
      _currentVehicleId = null;
      _currentLicensePlate = null;
      
      debugPrint('✅ Background location tracking stopped');
      
    } catch (e) {
      debugPrint('❌ Failed to stop background tracking: $e');
    }
  }

  /// Initialize notifications
  static Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);

    // Create notification channel
    const androidChannel = AndroidNotificationChannel(
      _notificationChannelId,
      _notificationChannelName,
      description: 'Notifications for location tracking service',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Show persistent tracking notification
  static Future<void> _showTrackingNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: 'Location tracking is active',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      'Đang theo dõi vị trí',
      'Xe ${_currentLicensePlate ?? 'N/A'} - Tracking active',
      notificationDetails,
    );
  }

  /// Update tracking notification with current info
  static Future<void> _updateTrackingNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      _notificationChannelId,
      _notificationChannelName,
      channelDescription: 'Location tracking is active',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      'Đang theo dõi vị trí',
      message,
      notificationDetails,
    );
  }

  /// Get current tracking status
  static Map<String, dynamic> getTrackingStatus() {
    return {
      'isRunning': _isRunning,
      'vehicleId': _currentVehicleId,
      'licensePlate': _currentLicensePlate,
      'hasTimer': _locationTimer != null,
      'trackingServiceActive': _trackingService != null,
    };
  }
}

/// Background location callback for AndroidAlarmManager
/// This runs in a separate isolate
@pragma('vm:entry-point')
void _backgroundLocationCallback(int id, Map<String, dynamic> params) async {
  debugPrint('🔄 Background location task started: $id');
  
  try {
    final vehicleId = params['vehicleId'] as String?;
    final licensePlateNumber = params['licensePlateNumber'] as String?;
    final jwtToken = params['jwtToken'] as String?;

    if (vehicleId == null || licensePlateNumber == null) {
      debugPrint('❌ Missing vehicle info in background task');
      return;
    }

    // Check location permission
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      debugPrint('❌ Location permission denied in background');
      return;
    }

    // Get current location with timeout
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium, // Medium accuracy to save battery
      timeLimit: const Duration(seconds: 30),
    );

    debugPrint('📍 Background location: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m');

    // Validate GPS quality
    if (position.accuracy > 100.0) {
      debugPrint('⚠️ GPS accuracy too poor in background: ${position.accuracy}m');
      return; // Skip poor quality locations
    }

    // Queue location for main app to process
    await _queueBackgroundLocation(
      vehicleId: vehicleId,
      licensePlateNumber: licensePlateNumber,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      bearing: position.heading,
      speed: position.speed,
      timestamp: DateTime.now(),
      jwtToken: jwtToken,
    );
    
    debugPrint('✅ Background location queued successfully');
    
  } catch (e) {
    debugPrint('❌ Background location task error: $e');
  }
}

/// Queue background location to Hive for main app to process
Future<void> _queueBackgroundLocation({
  required String vehicleId,
  required String licensePlateNumber,
  required double latitude,
  required double longitude,
  required double accuracy,
  double? bearing,
  double? speed,
  required DateTime timestamp,
  String? jwtToken,
}) async {
  try {
    // Initialize Hive if not already initialized
    if (!Hive.isBoxOpen('background_location_queue')) {
      await Hive.initFlutter();
      await Hive.openBox('background_location_queue');
    }

    final box = Hive.box('background_location_queue');
    
    // Create location data
    final locationData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'vehicleId': vehicleId,
      'licensePlateNumber': licensePlateNumber,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'bearing': bearing,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
      'jwtToken': jwtToken,
      'source': 'background_alarm',
    };

    // Add to queue
    await box.add(locationData);
    
    // Limit queue size to 100 items
    if (box.length > 100) {
      await box.deleteAt(0); // Remove oldest
    }

    debugPrint('📦 Background location queued: ${box.length} items in queue');
    
  } catch (e) {
    debugPrint('❌ Failed to queue background location: $e');
  }
}

// AndroidAlarmManager provides WorkManager-like functionality with better compatibility
