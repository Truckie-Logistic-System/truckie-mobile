import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service quản lý token cho mobile app
/// - Access token: Lưu trong memory (RAM) để truy cập nhanh
/// - Refresh token: Lưu trong Secure Storage (Keychain/Keystore) để bảo mật
class TokenStorageService {
  final FlutterSecureStorage _secureStorage;

  // Access token lưu trong memory
  String? _accessToken;

  // Keys cho secure storage
  static const String _refreshTokenKey = 'refresh_token';

  TokenStorageService({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  /// Lấy access token từ memory
  String? getAccessToken() {
    if (_accessToken == null) {
      debugPrint('❌ [TokenStorageService] Getting access token: NULL!');
      return null;
    }

    // Đảm bảo token không chứa dấu # hoặc khoảng trắng
    final cleanToken = _accessToken!.replaceAll('#', '').trim();

    // Log token đã được làm sạch
    if (_accessToken != cleanToken) {
      debugPrint('⚠️ [TokenStorageService] Token cleaned: removed invalid characters');
    }

    debugPrint(
      '✅ [TokenStorageService] Getting access token: ${cleanToken.substring(0, min(15, cleanToken.length))}...',
    );
    return cleanToken;
  }

  /// Helper method to get minimum of two integers
  int min(int a, int b) {
    return a < b ? a : b;
  }

  /// Lưu access token vào memory
  Future<void> saveAccessToken(String token) async {
    _accessToken = token;
    debugPrint('✅ [TokenStorageService] Access token saved to memory: ${token.substring(0, 15)}...');
  }

  /// Xóa access token khỏi memory
  Future<void> clearAccessToken() async {
    _accessToken = null;
    // debugPrint('Access token cleared from memory');
  }

  /// Lấy refresh token từ secure storage
  Future<String?> getRefreshToken() async {
    try {
      final token = await _secureStorage.read(key: _refreshTokenKey);
      return token;
    } catch (e) {
      // debugPrint('Error reading refresh token: $e');
      return null;
    }
  }

  /// Lưu refresh token vào secure storage
  Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: _refreshTokenKey, value: token);
      // debugPrint('Refresh token saved to secure storage');
    } catch (e) {
      // debugPrint('Error saving refresh token: $e');
      rethrow;
    }
  }

  /// Xóa refresh token khỏi secure storage
  Future<void> clearRefreshToken() async {
    try {
      await _secureStorage.delete(key: _refreshTokenKey);
      // debugPrint('Refresh token cleared from secure storage');
    } catch (e) {
      // debugPrint('Error clearing refresh token: $e');
    }
  }

  /// Xóa tất cả tokens
  Future<void> clearAllTokens() async {
    await clearAccessToken();
    await clearRefreshToken();
    // debugPrint('All tokens cleared');
  }

  /// Kiểm tra xem có access token không
  bool hasAccessToken() {
    return _accessToken != null && _accessToken!.isNotEmpty;
  }

  /// Kiểm tra xem có refresh token không
  Future<bool> hasRefreshToken() async {
    final token = await getRefreshToken();
    return token != null && token.isNotEmpty;
  }
}
