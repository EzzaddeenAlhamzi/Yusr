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

    test('appointment IDs are stable across offsets', () {
      final a = LocalNotificationIds.appointmentReminder(1, 9);
      final b = LocalNotificationIds.appointmentReminder(1, 9);
      final otherAppt = LocalNotificationIds.appointmentReminder(1, 10);
      final otherElderly = LocalNotificationIds.appointmentReminder(2, 9);
      expect(a, b);
      expect(a, isNot(otherAppt));
      expect(a, isNot(otherElderly));
      expect(a & 0x80000000, 0);
    });

    test('legacy offset IDs differ; cancel set covers stable + legacy', () {
      final stable = LocalNotificationIds.appointmentReminder(1, 9);
      final legacy60 =
          LocalNotificationIds.appointmentReminderLegacy(1, 9, 60);
      final legacy30 =
          LocalNotificationIds.appointmentReminderLegacy(1, 9, 30);
      expect(stable, isNot(legacy60));
      expect(legacy60, isNot(legacy30));
      final cancel =
          LocalNotificationIds.appointmentReminderIdsToCancel(1, 9);
      expect(cancel, contains(stable));
      expect(cancel, contains(legacy60));
      expect(cancel, contains(legacy30));
      expect(cancel, contains(
        LocalNotificationIds.appointmentReminderLegacy(1, 9, 15),
      ));
      expect(cancel, contains(
        LocalNotificationIds.appointmentReminderLegacy(1, 9, 1440),
      ));
      expect(cancel, contains(
        LocalNotificationIds.appointmentReminderLegacy(1, 9, 0),
      ));
      // Unrelated appointment / med not in cancel set.
      expect(
        cancel,
        isNot(contains(LocalNotificationIds.appointmentReminder(1, 10))),
      );
      expect(
        cancel,
        isNot(contains(LocalNotificationIds.medReminder(1, 'occ-1'))),
      );
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
    test('default is 60 minutes', () {
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

  group('P2.3 Lock K appointment cancel/reschedule (A–I)', () {
    final quiet = QuietHoursPolicy(
      enabled: false,
      startHm: '22:00',
      endHm: '07:00',
    );
    // Far-future appointment so fireAt is always ahead of now.
    final apptAt = DateTime.now().add(const Duration(days: 3));
    const elderlyId = 42;
    const apptId = 7;
    const otherApptId = 8;

    setUp(() {
      LocalNotificationService.instance.debugResetAppointmentTracking();
      LocalNotificationService.instance.debugAppointmentTracking = true;
    });

    tearDown(() {
      LocalNotificationService.instance.debugResetAppointmentTracking();
    });

    Future<bool> schedule({
      required int offset,
      int appointmentId = apptId,
      DateTime? at,
      String title = 'موعد طبي',
    }) {
      return LocalNotificationService.instance.scheduleAppointmentReminder(
        elderlyId: elderlyId,
        appointmentId: appointmentId,
        title: title,
        appointmentAtLocal: at ?? apptAt,
        offsetMinutes: offset,
        quiet: quiet,
      );
    }

    Map<String, dynamic>? pendingFor(int appointmentId) {
      final id = LocalNotificationIds.appointmentReminder(elderlyId, appointmentId);
      return LocalNotificationService.instance.debugPendingAppointments[id];
    }

    int pendingCountForElderly(int eid) {
      return LocalNotificationService.instance.debugPendingAppointments.values
          .where((m) => m['elderly_id'] == eid)
          .length;
    }

    test('A: default 60-minute offset schedules one pending', () async {
      final ok = await schedule(offset: AppointmentReminderOffset.defaultMinutes);
      expect(ok, isTrue);
      final pending = pendingFor(apptId);
      expect(pending, isNotNull);
      expect(pending!['offset_minutes'], 60);
      expect(
        LocalNotificationService.instance.debugPendingAppointments.length,
        1,
      );
    });

    test('B: 60m→30m cancels old and schedules only new', () async {
      await schedule(offset: 60);
      // Simulate leftover legacy 60m ID from older builds.
      final legacy60 =
          LocalNotificationIds.appointmentReminderLegacy(elderlyId, apptId, 60);
      LocalNotificationService.instance.debugPendingAppointments[legacy60] = {
        'elderly_id': elderlyId,
        'appointment_id': apptId,
        'offset_minutes': 60,
        'legacy': true,
      };
      expect(
        LocalNotificationService.instance.debugPendingAppointments.length,
        2,
      );

      await schedule(offset: 30);
      final pending = pendingFor(apptId);
      expect(pending, isNotNull);
      expect(pending!['offset_minutes'], 30);
      expect(
        LocalNotificationService.instance.debugPendingAppointments.containsKey(
          legacy60,
        ),
        isFalse,
        reason: 'legacy 60m ID must be cleared on reschedule',
      );
      expect(
        LocalNotificationService.instance.debugPendingAppointments.length,
        1,
      );
    });

    test('C: 30m→15m never creates duplicates', () async {
      await schedule(offset: 30);
      await schedule(offset: 15);
      await schedule(offset: 15); // repeat
      expect(
        LocalNotificationService.instance.debugPendingAppointments.length,
        1,
      );
      expect(pendingFor(apptId)!['offset_minutes'], 15);
    });

    test('D: disable (offset 0) cancels all pending for appointment', () async {
      await schedule(offset: 60);
      final legacy30 =
          LocalNotificationIds.appointmentReminderLegacy(elderlyId, apptId, 30);
      LocalNotificationService.instance.debugPendingAppointments[legacy30] = {
        'elderly_id': elderlyId,
        'appointment_id': apptId,
        'offset_minutes': 30,
        'legacy': true,
      };
      final ok = await schedule(offset: 0);
      expect(ok, isFalse);
      expect(pendingFor(apptId), isNull);
      expect(
        LocalNotificationService.instance.debugPendingAppointments.containsKey(
          legacy30,
        ),
        isFalse,
      );
    });

    test('E: re-enable after disable schedules again', () async {
      await schedule(offset: 60);
      await schedule(offset: 0);
      expect(pendingFor(apptId), isNull);
      final ok = await schedule(offset: 30);
      expect(ok, isTrue);
      expect(pendingFor(apptId)!['offset_minutes'], 30);
      expect(
        LocalNotificationService.instance.debugPendingAppointments.length,
        1,
      );
    });

    test('F: update appointment date/time replaces previous reminder', () async {
      await schedule(offset: 60, at: apptAt);
      final firstFire = pendingFor(apptId)!['fire_at'];
      final newAt = apptAt.add(const Duration(hours: 5));
      await schedule(offset: 60, at: newAt);
      final second = pendingFor(apptId)!;
      expect(second['offset_minutes'], 60);
      expect(second['fire_at'], isNot(firstFire));
      expect(second['appointment_at'], newAt.toIso8601String());
      expect(
        LocalNotificationService.instance.debugPendingAppointments.length,
        1,
      );
    });

    test('G: delete cancels all associated reminders', () async {
      await schedule(offset: 60);
      final legacy15 =
          LocalNotificationIds.appointmentReminderLegacy(elderlyId, apptId, 15);
      LocalNotificationService.instance.debugPendingAppointments[legacy15] = {
        'elderly_id': elderlyId,
        'appointment_id': apptId,
        'offset_minutes': 15,
        'legacy': true,
      };
      await LocalNotificationService.instance.cancelAppointmentReminder(
        elderlyId: elderlyId,
        appointmentId: apptId,
      );
      expect(pendingFor(apptId), isNull);
      expect(
        LocalNotificationService.instance.debugPendingAppointments.containsKey(
          legacy15,
        ),
        isFalse,
      );
    });

    test('H: unrelated appointment + med IDs remain intact', () async {
      await schedule(offset: 60, appointmentId: apptId);
      await schedule(offset: 30, appointmentId: otherApptId, title: 'آخر');
      final medId = LocalNotificationIds.medReminder(elderlyId, 'occ-x');
      LocalNotificationService.instance.debugPendingAppointments[medId] = {
        'kind': 'med',
        'elderly_id': elderlyId,
      };

      await schedule(offset: 15, appointmentId: apptId); // reschedule only appt 7
      expect(pendingFor(apptId)!['offset_minutes'], 15);
      expect(pendingFor(otherApptId)!['offset_minutes'], 30);
      expect(
        LocalNotificationService.instance.debugPendingAppointments.containsKey(
          medId,
        ),
        isTrue,
      );

      await LocalNotificationService.instance.cancelAppointmentReminder(
        elderlyId: elderlyId,
        appointmentId: apptId,
      );
      expect(pendingFor(apptId), isNull);
      expect(pendingFor(otherApptId), isNotNull);
      expect(
        LocalNotificationService.instance.debugPendingAppointments.containsKey(
          medId,
        ),
        isTrue,
      );
    });

    test('I: legacy pending notification cleanup on cancel set', () async {
      final cancel =
          LocalNotificationIds.appointmentReminderIdsToCancel(elderlyId, apptId);
      // Seed every legacy offset ID as if from an older build.
      for (final offset in LocalNotificationIds.supportedAppointmentOffsets) {
        final lid = LocalNotificationIds.appointmentReminderLegacy(
          elderlyId,
          apptId,
          offset,
        );
        LocalNotificationService.instance.debugPendingAppointments[lid] = {
          'elderly_id': elderlyId,
          'appointment_id': apptId,
          'offset_minutes': offset,
          'legacy': true,
        };
      }
      // Also seed stable.
      final stable =
          LocalNotificationIds.appointmentReminder(elderlyId, apptId);
      LocalNotificationService.instance.debugPendingAppointments[stable] = {
        'elderly_id': elderlyId,
        'appointment_id': apptId,
        'offset_minutes': 60,
      };
      expect(
        LocalNotificationService.instance.debugPendingAppointments.keys
            .where(cancel.contains)
            .length,
        cancel.length,
      );

      await LocalNotificationService.instance.cancelAppointmentReminder(
        elderlyId: elderlyId,
        appointmentId: apptId,
      );
      for (final id in cancel) {
        expect(
          LocalNotificationService.instance.debugPendingAppointments
              .containsKey(id),
          isFalse,
        );
      }
      expect(pendingCountForElderly(elderlyId), 0);
    });

    test('account isolation: other elderly appointment IDs untouched', () async {
      await schedule(offset: 60);
      const otherElderly = 99;
      await LocalNotificationService.instance.scheduleAppointmentReminder(
        elderlyId: otherElderly,
        appointmentId: apptId,
        title: 'موعد آخر حساب',
        appointmentAtLocal: apptAt,
        offsetMinutes: 60,
        quiet: quiet,
      );
      await LocalNotificationService.instance.cancelAppointmentReminder(
        elderlyId: elderlyId,
        appointmentId: apptId,
      );
      final otherId =
          LocalNotificationIds.appointmentReminder(otherElderly, apptId);
      expect(
        LocalNotificationService.instance.debugPendingAppointments
            .containsKey(otherId),
        isTrue,
      );
      expect(pendingFor(apptId), isNull);
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
