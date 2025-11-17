import 'dart:async';
import 'package:flutter/foundation.dart';

/// Utility to add timeout to async operations and prevent hanging
/// Provides consistent timeout handling across the app
class OperationTimeout {
  /// Default timeout duration
  static const Duration defaultTimeout = Duration(seconds: 30);
  
  /// Execute an async operation with timeout
  /// 
  /// If operation completes within timeout, returns the result
  /// If operation times out, calls onTimeout callback
  /// 
  /// Example:
  /// ```dart
  /// final result = await OperationTimeout.execute(
  ///   operation: () => _apiClient.get('/orders'),
  ///   timeout: Duration(seconds: 15),
  ///   onTimeout: () => throw TimeoutException('Request timed out'),
  /// );
  /// ```
  static Future<T> execute<T>({
    required Future<T> Function() operation,
    Duration? timeout,
    required T Function() onTimeout,
    String? debugLabel,
  }) async {
    final effectiveTimeout = timeout ?? defaultTimeout;
    
    if (debugLabel != null) {
      debugPrint('⏱️ [OperationTimeout] Starting: $debugLabel (timeout: ${effectiveTimeout.inSeconds}s)');
    }
    
    try {
      final result = await operation().timeout(
        effectiveTimeout,
        onTimeout: () {
          debugPrint('⏰ [OperationTimeout] TIMEOUT: ${debugLabel ?? 'unnamed operation'} (${effectiveTimeout.inSeconds}s)');
          return onTimeout();
        },
      );
      
      if (debugLabel != null) {
        debugPrint('✅ [OperationTimeout] Completed: $debugLabel');
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ [OperationTimeout] Error in ${debugLabel ?? 'operation'}: $e');
      rethrow;
    }
  }
  
  /// Execute with default timeout and error fallback
  static Future<T> executeWithFallback<T>({
    required Future<T> Function() operation,
    required T fallbackValue,
    Duration? timeout,
    String? debugLabel,
  }) async {
    return execute(
      operation: operation,
      timeout: timeout,
      onTimeout: () {
        debugPrint('⚠️ [OperationTimeout] Using fallback for: ${debugLabel ?? 'operation'}');
        return fallbackValue;
      },
      debugLabel: debugLabel,
    );
  }
  
  /// Execute and return null on timeout instead of throwing
  static Future<T?> executeOrNull<T>({
    required Future<T> Function() operation,
    Duration? timeout,
    String? debugLabel,
  }) async {
    try {
      return await execute(
        operation: operation,
        timeout: timeout,
        onTimeout: () => throw TimeoutException('Operation timed out'),
        debugLabel: debugLabel,
      );
    } on TimeoutException {
      debugPrint('⚠️ [OperationTimeout] Returning null for: ${debugLabel ?? 'operation'}');
      return null;
    }
  }
  
  /// Execute multiple operations with individual timeouts
  static Future<List<T>> executeMultiple<T>({
    required List<Future<T> Function()> operations,
    Duration? timeout,
    required T Function() onTimeout,
  }) async {
    debugPrint('⏱️ [OperationTimeout] Executing ${operations.length} operations with timeout');
    
    final futures = operations.map((op) => execute(
      operation: op,
      timeout: timeout,
      onTimeout: onTimeout,
    ));
    
    return await Future.wait(futures);
  }
  
  /// Execute with retry on timeout
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    Duration? timeout,
    required T Function() onTimeout,
    int maxRetries = 3,
    Duration? retryDelay,
    String? debugLabel,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      attempts++;
      
      try {
        debugPrint('🔄 [OperationTimeout] Attempt $attempts/$maxRetries: ${debugLabel ?? 'operation'}');
        
        return await execute(
          operation: operation,
          timeout: timeout,
          onTimeout: () => throw TimeoutException('Attempt $attempts timed out'),
          debugLabel: debugLabel,
        );
      } on TimeoutException catch (e) {
        debugPrint('⏰ [OperationTimeout] Attempt $attempts failed: $e');
        
        if (attempts >= maxRetries) {
          debugPrint('❌ [OperationTimeout] All retries exhausted, using fallback');
          return onTimeout();
        }
        
        if (retryDelay != null && attempts < maxRetries) {
          debugPrint('⏳ [OperationTimeout] Waiting ${retryDelay.inSeconds}s before retry...');
          await Future.delayed(retryDelay);
        }
      }
    }
    
    // Should never reach here
    return onTimeout();
  }
  
  /// Execute API call with timeout and user-friendly error
  static Future<T> executeApiCall<T>({
    required Future<T> Function() apiCall,
    required T Function() onTimeout,
    Duration? timeout,
    String? endpoint,
  }) async {
    return execute(
      operation: apiCall,
      timeout: timeout ?? const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⏰ [OperationTimeout] API call timed out: ${endpoint ?? 'unknown'}');
        return onTimeout();
      },
      debugLabel: endpoint != null ? 'API: $endpoint' : 'API call',
    );
  }
}

/// Custom timeout exception
class TimeoutException implements Exception {
  final String message;
  
  const TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}
