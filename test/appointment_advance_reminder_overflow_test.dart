import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yusr1/core/constants/app_colors.dart';
import 'package:yusr1/core/widgets/appointment_advance_reminder_line.dart';

/// Labels that must remain fully readable on the caregiver appointment card.
const _advanceLabels = <String>[
  'بدون تذكير مسبق',
  'قبل الموعد بـ 15 دقيقة',
  'قبل الموعد بـ 30 دقيقة',
  'قبل الموعد بساعة',
  'قبل الموعد بيوم واحد',
];

/// Mimics the caregiver card header row that overflowed by 6.5px @ 30m.
Widget _caregiverCardMeta({
  required String advanceReminder,
  required double textScale,
}) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 740),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.medical_services_rounded,
                      color: Color(0xFF1976D2),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'P23Rem2253',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 13, color: AppColors.mainColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '2026-11-21  الساعة 16:22',
                                softWrap: true,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.mainColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (AppointmentAdvanceReminderLine.shouldShow(
                            advanceReminder)) ...[
                          const SizedBox(height: 2),
                          AppointmentAdvanceReminderLine(
                            advanceReminder: advanceReminder,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.mainColor, size: 20),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFE53935), size: 20),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<FlutterErrorDetails>> pumpAndCollectOverflow(
    WidgetTester tester,
    Widget child,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      oldHandler?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = oldHandler;
    });

    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
    return errors
        .where((e) {
          final text = e.exceptionAsString();
          return text.contains('OVERFLOWED') || text.contains('overflowed');
        })
        .toList();
  }

  group('AppointmentAdvanceReminderLine overflow regression', () {
    for (final label in _advanceLabels) {
      testWidgets('no overflow @1.0 — $label', (tester) async {
        final overflow = await pumpAndCollectOverflow(
          tester,
          _caregiverCardMeta(advanceReminder: label, textScale: 1.0),
        );
        expect(overflow, isEmpty,
            reason: overflow.map((e) => e.exceptionAsString()).join('\n'));
        if (AppointmentAdvanceReminderLine.shouldShow(label)) {
          expect(find.textContaining(label), findsOneWidget);
        }
      });

      testWidgets('no overflow @1.3 enlarged — $label', (tester) async {
        final overflow = await pumpAndCollectOverflow(
          tester,
          _caregiverCardMeta(advanceReminder: label, textScale: 1.3),
        );
        expect(overflow, isEmpty,
            reason: overflow.map((e) => e.exceptionAsString()).join('\n'));
        if (AppointmentAdvanceReminderLine.shouldShow(label)) {
          expect(find.textContaining(label), findsOneWidget);
        }
      });
    }

    testWidgets('Off label is not rendered as reminder line', (tester) async {
      await tester.pumpWidget(
        _caregiverCardMeta(
          advanceReminder: 'بدون تذكير مسبق',
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('تذكير مسبق:'), findsNothing);
      expect(AppointmentAdvanceReminderLine.shouldShow('بدون تذكير مسبق'),
          isFalse);
    });
  });
}
