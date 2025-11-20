import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../../domain/entities/order_detail.dart';

/// Widget for confirming delivery of successful packages
class DeliveryConfirmationSection extends StatelessWidget {
  final List<OrderDetail> packages;
  final List<File> images;
  final bool hasIssues;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveImage;

  const DeliveryConfirmationSection({
    super.key,
    required this.packages,
    required this.images,
    required this.hasIssues,
    required this.onPickImages,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xác nhận giao hàng',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade900,
                        ),
                      ),
                      Text(
                        '${packages.length} kiện không có vấn đề',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info banner if there are issues
            if (hasIssues)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vui lòng chụp ảnh xác nhận giao hàng thành công cho các kiện không có vấn đề',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Package list
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Các kiện sẽ được xác nhận:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...packages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final pkg = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${index + 1}. ${pkg.description}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Image picker
            Text(
              'Ảnh xác nhận giao hàng: *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            _buildImagePicker(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    if (images.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đã chọn ${images.length} ảnh',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length + 1,
              itemBuilder: (context, index) {
                if (index == images.length) {
                  // Add more button
                  return GestureDetector(
                    onTap: onPickImages,
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.add_a_photo,
                            size: 32, color: Colors.grey[400]),
                      ),
                    ),
                  );
                }

                // Image thumbnail
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(images[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => onRemoveImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    // Empty state
    return GestureDetector(
      onTap: onPickImages,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.shade300,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate,
                size: 48, color: Colors.green.shade300),
            const SizedBox(height: 8),
            Text(
              'Chụp ảnh xác nhận',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bắt buộc',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
