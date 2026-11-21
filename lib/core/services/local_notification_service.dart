import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_notification_ids.dart';

typedef NotificationNavHandler = void Function(String route, Map<String, dynamic> payload);

/// P2.3 Channel A — real Android local notifications (no FCM).
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const channelMeds = 'yusr_meds';
  static const channelAppts = 'yusr_appts';
  static const channelGeneral = 'yusr_general';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  NotificationNavHandler? onNavigate;

  /// Test hook: when set, [cancelAll] invokes this instead of the OS plugin.
  @visibleForTesting
  Future<void> Function()? debugCancelAllHook;

  /// Test hook: when true, appointment schedule/cancel use in-memory tracking
  /// instead of the OS plugin (Lock K regression tests).
  @visibleForTesting
  bool debugAppointmentTracking = false;

  /// Pending appointment reminders under [debugAppointmentTracking].
  /// Key = notification id; value = meta for assertions.
  @visibleForTesting
  final Map<int, Map<String, dynamic>> debugPendingAppointments = {};

  /// Lock-screen / shade copy — no medication names or dosage (M-4).
  static const lockScreenMedReminderCopy = 'لديك تذكير دواء';

  bool get isInitialized => _initialized;

  @visibleForTesting
  void debugResetAppointmentTracking() {
    debugAppointmentTracking = false;
    debugPendingAppointments.clear();
  }

  Future<void> initialize({NotificationNavHandler? onNavigate}) async {
    this.onNavigate = onNavigate;
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelMeds,
        'تذكير الأدوية',
        description: 'تذكيرات جرعات الدواء في موعدها',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelAppts,
        'تذكير المواعيد',
        description: 'تذكيرات المواعيد الطبية',
        importance: Importance.defaultImportance,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelGeneral,
        'تنبيهات عامة',
        description: 'تنبيهات عامة داخل تطبيق يُسر',
        importance: Importance.defaultImportance,
      ),
    );

    _initialized = true;
  }

  void _onResponse(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final route = map['route']?.toString() ?? '/medicines-elderly';
      onNavigate?.call(route, map);
    } catch (_) {}
  }

  /// Request POST_NOTIFICATIONS (Android 13+). Returns whether permission granted.
  Future<bool> requestPermissionHonest() async {
    if (kIsWeb) return false;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> isPermissionGranted() async {
    if (kIsWeb) return false;
    return Permission.notification.isGranted;
  }

  Future<QuietHoursPolicy> loadQuietHours(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return QuietHoursPolicy(
      enabled: prefs.getBool('quiet_hours_enabled_$userId') ?? false,
      startHm: prefs.getString('quiet_hours_start_$userId') ?? '22:00',
      endHm: prefs.getString('quiet_hours_end_$userId') ?? '07:00',
    );
  }

  /// Persist quiet-hours prefs. Medication reminders are never suppressed (Lock G).
  Future<void> saveQuietHours(int userId, QuietHoursPolicy policy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quiet_hours_enabled_$userId', policy.enabled);
    await prefs.setString('quiet_hours_start_$userId', policy.startHm);
    await prefs.setString('quiet_hours_end_$userId', policy.endHm);
  }

  Future<void> cancelAll() async {
    final hook = debugCancelAllHook;
    if (hook != null) {
      await hook();
      return;
    }
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  Future<void> cancelId(int id) async {
    if (debugAppointmentTracking) {
      debugPendingAppointments.remove(id);
      return;
    }
    if (!_initialized) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelMedicationOccurrence({
    required int elderlyId,
    required String occurrenceKey,
  }) async {
    await cancelId(LocalNotificationIds.medReminder(elderlyId, occurrenceKey));
  }

  /// Cancel stable + legacy offset-based IDs for one appointment.
  /// Safe for unrelated meds/other appointments (ID set is scoped).
  Future<void> cancelAppointmentReminder({
    required int elderlyId,
    required int appointmentId,
  }) async {
    for (final id in LocalNotificationIds.appointmentReminderIdsToCancel(
      elderlyId,
      appointmentId,
    )) {
      await cancelId(id);
    }
  }

  /// Schedule med reminder at scheduled_at. Never auto-Taken. Quiet hours do not suppress.
  Future<bool> scheduleMedicationReminder({
    required int elderlyId,
    required String occurrenceKey,
    required String medicationName,
    required DateTime scheduledAtLocal,
    String? displayState,
  }) async {
    if (!_initialized) await initialize();
    if (displayState == 'taken' || displayState == 'late_confirmed') {
      await cancelMedicationOccurrence(
        elderlyId: elderlyId,
        occurrenceKey: occurrenceKey,
      );
      return false;
    }
    if (scheduledAtLocal.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      return false;
    }
    final granted = await isPermissionGranted();
    if (!granted) return false;

    final id = LocalNotificationIds.medReminder(elderlyId, occurrenceKey);
    final when = tz.TZDateTime.from(scheduledAtLocal, tz.local);
    final payload = jsonEncode({
      'route': '/medicines-elderly',
      'occurrence_key': occurrenceKey,
      'elderly_id': elderlyId,
      'kind': 'med',
    });

    // M-4: conservative lock-screen — generic title/body only (no med name /
    // dosage / account). Details appear after opening the authorized app
    // (payload → medicines page). [medicationName] kept for caller API.
    final _ = medicationName;
    await _plugin.zonedSchedule(
      id,
      lockScreenMedReminderCopy,
      lockScreenMedReminderCopy,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelMeds,
          'تذكير الأدوية',
          channelDescription: 'تذكيرات جرعات الدواء في موعدها',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
          styleInformation: const BigTextStyleInformation(
            lockScreenMedReminderCopy,
          ),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
    return true;
  }

  Future<bool> scheduleAppointmentReminder({
    required int elderlyId,
    required int appointmentId,
    required String title,
    required DateTime appointmentAtLocal,
    required int offsetMinutes,
    required QuietHoursPolicy quiet,
  }) async {
    // Always clear prior stable + legacy IDs first so offset changes never
    // leave duplicate pending reminders for the same appointment.
    await cancelAppointmentReminder(
      elderlyId: elderlyId,
      appointmentId: appointmentId,
    );

    if (offsetMinutes <= 0) {
      return false;
    }

    final fireAt = appointmentAtLocal.subtract(Duration(minutes: offsetMinutes));
    if (fireAt.isBefore(DateTime.now())) return false;
    if (quiet.shouldSuppressAppointment(fireAt)) {
      // Honest skip — do not silently claim scheduled.
      return false;
    }

    final id = LocalNotificationIds.appointmentReminder(elderlyId, appointmentId);

    if (debugAppointmentTracking) {
      debugPendingAppointments[id] = {
        'elderly_id': elderlyId,
        'appointment_id': appointmentId,
        'offset_minutes': offsetMinutes,
        'appointment_at': appointmentAtLocal.toIso8601String(),
        'fire_at': fireAt.toIso8601String(),
        'title': title,
      };
      return true;
    }

    if (!_initialized) await initialize();
    final granted = await isPermissionGranted();
    if (!granted) return false;

    final when = tz.TZDateTime.from(fireAt, tz.local);
    final payload = jsonEncode({
      'route': '/appointments',
      'appointment_id': appointmentId,
      'elderly_id': elderlyId,
      'kind': 'appt',
    });

    await _plugin.zonedSchedule(
      id,
      'تذكير موعد',
      'موعد «$title» بعد $offsetMinutes دقيقة.',
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelAppts,
          'تذكير المواعيد',
          channelDescription: 'تذكيرات المواعيد الطبية',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
    return true;
  }

  /// Sync rolling horizon from today's dose rows (unconfirmed only).
  Future<void> syncMedicationDoses({
    required int elderlyId,
    required List<Map<String, dynamic>> doses,
    required bool Function(int medId) remindersEnabledForMed,
  }) async {
    if (!_initialized) await initialize();
    for (final row in doses) {
      final occKey = row['occurrence_key']?.toString();
      if (occKey == null || occKey.isEmpty) continue;
      final medId = row['Medicayion_ID'] is int
          ? row['Medicayion_ID'] as int
          : int.tryParse(row['Medicayion_ID']?.toString() ?? '') ?? 0;
      final display = row['display_state']?.toString();
      final medNested = row['medication'];
      final name = row['M_Name']?.toString() ??
          row['medication_name']?.toString() ??
          (medNested is Map ? medNested['M_Name']?.toString() : null) ??
          'دواء';
      final scheduledRaw = row['scheduled_at']?.toString();
      if (scheduledRaw == null) continue;
      // Server stores civil local wall-clock; parse as local (no Z suffix).
      final scheduled = DateTime.tryParse(scheduledRaw.replaceFirst(' ', 'T'));
      if (scheduled == null) continue;

      if (!remindersEnabledForMed(medId)) {
        await cancelMedicationOccurrence(elderlyId: elderlyId, occurrenceKey: occKey);
        continue;
      }
      await scheduleMedicationReminder(
        elderlyId: elderlyId,
        occurrenceKey: occKey,
        medicationName: name,
        scheduledAtLocal: scheduled,
        displayState: display,
      );
    }
  }
}
