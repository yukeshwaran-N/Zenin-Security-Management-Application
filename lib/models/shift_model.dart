import 'package:flutter/material.dart';

class Shift {
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Shift({
    required this.name,
    required this.startTime,
    required this.endTime,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shift &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  bool isTimeInShift(DateTime time) {
    final nowTime = TimeOfDay.fromDateTime(time);
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final currentMinutes = nowTime.hour * 60 + nowTime.minute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight shift (e.g., C-shift)
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  static List<Shift> get allShifts => [
    Shift(
      name: 'A-shift',
      startTime: const TimeOfDay(hour: 6, minute: 0),
      endTime: const TimeOfDay(hour: 14, minute: 0),
    ),
    Shift(
      name: 'B-shift',
      startTime: const TimeOfDay(hour: 14, minute: 0),
      endTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    Shift(
      name: 'C-shift',
      startTime: const TimeOfDay(hour: 22, minute: 0),
      endTime: const TimeOfDay(hour: 6, minute: 0),
    ),
    Shift(
      name: 'General shift',
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 18, minute: 0),
    ),
  ];
}
