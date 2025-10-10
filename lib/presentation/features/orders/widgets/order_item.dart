import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/order.dart';

class OrderItem extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const OrderItem({Key? key, required this.order, required this.onTap})
    : super(key: key);

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
    Color color;
    String displayStatus;

    switch (status) {
      case 'ASSIGNED_TO_DRIVER':
        color = Colors.blue;
        displayStatus = 'Đã giao cho tài xế';
        break;
      case 'FULLY_PAID':
      case 'PICKING_UP':
        color = Colors.orange;
        displayStatus = 'Đang lấy hàng';
        break;
      case 'PICKED_UP':
        color = Colors.orange;
        displayStatus = 'Đã lấy hàng';
        break;
      case 'DELIVERING':
        color = Colors.purple;
        displayStatus = 'Đang giao';
        break;
      case 'DELIVERED':
        color = Colors.green;
        displayStatus = 'Đã giao';
        break;
      case 'CANCELLED':
        color = Colors.red;
        displayStatus = 'Đã hủy';
        break;
      default:
        color = Colors.grey;
        displayStatus = status;
    }

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
}
