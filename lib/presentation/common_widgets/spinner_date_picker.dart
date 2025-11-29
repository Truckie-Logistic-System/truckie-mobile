import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../theme/app_colors.dart';

class SpinnerDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Function(DateTime) onDateSelected;

  const SpinnerDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  });

  @override
  State<SpinnerDatePicker> createState() => _SpinnerDatePickerState();
}

class _SpinnerDatePickerState extends State<SpinnerDatePicker> {
  late int _selectedDay;
  late int _selectedMonth;
  late int _selectedYear;
  late List<int> _days;
  late List<String> _months;
  late List<int> _years;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDate.day;
    _selectedMonth = widget.initialDate.month;
    _selectedYear = widget.initialDate.year;
    _updateDays();

    // Tạo danh sách tháng
    _months = List.generate(12, (index) {
      final month = index + 1;
      return intl.DateFormat('MMMM').format(DateTime(2022, month));
    });

    // Tạo danh sách năm
    _years = List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );
  }

  void _updateDays() {
    // Tính số ngày trong tháng
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    _days = List.generate(daysInMonth, (index) => index + 1);

    // Đảm bảo ngày được chọn không vượt quá số ngày trong tháng
    if (_selectedDay > daysInMonth) {
      _selectedDay = daysInMonth;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () {
                  final selectedDate = DateTime(
                    _selectedYear,
                    _selectedMonth,
                    _selectedDay,
                  );
                  widget.onDateSelected(selectedDate);
                  Navigator.pop(context);
                },
                child: const Text('Xong'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                // Ngày
                Expanded(
                  child: _buildSpinnerList(
                    _days,
                    _selectedDay,
                    (value) => setState(() {
                      _selectedDay = value;
                    }),
                    (index) => _days[index].toString(),
                  ),
                ),
                // Tháng
                Expanded(
                  flex: 2,
                  child: _buildSpinnerList(
                    List.generate(_months.length, (index) => index + 1),
                    _selectedMonth,
                    (value) => setState(() {
                      _selectedMonth = value;
                      _updateDays();
                    }),
                    (index) => _months[index - 1],
                  ),
                ),
                // Năm
                Expanded(
                  child: _buildSpinnerList(
                    _years,
                    _selectedYear,
                    (value) => setState(() {
                      _selectedYear = value;
                      _updateDays();
                    }),
                    (index) => index.toString(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinnerList(
    List<int> items,
    int selectedItem,
    Function(int) onItemSelected,
    String Function(int) itemText,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: ListWheelScrollView.useDelegate(
        itemExtent: 40,
        diameterRatio: 1.5,
        squeeze: 1.0,
        useMagnifier: true,
        magnification: 1.2,
        physics: const FixedExtentScrollPhysics(),
        controller: FixedExtentScrollController(
          initialItem: items.indexOf(selectedItem),
        ),
        onSelectedItemChanged: (index) {
          onItemSelected(items[index]);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (context, index) {
            final isSelected = items[index] == selectedItem;
            return Center(
              child: Text(
                itemText(items[index]),
                style: TextStyle(
                  fontSize: isSelected ? 18 : 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.black,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Hiển thị spinner date picker
Future<void> showSpinnerDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required Function(DateTime) onDateSelected,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  await showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return SpinnerDatePicker(
        initialDate: initialDate,
        firstDate: firstDate ?? DateTime(1900),
        lastDate: lastDate ?? DateTime(2100),
        onDateSelected: onDateSelected,
      );
    },
  );
}
