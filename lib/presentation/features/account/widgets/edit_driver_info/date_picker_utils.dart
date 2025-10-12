import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../../../presentation/common_widgets/spinner_date_picker.dart';

/// Utility class để hiển thị date picker
class DatePickerUtils {
  /// Hiển thị date picker phù hợp với nền tảng
  static Future<void> selectDate(
    BuildContext context,
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    // Sử dụng CupertinoDatePicker trên iOS và custom date picker trên Android
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // iOS date picker
      await showIOSDatePicker(context, initialDate, onDateSelected);
    } else {
      // Android date picker
      await showAndroidDatePicker(context, initialDate, onDateSelected);
    }
  }

  /// Hiển thị date picker cho Android
  static Future<void> showAndroidDatePicker(
    BuildContext context,
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    // Sử dụng spinner date picker tùy chỉnh
    await showSpinnerDatePicker(
      context: context,
      initialDate: initialDate,
      onDateSelected: onDateSelected,
    );
  }

  /// Hiển thị date picker cho iOS
  static Future<void> showIOSDatePicker(
    BuildContext context,
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) async {
    DateTime selectedDate = initialDate;

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext builder) {
        return Container(
          height: MediaQuery.of(context).copyWith().size.height / 3,
          color: Colors.white,
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
                      onDateSelected(selectedDate);
                      Navigator.pop(context);
                    },
                    child: const Text('Xong'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initialDate,
                  onDateTimeChanged: (DateTime newDate) {
                    selectedDate = newDate;
                  },
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime(2100),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
