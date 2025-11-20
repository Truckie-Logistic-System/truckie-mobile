import 'package:flutter/foundation.dart';

/// Utility to prevent duplicate requests from being sent simultaneously
/// Useful for preventing multiple API calls when user taps a button rapidly
class RequestDeduplicator {
  static final Map<String, DateTime> _lastRequests = {};
  static const Duration _minInterval = Duration(milliseconds: 500);
  
  /// Check if a request with the given key can be made
  /// Returns true if enough time has passed since last request with this key
  /// Returns false if request should be blocked (too soon after last request)
  static bool canMakeRequest(String key) {
    final lastTime = _lastRequests[key];
    
    if (lastTime == null) {
      // First request with this key
      _lastRequests[key] = DateTime.now();
      return true;
    }
    
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(lastTime);
    
    if (timeSinceLastRequest >= _minInterval) {
      // Enough time has passed, allow request
      _lastRequests[key] = now;
      return true;
    }
    
    // Too soon, block request
    
    return false;
  }
  
  /// Clear a specific request key
  /// Call this after a request completes (success or failure)
  /// to allow immediate retry if needed
  static void clearRequest(String key) {
    _lastRequests.remove(key);
  }
  
  /// Clear all tracked requests
  /// Useful for cleanup or reset scenarios
  static void clearAll() {
    _lastRequests.clear();
  }
  
  /// Get time until next request is allowed for a given key
  /// Returns null if request can be made immediately
  static Duration? getTimeUntilNextRequest(String key) {
    final lastTime = _lastRequests[key];
    if (lastTime == null) return null;
    
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(lastTime);
    
    if (timeSinceLastRequest >= _minInterval) {
      return null; // Can make request immediately
    }
    
    return _minInterval - timeSinceLastRequest;
  }
  
  /// Execute a function only if enough time has passed since last execution
  /// Automatically handles timing and cleanup
  /// 
  /// Example:
  /// ```dart
  /// await RequestDeduplicator.execute(
  ///   key: 'uploadPhoto',
  ///   action: () async {
  ///     await _repository.uploadPhoto(file);
  ///   },
  ///   onBlocked: () {
  ///     
  ///   },
  /// );
  /// ```
  static Future<T?> execute<T>({
    required String key,
    required Future<T> Function() action,
    VoidCallback? onBlocked,
  }) async {
    if (!canMakeRequest(key)) {
      onBlocked?.call();
      return null;
    }
    
    try {
      final result = await action();
      return result;
    } finally {
      // Clear request after completion to allow immediate retry if needed
      clearRequest(key);
    }
  }
  
  /// Execute a synchronous function with deduplication
  static T? executeSync<T>({
    required String key,
    required T Function() action,
    VoidCallback? onBlocked,
  }) {
    if (!canMakeRequest(key)) {
      onBlocked?.call();
      return null;
    }
    
    try {
      return action();
    } finally {
      clearRequest(key);
    }
  }
  
  /// Clean up old entries to prevent memory growth
  /// Call this periodically or when app goes to background
  static void cleanup({Duration maxAge = const Duration(minutes: 5)}) {
    final now = DateTime.now();
    _lastRequests.removeWhere((key, timestamp) {
      final age = now.difference(timestamp);
      final shouldRemove = age > maxAge;
      if (shouldRemove) {
        
      }
      return shouldRemove;
    });
  }
}
