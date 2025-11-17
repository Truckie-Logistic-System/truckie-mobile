/// Maps technical errors to user-friendly Vietnamese messages
class ErrorMapper {
  /// Convert any error/exception to user-friendly message
  static String mapToUserFriendlyMessage(dynamic error) {
    if (error == null) {
      return 'Có lỗi không xác định xảy ra. Vui lòng thử lại.';
    }
    
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (_isNetworkError(errorString)) {
      return 'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.';
    }
    
    // Timeout errors
    if (_isTimeoutError(errorString)) {
      return 'Kết nối quá lâu. Vui lòng thử lại.';
    }
    
    // Authentication errors
    if (_isAuthError(errorString)) {
      return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
    }
    
    // Permission errors
    if (_isPermissionError(errorString)) {
      return 'Ứng dụng cần quyền truy cập để thực hiện chức năng này.';
    }
    
    // Server errors (500, 502, 503)
    if (_isServerError(errorString)) {
      return 'Hệ thống đang bảo trì. Vui lòng thử lại sau.';
    }
    
    // Not found errors (404)
    if (_isNotFoundError(errorString)) {
      return 'Không tìm thấy thông tin. Vui lòng thử lại.';
    }
    
    // File/Upload errors
    if (_isFileError(errorString)) {
      return 'Không thể xử lý file. Vui lòng chọn file khác.';
    }
    
    // Location/GPS errors
    if (_isLocationError(errorString)) {
      return 'Không thể lấy vị trí hiện tại. Vui lòng bật GPS và thử lại.';
    }
    
    // WebSocket errors
    if (_isWebSocketError(errorString)) {
      return 'Mất kết nối theo dõi. Đang thử kết nối lại...';
    }
    
    // Default fallback
    return 'Có lỗi xảy ra. Vui lòng thử lại sau.';
  }
  
  /// Check if error is network-related
  static bool _isNetworkError(String error) {
    return error.contains('socket') ||
           error.contains('network') ||
           error.contains('connection refused') ||
           error.contains('failed host lookup') ||
           error.contains('no internet') ||
           error.contains('no connection');
  }
  
  /// Check if error is timeout-related
  static bool _isTimeoutError(String error) {
    return error.contains('timeout') ||
           error.contains('time out') ||
           error.contains('deadline exceeded');
  }
  
  /// Check if error is authentication-related
  static bool _isAuthError(String error) {
    return error.contains('401') ||
           error.contains('unauthorized') ||
           error.contains('unauthenticated') ||
           error.contains('invalid token') ||
           error.contains('token expired') ||
           error.contains('missing authorization') ||
           error.contains('không có quyền');
  }
  
  /// Check if error is permission-related
  static bool _isPermissionError(String error) {
    return error.contains('permission denied') ||
           error.contains('403') ||
           error.contains('forbidden') ||
           error.contains('access denied');
  }
  
  /// Check if error is server error (5xx)
  static bool _isServerError(String error) {
    return error.contains('500') ||
           error.contains('502') ||
           error.contains('503') ||
           error.contains('504') ||
           error.contains('internal server error') ||
           error.contains('bad gateway') ||
           error.contains('service unavailable');
  }
  
  /// Check if error is not found (404)
  static bool _isNotFoundError(String error) {
    return error.contains('404') ||
           error.contains('not found');
  }
  
  /// Check if error is file-related
  static bool _isFileError(String error) {
    return error.contains('file') ||
           error.contains('image') ||
           error.contains('too large') ||
           error.contains('invalid format') ||
           error.contains('corrupt');
  }
  
  /// Check if error is location/GPS related
  static bool _isLocationError(String error) {
    return error.contains('location') ||
           error.contains('gps') ||
           error.contains('geolocation') ||
           error.contains('position');
  }
  
  /// Check if error is WebSocket related
  static bool _isWebSocketError(String error) {
    return error.contains('websocket') ||
           error.contains('stomp') ||
           error.contains('connection lost');
  }
  
  /// Get specific error for upload operations
  static String getUploadErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('too large') || errorString.contains('size')) {
      return 'File quá lớn. Vui lòng chọn file nhỏ hơn.';
    }
    
    if (errorString.contains('format') || errorString.contains('type')) {
      return 'Định dạng file không được hỗ trợ.';
    }
    
    if (_isNetworkError(errorString)) {
      return 'Không có kết nối mạng. Không thể tải lên.';
    }
    
    if (_isTimeoutError(errorString)) {
      return 'Tải lên quá lâu. Vui lòng thử lại.';
    }
    
    return 'Không thể tải lên. Vui lòng thử lại.';
  }
  
  /// Get specific error for location operations
  static String getLocationErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'Cần quyền truy cập vị trí. Vui lòng cấp quyền trong Cài đặt.';
    }
    
    if (errorString.contains('disabled') || errorString.contains('off')) {
      return 'GPS chưa được bật. Vui lòng bật GPS và thử lại.';
    }
    
    if (_isTimeoutError(errorString)) {
      return 'Không thể lấy vị trí. Vui lòng di chuyển ra ngoài trời và thử lại.';
    }
    
    return 'Không thể lấy vị trí hiện tại. Vui lòng thử lại.';
  }
  
  /// Get specific error for API operations
  static String getApiErrorMessage(dynamic error, {String? context}) {
    final friendlyMessage = mapToUserFriendlyMessage(error);
    
    // Add context if provided
    if (context != null && context.isNotEmpty) {
      return '$context: $friendlyMessage';
    }
    
    return friendlyMessage;
  }
}
