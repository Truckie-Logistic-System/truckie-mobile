import 'package:flutter/material.dart';

import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truckie Driver'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Hiển thị thông báo
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDriverInfo(),
              const SizedBox(height: 24),
              _buildStatistics(),
              const SizedBox(height: 24),
              _buildCurrentDelivery(context),
              const SizedBox(height: 24),
              _buildRecentOrders(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Đơn hàng',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
        ],
        onTap: (index) {
          // TODO: Xử lý chuyển tab
          if (index == 1) {
            Navigator.pushNamed(context, '/orders');
          }
        },
      ),
    );
  }

  Widget _buildDriverInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: const Icon(
                Icons.person,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nguyễn Văn A', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 4),
                  Text('Tài xế ID: TX001', style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Đang hoạt động',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thống kê', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Đơn hàng hôm nay',
                value: '5',
                icon: Icons.local_shipping,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Hoàn thành',
                value: '3',
                icon: Icons.check_circle,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Đang giao',
                value: '1',
                icon: Icons.directions_car,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Chờ lấy hàng',
                value: '1',
                icon: Icons.access_time,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: AppTextStyles.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.headlineMedium.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentDelivery(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Đơn hàng hiện tại', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mã đơn: #DH001', style: AppTextStyles.titleMedium),
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
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '123 Nguyễn Văn Linh, Quận 7, TP.HCM',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.flag, color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '456 Lê Văn Lương, Quận 7, TP.HCM',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/delivery-map',
                            arguments: 'DH001',
                          );
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('Xem bản đồ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentOrders(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Đơn hàng gần đây', style: AppTextStyles.headlineSmall),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/orders');
              },
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildOrderItem(
          orderId: 'DH002',
          status: 'Chờ lấy hàng',
          statusColor: AppColors.warning,
          address: '789 Nguyễn Hữu Thọ, Quận 7, TP.HCM',
          time: '14:30',
          context: context,
        ),
        const SizedBox(height: 12),
        _buildOrderItem(
          orderId: 'DH003',
          status: 'Hoàn thành',
          statusColor: AppColors.success,
          address: '101 Võ Văn Kiệt, Quận 1, TP.HCM',
          time: '11:15',
          context: context,
        ),
      ],
    );
  }

  Widget _buildOrderItem({
    required String orderId,
    required String status,
    required Color statusColor,
    required String address,
    required String time,
    required BuildContext context,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // TODO: Chuyển đến trang chi tiết đơn hàng
          Navigator.pushNamed(context, '/order-detail', arguments: orderId);
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
