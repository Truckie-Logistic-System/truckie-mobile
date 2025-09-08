import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../presentation/common_widgets/skeleton_loader.dart';
import '../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => getIt<AuthViewModel>(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Truckie Driver'),
          centerTitle: true,
          automaticallyImplyLeading: false, // Loại bỏ nút back
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // TODO: Hiển thị thông báo
              },
            ),
          ],
        ),
        body: Consumer<AuthViewModel>(
          builder: (context, authViewModel, _) {
            final user = authViewModel.user;
            final driver = authViewModel.driver;

            // Always show content, use skeleton loaders when data is not available
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Driver info with skeleton loading
                    if (user == null || driver == null)
                      const DriverInfoSkeletonCard()
                    else
                      _buildDriverInfo(user, driver),
                    const SizedBox(height: 24),

                    // Statistics with skeleton loading
                    if (user == null || driver == null)
                      const StatisticsSkeletonCard()
                    else
                      _buildStatistics(),
                    const SizedBox(height: 24),

                    // Current delivery with skeleton loading
                    if (user == null || driver == null)
                      const DeliverySkeletonCard()
                    else
                      _buildCurrentDelivery(context),
                    const SizedBox(height: 24),

                    // Recent orders with skeleton loading
                    if (user == null || driver == null)
                      const OrdersSkeletonList(itemCount: 2)
                    else
                      _buildRecentOrders(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDriverInfo(user, driver) {
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
              child: user.imageUrl.isNotEmpty && user.imageUrl != "string"
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        user.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.person,
                              size: 30,
                              color: AppColors.primary,
                            ),
                      ),
                    )
                  : const Icon(
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
                  Text(user.fullName, style: AppTextStyles.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Tài xế ID: ${user.id.length > 8 ? user.id.substring(0, 8) : user.id}',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: user.status == 'ACTIVE'
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.warning.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      user.status == 'ACTIVE' ? 'Đang hoạt động' : user.status,
                      style: TextStyle(
                        color: user.status == 'ACTIVE'
                            ? AppColors.success
                            : AppColors.warning,
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
