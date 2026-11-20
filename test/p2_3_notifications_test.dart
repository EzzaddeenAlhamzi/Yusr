import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/core/services/local_notification_ids.dart';

void main() {
  group('P2.3 LocalNotificationIds', () {
    test('medication IDs are deterministic and positive', () {
      final a = LocalNotificationIds.medReminder(12, '2026-11-20:morning');
      final b = LocalNotificationIds.medReminder(12, '2026-11-20:morning');
      final c = LocalNotificationIds.medReminder(12, '2026-11-20:evening');
      expect(a, b);
      expect(a, isNonNegative);
      expect(a, isNot(c));
      expect(a & 0x80000000, 0);
    });

    test('appointment IDs include offset', () {
      final a = LocalNotificationIds.appointmentReminder(1, 9, 60);
      final b = LocalNotificationIds.appointmentReminder(1, 9, 30);
      expect(a, isNot(b));
    });
  });

  group('P2.3 QuietHoursPolicy Lock G', () {
    test('medication reminders are never suppressed', () {
      final q = QuietHoursPolicy(
        enabled: true,
        startHm: '22:00',
        endHm: '07:00',
      );
      expect(q.shouldSuppressMedication(DateTime(2026, 11, 20, 23, 0)), isFalse);
      expect(q.isInsideQuietWindow(DateTime(2026, 11, 20, 23, 0)), isTrue);
    });

    test('appointment may be suppressed inside quiet hours', () {
      final q = QuietHoursPolicy(
        enabled: true,
        startHm: '22:00',
        endHm: '07:00',
      );
      expect(q.shouldSuppressAppointment(DateTime(2026, 11, 20, 23, 0)), isTrue);
      expect(q.shouldSuppressAppointment(DateTime(2026, 11, 20, 10, 0)), isFalse);
    });

    test('disabled quiet hours never suppress', () {
      final q = QuietHoursPolicy(
        enabled: false,
        startHm: '22:00',
        endHm: '07:00',
      );
      expect(q.shouldSuppressAppointment(DateTime(2026, 11, 20, 23, 0)), isFalse);
    });
  });

  group('P2.3 AppointmentReminderOffset Lock K', () {
    test('default is 60 minutes (PROPOSED)', () {
      expect(AppointmentReminderOffset.defaultMinutes, 60);
      expect(
        AppointmentReminderOffset.minutesFromLabel(
          AppointmentReminderOffset.defaultLabel,
        ),
        60,
      );
    });

    test('parses Arabic labels', () {
      expect(AppointmentReminderOffset.minutesFromLabel('قبل الموعد بـ 15 دقيقة'), 15);
      expect(AppointmentReminderOffset.minutesFromLabel('قبل الموعد بـ 30 دقيقة'), 30);
      expect(AppointmentReminderOffset.minutesFromLabel('قبل الموعد بيوم واحد'), 1440);
      expect(AppointmentReminderOffset.minutesFromLabel('بدون تذكير مسبق'), 0);
    });
  });
}
