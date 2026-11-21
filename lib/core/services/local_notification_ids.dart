/// Deterministic local notification IDs for P2.3 Channel A.
/// Pure Dart — unit-testable without OS plugins.
class LocalNotificationIds {
  LocalNotificationIds._();

  /// Supported Lock K UI offsets (minutes). Used for legacy ID cleanup only.
  static const List<int> supportedAppointmentOffsets = [0, 15, 30, 60, 1440];

  static int medReminder(int elderlyId, String occurrenceKey) {
    return _hash32('med|$elderlyId|$occurrenceKey');
  }

  /// Stable appointment reminder ID — independent of offset (Lock K hygiene).
  /// One pending reminder slot per elderly+appointment.
  static int appointmentReminder(int elderlyId, int appointmentId) {
    return _hash32('appt|$elderlyId|$appointmentId');
  }

  /// Pre-fix V1 IDs that encoded [offsetMinutes] in the hash key.
  /// Kept only so cancel/reschedule can clear leftovers from older builds.
  static int appointmentReminderLegacy(
    int elderlyId,
    int appointmentId,
    int offsetMinutes,
  ) {
    return _hash32('appt|$elderlyId|$appointmentId|$offsetMinutes');
  }

  /// Stable ID + all known legacy offset IDs for one appointment.
  /// Does not include medication IDs or other appointments.
  static Set<int> appointmentReminderIdsToCancel(
    int elderlyId,
    int appointmentId,
  ) {
    final ids = <int>{appointmentReminder(elderlyId, appointmentId)};
    for (final offset in supportedAppointmentOffsets) {
      ids.add(appointmentReminderLegacy(elderlyId, appointmentId, offset));
    }
    return ids;
  }

  /// FNV-1a 32-bit → positive 31-bit int (Android notification id range).
  static int _hash32(String input) {
    var hash = 0x811c9dc5;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}

/// Quiet-hours helpers (Lock G): med reminders are never silently dropped.
class QuietHoursPolicy {
  QuietHoursPolicy({
    required this.enabled,
    required this.startHm,
    required this.endHm,
  });

  final bool enabled;
  final String startHm; // HH:mm
  final String endHm;

  /// Medication reminders always fire at scheduled time (Lock G).
  bool shouldSuppressMedication(DateTime scheduledLocal) => false;

  /// Appointment reminders may be skipped inside quiet window.
  bool shouldSuppressAppointment(DateTime fireAtLocal) {
    if (!enabled) return false;
    return isInsideQuietWindow(fireAtLocal);
  }

  bool isInsideQuietWindow(DateTime local) {
    final start = _parseHm(startHm);
    final end = _parseHm(endHm);
    if (start == null || end == null) return false;
    final minutes = local.hour * 60 + local.minute;
    if (start == end) return false;
    if (start < end) {
      return minutes >= start && minutes < end;
    }
    // Overnight window e.g. 22:00 → 07:00
    return minutes >= start || minutes < end;
  }

  static int? _parseHm(String hm) {
    final parts = hm.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  static const arabicMedExceptionCopy =
      'ساعات الهدوء لا تلغي تذكيرات الدواء — تُعرض في موعدها دائماً.';
}

/// Maps Arabic advance-reminder labels to minutes (Lock K default = 60).
class AppointmentReminderOffset {
  AppointmentReminderOffset._();

  /// V1 documented default: 60 minutes (Lock K — PO APPROVED — FINAL).
  static const int defaultMinutes = 60;
  static const String defaultLabel = 'قبل الموعد بساعة';

  static int minutesFromLabel(String? label) {
    final s = (label ?? '').trim();
    if (s.isEmpty || s.contains('بدون')) return 0;
    if (s.contains('15')) return 15;
    if (s.contains('30')) return 30;
    if (s.contains('يوم')) return 24 * 60;
    if (s.contains('ساعة')) return 60;
    return defaultMinutes;
  }
}
