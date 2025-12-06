import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../data/models/driver_dashboard_model.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị biểu đồ xu hướng chuyến xe
class TripTrendChart extends StatelessWidget {
  final List<TripTrendPoint> trendData;
  final bool isLoading;

  const TripTrendChart({
    super.key,
    required this.trendData,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: AppColors.primary, size: 24.r),
                SizedBox(width: 8.w),
                Text(
                  'Xu hướng chuyến xe',
                  style: AppTextStyles.titleMedium,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (isLoading)
              _buildLoadingState()
            else if (trendData.isEmpty)
              _buildEmptyState()
            else
              _buildChart(),
            SizedBox(height: 16.h),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200.h,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200.h,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 48.r,
            color: Colors.grey[400],
          ),
          SizedBox(height: 8.h),
          Text(
            'Chưa có dữ liệu xu hướng',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return SizedBox(
      height: 200.h,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[200]!,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trendData.length) {
                    return const Text('');
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Text(
                      trendData[index].label,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _calculateInterval(),
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 10.sp,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              left: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          minX: 0,
          maxX: (trendData.length - 1).toDouble(),
          minY: 0,
          maxY: _getMaxY(),
          lineBarsData: _getLineBarsData(),
        ),
      ),
    );
  }

  List<LineChartBarData> _getLineBarsData() {
    if (trendData.isEmpty) return [];

    return [
      // Only completed trips line
      LineChartBarData(
        spots: trendData
            .asMap()
            .entries
            .map((entry) => FlSpot(entry.key.toDouble(), entry.value.tripsCompleted.toDouble()))
            .toList(),
        isCurved: true,
        color: AppColors.success,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 4,
              color: AppColors.success,
              strokeWidth: 2,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          color: AppColors.success.withOpacity(0.1),
        ),
      ),
    ];
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Hoàn thành', AppColors.success),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16.w,
          height: 3.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _getSpots(double Function(TripTrendPoint) getValue) {
    return List.generate(
      trendData.length,
      (index) => FlSpot(index.toDouble(), getValue(trendData[index])),
    );
  }

  double _getMaxY() {
    if (trendData.isEmpty) return 10;
    
    final maxCompleted = trendData.map((e) => e.tripsCompleted).reduce((a, b) => a > b ? a : b);
    
    // Add 20% padding to max value
    return (maxCompleted * 1.2).ceilToDouble();
  }

  double _calculateInterval() {
    final maxY = _getMaxY();
    if (maxY <= 5) return 1;
    if (maxY <= 10) return 2;
    if (maxY <= 20) return 5;
    return (maxY / 5).ceilToDouble();
  }
}
