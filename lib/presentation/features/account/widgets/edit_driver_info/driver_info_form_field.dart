import 'package:flutter/material.dart';

/// Widget hiển thị trường nhập liệu thông tin tài xế
class DriverInfoFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final int? maxLength;

  const DriverInfoFormField({
    Key? key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLength,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        counterText: '', // Ẩn bộ đếm ký tự
      ),
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLength: maxLength,
    );
  }
}
