import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';

import '../../../core/models/vietmap_config.dart';
import '../../../core/services/vietmap_service.dart';

class VietMapViewModel extends ChangeNotifier {
  final VietMapService _vietMapService;

  VietmapController? _mapController;
  VietMapConfig? _mapConfig;
  String? _mapStyle;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isDisposed = false;
  bool _useCache = true; // Mặc định sử dụng cache

  // Getters
  VietmapController? get mapController => _mapController;
  VietMapConfig? get mapConfig => _mapConfig;
  String? get mapStyle => _mapStyle;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get useCache => _useCache;

  // Setter cho useCache
  set useCache(bool value) {
    _useCache = value;
    if (!_useCache) {
      clearCache();
    }
  }

  VietMapViewModel({
    required VietMapService vietMapService,
    bool useCache = true,
  }) : _vietMapService = vietMapService,
       _useCache = useCache {
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    if (_isDisposed) return;

    try {
      _isLoading = true;
      _hasError = false;
      notifyListeners();

      // Fetch map style URL from API (OPTIMIZED approach)
      // SDK handles caching, progressive loading, and tile optimization
      final styleUrl = await _vietMapService.getMobileStyleUrl();

      if (_isDisposed) return;

      _mapStyle = styleUrl;

      // Create default config with style URL
      _mapConfig = VietMapConfig.defaultConfig(styleUrl);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (_isDisposed) return;

      _isLoading = false;
      _hasError = true;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void setMapController(VietmapController controller) {
    if (_isDisposed) return;

    _mapController = controller;
    notifyListeners();
  }

  void updateCameraPosition(CameraPosition position) {
    // Implement if needed
  }

  // Phương thức để reload map style
  Future<void> reloadMapStyle({bool forceRefresh = false}) async {
    if (_isDisposed) return;

    if (forceRefresh) {
      await clearCache();
    }

    await _initializeMap();
  }

  // Phương thức để thử lại khi khởi tạo lỗi
  Future<void> retryInitialization() async {
    if (_isDisposed) return;

    await _initializeMap();
  }

  // Phương thức để xóa cache
  Future<void> clearCache() async {
    if (_isDisposed) return;

    await _vietMapService.clearCache();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mapController = null;
    super.dispose();
  }
}
