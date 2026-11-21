import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusr1/core/geo/geofence_math.dart';
import 'package:yusr1/core/location/location_alert_category.dart';
import 'package:yusr1/core/location/location_freshness.dart';
import 'package:yusr1/core/map/osm_tile_provider.dart';
import 'package:yusr1/core/services/auth_service.dart';
import 'package:yusr1/core/services/location_sharing_service.dart';
import 'package:yusr1/core/widgets/yusr_map_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2.4 OsmTileProvider', () {
    tearDown(() {
      OsmTileProvider.overrideUrlTemplate = null;
    });

    test('uses legitimate OSM-derived tiles (not OSMF public CDN)', () {
      expect(OsmTileProvider.urlTemplate, contains('{z}'));
      expect(OsmTileProvider.urlTemplate, contains('{x}'));
      expect(OsmTileProvider.urlTemplate, contains('{y}'));
      expect(OsmTileProvider.urlTemplate, isNot(contains('tile.openstreetmap.org')));
      expect(OsmTileProvider.urlTemplate, contains('openstreetmap.fr'));
      expect(OsmTileProvider.fallbackUrl, contains('cartocdn.com'));
      expect(OsmTileProvider.attributionText.toLowerCase(), contains('openstreetmap'));
      expect(OsmTileProvider.httpUserAgent, contains('YusrMobile'));
      expect(OsmTileProvider.userAgentPackageName, isNotEmpty);
      expect(
        OsmTileProvider.tileLoadErrorArabic,
        'تعذر تحميل الخريطة، تحقق من اتصال الإنترنت وحاول مرة أخرى',
      );
    });
  });

  group('P2.4 EXIT vs SOS categories', () {
    test('safe_zone_exit is not SOS', () {
      expect(
        LocationAlertCategory.classify(
          eventType: 'safe_zone_exit',
          title: 'خروج من المنطقة الآمنة',
          message: 'غادر كبير السن منطقة «المنزل».',
        ),
        LocationAlertCategory.zoneExit,
      );
      expect(
        LocationAlertCategory.classify(
          eventType: 'sos',
          title: 'بلاغ طوارئ',
          message: 'نداء استغاثة طارئ SOS',
        ),
        LocationAlertCategory.sos,
      );
      expect(
        LocationAlertCategory.classify(
          eventType: 'safe_zone_enter',
          title: 'دخول إلى المنطقة',
        ),
        LocationAlertCategory.zoneEnter,
      );
    });
  });

  group('P2.4 LocationFreshness Arabic honesty', () {
    test('never exposes English enum tokens in Arabic labels', () {
      for (final code in [
        LocationFreshness.fresh,
        LocationFreshness.recent,
        LocationFreshness.stale,
        LocationFreshness.old,
        LocationFreshness.unknown,
        LocationFreshness.sharingStopped,
        LocationFreshness.noData,
        LocationFreshness.updateFailed,
      ]) {
        final ar = LocationFreshness.arabicLabel(code);
        expect(ar, isNot(contains(code)));
        expect(ar.toLowerCase(), isNot(contains('fresh')));
        expect(ar.toLowerCase(), isNot(contains('stale')));
        expect(ar, isNot(contains('live')));
      }
      expect(
        LocationFreshness.arabicBannerTitle(LocationFreshness.fresh),
        isNot(contains('مباشر')),
      );
      expect(
        LocationFreshness.arabicBannerSubtitle(LocationFreshness.fresh),
        isNot(contains('حي ومباشر')),
      );
    });

    test('formats Arabic-readable timestamps (no raw ISO)', () {
      final dt = DateTime(2026, 11, 21, 15, 23, 29);
      final s = LocationFreshness.formatArabicDateTime(dt);
      expect(s, isNot(contains('T')));
      expect(s, contains('2026'));
      expect(s, contains('15:23'));
    });
  });

  group('P2.4 GeofenceMath (synthetic GPS labeled)', () {
    test('synthetic: center is INSIDE with tight accuracy', () {
      // SYNTHETIC fixture — not a live device fix.
      final state = GeofenceMath.classify(
        lat: 15.3694,
        lng: 44.1910,
        accuracyMeters: 5,
        centerLat: 15.3694,
        centerLng: 44.1910,
        radiusMeters: 100,
      );
      expect(state, GeofenceMath.stateInside);
    });

    test('synthetic: far point is OUTSIDE', () {
      final state = GeofenceMath.classify(
        lat: 15.3900,
        lng: 44.1910,
        accuracyMeters: 5,
        centerLat: 15.3694,
        centerLng: 44.1910,
        radiusMeters: 100,
      );
      expect(state, GeofenceMath.stateOutside);
    });

    test('synthetic: missing GPS is UNKNOWN (no false safe)', () {
      final state = GeofenceMath.classify(
        lat: null,
        lng: null,
        accuracyMeters: null,
        centerLat: 15.3694,
        centerLng: 44.1910,
        radiusMeters: 100,
      );
      expect(state, GeofenceMath.stateUnknown);
    });

    test('synthetic: large accuracy near edge is BOUNDARY_UNCERTAIN', () {
      final state = GeofenceMath.classify(
        lat: 15.3694,
        lng: 44.1910,
        accuracyMeters: 80,
        centerLat: 15.3694,
        centerLng: 44.1910,
        radiusMeters: 50,
      );
      expect(state, GeofenceMath.stateBoundaryUncertain);
    });

    test('haversine zero distance', () {
      expect(
        GeofenceMath.haversineMeters(15.0, 44.0, 15.0, 44.0),
        closeTo(0, 0.01),
      );
    });
  });

  group('P2.4 LocationSharingService foreground policy', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('interval is 60 seconds (L2)', () {
      expect(
        LocationSharingService.updateInterval,
        const Duration(seconds: 60),
      );
    });

    test('loop starts stopped; clearLocalState resets', () async {
      final svc = LocationSharingService.instance;
      svc.stopForegroundLoop();
      expect(svc.isForegroundLoopRunning, isFalse);
      await svc.clearLocalState();
      expect(svc.serverSharingEnabled, isFalse);
      expect(svc.lastKnownPosition, isNull);
    });

    test('M-P24-2: sessionCleanupHook clears location sharing state', () async {
      final svc = LocationSharingService.instance;
      AuthService.sessionCleanupHook = () => svc.clearLocalState();
      addTearDown(() {
        AuthService.sessionCleanupHook = null;
      });

      // Simulate leftover in-memory sharing flag from a prior session.
      svc.stopForegroundLoop();
      await svc.clearLocalState();
      expect(svc.serverSharingEnabled, isFalse);

      var hookRan = false;
      AuthService.sessionCleanupHook = () async {
        hookRan = true;
        await svc.clearLocalState();
      };

      await AuthService.sessionCleanupHook?.call();
      expect(hookRan, isTrue);
      expect(svc.isForegroundLoopRunning, isFalse);
      expect(svc.serverSharingEnabled, isFalse);
      expect(svc.lastKnownPosition, isNull);
    });
  });

  group('P2.4 YusrMapView widget', () {
    testWidgets('shows unknown overlay when no coordinates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: YusrMapView(
              latitude: null,
              longitude: null,
              height: 200,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('غير معروف'), findsOneWidget);
      expect(find.textContaining(OsmTileProvider.attributionText), findsOneWidget);
    });

    testWidgets('tile failure shows Arabic error and retry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: YusrMapView(
              latitude: 15.3694,
              longitude: 44.1910,
              height: 220,
              debugForceTilesFailed: true,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(OsmTileProvider.tileLoadErrorArabic), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      expect(find.text(OsmTileProvider.tileLoadErrorArabic), findsNothing);
    });
  });

  group('P2.4 AndroidManifest foreground permissions', () {
    test('declares fine/coarse location and not background', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml');
      expect(manifest.existsSync(), isTrue);
      final text = manifest.readAsStringSync();
      expect(text, contains('ACCESS_FINE_LOCATION'));
      expect(text, contains('ACCESS_COARSE_LOCATION'));
      // Permission declaration must not appear as uses-permission (comment OK).
      expect(
        text.contains('android.permission.ACCESS_BACKGROUND_LOCATION'),
        isFalse,
      );
    });

    test('iOS Info.plist has WhenInUse description', () {
      final plist = File('ios/Runner/Info.plist');
      expect(plist.existsSync(), isTrue);
      final text = plist.readAsStringSync();
      expect(text, contains('NSLocationWhenInUseUsageDescription'));
      expect(text.contains('NSLocationAlwaysAndWhenInUseUsageDescription'), isFalse);
      expect(text.contains('NSLocationAlwaysUsageDescription'), isFalse);
    });
  });
}
