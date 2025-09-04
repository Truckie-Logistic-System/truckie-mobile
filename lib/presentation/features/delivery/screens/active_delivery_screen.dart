import 'package:flutter/material.dart';

import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

class ActiveDeliveryScreen extends StatelessWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao hàng hiện tại'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDeliveryProgress(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOrderInfo(),
                    const SizedBox(height: 24),
                    _buildLocationInfo(),
                    const SizedBox(height: 24),
                    _buildCustomerInfo(),
                    const SizedBox(height: 24),
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đang giao hàng',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Thời gian còn lại: 15 phút',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      '2.5 km',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            value: 0.7,
            backgroundColor: Colors.white30,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã lấy hàng',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                'Đang giao',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Đã giao hàng',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
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
                Text('Mã đơn: #DH001', style: AppTextStyles.titleLarge),
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
                Text('Thời gian lấy hàng: 09:15 - 15/09/2025'),
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
                  isCompleted: true,
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
                  isCompleted: false,
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
    required bool isCompleted,
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
              Row(
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  const Spacer(),
                  if (isCompleted)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 16,
                    ),
                ],
              ),
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
                  isPhone: true,
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
    bool isPhone = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
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
        ),
        if (isPhone)
          IconButton(
            onPressed: () {
              // TODO: Gọi điện cho khách hàng
            },
            icon: const Icon(Icons.call, color: AppColors.primary),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/delivery-map', arguments: 'DH001');
          },
          icon: const Icon(Icons.map),
          label: const Text('Xem bản đồ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Cập nhật trạng thái đơn hàng
            _showCompleteDeliveryDialog(context);
          },
          icon: const Icon(Icons.check_circle),
          label: const Text('Hoàn thành giao hàng'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Báo cáo vấn đề
            _showReportIssueDialog(context);
          },
          icon: const Icon(Icons.report_problem),
          label: const Text('Báo cáo vấn đề'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  void _showCompleteDeliveryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hoàn thành'),
        content: const Text('Bạn có chắc chắn muốn hoàn thành giao hàng này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã hoàn thành giao hàng'),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pushReplacementNamed(context, '/');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _showReportIssueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Báo cáo vấn đề'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIssueOption(context, 'Không liên hệ được khách hàng'),
            _buildIssueOption(context, 'Địa chỉ không chính xác'),
            _buildIssueOption(context, 'Khách hàng không nhận hàng'),
            _buildIssueOption(context, 'Vấn đề khác'),
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

  Widget _buildIssueOption(BuildContext context, String issue) {
    return ListTile(
      title: Text(issue),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã báo cáo: $issue'),
            backgroundColor: AppColors.info,
          ),
        );
      },
    );
  }
}
