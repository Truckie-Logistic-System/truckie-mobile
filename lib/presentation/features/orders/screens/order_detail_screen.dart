import 'package:flutter/material.dart';

import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderHeader(),
              const SizedBox(height: 24),
              _buildLocationInfo(),
              const SizedBox(height: 24),
              _buildCustomerInfo(),
              const SizedBox(height: 24),
              _buildItemsList(),
              const SizedBox(height: 24),
              _buildNotes(),
              const SizedBox(height: 32),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mã đơn: #$orderId', style: AppTextStyles.titleLarge),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inProgress.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Đang giao',
                    style: TextStyle(
                      color: AppColors.inProgress,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text('Thời gian tạo: 08:30 - 15/09/2025'),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text('Dự kiến giao: 10:30 - 15/09/2025'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thông tin địa điểm', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildLocationItem(
                  icon: Icons.location_on,
                  iconColor: AppColors.error,
                  title: 'Điểm lấy hàng',
                  address: '123 Nguyễn Văn Linh, Quận 7, TP.HCM',
                  time: '09:00 - 15/09/2025',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(),
                ),
                _buildLocationItem(
                  icon: Icons.flag,
                  iconColor: AppColors.success,
                  title: 'Điểm giao hàng',
                  address: '456 Lê Văn Lương, Quận 7, TP.HCM',
                  time: '10:30 - 15/09/2025',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleSmall),
              const SizedBox(height: 4),
              Text(address, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 4),
              Text(time, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thông tin khách hàng', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.person,
                  label: 'Tên khách hàng',
                  value: 'Nguyễn Thị B',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.phone,
                  label: 'Số điện thoại',
                  value: '0987654321',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodySmall),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Danh sách hàng hóa', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildItemRow('Thùng hàng điện tử', '1'),
                const Divider(),
                _buildItemRow('Laptop', '2'),
                const Divider(),
                _buildItemRow('Điện thoại', '3'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(String name, String quantity) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: AppTextStyles.bodyMedium),
          Text(
            'x$quantity',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ghi chú', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Giao hàng trong giờ hành chính. Gọi trước khi giao 15 phút.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/delivery-map', arguments: orderId);
            },
            icon: const Icon(Icons.map),
            label: const Text('Xem bản đồ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Cập nhật trạng thái đơn hàng
              _showUpdateStatusDialog(context);
            },
            icon: const Icon(Icons.update),
            label: const Text('Cập nhật'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _showUpdateStatusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cập nhật trạng thái'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption(context, 'Đã lấy hàng', AppColors.inProgress),
            _buildStatusOption(context, 'Đang giao hàng', AppColors.inProgress),
            _buildStatusOption(context, 'Đã giao hàng', AppColors.success),
            _buildStatusOption(context, 'Giao hàng thất bại', AppColors.error),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(BuildContext context, String status, Color color) {
    return ListTile(
      title: Text(status),
      leading: Icon(Icons.circle, color: color, size: 16),
      onTap: () {
        // TODO: Cập nhật trạng thái đơn hàng
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật trạng thái: $status'),
            backgroundColor: AppColors.success,
          ),
        );
      },
    );
  }
}
