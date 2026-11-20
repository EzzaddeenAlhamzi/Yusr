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

  AppointmentItem({
    String? id,
    required this.title,
    required this.day,
    required this.time,
    this.date,
    this.notes,
    this.location,
    this.iconWidget,
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
    );
  }
}
