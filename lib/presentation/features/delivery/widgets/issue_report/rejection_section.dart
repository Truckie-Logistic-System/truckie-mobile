import 'package:flutter/material.dart';

import '../../../../../domain/entities/order_detail.dart';
import 'package_selection_card.dart';

/// Widget for selecting packages that customer rejected
class RejectionSection extends StatelessWidget {
  final List<OrderDetail> packages;
  final Set<String> selectedIds;
  final Set<String> disabledIds;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Function(String id, bool isSelected) onSelectionChanged;

  const RejectionSection({
    super.key,
    required this.packages,
    required this.selectedIds,
    required this.disabledIds,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onSelectionChanged,
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
                      ? Colors.orange.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.cancel_outlined,
                  color: selectedIds.isNotEmpty ? Colors.orange : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khách hàng từ chối nhận',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: selectedIds.isNotEmpty
                            ? Colors.orange.shade900
                            : Colors.grey.shade800,
                      ),
                    ),
                    if (selectedIds.isNotEmpty)
                      Text(
                        'Đã chọn ${selectedIds.length} kiện',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade700,
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
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chọn các kiện hàng mà khách hàng từ chối nhận',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Package selection
                Text(
                  'Chọn các kiện hàng bị từ chối:',
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
                      color: Colors.orange,
                      disabledLabel: 'Đã chọn hư hại',
                      onChanged: (value) =>
                          onSelectionChanged(package.id, value ?? false),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
