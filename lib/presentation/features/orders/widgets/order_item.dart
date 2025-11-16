import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_status.dart';

class OrderItem extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const OrderItem({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.person, 'Người nhận: ${order.receiverName}'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone, 'SĐT: ${order.receiverPhone}'),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.calendar_today,
                'Ngày tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.shopping_bag,
                'Số lượng: ${order.totalQuantity}',
              ),
              if (order.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.note, 'Ghi chú: ${order.notes}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: Colors.grey[800])),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final orderStatus = OrderStatus.fromString(status);
    final displayStatus = orderStatus.toVietnamese();
    final color = _getStatusColor(orderStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.processing:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.contractDraft:
      case OrderStatus.contractSigned:
      case OrderStatus.onPlanning:
        return Colors.blue;
      case OrderStatus.assignedToDriver:
      case OrderStatus.fullyPaid:
        return Colors.blue;
      case OrderStatus.pickingUp:
        return Colors.orange;
      case OrderStatus.onDelivered:
      case OrderStatus.ongoingDelivered:
        return Colors.purple;
      case OrderStatus.delivered:
      case OrderStatus.successful:
        return Colors.green;
      case OrderStatus.inTroubles:
        return Colors.red;
      case OrderStatus.resolved:
      case OrderStatus.compensation:
        return Colors.orange;
      case OrderStatus.rejectOrder:
        return Colors.red;
      case OrderStatus.returning:
        return Colors.orange;
      case OrderStatus.returned:
        return Colors.grey;
    }
  }
}
