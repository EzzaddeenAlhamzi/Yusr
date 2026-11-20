import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/core/services/api_service.dart';
import 'package:yusr1/pages/appointments_page.dart';
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

  group('E appointments UPDATE honesty (P2.1 — real UPDATE, no fake success)', () {
    test('caregiver appointments page uses updateAppointment (not delete+add)', () {
      final src = File('lib/pages/appointments_page.dart').readAsStringSync();
      expect(src.contains('updateAppointment('), isTrue);
      expect(
        src.contains(
          'تعديل الموعد على الخادم غير متاح حالياً. احذف الموعد وأضفه من جديد.',
        ),
        isFalse,
      );
      expect(src.contains("res['status'] != 'success'"), isTrue);
      final editStart = src.indexOf('void _showEditAppointmentDialog');
      final editEnd = src.indexOf('void _confirmDeleteAppointment');
      final editFn = src.substring(editStart, editEnd);
      expect(editFn.contains('deleteAppointment'), isFalse);
      expect(editFn.contains('addAppointment'), isFalse);
    });

    test('elderly dates page uses updateAppointment (not deferred message)', () {
      final src = File('lib/pages/dates.dart').readAsStringSync();
      expect(src.contains('updateAppointment('), isTrue);
      expect(
        src.contains(
          'تعديل الموعد على الخادم غير متاح حالياً. احذف الموعد وأضفه من جديد.',
        ),
        isFalse,
      );
    });
  });

  group('E invalid date / API failure must surface error (no silent success)', () {
    test('rejects impossible calendar dates like 2026-13-40', () {
      expect(
        AppointmentsPage.isValidAppointmentDateForTest('2026-13-40'),
        isFalse,
      );
      expect(
        AppointmentsPage.isValidAppointmentDateForTest('2026-12-20'),
        isTrue,
      );
      expect(
        AppointmentsPage.isValidAppointmentDateForTest('not-a-date'),
        isFalse,
      );
    });

    test('SQLSTATE / exception payloads map to Arabic user message', () {
      final msg = AppointmentsPage.appointmentErrorMessageForTest({
        'status': 'error',
        'message':
            'SQLSTATE[22007]: Invalid datetime format: 1292 Incorrect date value',
      });
      expect(msg.contains('SQLSTATE'), isFalse);
      expect(msg.contains('تاريخ'), isTrue);
    });

    test('add dialog uses page messenger after pop (not dialog context)', () {
      final src = File('lib/pages/appointments_page.dart').readAsStringSync();
      expect(src.contains('pageMessenger'), isTrue);
      expect(
        src.contains(
          'Capture page messenger before dialog — StatefulBuilder shadows',
        ),
        isTrue,
      );
      expect(src.contains('_isValidAppointmentDate'), isTrue);
      // Error path must show via pageMessenger (survives dialog pop).
      expect(src.contains('pageMessenger.showSnackBar'), isTrue);
      final addFnStart = src.indexOf('void _showAddAppointmentDialog');
      final addFnEnd = src.indexOf('void _showEditAppointmentDialog');
      expect(addFnStart, greaterThan(0));
      expect(addFnEnd, greaterThan(addFnStart));
      final addFn = src.substring(addFnStart, addFnEnd);
      expect(addFn.contains('pageMessenger.showSnackBar'), isTrue);
      // Add path must not gate API error UI on shadowed dialog `context.mounted`.
      expect(addFn.contains('if (!context.mounted) return;'), isFalse);
      expect(addFn.contains("res['status'] != 'success'"), isTrue);
    });

    testWidgets('invalid typed date shows Arabic error snackbar on add',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AppointmentsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final openAdd = find.text('إضافة موعد جديد');
      expect(openAdd, findsOneWidget);
      await tester.ensureVisible(openAdd);
      await tester.tap(openAdd);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('إضافة موعد أو فحص جديد'), findsOneWidget);

      final dateFields = find.byType(TextField);
      expect(dateFields, findsWidgets);
      var filledInvalidDate = false;
      for (final element in dateFields.evaluate().toList()) {
        final widget = element.widget as TextField;
        final controller = widget.controller;
        if (controller != null &&
            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(controller.text)) {
          await tester.enterText(find.byWidget(widget), '2026-13-40');
          filledInvalidDate = true;
        }
      }
      expect(filledInvalidDate, isTrue);
      await tester.pump();

      final save = find.text('إضافة الموعد');
      expect(save, findsOneWidget);
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Client-side validation shows snackbar without leaving a silent success.
      expect(find.textContaining('تاريخ الموعد غير صالح'), findsOneWidget);
      // Dialog should remain open when validation fails before pop.
      expect(find.text('إضافة موعد أو فحص جديد'), findsOneWidget);
    });
  });
}
