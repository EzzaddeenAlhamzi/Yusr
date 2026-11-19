import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/core/services/api_service.dart';
import 'package:yusr1/shard/appointment_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('past appointment filtering honesty', () {
    test('AppointmentItem keeps server id for delete', () {
      final item = AppointmentItem(
        id: '42',
        title: 'فحص',
        day: '2024-01-01',
        time: '09:00',
        date: '2024-01-01',
      );
      expect(item.id, '42');
      expect(int.tryParse(item.id), 42);
    });

    test('listDataOrEmpty treats appointment error as empty+error', () {
      final rows = ApiService.listDataOrEmpty({
        'status': 'error',
        'message': 'غير مصرح',
      });
      expect(rows, isEmpty);
      expect(ApiService.lastListError, 'غير مصرح');
    });
  });

  group('E appointments UPDATE deferred honesty (source contract)', () {
    test('caregiver appointments page defers UPDATE instead of delete+add', () {
      final src = File('lib/pages/appointments_page.dart').readAsStringSync();
      expect(
        src.contains(
          'تعديل الموعد على الخادم غير متاح حالياً. احذف الموعد وأضفه من جديد.',
        ),
        isTrue,
      );
      // Must not silently recreate on edit save.
      expect(
        src.contains('do not fake success via silent delete+recreate'),
        isTrue,
      );
      expect(src.contains("res['status'] != 'success'"), isTrue);
    });

    test('elderly dates page keeps UPDATE deferred message', () {
      final src = File('lib/pages/dates.dart').readAsStringSync();
      expect(
        src.contains(
          'تعديل الموعد على الخادم غير متاح حالياً. احذف الموعد وأضفه من جديد.',
        ),
        isTrue,
      );
    });
  });
}
