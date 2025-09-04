import 'package:flutter/material.dart';

import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách đơn hàng'),
        centerTitle: true,
        automaticallyImplyLeading: false, // Loại bỏ nút back
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterSection(),
              const SizedBox(height: 16),
              Expanded(child: _buildOrdersList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lọc theo trạng thái', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Tất cả', true),
              const SizedBox(width: 8),
              _buildFilterChip('Chờ lấy hàng', false),
              const SizedBox(width: 8),
              _buildFilterChip('Đang giao', false),
              const SizedBox(width: 8),
              _buildFilterChip('Hoàn thành', false),
              const SizedBox(width: 8),
              _buildFilterChip('Đã hủy', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      onSelected: (bool selected) {
        // TODO: Xử lý lọc theo trạng thái
      },
    );
  }

  Widget _buildOrdersList() {
    return ListView.separated(
      itemCount: 10,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildOrderItem(
          orderId: 'DH00${index + 1}',
          status: _getRandomStatus(index),
          address: '${index + 100} Nguyễn Văn Linh, Quận 7, TP.HCM',
          time: '${(index + 8) % 12 + 1}:${index * 10 % 60}',
        );
      },
    );
  }

  String _getRandomStatus(int index) {
    final statuses = ['Chờ lấy hàng', 'Đang giao', 'Hoàn thành', 'Đã hủy'];
    return statuses[index % statuses.length];
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Chờ lấy hàng':
        return AppColors.warning;
      case 'Đang giao':
        return AppColors.inProgress;
      case 'Hoàn thành':
        return AppColors.success;
      case 'Đã hủy':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildOrderItem({
    required String orderId,
    required String status,
    required String address,
    required String time,
  }) {
    final statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // TODO: Chuyển đến trang chi tiết đơn hàng
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mã đơn: #$orderId', style: AppTextStyles.titleMedium),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(address, style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(time, style: AppTextStyles.bodyMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
