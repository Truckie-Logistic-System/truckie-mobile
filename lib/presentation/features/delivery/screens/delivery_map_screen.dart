import 'package:flutter/material.dart';

import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

class DeliveryMapScreen extends StatelessWidget {
  final String deliveryId;

  const DeliveryMapScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ giao hàng'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(children: [_buildMap(), _buildBottomPanel()]),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              // TODO: Định vị hiện tại
            },
            heroTag: 'location',
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              // TODO: Chỉ đường
            },
            heroTag: 'directions',
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.directions, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    // TODO: Thay thế bằng Google Maps thực tế
    return Container(
      color: const Color(0xFFE5E3DF),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 100, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Google Maps sẽ được hiển thị ở đây',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Mã giao hàng: $deliveryId', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đang giao hàng',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.inProgress,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Mã đơn: #DH001'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '15 phút',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRouteInfo(),
            const SizedBox(height: 16),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                '123 Nguyễn Văn Linh, Quận 7, TP.HCM',
                style: TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(left: 4),
          width: 2,
          height: 30,
          color: Colors.grey.withOpacity(0.5),
        ),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                '456 Lê Văn Lương, Quận 7, TP.HCM',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Gọi điện cho khách hàng
            },
            icon: const Icon(Icons.call),
            label: const Text('Gọi khách hàng'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Cập nhật trạng thái
            },
            icon: const Icon(Icons.update),
            label: const Text('Cập nhật'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
