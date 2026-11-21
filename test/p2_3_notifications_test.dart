import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusr1/core/services/auth_service.dart';
import 'package:yusr1/core/services/local_notification_ids.dart';
import 'package:yusr1/core/services/local_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('P2.3 quiet hours prefs UI reachable (s08)', () {
    test('home bell embeds quiet hours toggle + Lock G copy', () {
      final home = File('lib/pages/home_page.dart').readAsStringSync();
      expect(home.contains('QuietHoursPrefsSection'), isTrue);
      expect(home.contains('QuietHoursPolicy.arabicMedExceptionCopy'), isTrue);
      expect(home.contains('إعدادات التنبيهات وساعات الهدوء'), isTrue);
      expect(home.contains('ElderlyNotificationSettingsPage'), isTrue);
    });

    test('settings page + prefs section persist quiet hours keys', () {
      final page =
          File('lib/pages/elderly_notification_settings_page.dart')
              .readAsStringSync();
      final section =
          File('lib/core/widgets/quiet_hours_prefs_section.dart')
              .readAsStringSync();
      final svc =
          File('lib/core/services/local_notification_service.dart')
              .readAsStringSync();
      expect(page.contains('QuietHoursPrefsSection'), isTrue);
      expect(page.contains('ساعات الهدوء'), isTrue);
      expect(section.contains('saveQuietHours'), isTrue);
      expect(section.contains('QuietHoursPolicy.arabicMedExceptionCopy'), isTrue);
      expect(svc.contains('Future<void> saveQuietHours'), isTrue);
      expect(svc.contains('quiet_hours_enabled_'), isTrue);
      // Lock G: med suppress always false — never silently discard meds.
      expect(
        File('lib/core/services/local_notification_ids.dart')
            .readAsStringSync()
            .contains('shouldSuppressMedication(DateTime scheduledLocal) => false'),
        isTrue,
      );
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

  group('P2.3 M-3 account switch cancels prior schedules', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AuthService().resetForTest();
      LocalNotificationService.instance.debugCancelAllHook = null;
    });

    tearDown(() {
      LocalNotificationService.instance.debugCancelAllHook = null;
      AuthService().resetForTest();
    });

    test('elderly A → elderly B cancels previous schedules only', () async {
      var cancelCalls = 0;
      LocalNotificationService.instance.debugCancelAllHook = () async {
        cancelCalls++;
      };

      AuthService().setSeniorSession(id: 101, name: 'A', phone: '771000101');
      await AuthService().prepareForUserSwitch(
        newRole: 'senior',
        newUserId: 202,
      );
      expect(cancelCalls, 1);
      expect(AuthService().isLoggedIn, isFalse);

      // Apply B (simulates login after switch). New account has no schedules yet;
      // prepareForUserSwitch must not cancel again for same-user / cold apply.
      AuthService().setSeniorSession(id: 202, name: 'B', phone: '771000202');
      await AuthService().prepareForUserSwitch(
        newRole: 'senior',
        newUserId: 202,
      );
      expect(cancelCalls, 1, reason: 'same-user re-entry must not cancelAll');
    });

    test('same-user prepareForUserSwitch does not cancelAll', () async {
      var cancelCalls = 0;
      LocalNotificationService.instance.debugCancelAllHook = () async {
        cancelCalls++;
      };

      AuthService().setSeniorSession(id: 55, name: 'Same', phone: '771000055');
      await AuthService().prepareForUserSwitch(
        newRole: 'senior',
        newUserId: 55,
      );
      expect(cancelCalls, 0);
      expect(AuthService().isLoggedIn, isTrue);
    });

    test('logout still cancels schedules (Lock I preserved)', () async {
      var cancelCalls = 0;
      LocalNotificationService.instance.debugCancelAllHook = () async {
        cancelCalls++;
      };
      AuthService().setSeniorSession(id: 7, name: 'L', phone: '7');
      AuthService.remoteLogoutHook = () async => true;
      await AuthService().logout();
      expect(cancelCalls, 1);
    });
  });

  group('P2.3 M-4 lock-screen privacy copy', () {
    test('med reminder OS copy is generic; no med-name template', () {
      final src = File('lib/core/services/local_notification_service.dart')
          .readAsStringSync();
      expect(src.contains('lockScreenMedReminderCopy'), isTrue);
      expect(src.contains('لديك تذكير دواء'), isTrue);
      expect(src.contains('NotificationVisibility.private'), isTrue);
      expect(src.contains('حان موعد تناول'), isFalse);
      expect(
        src.contains("«\$medicationName»"),
        isFalse,
        reason: 'lock/shade body must not interpolate medication names',
      );
      expect(
        LocalNotificationService.lockScreenMedReminderCopy,
        'لديك تذكير دواء',
      );
    });
  });
}
