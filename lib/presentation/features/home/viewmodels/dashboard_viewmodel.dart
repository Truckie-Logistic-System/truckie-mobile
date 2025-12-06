import 'package:flutter/foundation.dart';
import '../../../../data/datasources/dashboard_data_source.dart';
import '../../../../data/models/driver_dashboard_model.dart';

/// Trạng thái của Dashboard
enum DashboardStatus {
  initial,
  loading,
  loaded,
  error,
}

/// Trạng thái của AI Summary
enum AiSummaryStatus {
  initial,
  loading,
  loaded,
  error,
}

/// ViewModel cho Driver Dashboard
class DashboardViewModel extends ChangeNotifier {
  final DashboardDataSource _dashboardDataSource;

  DashboardViewModel({required DashboardDataSource dashboardDataSource})
      : _dashboardDataSource = dashboardDataSource;

  // State
  DashboardStatus _status = DashboardStatus.initial;
  DriverDashboardModel? _dashboard;
  String? _errorMessage;
  String _currentRange = 'WEEK';
  
  // AI Summary State
  AiSummaryStatus _aiSummaryStatus = AiSummaryStatus.initial;
  String? _aiSummary;
  String? _aiSummaryError;
  int _aiSummaryRetryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Getters
  DashboardStatus get status => _status;
  DriverDashboardModel? get dashboard => _dashboard;
  String? get errorMessage => _errorMessage;
  String get currentRange => _currentRange;
  bool get isLoading => _status == DashboardStatus.loading;
  bool get hasError => _status == DashboardStatus.error;
  bool get hasData => _dashboard != null;
  
  // AI Summary Getters
  AiSummaryStatus get aiSummaryStatus => _aiSummaryStatus;
  String? get aiSummary => _aiSummary;
  String? get aiSummaryError => _aiSummaryError;
  bool get isAiSummaryLoading => _aiSummaryStatus == AiSummaryStatus.loading;
  bool get hasAiSummaryError => _aiSummaryStatus == AiSummaryStatus.error;
  bool get hasAiSummary => _aiSummary != null && _aiSummary!.isNotEmpty;

  // Convenience getters
  // Simplified dashboard properties (5 key metrics)
  int get completedTripsCount => _dashboard?.completedTripsCount ?? 0;
  int get incidentsCount => _dashboard?.incidentsCount ?? 0;
  int get trafficViolationsCount => _dashboard?.trafficViolationsCount ?? 0;
  List<TripTrendPoint> get tripTrend => _dashboard?.tripTrend ?? [];
  List<RecentOrder> get recentOrders => _dashboard?.recentOrders ?? [];

  /// Tải dữ liệu dashboard
  Future<void> loadDashboard({String range = 'WEEK'}) async {
    if (_status == DashboardStatus.loading) return;

    _status = DashboardStatus.loading;
    _errorMessage = null;
    _currentRange = range;
    notifyListeners();

    try {
      _dashboard = await _dashboardDataSource.getDriverDashboard(range: range);
      _status = DashboardStatus.loaded;
      
      // Load AI summary in parallel after main dashboard loads
      _loadAiSummary(range: range, isRetry: false);
    } catch (e) {
      _status = DashboardStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    notifyListeners();
  }

  /// Tải AI summary với retry logic
  Future<void> _loadAiSummary({required String range, bool isRetry = true}) async {
    if (_aiSummaryStatus == AiSummaryStatus.loading) return;

    _aiSummaryStatus = AiSummaryStatus.loading;
    _aiSummaryError = null;
    notifyListeners();

    try {
      // Thêm timeout cho AI summary call để tránh loading vô hạn
      _aiSummary = await _dashboardDataSource.getDriverAiSummary(range: range)
          .timeout(const Duration(seconds: 15));
      _aiSummaryStatus = AiSummaryStatus.loaded;
      _aiSummaryRetryCount = 0;
    } catch (e) {
      if (isRetry && _aiSummaryRetryCount < _maxRetries) {
        _aiSummaryRetryCount++;
        _aiSummaryStatus = AiSummaryStatus.initial;
        
        // Exponential backoff cho retry
        final delay = Duration(seconds: _retryDelay.inSeconds * _aiSummaryRetryCount);
        await Future.delayed(delay);
        
        // Retry tự động
        _loadAiSummary(range: range, isRetry: true);
        return;
      } else {
        _aiSummaryStatus = AiSummaryStatus.error;
        _aiSummaryError = e.toString().replaceAll('Exception: ', '');
        _aiSummaryRetryCount = 0;
      }
    }

    notifyListeners();
  }

  /// Retry AI summary manually
  Future<void> retryAiSummary() async {
    if (_currentRange.isNotEmpty) {
      await _loadAiSummary(range: _currentRange, isRetry: false);
    }
  }

  /// Làm mới dữ liệu
  Future<void> refresh() async {
    await loadDashboard(range: _currentRange);
  }

  /// Làm mới chỉ AI summary
  Future<void> refreshAiSummary() async {
    await retryAiSummary();
  }

  /// Đổi khoảng thời gian
  Future<void> changeTimeRange(String range) async {
    if (range != _currentRange) {
      await loadDashboard(range: range);
    }
  }

  /// Reset state
  void reset() {
    _status = DashboardStatus.initial;
    _dashboard = null;
    _errorMessage = null;
    _currentRange = 'WEEK';
    
    // Reset AI summary state
    _aiSummaryStatus = AiSummaryStatus.initial;
    _aiSummary = null;
    _aiSummaryError = null;
    _aiSummaryRetryCount = 0;
    
    notifyListeners();
  }
}
