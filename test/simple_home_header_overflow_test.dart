import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/pages/simple_elderly/simple_home_page.dart';

void main() {
  testWidgets('simple home header does not overflow on narrow phone',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      oldHandler?.call(details);
    };

    addTearDown(() {
      FlutterError.onError = oldHandler;
    });

    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SimpleHomeTopHeader(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overflow = errors.where((e) {
      final text = e.exceptionAsString();
      return text.contains('OVERFLOWED') || text.contains('overflowed');
    });
    expect(overflow, isEmpty, reason: overflow.map((e) => e.exceptionAsString()).join('\n'));
  });

  testWidgets('simple home page header survives text scale 1.3', (tester) async {
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

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 740),
          textScaler: TextScaler.linear(1.3),
        ),
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(child: SimpleHomeTopHeader()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overflow = errors.where((e) {
      final text = e.exceptionAsString();
      return text.contains('OVERFLOWED') || text.contains('overflowed');
    });
    expect(overflow, isEmpty);
  });

  testWidgets('full SimpleHomePage pumps without header overflow at 360px',
      (tester) async {
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

    await tester.pumpWidget(
      const MaterialApp(home: SimpleHomePage()),
    );
    await tester.pump();

    final overflow = errors.where((e) {
      final text = e.exceptionAsString();
      return text.contains('OVERFLOWED') || text.contains('overflowed');
    });
    expect(overflow, isEmpty);
    // SOS uses stacked outline Text widgets — assert presence, not uniqueness.
    expect(find.text('SOS'), findsWidgets);
    expect(find.text('الوضع المتقدم'), findsOneWidget);
  });
}
