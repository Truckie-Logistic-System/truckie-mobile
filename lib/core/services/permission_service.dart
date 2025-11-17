import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to handle runtime permissions with user-friendly dialogs
class PermissionService {
  /// Check and request location permission
  /// Returns true if permission is granted
  static Future<bool> checkAndRequestLocationPermission({
    BuildContext? context,
    bool showRationale = true,
  }) async {
    var status = await Permission.location.status;
    
    debugPrint('📍 [PermissionService] Current location permission: $status');
    
    if (status.isGranted) {
      debugPrint('✅ [PermissionService] Location permission already granted');
      return true;
    }
    
    if (status.isDenied) {
      debugPrint('⚠️ [PermissionService] Location permission denied, requesting...');
      
      // Show rationale if context provided
      if (showRationale && context != null) {
        final shouldRequest = await _showPermissionRationale(
          context,
          title: 'Quyền truy cập vị trí',
          message: 'Ứng dụng cần quyền truy cập vị trí để theo dõi chuyến hàng và cập nhật vị trí real-time.',
        );
        
        if (!shouldRequest) {
          debugPrint('❌ [PermissionService] User declined permission request');
          return false;
        }
      }
      
      // Request permission
      status = await Permission.location.request();
      debugPrint('📍 [PermissionService] Permission request result: $status');
    }
    
    if (status.isPermanentlyDenied) {
      debugPrint('🚫 [PermissionService] Location permission permanently denied');
      
      // Show dialog to open settings
      if (context != null) {
        await _showPermissionDeniedDialog(context);
      }
      
      return false;
    }
    
    return status.isGranted;
  }
  
  /// Check location permission status without requesting
  static Future<PermissionStatus> getLocationPermissionStatus() async {
    return await Permission.location.status;
  }
  
  /// Check if location permission is granted
  static Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }
  
  /// Show rationale dialog before requesting permission
  static Future<bool> _showPermissionRationale(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không cho phép'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cho phép'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  /// Show dialog when permission is permanently denied
  static Future<void> _showPermissionDeniedDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cần cấp quyền',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ứng dụng cần quyền truy cập vị trí để theo dõi chuyến hàng.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            SizedBox(height: 16),
            Text(
              'Vui lòng:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              '1. Nhấn "Mở Cài đặt"\n2. Chọn "Quyền"\n3. Bật "Vị trí"',
              style: TextStyle(fontSize: 14, height: 1.8),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mở Cài đặt'),
          ),
        ],
      ),
    );
  }
  
  /// Show a simple snackbar for permission errors
  static void showPermissionError(
    BuildContext context, {
    String message = 'Cần quyền truy cập để sử dụng tính năng này',
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Cài đặt',
          textColor: Colors.white,
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }
  
  /// Request multiple permissions at once
  static Future<Map<Permission, PermissionStatus>> requestMultiplePermissions(
    List<Permission> permissions,
  ) async {
    debugPrint('📋 [PermissionService] Requesting multiple permissions: $permissions');
    final statuses = await permissions.request();
    
    for (final entry in statuses.entries) {
      debugPrint('   - ${entry.key}: ${entry.value}');
    }
    
    return statuses;
  }
  
  /// Check if all required permissions are granted
  static Future<bool> areAllPermissionsGranted(
    List<Permission> permissions,
  ) async {
    for (final permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        debugPrint('❌ [PermissionService] Permission not granted: $permission');
        return false;
      }
    }
    
    debugPrint('✅ [PermissionService] All permissions granted');
    return true;
  }
  
  /// Request location permission with better error handling
  /// Returns detailed result
  static Future<LocationPermissionResult> requestLocationPermissionWithResult() async {
    var status = await Permission.location.status;
    
    if (status.isGranted) {
      return LocationPermissionResult(
        isGranted: true,
        status: status,
        message: 'Quyền truy cập vị trí đã được cấp',
      );
    }
    
    if (status.isDenied) {
      status = await Permission.location.request();
      
      if (status.isGranted) {
        return LocationPermissionResult(
          isGranted: true,
          status: status,
          message: 'Đã cấp quyền truy cập vị trí',
        );
      }
    }
    
    if (status.isPermanentlyDenied) {
      return LocationPermissionResult(
        isGranted: false,
        status: status,
        message: 'Quyền truy cập vị trí bị từ chối. Vui lòng mở Cài đặt để cấp quyền.',
        shouldOpenSettings: true,
      );
    }
    
    return LocationPermissionResult(
      isGranted: false,
      status: status,
      message: 'Cần quyền truy cập vị trí để sử dụng tính năng này',
    );
  }
}

/// Result object for location permission requests
class LocationPermissionResult {
  final bool isGranted;
  final PermissionStatus status;
  final String message;
  final bool shouldOpenSettings;
  
  const LocationPermissionResult({
    required this.isGranted,
    required this.status,
    required this.message,
    this.shouldOpenSettings = false,
  });
  
  @override
  String toString() {
    return 'LocationPermissionResult(isGranted: $isGranted, status: $status, message: $message)';
  }
}
