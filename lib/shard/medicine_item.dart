import 'package:flutter/material.dart';

class MedicineItem {
  String name; // اسم الدواء
  String boxDescription; // لون العلبة
  String pillDescription; // لون الحبة أو الجرعة
  Widget? iconWidget;

  MedicineItem({
    required this.name,
    required this.boxDescription,
    required this.pillDescription,
    this.iconWidget,
  });

  // تحليل النص الخام في حال تم تمريره كـ String
  factory MedicineItem.fromString(String text, {Widget? iconWidget}) {
    final clean = text.trim();
    String name = '';
    String box = '';
    String pill = '';

    if (clean.contains('\n')) {
      final lines = clean.split('\n');
      final line1 = lines[0].trim();
      final line2 = lines.sublist(1).join(' ').trim();

      if (line1.contains('،')) {
        final parts = line1.split('،');
        name = parts[0].trim();
        pill = parts.sublist(1).join('،').trim();
      } else {
        name = line1;
      }
      box = line2.trim();
    } else if (clean.contains('،')) {
      final parts = clean.split('،');
      name = parts[0].trim();
      if (parts.length > 1) box = parts[1].trim();
      if (parts.length > 2) pill = parts.sublist(2).join('،').trim();
    } else {
      name = clean;
    }

    if (box.isEmpty) box = 'العلبة المحددة';
    if (pill.isEmpty) pill = 'حبة واحدة';

    return MedicineItem(
      name: name,
      boxDescription: box,
      pillDescription: pill,
      iconWidget: iconWidget,
    );
  }

  factory MedicineItem.fromMap(Map<String, dynamic> map) {
    return MedicineItem(
      name: map['name']?.toString() ?? '',
      boxDescription: map['boxDescription']?.toString() ??
          map['boxColor']?.toString() ??
          'العلبة المحددة',
      pillDescription: map['pillDescription']?.toString() ??
          map['pillColor']?.toString() ??
          map['dosage']?.toString() ??
          'حبة واحدة',
      iconWidget: map['icon'] as Widget?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'boxDescription': boxDescription,
      'pillDescription': pillDescription,
      'icon': iconWidget,
    };
  }
}
