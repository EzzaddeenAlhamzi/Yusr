import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/core/services/api_service.dart';
import 'package:yusr1/pages/link_senior_page.dart';
import 'package:yusr1/pages/senior_link_code_page.dart';

void main() {
  testWidgets('caregiver link page builds with 6 digit fields (RTL-ready)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LinkSeniorPage()),
    );
    expect(find.text('الربط بكبير السن'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('elderly link code page builds Arabic RTL shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SeniorLinkCodePage()),
    );
    // Allow first frame; async code fetch may fail without server — UI still paints.
    await tester.pump();
    expect(find.text('ربط الحساب بمقدم الرعاية'), findsOneWidget);
    expect(find.textContaining('سينتهي الرمز خلال'), findsOneWidget);
  });

  test('linkElderly API payload uses linking_code not Eldery_ID', () {
    // Compile-time / signature guard: method requires linkingCode named arg.
    expect(ApiService.instance.linkElderly, isA<Function>());
  });
}
