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
}
