import 'package:arabic_voice_feasibility/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('feasibility banner and mic control render', (tester) async {
    await tester.pumpWidget(const ArabicVoiceFeasibilityApp());
    await tester.pump();

    expect(find.textContaining('NON-PRODUCTION'), findsOneWidget);
    expect(find.bySemanticsLabel('بدء الاستماع'), findsOneWidget);
  });
}
