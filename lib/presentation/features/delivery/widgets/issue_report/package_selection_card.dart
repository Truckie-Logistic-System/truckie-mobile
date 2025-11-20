import 'package:flutter/material.dart';

import '../../../../../domain/entities/order_detail.dart';

/// Reusable widget for displaying package selection card
class PackageSelectionCard extends StatelessWidget {
  final OrderDetail package;
  final bool isSelected;
  final bool isDisabled;
  final MaterialColor color;
  final String disabledLabel;
  final ValueChanged<bool?>? onChanged;

  const PackageSelectionCard({
    super.key,
    required this.package,
    required this.isSelected,
    required this.isDisabled,
    required this.color,
    required this.disabledLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? color.shade400
              : isDisabled
                  ? Colors.grey.shade300
                  : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected
            ? color.shade50
            : isDisabled
                ? Colors.grey.shade100
                : Colors.white,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: CheckboxListTile(
        value: isSelected,
        enabled: !isDisabled,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title: Row(
          children: [
            // Tracking code badge
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.shade100
                      : isDisabled
                          ? Colors.grey.shade200
                          : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  package.trackingCode,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isSelected
                        ? color.shade900
                        : isDisabled
                            ? Colors.grey.shade600
                            : Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),

            // Disabled label
            if (isDisabled) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 12, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      disabledLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      package.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Weight
              Row(
                children: [
                  Icon(Icons.scale_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    '${package.weightBaseUnit ?? 0} ${package.unit}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        activeColor: color.shade700,
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
