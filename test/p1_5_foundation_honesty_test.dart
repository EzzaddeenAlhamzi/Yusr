import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/core/models/senior_model.dart';
import 'package:yusr1/core/services/api_service.dart';
import 'package:yusr1/core/services/senior_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P1.5 SeniorModel / Manager honesty', () {
    test('defaults do not invent gender ذكر or health مستقر', () {
      final m = SeniorModel(
        id: 'x',
        name: 'ت',
        relationship: 'قريب',
        age: 70,
        bloodType: 'O+',
        chronicDiseases: const [],
        allergies: '',
        criticalMedications: const [],
        doctorName: '',
        hospital: '',
        location: '',
        nextTask: '',
        nextTaskTime: '',
        pairingCode: '——',
      );
      expect(m.gender, 'غير محدد');
      expect(m.healthStatus, 'غير متوفر');
      expect(m.watchBattery, 0);
      expect(m.watchConnected, isFalse);
    });

    test('addSenior refuses local invent without API password', () async {
      final before = SeniorManager().seniors.length;
      final ok = await SeniorManager().addSenior(
        SeniorModel(
          id: 'local_fake',
          name: 'وهمي',
          relationship: 'قريب',
          age: 70,
          bloodType: 'O+',
          chronicDiseases: const [],
          allergies: '',
          criticalMedications: const [],
          doctorName: '',
          hospital: '',
          location: '',
          nextTask: '',
          nextTaskTime: '',
          pairingCode: 'YS-9999',
        ),
      );
      expect(ok, isFalse);
      expect(SeniorManager().seniors.length, before);
    });

    test('empty currentSenior placeholder is not مستقر', () {
      SeniorManager().clear();
      final empty = SeniorManager().currentSenior;
      expect(empty.healthStatus, isNot(equals('مستقر')));
      expect(empty.watchBattery, 0);
    });
  });

  group('P1.5 addDevice serial honesty', () {
    test('addDevice rejects empty serial without inventing YS-WATCH-1', () async {
      final res = await ApiService.instance.addDevice(
        elderlyId: 1,
        deviceType: 'ساعة ذكية',
        deviceName: 'اختبار',
        number: '',
      );
      expect(res['status'], 'error');
      expect(res['success'], isFalse);
      expect(res['message'], contains('مطلوب'));
      // Must not invent a YS-* number in the response payload.
      expect(res['T_Number'], isNull);
    });
  });
}
