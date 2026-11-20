import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/core/services/api_service.dart';
import 'package:yusr1/core/services/auth_service.dart';
import 'package:yusr1/core/services/senior_manager.dart';
import 'package:yusr1/core/models/senior_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService.listDataOrEmpty honesty', () {
    test('success list clears error and returns rows', () {
      ApiService.lastListError = 'stale';
      ApiService.lastListConnectionError = true;
      final rows = ApiService.listDataOrEmpty({
        'status': 'success',
        'data': [
          {'M_Name': 'aspirin'},
        ],
      });
      expect(rows, hasLength(1));
      expect(ApiService.lastListError, isNull);
      expect(ApiService.lastListConnectionError, isFalse);
    });

    test('error response records message and returns empty (not fake success)', () {
      final rows = ApiService.listDataOrEmpty({
        'status': 'error',
        'message': 'غير مصرح',
        'error_type': 'forbidden',
      });
      expect(rows, isEmpty);
      expect(ApiService.lastListError, 'غير مصرح');
      expect(ApiService.lastListConnectionError, isFalse);
    });

    test('connection error flag is preserved', () {
      final rows = ApiService.listDataOrEmpty({
        'status': 'error',
        'is_connection_error': true,
        'error_type': 'connection_error',
        'message': 'تعذّر الاتصال بالخادم',
      });
      expect(rows, isEmpty);
      expect(ApiService.lastListConnectionError, isTrue);
      expect(ApiService.lastListError, contains('تعذّر'));
    });
  });

  group('SeniorManager honesty (no invented battery/health)', () {
    test('SeniorModel defaults do not invent healthy battery', () {
      final empty = SeniorManager().currentSenior;
      // When no seniors linked, placeholder model must not claim battery/health.
      expect(empty.watchBattery, 0);
      expect(empty.watchConnected, isFalse);
      expect(empty.healthStatus, isNot(equals('مستقر')));
    });

    test('role normalize still maps elderly→senior (auth compat)', () {
      expect(AuthService.normalizeClientRole('elderly'), 'senior');
      expect(AuthService.normalizeClientRole('caregiver'), 'caregiver');
    });
  });

  group('SeniorModel copy honesty', () {
    test('explicit zero battery is preserved', () {
      final m = SeniorModel(
        id: '1',
        name: 'سعد',
        relationship: 'حسابي',
        age: 0,
        bloodType: 'غير محدد',
        healthStatus: 'غير متوفر',
        chronicDiseases: const [],
        allergies: 'غير محدد',
        criticalMedications: const [],
        doctorName: 'غير محدد',
        hospital: 'غير محدد',
        location: 'الموقع غير محدد',
        nextTask: 'لا توجد مهام مسجلة',
        nextTaskTime: '--:--',
        pairingCode: '——',
        watchBattery: 0,
        watchConnected: true,
        watchModel: 'ساعة ذكية',
      );
      expect(m.watchBattery, 0);
      expect(m.pairingCode, '——');
      expect(m.healthStatus, 'غير متوفر');
    });
  });
}
