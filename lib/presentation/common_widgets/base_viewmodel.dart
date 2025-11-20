import 'package:flutter/foundation.dart';

import '../../app/di/service_locator.dart';
import '../features/auth/viewmodels/auth_viewmodel.dart';

/// BaseViewModel cung cấp các chức năng cơ bản cho tất cả các ViewModel
/// như xử lý lỗi, refresh token, v.v.
abstract class BaseViewModel extends ChangeNotifier {
  bool _isDisposed = false;
  bool _isRetrying = false;

  /// Ghi đè phương thức notifyListeners để tránh lỗi khi ViewModel đã bị dispose
  /// CRITICAL: Wrap in try-catch to handle rare race condition where dispose() 
  /// is called between the check and super.notifyListeners()
  @override
  void notifyListeners() {
    if (_isDisposed) return;
    
    try {
      super.notifyListeners();
    } catch (e) {
      // Handle case where disposal happened during notifyListeners()
      // This is a rare race condition but can occur under heavy load
      if (!e.toString().contains('disposed')) {
        // Re-throw if it's not a disposal error
        
        rethrow;
      }
      // Silently ignore disposal errors as they're expected
    }
  }

  /// Xử lý lỗi unauthorized và thử refresh token
  Future<bool> handleUnauthorizedError(String errorMessage) async {
    if (errorMessage.contains('Missing or invalid Authorization header') ||
        errorMessage.contains('Invalid or missing token') ||
        errorMessage.contains('Unauthorized') ||
        errorMessage.contains(
          'Access token expired. Please refresh your token.',
        ) ||
        errorMessage.contains('không có quyền truy cập') ||
        errorMessage.contains('401') ||
        errorMessage.contains('token')) {
      if (!_isRetrying) {
        _isRetrying = true;
        

        try {
          final authViewModel = getIt<AuthViewModel>();
          final refreshed = await authViewModel.handleTokenExpired();

          _isRetrying = false;
          if (refreshed) {
            
            return true; // Thành công, có thể thử lại request
          } else {
            
            return false; // Thất bại, không thể thử lại
          }
        } catch (e) {
          _isRetrying = false;
          
          return false;
        }
      } else {
        
        return false;
      }
    }

    // Không phải lỗi unauthorized
    return false;
  }

  /// Ghi đè phương thức dispose để đánh dấu ViewModel đã bị dispose
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
