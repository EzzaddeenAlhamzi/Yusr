import 'package:flutter/material.dart';

/// نموذج بيانات الموعد (AppointmentItem)
class AppointmentItem {
  final String id;
  final String title;
  final String day;
  final String time;
  final String? date;
  final String? notes;
  final String? location;
  final Widget? iconWidget;
  /// Device-local Lock K advance label (prefs); default 60m when unset.
  final String? advanceReminder;
  final DateTime? dateTime;
  final bool isPast;

  AppointmentItem({
    String? id,
    required this.title,
    required this.day,
    required this.time,
    this.date,
    this.notes,
    this.location,
    this.iconWidget,
    this.advanceReminder,
    this.dateTime,
    this.isPast = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory AppointmentItem.fromMap(Map<String, dynamic> map) {
    return AppointmentItem(
      id: map['id']?.toString(),
      title: map['title'] ?? map['name'] ?? 'موعد جديد',
      day: map['day'] ?? 'اليوم',
      time: map['time'] ?? '12:00',
      date: map['date']?.toString(),
      notes: map['notes']?.toString(),
      location: map['location']?.toString(),
      advanceReminder: map['advanceReminder']?.toString(),
      dateTime: map['dateTime'] is DateTime ? map['dateTime'] as DateTime : null,
      isPast: map['isPast'] == true,
    );
  }

  factory AppointmentItem.fromString(String text) {
    return AppointmentItem(
      title: text,
      day: 'قريباً',
      time: 'غير محدد',
    );
  }

  AppointmentItem copyWith({
    String? id,
    String? title,
    String? day,
    String? time,
    String? date,
    String? notes,
    String? location,
    Widget? iconWidget,
    String? advanceReminder,
    DateTime? dateTime,
    bool? isPast,
  }) {
    return AppointmentItem(
      id: id ?? this.id,
      title: title ?? this.title,
      day: day ?? this.day,
      time: time ?? this.time,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      iconWidget: iconWidget ?? this.iconWidget,
      advanceReminder: advanceReminder ?? this.advanceReminder,
      dateTime: dateTime ?? this.dateTime,
      isPast: isPast ?? this.isPast,
    );
  }
}
