import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/pages/senior_link_code_page.dart';
import 'package:yusr1/pages/simple_elderly/simple_home_page.dart';

/// Guards P1.2 UX gate: authenticated elderly UI must reach `/senior-link-code`
/// without a local harness.
void main() {
  testWidgets('simple home link-code bar navigates to SeniorLinkCodePage',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => const SimpleHomePage(),
          '/senior-link-code': (_) => const SeniorLinkCodePage(),
          '/home-elderly': (_) => const SizedBox.shrink(),
          '/simple-contacts': (_) => const SizedBox.shrink(),
          '/simple-medicines': (_) => const SizedBox.shrink(),
          '/simple-return-home': (_) => const SizedBox.shrink(),
          '/ai': (_) => const SizedBox.shrink(),
        },
      ),
    );
    await tester.pump();

    expect(find.text('رمز ربط العائلة'), findsOneWidget);
    await tester.tap(find.text('رمز ربط العائلة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SeniorLinkCodePage), findsOneWidget);
    expect(find.text('ربط الحساب بمقدم الرعاية'), findsOneWidget);
  });
}
