import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'http_client_interface.dart';

class VietMapService {
  final IHttpClient _apiClient;
  static const String _cacheKey = 'vietmap_mobile_styles';
  static const String _cacheKeyStyleUrl = 'vietmap_style_url';
  static const Duration _cacheDuration = Duration(days: 7); // Cache 7 ngày
  String? _cachedStyle;
  String? _cachedStyleUrl;
  DateTime? _cacheTimestamp;
  DateTime? _styleUrlCacheTimestamp;

  // Cache for reverse geocoding (address from lat/lng)
  final Map<String, String> _addressCache = {};

  VietMapService({required IHttpClient apiClient}) : _apiClient = apiClient;

  // Lấy style map từ API backend
  Future<String> getMobileStyles() async {
    // Kiểm tra cache trong memory
    if (_cachedStyle != null && _cacheTimestamp != null) {
      final now = DateTime.now();
      if (now.difference(_cacheTimestamp!) < _cacheDuration) {
        return _cachedStyle!;
      }
    }

    // Kiểm tra cache trong SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);

      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        final timestamp = DateTime.parse(data['timestamp']);
        final now = DateTime.now();

        if (now.difference(timestamp) < _cacheDuration) {
          _cachedStyle = data['style'];
          _cacheTimestamp = timestamp;
          return _cachedStyle!;
        }
      }
    } catch (e) {
    }

    // Nếu không có cache hoặc cache đã hết hạn, gọi API
    try {
      final response = await _apiClient.dio.get('/vietmap/mobile-styles');

      if (response.data != null) {
        String styleString;

        // Kiểm tra xem response có phải là Map với data không
        if (response.data is Map && response.data.containsKey('data')) {
          styleString = json.encode(response.data['data']);
        } else {
          // Nếu response đã là style trực tiếp
          styleString = json.encode(response.data);
        }

        // Xử lý style JSON để đảm bảo các thuộc tính text-font là mảng
        try {
          final styleJson = json.decode(styleString);

          // Thêm background layer để tránh mảng đen
          if (styleJson['layers'] != null && styleJson['layers'] is List) {
            final layers = styleJson['layers'] as List;

            // Kiểm tra nếu đã có background layer
            bool hasBackgroundLayer = false;
            for (var layer in layers) {
              if (layer['id'] == 'background') {
                hasBackgroundLayer = true;
                break;
              }
            }

            // Thêm background layer nếu chưa có
            if (!hasBackgroundLayer) {
              layers.insert(0, {
                'id': 'background',
                'type': 'background',
                'paint': {'background-color': '#ffffff'},
              });
            }
          }

          // Cập nhật styleString với các thay đổi
          styleString = json.encode(styleJson);
        } catch (e) {
        }

        // Lưu vào cache memory
        _cachedStyle = styleString;
        _cacheTimestamp = DateTime.now();

        // Lưu vào SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          final cacheData = {
            'style': styleString,
            'timestamp': _cacheTimestamp!.toIso8601String(),
          };
          await prefs.setString(_cacheKey, json.encode(cacheData));
        } catch (e) {
        }

        return styleString;
      } else {
        throw Exception('Không thể tải style map: response là null');
      }
    } catch (e) {
      // Nếu có lỗi và có cache cũ, sử dụng cache cũ
      if (_cachedStyle != null) {
        return _cachedStyle!;
      }

      // Nếu không có cache, throw exception
      rethrow;
    }
  }

  /// OPTIMIZED: Get VietMap style URL for SDK
  /// Returns direct URL to VietMap Vector style (SDK handles caching & optimization)
  /// This is the RECOMMENDED approach per VietMap SDK documentation
  Future<String> getMobileStyleUrl() async {
    // Check memory cache
    if (_cachedStyleUrl != null && _styleUrlCacheTimestamp != null) {
      final now = DateTime.now();
      if (now.difference(_styleUrlCacheTimestamp!) < _cacheDuration) {
        return _cachedStyleUrl!;
      }
    }

    // Check SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKeyStyleUrl);

      if (cachedData != null) {
        final Map<String, dynamic> data = json.decode(cachedData);
        final timestamp = DateTime.parse(data['timestamp']);
        final now = DateTime.now();

        if (now.difference(timestamp) < _cacheDuration) {
          _cachedStyleUrl = data['styleUrl'];
          _styleUrlCacheTimestamp = timestamp;
          return _cachedStyleUrl!;
        }
      }
    } catch (e) {
    }

    // Fetch from backend
    try {
      final response = await _apiClient.dio.get('/vietmap/mobile-style-url');

      if (response.data != null && response.data['styleUrl'] != null) {
        final styleUrl = response.data['styleUrl'] as String;
        

        // Save to memory cache
        _cachedStyleUrl = styleUrl;
        _styleUrlCacheTimestamp = DateTime.now();

        // Save to SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          final cacheData = {
            'styleUrl': styleUrl,
            'timestamp': _styleUrlCacheTimestamp!.toIso8601String(),
          };
          await prefs.setString(_cacheKeyStyleUrl, json.encode(cacheData));
        } catch (e) {
        }

        return styleUrl;
      } else {
        throw Exception('Không thể tải style URL: response không hợp lệ');
      }
    } catch (e) {
      // Fallback to old cache if available
      if (_cachedStyleUrl != null) {
        return _cachedStyleUrl!;
      }

      rethrow;
    }
  }

  // Xóa cache khi cần thiết
  Future<void> clearCache() async {
    _cachedStyle = null;
    _cachedStyleUrl = null;
    _cacheTimestamp = null;
    _styleUrlCacheTimestamp = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheKeyStyleUrl);
    } catch (e) {
    }
  }

  // Reverse geocoding: convert lat/lng thành địa chỉ
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    // Create cache key from coordinates (rounded to 5 decimal places for cache key)
    final cacheKey = '${latitude.toStringAsFixed(5)}_${longitude.toStringAsFixed(5)}';
    
    // Check cache first
    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey];
    }

    try {
      final response = await _apiClient.dio.get(
        '/vietmap/reverse',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
        },
      );

      // Response is an array, get first item's display field
      if (response.data != null && response.data is List && (response.data as List).isNotEmpty) {
        final firstResult = (response.data as List)[0];
        final address = firstResult['display'];
        // Cache the address
        _addressCache[cacheKey] = address;
        
        return address;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get cached address without API call
  String? getCachedAddress(double latitude, double longitude) {
    final cacheKey = '${latitude.toStringAsFixed(5)}_${longitude.toStringAsFixed(5)}';
    return _addressCache[cacheKey];
  }
}
