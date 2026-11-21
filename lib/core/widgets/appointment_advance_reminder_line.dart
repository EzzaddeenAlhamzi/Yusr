import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Caregiver appointment-card advance-reminder row (Lock K).
/// Uses [Flexible] so long Arabic labels wrap instead of overflowing.
class AppointmentAdvanceReminderLine extends StatelessWidget {
  const AppointmentAdvanceReminderLine({
    super.key,
    required this.advanceReminder,
    this.fontSize = 11,
    this.iconSize = 13,
    this.labelPrefix = 'تذكير مسبق: ',
  });

  final String advanceReminder;
  final double fontSize;
  final double iconSize;
  final String labelPrefix;

  /// True when the label should be shown on the card (not empty / not Off).
  static bool shouldShow(String? label) {
    final s = (label ?? '').trim();
    return s.isNotEmpty && s != 'بدون تذكير مسبق';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.alarm_on_rounded,
          size: iconSize,
          color: const Color(0xFFE65100),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$labelPrefix$advanceReminder',
            softWrap: true,
            style: GoogleFonts.cairo(
              fontSize: fontSize,
              color: const Color(0xFFE65100),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
