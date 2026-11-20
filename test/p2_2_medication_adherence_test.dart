import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/core/services/medication_adherence_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2.2 ApiService adherence contract', () {
    test('api_service exposes today/history/confirm legacy actions', () {
      final src = File('lib/core/services/api_service.dart').readAsStringSync();
      expect(src.contains('getTodayMedicationDoses'), isTrue);
      expect(src.contains('getMedicationAdherenceHistory'), isTrue);
      expect(src.contains('confirmMedicationDose'), isTrue);
      expect(src.contains("'action': 'get_medication_doses_today'"), isTrue);
      expect(
          src.contains("'action': 'get_medication_adherence_history'"), isTrue);
      expect(src.contains("'action': 'confirm_medication_dose'"), isTrue);
      expect(src.contains('client_confirm_id'), isTrue);
      expect(src.contains('occurrence_key'), isTrue);
    });

    test('confirmMedicationDose does not invent local success without request',
        () {
      final src = File('lib/core/services/api_service.dart').readAsStringSync();
      final start = src.indexOf('Future<Map<String, dynamic>> confirmMedicationDose');
      final end = src.indexOf('// ==================== المواعيد (appointments)');
      expect(start, greaterThan(0));
      expect(end, greaterThan(start));
      final fn = src.substring(start, end);
      expect(fn.contains('return _sendRequest'), isTrue);
      expect(fn.contains("status': 'success'"), isFalse);
      expect(fn.contains('SharedPreferences'), isFalse);
    });
  });

  group('P2.2 elderly confirm UX honesty', () {
    test('elderly page gates success on server status and blocks offline fake success',
        () {
      final src =
          File('lib/pages/medicines_page_elderly.dart').readAsStringSync();
      expect(src.contains('confirmMedicationDose'), isTrue);
      expect(src.contains("res['status'] != 'success'"), isTrue);
      expect(src.contains('تم تناول الدواء'), isTrue);
      expect(src.contains('offlineConfirmBlockedMessage'), isTrue);
      expect(src.contains('_confirmInFlight'), isTrue);
      // Must not write SharedPreferences as adherence SoT.
      expect(src.contains('med_confirmed_'), isFalse);
    });

    test('simple elderly page uses server today doses + large confirm CTA', () {
      final src = File('lib/pages/simple_elderly/simple_medicines_page.dart')
          .readAsStringSync();
      expect(src.contains('getTodayMedicationDoses'), isTrue);
      expect(src.contains('confirmMedicationDose'), isTrue);
      expect(src.contains('تم تناول الدواء'), isTrue);
      expect(src.contains('offlineConfirmBlockedMessage'), isTrue);
      expect(src.contains('_confirmInFlight'), isTrue);
      expect(src.contains("res['status'] != 'success'"), isTrue);
    });
  });

  group('P2.2 caregiver read-only adherence', () {
    test('caregiver medicines page reads server doses and does not confirm', () {
      final src = File('lib/pages/medicines_page.dart').readAsStringSync();
      expect(src.contains('getTodayMedicationDoses'), isTrue);
      expect(src.contains('caregiverReadOnlyMessage'), isTrue);
      expect(src.contains('اطلاع فقط'), isTrue);
      expect(src.contains('متأخر — غير مؤكد'), isTrue);
      // Must not treat prefs as adherence SoT anymore.
      expect(src.contains("prefs.setBool(confKey"), isFalse);
      expect(src.contains('med_confirmed_'), isFalse);
      // Confirm write path removed.
      expect(src.contains('confirmMedicationDose'), isFalse);
      expect(src.contains('_toggleConfirm'), isFalse);
    });
  });

  group('P2.2 helper vocabulary A1', () {
    test('labels cover upcoming/due/overdue_not_confirmed/taken/late', () {
      expect(MedicationAdherenceHelper.displayLabelAr('upcoming'), 'قادم');
      expect(MedicationAdherenceHelper.displayLabelAr('due'), 'مستحق');
      expect(
        MedicationAdherenceHelper.displayLabelAr('overdue_not_confirmed'),
        'متأخر — غير مؤكد',
      );
      expect(MedicationAdherenceHelper.displayLabelAr('taken'), 'تم التناول');
      expect(
        MedicationAdherenceHelper.displayLabelAr('late_confirmed'),
        'تأكيد متأخر',
      );
      expect(MedicationAdherenceHelper.graceMinutes, 30);
      expect(
        MedicationAdherenceHelper.isConfirmedState('late_confirmed'),
        isTrue,
      );
      expect(
        MedicationAdherenceHelper.isOverdueNotConfirmed('overdue_not_confirmed'),
        isTrue,
      );
      expect(
        MedicationAdherenceHelper.offlineConfirmBlockedMessage().contains('يلزم الاتصال'),
        isTrue,
      );
    });

    test('civilDateToday zero-pads month and day', () {
      expect(
        MedicationAdherenceHelper.civilDateToday(DateTime(2026, 11, 5)),
        '2026-11-05',
      );
    });
  });

  group('P2.2 legacy bridge + backend routes present', () {
    test('legacy bridge wires adherence actions', () {
      final src = File(
              'backend/app/Http/Controllers/Api/LegacyBridgeController.php')
          .readAsStringSync();
      expect(src.contains('get_medication_doses_today'), isTrue);
      expect(src.contains('get_medication_adherence_history'), isTrue);
      expect(src.contains('confirm_medication_dose'), isTrue);
    });

    test('REST dose routes registered before medication id catch-alls', () {
      final src = File('backend/routes/api.php').readAsStringSync();
      final today = src.indexOf("medications/doses/today");
      final confirm = src.indexOf("medications/doses/confirm");
      final update = src.indexOf("medications/{id?}");
      expect(today, greaterThan(0));
      expect(confirm, greaterThan(0));
      expect(update, greaterThan(confirm));
    });
  });
}
