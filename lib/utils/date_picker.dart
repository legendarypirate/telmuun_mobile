import 'package:flutter/material.dart';

const Color _orange = Color(0xFFFF6A1A);
const Color _navy = Color(0xFF0F2744);

Future<DateTimeRange?> pickAppDateRange(
  BuildContext context, {
  DateTimeRange? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final now = DateTime.now();
  return showDateRangePicker(
    context: context,
    firstDate: firstDate ?? DateTime(2023),
    lastDate: lastDate ?? DateTime(now.year + 1),
    initialDateRange: initialDateRange,
    helpText: 'Огноо сонгох',
    cancelText: 'Болих',
    confirmText: 'Хадгалах',
    saveText: 'Хадгалах',
    fieldStartHintText: 'Эхлэх огноо',
    fieldEndHintText: 'Дуусах огноо',
    fieldStartLabelText: 'Эхлэх',
    fieldEndLabelText: 'Дуусах',
    errorFormatText: 'Буруу формат',
    errorInvalidText: 'Буруу огноо',
    errorInvalidRangeText: 'Муж буруу',
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _orange,
            onPrimary: Colors.white,
            secondary: _orange,
            onSecondary: Colors.white,
            surface: Colors.white,
            onSurface: _navy,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: _orange,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            headerBackgroundColor: _orange,
            headerForegroundColor: Colors.white,
            rangeSelectionBackgroundColor: _orange.withValues(alpha: 0.14),
            rangeSelectionOverlayColor:
                WidgetStateProperty.all(_orange.withValues(alpha: 0.08)),
            todayForegroundColor: WidgetStateProperty.all(_orange),
            todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
            todayBorder: const BorderSide(color: _orange, width: 1.2),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              if (states.contains(WidgetState.disabled)) {
                return _navy.withValues(alpha: 0.3);
              }
              return _navy;
            }),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return _orange;
              return Colors.transparent;
            }),
            rangePickerHeaderBackgroundColor: _orange,
            rangePickerHeaderForegroundColor: Colors.white,
            rangePickerBackgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
        ),
        child: child!,
      );
    },
  );
}
