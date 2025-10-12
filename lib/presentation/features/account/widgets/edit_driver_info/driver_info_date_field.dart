import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget hiển thị trường chọn ngày tháng
class DriverInfoDateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime date;
  final VoidCallback onTap;

  const DriverInfoDateField({
    Key? key,
    required this.label,
    required this.icon,
    required this.date,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(dateFormat.format(date)),
      ),
    );
  }
}
