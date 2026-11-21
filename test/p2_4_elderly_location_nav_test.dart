import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// P2.4 UX: elderly Home «الموقع» must open LocationPageElderly (not ReturnHomePage).
void main() {
  test(
    'home_page الموقع tile navigates to /location-elderly',
    () {
      final src = File('lib/pages/home_page.dart').readAsStringSync();
      expect(src, isNot(contains("import 'return_home_page.dart'")));

      final tileIdx = src.indexOf("title: 'الموقع'");
      expect(tileIdx, greaterThanOrEqualTo(0));
      final end = (tileIdx + 2200).clamp(0, src.length);
      final tile = src.substring(tileIdx, end);
      expect(tile, contains("'/location-elderly'"));
      expect(tile, contains('pushNamed'));
      expect(tile, isNot(contains('ReturnHomePage')));
    },
  );

  test(
    'LocationPageElderly keeps return-home as secondary flow',
    () {
      final src = File('lib/pages/location_page_elderly.dart').readAsStringSync();
      expect(src, contains("Navigator.pushNamed(context, '/return-home')"));
      expect(src, contains('العودة للمنزل'));
    },
  );

  test(
    'ReturnHomePage still routes to location-elderly for sharing',
    () {
      final src = File('lib/pages/return_home_page.dart').readAsStringSync();
      expect(src, contains("Navigator.pushNamed(context, '/location-elderly')"));
      expect(src, contains('مشاركة موقعي'));
      final mainSrc = File('lib/main.dart').readAsStringSync();
      expect(mainSrc, contains("'/return-home'"));
      expect(mainSrc, contains("'/location-elderly'"));
      expect(mainSrc, contains('LocationPageElderly'));
      expect(mainSrc, contains('ReturnHomePage'));
    },
  );

  test(
    'simple return-home exposes مشاركة موقعي entry',
    () {
      final src =
          File('lib/pages/simple_elderly/simple_return_home_page.dart')
              .readAsStringSync();
      expect(src, contains("'/location-elderly'"));
      expect(src, contains('مشاركة موقعي'));
    },
  );
}
