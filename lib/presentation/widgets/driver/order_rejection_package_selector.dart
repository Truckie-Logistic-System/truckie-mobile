import 'package:flutter/material.dart';

/// Widget để driver chọn các kiện hàng cần trả
class OrderRejectionPackageSelector extends StatefulWidget {
  final List<PackageItem> packages;
  final Function(List<String>) onConfirm;

  const OrderRejectionPackageSelector({
    super.key,
    required this.packages,
    required this.onConfirm,
  });

  @override
  State<OrderRejectionPackageSelector> createState() =>
      _OrderRejectionPackageSelectorState();
}

class _OrderRejectionPackageSelectorState
    extends State<OrderRejectionPackageSelector> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.orange[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Chọn kiện hàng bị từ chối',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Selected count
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Đã chọn: ${_selectedIds.length}/${widget.packages.length} kiện',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Package list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.packages.length,
              itemBuilder: (context, index) {
                final package = widget.packages[index];
                final isSelected = _selectedIds.contains(package.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(package.id);
                        } else {
                          _selectedIds.remove(package.id);
                        }
                      });
                    },
                    title: Text(
                      package.trackingCode,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (package.description != null) ...[
                          const SizedBox(height: 4),
                          Text(package.description!),
                        ],
                        if (package.weight != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Khối lượng: ${package.weight} ${package.unit ?? 'kg'}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    activeColor: Colors.orange[700],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Confirm button
          ElevatedButton(
            onPressed: _selectedIds.isEmpty
                ? null
                : () => widget.onConfirm(_selectedIds.toList()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _selectedIds.isEmpty
                  ? 'Chọn ít nhất 1 kiện hàng'
                  : 'Xác nhận (${_selectedIds.length} kiện)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple model for package display
class PackageItem {
  final String id;
  final String trackingCode;
  final String? description;
  final double? weight;
  final String? unit; // e.g., 'kg', 'g', 'piece'

  PackageItem({
    required this.id,
    required this.trackingCode,
    this.description,
    this.weight,
    this.unit,
  });
}
