import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../../domain/entities/order_detail.dart';
import 'package_selection_card.dart';

/// Widget for selecting damaged packages and providing damage details
class DamageSection extends StatelessWidget {
  final List<OrderDetail> packages;
  final Set<String> selectedIds;
  final Set<String> disabledIds;
  final List<File> images;
  final String description;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Function(String id, bool isSelected) onSelectionChanged;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveImage;

  const DamageSection({
    super.key,
    required this.packages,
    required this.selectedIds,
    required this.disabledIds,
    required this.images,
    required this.description,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onSelectionChanged,
    required this.onDescriptionChanged,
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selectedIds.isNotEmpty
                      ? Colors.red.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.broken_image_outlined,
                  color: selectedIds.isNotEmpty ? Colors.red : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hàng hóa bị hư hại',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: selectedIds.isNotEmpty
                            ? Colors.red.shade900
                            : Colors.grey.shade800,
                      ),
                    ),
                    if (selectedIds.isNotEmpty)
                      Text(
                        'Đã chọn ${selectedIds.length} kiện',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          initiallyExpanded: isExpanded,
          onExpansionChanged: onExpansionChanged,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Package selection
                Text(
                  'Chọn các kiện hàng bị hư hại:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),

                ...packages.map((package) => PackageSelectionCard(
                      package: package,
                      isSelected: selectedIds.contains(package.id),
                      isDisabled: disabledIds.contains(package.id),
                      color: Colors.red,
                      disabledLabel: 'Đã chọn trả hàng',
                      onChanged: (value) =>
                          onSelectionChanged(package.id, value ?? false),
                    )),

                // Damage details (shown when packages selected)
                if (selectedIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Images
                  Text(
                    'Ảnh hư hại: *',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildImagePicker(context),

                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Mô tả chi tiết:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Mô tả chi tiết tình trạng hư hại...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.red.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.red.shade400, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      filled: true,
                      fillColor: Colors.red.shade50,
                    ),
                    maxLines: 3,
                    onChanged: onDescriptionChanged,
                    controller: TextEditingController(text: description)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: description.length),
                      ),
                  ),
                ],
              ],
            ),
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

    // Empty state - prompt to add images
    return GestureDetector(
      onTap: onPickImages,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.shade200,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate,
                size: 48, color: Colors.red.shade300),
            const SizedBox(height: 8),
            Text(
              'Chụp hư hại',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bắt buộc',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
