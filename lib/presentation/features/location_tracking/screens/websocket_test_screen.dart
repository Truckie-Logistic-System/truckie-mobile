import 'package:flutter/material.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/vehicle_websocket_service.dart';
import '../../../../core/services/mock_vehicle_websocket_service.dart';

class WebSocketTestScreen extends StatefulWidget {
  const WebSocketTestScreen({Key? key}) : super(key: key);

  @override
  State<WebSocketTestScreen> createState() => _WebSocketTestScreenState();
}

class _WebSocketTestScreenState extends State<WebSocketTestScreen> {
  final VehicleWebSocketService _webSocketService =
      getIt<VehicleWebSocketService>();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _vehicleIdController = TextEditingController();

  bool _isConnected = false;
  String _status = 'Chưa kết nối';
  String _lastMessage = 'Chưa có dữ liệu';
  String _serviceType = 'Unknown';
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _tokenController.text = 'test_token';
    _vehicleIdController.text = 'test_vehicle_1';

    // Determine service type
    if (_webSocketService is MockVehicleWebSocketService) {
      _serviceType = 'Mock Service';

      final mockService = _webSocketService as MockVehicleWebSocketService;
      mockService.locationUpdates.listen((data) {
        setState(() {
          _lastMessage =
              'Vị trí: ${data['latitude']?.toStringAsFixed(6)}, ${data['longitude']?.toStringAsFixed(6)}';
        });
      });
    } else {
      _serviceType = 'Real Service';
    }

    setState(() {
      _debugInfo =
          'Service type: $_serviceType\n'
          'Base URL: ${_webSocketService.baseUrl}';
    });
  }

  Future<void> _connect() async {
    setState(() {
      _status = 'Đang kết nối...';
    });

    try {
      await _webSocketService.connect(
        jwtToken: _tokenController.text,
        vehicleId: _vehicleIdController.text,
        onConnected: () {
          setState(() {
            _isConnected = true;
            _status = 'Đã kết nối';
            _debugInfo += '\nConnected successfully';
          });
        },
        onError: (error) {
          setState(() {
            _isConnected = false;
            _status = 'Lỗi: $error';
            _debugInfo += '\nError: $error';
          });
        },
        onLocationBroadcast: (data) {
          setState(() {
            _lastMessage =
                'Vị trí: ${data['latitude']?.toStringAsFixed(6)}, ${data['longitude']?.toStringAsFixed(6)}';
            _debugInfo += '\nReceived location update';
          });
        },
      );
    } catch (e) {
      setState(() {
        _status = 'Lỗi kết nối: $e';
        _debugInfo += '\nException: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _webSocketService.disconnect();
      setState(() {
        _isConnected = false;
        _status = 'Đã ngắt kết nối';
        _debugInfo += '\nDisconnected';
      });
    } catch (e) {
      setState(() {
        _status = 'Lỗi ngắt kết nối: $e';
        _debugInfo += '\nDisconnect error: $e';
      });
    }
  }

  void _sendLocation() {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng kết nối trước khi gửi vị trí')),
      );
      return;
    }

    try {
      // Send random location near Ho Chi Minh City
      final lat = 10.762622 + (DateTime.now().millisecond / 10000);
      final lng = 106.660172 + (DateTime.now().second / 100);

      _webSocketService.sendLocationUpdateRateLimited(
        vehicleId: _vehicleIdController.text,
        latitude: lat,
        longitude: lng,
        licensePlateNumber: 'TEST-123',
      );

      setState(() {
        _lastMessage =
            'Đã gửi vị trí: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
        _debugInfo += '\nSent location update';
      });
    } catch (e) {
      setState(() {
        _status = 'Lỗi gửi vị trí: $e';
        _debugInfo += '\nSend error: $e';
      });
    }
  }

  void _clearDebugInfo() {
    setState(() {
      _debugInfo =
          'Service type: $_serviceType\n'
          'Base URL: ${_webSocketService.baseUrl}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm tra WebSocket'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'JWT Token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vehicleIdController,
              decoration: const InputDecoration(
                labelText: 'ID Xe',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Trạng thái: $_status',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Dữ liệu: $_lastMessage',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _disconnect : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(_isConnected ? 'Ngắt kết nối' : 'Kết nối'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _sendLocation : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Gửi vị trí'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Debug Information:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              height: 200,
              child: SingleChildScrollView(child: Text(_debugInfo)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearDebugInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa thông tin debug'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _vehicleIdController.dispose();
    super.dispose();
  }
}
