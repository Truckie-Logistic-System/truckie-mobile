import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service để quản lý queue locations khi offline
class LocationQueueService {
  static const String _boxName = 'location_queue';
  static const int _maxQueueSize = 50; // Giữ tối đa 50 locations

  Box<Map>? _box;
  bool _isInitialized = false;

  int get queueSize => _box?.length ?? 0;
  bool get isInitialized => _isInitialized;

  /// Initialize Hive box
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive if not already done
      if (!Hive.isAdapterRegistered(0)) {
        await Hive.initFlutter();
      }

      // Open box
      _box = await Hive.openBox<Map>(_boxName);
      _isInitialized = true;

      

      // Clean old items if queue is too large
      await _cleanOldItems();
    } catch (e) {
      
      rethrow;
    }
  }

  /// Queue a location for later sending
  Future<void> queueLocation({
    required String vehicleId,
    required double latitude,
    required double longitude,
    required double bearing,
    required double accuracy,
    required DateTime timestamp,
  }) async {
    if (!_isInitialized || _box == null) {
      
      return;
    }

    try {
      final locationData = {
        'id': _generateId(),
        'vehicleId': vehicleId,
        'latitude': latitude,
        'longitude': longitude,
        'bearing': bearing,
        'accuracy': accuracy,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'queuedAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Add to queue
      await _box!.add(locationData);

      

      // Clean old items if queue is getting too large
      if (queueSize > _maxQueueSize) {
        await _cleanOldItems();
      }
    } catch (e) {
      
    }
  }

  /// Get all queued locations (oldest first)
  Future<List<Map<String, dynamic>>> getQueuedLocations() async {
    if (!_isInitialized || _box == null) {
      return [];
    }

    try {
      final locations = <Map<String, dynamic>>[];

      for (int i = 0; i < _box!.length; i++) {
        final item = _box!.getAt(i);
        if (item != null) {
          locations.add(Map<String, dynamic>.from(item));
        }
      }

      // Sort by timestamp (oldest first)
      locations.sort((a, b) {
        final timestampA = a['timestamp'] as int? ?? 0;
        final timestampB = b['timestamp'] as int? ?? 0;
        return timestampA.compareTo(timestampB);
      });

      
      return locations;
    } catch (e) {
      
      return [];
    }
  }

  /// Remove a specific location from queue by ID
  Future<void> removeLocation(String id) async {
    if (!_isInitialized || _box == null) {
      return;
    }

    try {
      // Find and remove the item with matching ID
      for (int i = 0; i < _box!.length; i++) {
        final item = _box!.getAt(i);
        if (item != null && item['id'] == id) {
          await _box!.deleteAt(i);
          
          break;
        }
      }
    } catch (e) {
      
    }
  }

  /// Clear all queued locations
  Future<void> clearQueue() async {
    if (!_isInitialized || _box == null) {
      return;
    }

    try {
      await _box!.clear();
      
    } catch (e) {
      
    }
  }

  /// Get queue statistics
  Map<String, dynamic> getQueueStats() {
    if (!_isInitialized || _box == null) {
      return {
        'size': 0,
        'oldestTimestamp': null,
        'newestTimestamp': null,
        'isInitialized': false,
      };
    }

    try {
      final locations = <Map<String, dynamic>>[];

      for (int i = 0; i < _box!.length; i++) {
        final item = _box!.getAt(i);
        if (item != null) {
          locations.add(Map<String, dynamic>.from(item));
        }
      }

      if (locations.isEmpty) {
        return {
          'size': 0,
          'oldestTimestamp': null,
          'newestTimestamp': null,
          'isInitialized': true,
        };
      }

      // Sort by timestamp
      locations.sort((a, b) {
        final timestampA = a['timestamp'] as int? ?? 0;
        final timestampB = b['timestamp'] as int? ?? 0;
        return timestampA.compareTo(timestampB);
      });

      return {
        'size': locations.length,
        'oldestTimestamp': DateTime.fromMillisecondsSinceEpoch(
          locations.first['timestamp'],
        ),
        'newestTimestamp': DateTime.fromMillisecondsSinceEpoch(
          locations.last['timestamp'],
        ),
        'isInitialized': true,
      };
    } catch (e) {
      
      return {
        'size': 0,
        'oldestTimestamp': null,
        'newestTimestamp': null,
        'isInitialized': true,
        'error': e.toString(),
      };
    }
  }

  /// Clean old items to keep queue size manageable
  Future<void> _cleanOldItems() async {
    if (!_isInitialized || _box == null) {
      return;
    }

    try {
      while (_box!.length > _maxQueueSize) {
        // Remove oldest item (index 0)
        await _box!.deleteAt(0);
      }

      // Also remove items older than 24 hours
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      final itemsToRemove = <int>[];

      for (int i = 0; i < _box!.length; i++) {
        final item = _box!.getAt(i);
        if (item != null) {
          final queuedAt = DateTime.fromMillisecondsSinceEpoch(
            item['queuedAt'] ?? 0,
          );
          if (queuedAt.isBefore(cutoffTime)) {
            itemsToRemove.add(i);
          }
        }
      }

      // Remove old items (in reverse order to maintain indices)
      for (int i = itemsToRemove.length - 1; i >= 0; i--) {
        await _box!.deleteAt(itemsToRemove[i]);
      }

      if (itemsToRemove.isNotEmpty) {
        
      }
    } catch (e) {
      
    }
  }

  /// Generate unique ID for location
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Get locations within a time range
  Future<List<Map<String, dynamic>>> getLocationsByTimeRange({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (!_isInitialized || _box == null) {
      return [];
    }

    try {
      final locations = <Map<String, dynamic>>[];

      for (int i = 0; i < _box!.length; i++) {
        final item = _box!.getAt(i);
        if (item != null) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            item['timestamp'] ?? 0,
          );
          if (timestamp.isAfter(startTime) && timestamp.isBefore(endTime)) {
            locations.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // Sort by timestamp
      locations.sort((a, b) {
        final timestampA = a['timestamp'] as int? ?? 0;
        final timestampB = b['timestamp'] as int? ?? 0;
        return timestampA.compareTo(timestampB);
      });

      return locations;
    } catch (e) {
      
      return [];
    }
  }

  /// Export queue data as JSON (for debugging)
  Future<String> exportQueueAsJson() async {
    if (!_isInitialized || _box == null) {
      return '[]';
    }

    try {
      final locations = await getQueuedLocations();
      return jsonEncode(locations);
    } catch (e) {
      
      return '[]';
    }
  }

  /// Dispose resources
  void dispose() {
    // Note: We don't close the Hive box here as it might be used elsewhere
    // The box will be closed when the app terminates
    _isInitialized = false;
    
  }
}
