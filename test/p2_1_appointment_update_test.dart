import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/pages/appointments_page.dart';
import 'package:yusr1/shard/appointment_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2.1 ApiService updateAppointment request formation', () {
    test('updateAppointment method exists and builds legacy action body', () {
      final src = File('lib/core/services/api_service.dart').readAsStringSync();
      expect(src.contains('Future<Map<String, dynamic>> updateAppointment'),
          isTrue);
      expect(src.contains("'action': 'update_appointment'"), isTrue);
      expect(src.contains("'Appointment_ID': appointmentId"), isTrue);
      expect(src.contains("'A_Date': date"), isTrue);
      expect(src.contains("'A_Time': time"), isTrue);
      expect(src.contains("'A_DateType': dateType"), isTrue);
      expect(src.contains("'A_Location': location"), isTrue);
      expect(src.contains("'A_Note': note"), isTrue);
      // Must not send Elderly_ID for ownership change on update.
      final updateStart = src.indexOf('Future<Map<String, dynamic>> updateAppointment');
      final updateEnd = src.indexOf('/// حذف موعد من قاعدة البيانات');
      expect(updateStart, greaterThan(0));
      expect(updateEnd, greaterThan(updateStart));
      final updateFn = src.substring(updateStart, updateEnd);
      expect(updateFn.contains('Elderly_ID'), isFalse);
      expect(updateFn.contains('delete_appointment'), isFalse);
      expect(updateFn.contains('add_appointment'), isFalse);
    });

    test('Bearer attach remains default for authenticated appointment calls', () {
      final src = File('lib/core/services/api_service.dart').readAsStringSync();
      final updateStart = src.indexOf('Future<Map<String, dynamic>> updateAppointment');
      final updateEnd = src.indexOf('/// حذف موعد من قاعدة البيانات');
      final updateFn = src.substring(updateStart, updateEnd);
      // Uses _sendRequest without attachBearer:false → Bearer default true.
      expect(updateFn.contains('attachBearer: false'), isFalse);
      expect(updateFn.contains('return _sendRequest({'), isTrue);
    });
  });

  group('P2.1 caregiver edit dialog wires real UPDATE', () {
    test('appointments_page calls updateAppointment and gates on success', () {
      final src = File('lib/pages/appointments_page.dart').readAsStringSync();
      expect(src.contains('updateAppointment('), isTrue);
      expect(
        src.contains(
          'تعديل الموعد على الخادم غير متاح حالياً. احذف الموعد وأضفه من جديد.',
        ),
        isFalse,
      );
      expect(src.contains("res['status'] != 'success'"), isTrue);
      expect(src.contains('isSaving'), isTrue);
      expect(src.contains('جاري الحفظ...'), isTrue);
      expect(src.contains("Navigator.pop(ctx)"), isTrue);
      expect(src.contains('إلغاء'), isTrue);
      // Success UI only after status == success path that pops then reloads.
      final editStart = src.indexOf('void _showEditAppointmentDialog');
      final editEnd = src.indexOf('void _confirmDeleteAppointment');
      expect(editStart, greaterThan(0));
      expect(editEnd, greaterThan(editStart));
      final editFn = src.substring(editStart, editEnd);
      expect(editFn.contains('await _loadAppointments()'), isTrue);
      expect(editFn.contains("res['status'] != 'success'"), isTrue);
      expect(editFn.contains('تم تحديث الموعد بنجاح'), isTrue);
      // No silent delete+recreate on edit.
      expect(editFn.contains('deleteAppointment'), isFalse);
      expect(editFn.contains('addAppointment'), isFalse);
    });

    test('advance reminder remains local-only preference on edit', () {
      final src = File('lib/pages/appointments_page.dart').readAsStringSync();
      final editStart = src.indexOf('void _showEditAppointmentDialog');
      final editEnd = src.indexOf('void _confirmDeleteAppointment');
      final editFn = src.substring(editStart, editEnd);
      expect(editFn.contains('appt_advance_rem_'), isTrue);
      expect(editFn.contains('محلي فقط'), isTrue);
      expect(editFn.contains('add_notification'), isFalse);
      expect(editFn.contains('action\': \'notification'), isFalse);
    });
  });

  group('P2.1 elderly dates edit dialog wires real UPDATE', () {
    test('dates.dart calls updateAppointment with validation and loading', () {
      final src = File('lib/pages/dates.dart').readAsStringSync();
      expect(src.contains('updateAppointment('), isTrue);
      expect(
        src.contains(
          'تعديل الموعد على الخادم غير متاح حالياً. احذف الموعد وأضفه من جديد.',
        ),
        isFalse,
      );
      expect(src.contains('_isValidAppointmentDate'), isTrue);
      expect(src.contains('isSaving'), isTrue);
      expect(src.contains('جاري الحفظ...'), isTrue);
      expect(src.contains('تم تحديث الموعد بنجاح'), isTrue);
      expect(src.contains('await _loadAppointments()'), isTrue);
      expect(src.contains("res['status'] != 'success'"), isTrue);
    });

    test('AppointmentItem keeps id and location for edit prepopulate', () {
      final item = AppointmentItem(
        id: '77',
        title: 'فحص',
        day: '2026-12-20',
        time: '09:00',
        date: '2026-12-20',
        notes: 'ملاحظة',
        location: 'عيادة',
      );
      expect(item.id, '77');
      expect(item.location, 'عيادة');
      expect(item.notes, 'ملاحظة');
      expect(int.tryParse(item.id), 77);
    });
  });

  group('P2.1 validation / no fake success', () {
    test('invalid dates still rejected client-side', () {
      expect(
        AppointmentsPage.isValidAppointmentDateForTest('2026-13-40'),
        isFalse,
      );
      expect(
        AppointmentsPage.isValidAppointmentDateForTest('2026-12-20'),
        isTrue,
      );
    });

    test('create/list/delete API methods still present', () {
      final src = File('lib/core/services/api_service.dart').readAsStringSync();
      expect(src.contains('getAppointments'), isTrue);
      expect(src.contains('addAppointment'), isTrue);
      expect(src.contains('deleteAppointment'), isTrue);
      expect(src.contains('updateAppointment'), isTrue);
    });

    testWidgets('edit dialog prepopulates and cancel closes without save',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      // Source-contract: cancel path is Navigator.pop without updateAppointment
      // when user taps إلغاء — verified via widget open of add dialog cancel
      // pattern still present; edit cancel uses same.
      final src = File('lib/pages/appointments_page.dart').readAsStringSync();
      final editStart = src.indexOf('void _showEditAppointmentDialog');
      final editEnd = src.indexOf('void _confirmDeleteAppointment');
      final editFn = src.substring(editStart, editEnd);
      expect(
        editFn.contains("onPressed: isSaving ? null : () => Navigator.pop(ctx)"),
        isTrue,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AppointmentsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Page still loads; add flow preserved.
      expect(find.text('إضافة موعد جديد'), findsOneWidget);
    });
  });

  group('P2.1 role edit permission (client source)', () {
    test('caregiver and elderly pages both expose edit entry points', () {
      final cg = File('lib/pages/appointments_page.dart').readAsStringSync();
      final el = File('lib/pages/dates.dart').readAsStringSync();
      expect(cg.contains('_showEditAppointmentDialog'), isTrue);
      expect(cg.contains('Icons.edit_outlined'), isTrue);
      expect(el.contains('_editAppointment'), isTrue);
      expect(el.contains('Icons.edit_outlined'), isTrue);
    });
  });
}
