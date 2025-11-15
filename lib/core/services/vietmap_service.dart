import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'http_client_interface.dart';

class VietMapService {
  final IHttpClient _apiClient;
  static const String _cacheKey = 'vietmap_mobile_styles';
  static const Duration _cacheDuration = Duration(days: 7); // Cache 7 ngày
  String? _cachedStyle;
  DateTime? _cacheTimestamp;

  // Cache for reverse geocoding (address from lat/lng)
  final Map<String, String> _addressCache = {};

  VietMapService({required IHttpClient apiClient}) : _apiClient = apiClient;

  // Lấy style map từ API backend
  Future<String> getMobileStyles() async {
    // Kiểm tra cache trong memory
    if (_cachedStyle != null && _cacheTimestamp != null) {
      final now = DateTime.now();
      if (now.difference(_cacheTimestamp!) < _cacheDuration) {
        debugPrint('Sử dụng style map từ cache trong memory');
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
          debugPrint('Sử dụng style map từ cache trong SharedPreferences');
          _cachedStyle = data['style'];
          _cacheTimestamp = timestamp;
          return _cachedStyle!;
        }
      }
    } catch (e) {
      debugPrint('Lỗi khi đọc cache: $e');
    }

    // Nếu không có cache hoặc cache đã hết hạn, gọi API
    try {
      debugPrint('Đang lấy style map từ API backend');
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
          debugPrint('Lỗi khi xử lý style JSON: $e');
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
          debugPrint('Style map đã được lưu vào cache');
        } catch (e) {
          debugPrint('Lỗi khi lưu style map vào cache: $e');
        }

        return styleString;
      } else {
        throw Exception('Không thể tải style map: response là null');
      }
    } catch (e) {
      debugPrint('Lỗi khi lấy style map từ API: $e');

      // Nếu có lỗi và có cache cũ, sử dụng cache cũ
      if (_cachedStyle != null) {
        debugPrint('Sử dụng cache cũ do lỗi API');
        return _cachedStyle!;
      }

      // Nếu không có cache, throw exception
      rethrow;
    }
  }

  // Xóa cache khi cần thiết
  Future<void> clearCache() async {
    _cachedStyle = null;
    _cacheTimestamp = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      debugPrint('Đã xóa cache style map');
    } catch (e) {
      debugPrint('Lỗi khi xóa cache style map: $e');
    }
  }

  // Reverse geocoding: convert lat/lng thành địa chỉ
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    // Create cache key from coordinates (rounded to 5 decimal places for cache key)
    final cacheKey = '${latitude.toStringAsFixed(5)}_${longitude.toStringAsFixed(5)}';
    
    // Check cache first
    if (_addressCache.containsKey(cacheKey)) {
      debugPrint('🗺️ Using cached address for: $latitude, $longitude');
      return _addressCache[cacheKey];
    }

    try {
      debugPrint('🗺️ Reverse geocoding: $latitude, $longitude');
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
        debugPrint('✅ Địa chỉ: $address');
        
        // Cache the address
        _addressCache[cacheKey] = address;
        
        return address;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Lỗi reverse geocoding: $e');
      return null;
    }
  }

  // Get cached address without API call
  String? getCachedAddress(double latitude, double longitude) {
    final cacheKey = '${latitude.toStringAsFixed(5)}_${longitude.toStringAsFixed(5)}';
    return _addressCache[cacheKey];
  }
}
