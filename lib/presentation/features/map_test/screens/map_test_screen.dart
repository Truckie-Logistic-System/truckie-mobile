import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../../core/services/api_service.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/vietmap_service.dart';
import '../../../common_widgets/vietmap/vietmap_provider.dart';
import '../../../common_widgets/vietmap/vietmap_viewmodel.dart';
import '../../../common_widgets/vietmap/vietmap_widget.dart';
import '../../../theme/app_colors.dart';

class MapTestScreen extends StatefulWidget {
  const MapTestScreen({Key? key}) : super(key: key);

  @override
  State<MapTestScreen> createState() => _MapTestScreenState();
}

class _MapTestScreenState extends State<MapTestScreen>
    with AutomaticKeepAliveClientMixin {
  VietmapController? _mapController;
  String? _mapStyle;
  bool _isLoading = true;
  String _errorMessage = '';
  String _apiResponse = '';
  bool _isTestingApi = false;
  late VietMapViewModel _viewModel;
  bool _useCache = true;

  // Style string mặc định - chỉ sử dụng khi API lỗi
  final String _defaultStyleString = jsonEncode({
    "version": 8,
    "sources": {
      "raster_vm": {
        "type": "raster",
        "tiles": [
          "https://maps.vietmap.vn/tm/{z}/{x}/{y}@2x.png?apikey=df5d9a3fffec4d07c7e3710bd0caf8181945d446509a3d42",
        ],
        "tileSize": 256,
        "attribution": "Vietmap@copyright",
      },
    },
    "layers": [
      {
        "id": "layer_raster_vm",
        "type": "raster",
        "source": "raster_vm",
        "minzoom": 0,
        "maxzoom": 20,
      },
    ],
  });

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initViewModel();
  }

  void _initViewModel() {
    // Khởi tạo ViewModel trực tiếp
    final apiService = getIt<ApiService>();
    final vietMapService = VietMapService(apiService: apiService);
    _viewModel = VietMapViewModel(
      vietMapService: vietMapService,
      useCache: _useCache,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm tra bản đồ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.api),
            tooltip: 'Kiểm tra API trực tiếp',
            onPressed: _testMapStyleApi,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại bản đồ',
            onPressed: _reloadMap,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Xóa cache',
            onPressed: _clearCache,
          ),
          IconButton(
            icon: Icon(_useCache ? Icons.cached : Icons.cancel),
            tooltip: _useCache ? 'Đang sử dụng cache' : 'Không sử dụng cache',
            onPressed: _toggleCache,
          ),
        ],
      ),
      body: ChangeNotifierProvider.value(
        value: _viewModel,
        child: _buildMapTestContent(),
      ),
    );
  }

  void _toggleCache() {
    setState(() {
      _useCache = !_useCache;
      _apiResponse = _useCache ? 'Đã bật cache' : 'Đã tắt cache';
    });

    _viewModel.useCache = _useCache;
  }

  void _clearCache() async {
    setState(() {
      _apiResponse = 'Đang xóa cache...';
    });

    await _viewModel.clearCache();

    setState(() {
      _apiResponse = 'Đã xóa cache';
    });
  }

  void _reloadMap() {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _apiResponse = 'Đang tải lại bản đồ...';
    });

    // Reload với tùy chọn forceRefresh
    _viewModel.reloadMapStyle(forceRefresh: !_useCache).then((_) {
      setState(() {
        _apiResponse = 'Đã tải lại bản đồ';
      });
    });
  }

  Future<void> _testMapStyleApi() async {
    setState(() {
      _isTestingApi = true;
      _apiResponse = 'Đang gọi API...';
    });

    try {
      // Lấy service từ provider hoặc service locator
      final apiService = getIt<ApiService>();
      final vietMapService = VietMapService(apiService: apiService);

      // Gọi API trực tiếp
      final styleString = await vietMapService.getMobileStyles();

      setState(() {
        _isTestingApi = false;
        _apiResponse =
            'API trả về thành công: ${styleString.substring(0, min(styleString.length, 100))}...';
      });

      // Hiển thị dialog kết quả
      _showApiResultDialog(true, styleString);
    } catch (e) {
      setState(() {
        _isTestingApi = false;
        _apiResponse = 'Lỗi khi gọi API: $e';
      });

      // Hiển thị dialog lỗi
      _showApiResultDialog(false, e.toString());
    }
  }

  void _showApiResultDialog(bool success, String result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          success ? 'API hoạt động' : 'Lỗi API',
          style: TextStyle(color: success ? Colors.green : Colors.red),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                success
                    ? 'API map style đã trả về kết quả thành công:'
                    : 'Có lỗi khi gọi API map style:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                width: double.infinity,
                child: Text(
                  success
                      ? '${result.substring(0, min(result.length, 300))}...'
                      : result,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTestContent() {
    return Consumer<VietMapViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          children: [
            // Status panel
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _isLoading
                  ? Colors.amber.shade100
                  : (_errorMessage.isNotEmpty
                        ? Colors.red.shade100
                        : Colors.green.shade100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trạng thái: ${_isLoading ? 'Đang tải...' : (_errorMessage.isNotEmpty ? 'Lỗi' : 'Hoạt động')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Lỗi: $_errorMessage',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (!_isLoading && _errorMessage.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Bản đồ đang hoạt động bình thường',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  if (_apiResponse.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'API: $_apiResponse',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: _isTestingApi ? Colors.orange : Colors.blue,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Cache: ${_useCache ? 'Đang sử dụng' : 'Không sử dụng'}',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: _useCache ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map container
            Expanded(
              child: Builder(
                builder: (context) {
                  if (viewModel.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (viewModel.hasError) {
                    // Use post-frame callback to avoid setState during build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                          _errorMessage = viewModel.errorMessage;
                        });
                      }
                    });

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không thể tải bản đồ: ${viewModel.errorMessage}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _reloadMap,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Use post-frame callback to avoid setState during build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _mapStyle = viewModel.mapStyle;
                      });
                    }
                  });

                  return VietMapWidget(
                    onMapCreated: (controller) {
                      if (mounted) {
                        setState(() {
                          _mapController = controller;
                        });
                      }
                    },
                    onMapRenderedCallback: () {
                      // Map is fully rendered
                      debugPrint('Map rendered successfully');
                    },
                    showUserLocation: true,
                  );
                },
              ),
            ),

            // Debug info panel
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin debug:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Map controller: ${_mapController != null ? 'Đã khởi tạo' : 'Chưa khởi tạo'}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Map style: ${_mapStyle != null ? 'Đã tải' : 'Chưa tải'}',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'API endpoint: /vietmap/mobile-styles',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _mapController = null;
    super.dispose();
  }
}
