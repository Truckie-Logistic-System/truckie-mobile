import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class VietMapService {
  final ApiService _apiService;
  static const String _cacheKey = 'vietmap_mobile_styles';
  static const Duration _cacheDuration = Duration(days: 7); // Cache 7 ngày
  String? _cachedStyle;
  DateTime? _cacheTimestamp;

  VietMapService({required ApiService apiService}) : _apiService = apiService;

  Future<String> getMobileStyles() async {
    // Kiểm tra cache trong memory
    if (_cachedStyle != null && _cacheTimestamp != null) {
      final now = DateTime.now();
      if (now.difference(_cacheTimestamp!) < _cacheDuration) {
        debugPrint('Using in-memory cached map style');
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
          debugPrint('Using SharedPreferences cached map style');
          _cachedStyle = data['style'];
          _cacheTimestamp = timestamp;
          return _cachedStyle!;
        }
      }
    } catch (e) {
      debugPrint('Error reading cache: $e');
    }

    // Nếu không có cache hoặc cache đã hết hạn, gọi API
    try {
      debugPrint('Fetching map style from API');
      final response = await _apiService.get('/vietmap/mobile-styles');

      // API trả về style trực tiếp, không cần kiểm tra statusCode
      if (response != null) {
        String styleString;

        // Kiểm tra xem response có phải là Map với data không
        if (response is Map && response.containsKey('data')) {
          styleString = json.encode(response['data']);
        } else {
          // Nếu response đã là style trực tiếp
          styleString = json.encode(response);
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
          debugPrint('Map style cached successfully');
        } catch (e) {
          debugPrint('Error caching map style: $e');
        }

        return styleString;
      } else {
        throw Exception('Failed to load map style: response is null');
      }
    } catch (e) {
      debugPrint('Error fetching map style: $e');

      // Nếu có lỗi và có cache cũ, sử dụng cache cũ
      if (_cachedStyle != null) {
        debugPrint('Using outdated cached map style due to API error');
        return _cachedStyle!;
      }

      // Nếu không có cache, throw exception
      rethrow;
    }
  }

  // Xóa cache khi cần thiết
  Future<void> clearCache() async {
    try {
      _cachedStyle = null;
      _cacheTimestamp = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      debugPrint('VietMap style cache cleared');
    } catch (e) {
      debugPrint('Error clearing VietMap style cache: $e');
    }
  }
}
