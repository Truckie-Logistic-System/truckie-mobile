import 'package:flutter/material.dart';

class ReportIssueDialog extends StatelessWidget {
  final Function(String) onIssueSelected;
  final VoidCallback onCancel;
  final List<String> issueOptions;

  const ReportIssueDialog({
    super.key,
    required this.onIssueSelected,
    required this.onCancel,
    this.issueOptions = const [
      'Không liên hệ được khách hàng',
      'Địa chỉ không chính xác',
      'Khách hàng không nhận hàng',
      'Vấn đề khác',
    ],
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Báo cáo vấn đề'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: issueOptions
            .map((issue) => _buildIssueOption(context, issue))
            .toList(),
      ),
      actions: [TextButton(onPressed: onCancel, child: const Text('Hủy'))],
    );
  }

  Widget _buildIssueOption(BuildContext context, String issue) {
    return ListTile(title: Text(issue), onTap: () => onIssueSelected(issue));
  }

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => ReportIssueDialog(
        onIssueSelected: (issue) {
          Navigator.pop(context, issue);
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}
