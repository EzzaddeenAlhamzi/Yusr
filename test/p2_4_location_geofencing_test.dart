import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusr1/core/geo/geofence_math.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:yusr1/core/location/location_access_gate.dart';
import 'package:yusr1/core/location/location_alert_category.dart';
import 'package:yusr1/core/location/location_freshness.dart';
import 'package:yusr1/core/map/osm_tile_provider.dart';
import 'package:yusr1/core/services/auth_service.dart';
import 'package:yusr1/core/services/location_sharing_service.dart';
import 'package:yusr1/core/widgets/yusr_map_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2.4 OsmTileProvider (CARTO Free)', () {
    tearDown(() {
      OsmTileProvider.overrideUrlTemplate = null;
      OsmTileProvider.overrideApiKey = null;
    });

    test('missing key → empty URL + Arabic config error (no silent tiles)', () {
      OsmTileProvider.overrideApiKey = '';
      expect(OsmTileProvider.hasApiKey, isFalse);
      expect(OsmTileProvider.urlTemplate, isEmpty);
      expect(OsmTileProvider.fallbackUrl, isNull);
      expect(
        OsmTileProvider.missingKeyErrorArabic,
        contains('CARTO'),
      );
      expect(
        OsmTileProvider.missingKeyErrorArabic,
        contains('YUSR_CARTO_API_KEY'),
      );
    });

    test('key present builds CARTO URL without OSM France', () {
      // Fake test key — not a real secret.
      OsmTileProvider.overrideApiKey = 'test-carto-key';
      expect(OsmTileProvider.hasApiKey, isTrue);
      final url = OsmTileProvider.urlTemplate;
      expect(url, contains('basemaps.cartocdn.com'));
      expect(url, contains('rastertiles/voyager'));
      expect(url, contains('{z}'));
      expect(url, contains('{x}'));
      expect(url, contains('{y}'));
      expect(url, contains('key=test-carto-key'));
      expect(url, isNot(contains('openstreetmap.fr')));
      expect(url, isNot(contains('tile.openstreetmap.org')));
      expect(OsmTileProvider.fallbackUrl, isNull);
      expect(OsmTileProvider.attributionText.toLowerCase(), contains('openstreetmap'));
      expect(OsmTileProvider.attributionText.toUpperCase(), contains('CARTO'));
      expect(OsmTileProvider.httpUserAgent, contains('YusrMobile'));
      expect(
        OsmTileProvider.tileLoadErrorArabic,
        'تعذر تحميل الخريطة، تحقق من اتصال الإنترنت وحاول مرة أخرى',
      );
    });

    test('provider source does not embed a hardcoded production key', () {
      // Guard: committed Dart sources must not contain key=<long secret>.
      final source = File('lib/core/map/osm_tile_provider.dart').readAsStringSync();
      expect(OsmTileProvider.templateLooksLikeHardcodedSecret(source), isFalse);
      expect(source, isNot(contains('openstreetmap.fr')));
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

    test('3-hour-old is never «تم تحديث الموقع مؤخرًا»', () {
      final now = DateTime.utc(2026, 11, 21, 18, 0);
      final threeHoursAgo = now.subtract(const Duration(hours: 3));
      final code = LocationFreshness.fromTimestamp(threeHoursAgo, now: now);
      expect(code, LocationFreshness.stale);
      expect(
        LocationFreshness.arabicBannerTitle(code),
        isNot(contains('تم تحديث الموقع مؤخرًا')),
      );
      expect(LocationFreshness.arabicBannerTitle(code), 'الموقع قديم');
      expect(LocationFreshness.formatAge(threeHoursAgo, now: now), contains('3'));
    });

    test('resolve prefers timestamp over stale server fresh enum', () {
      final now = DateTime.utc(2026, 11, 21, 18, 0);
      final code = LocationFreshness.resolve(
        capturedAt: now.subtract(const Duration(hours: 3)),
        serverFreshness: 'fresh',
        now: now,
      );
      expect(code, LocationFreshness.stale);
    });

    test('UTC naive MySQL string ages correctly vs UTC now', () {
      final now = DateTime.utc(2026, 11, 21, 15, 0);
      final at = LocationFreshness.parseObservationTime('2026-11-21 12:00:00');
      expect(at, isNotNull);
      expect(at!.isUtc, isTrue);
      final code = LocationFreshness.fromTimestamp(at, now: now);
      expect(code, LocationFreshness.stale);
      expect(LocationFreshness.formatAge(at, now: now), 'العمر: 3 ساعة');
    });

    test('aging without new API: same capture becomes stale later', () {
      final capture = DateTime.utc(2026, 11, 21, 12, 0);
      expect(
        LocationFreshness.fromTimestamp(
          capture,
          now: capture.add(const Duration(minutes: 1)),
        ),
        LocationFreshness.fresh,
      );
      expect(
        LocationFreshness.fromTimestamp(
          capture,
          now: capture.add(const Duration(hours: 3)),
        ),
        LocationFreshness.stale,
      );
    });

    test('future/invalid timestamps are not fresh', () {
      final now = DateTime.utc(2026, 11, 21, 12, 0);
      expect(
        LocationFreshness.fromTimestamp(
          now.add(const Duration(hours: 5)),
          now: now,
        ),
        LocationFreshness.unknown,
      );
      expect(LocationFreshness.parseObservationTime(''), isNull);
      expect(LocationFreshness.fromTimestamp(null), LocationFreshness.unknown);
    });
  });

  group('P2.4 GPS feedback Arabic constants', () {
    test('services-off and permission-denied copy is Arabic', () {
      expect(LocationSharingService.errServicesOff, contains('مطفأة'));
      expect(LocationSharingService.errPermissionDenied, contains('رفض'));
      expect(
        LocationSharingService.errPermissionPermanentlyDenied,
        contains('نهائي'),
      );
      expect(LocationSharingService.errApproximateOnly, contains('التقريبي'));
    });
  });

  group('P2.4 permission deny gate (no false GPS success)', () {
    tearDown(() async {
      await LocationSharingService.instance.clearLocalState();
    });

    test('denied after fix → Arabic error, no success / no freshness bump',
        () async {
      final svc = LocationSharingService.instance;
      await svc.clearLocalState();
      svc.debugSetServerSharingEnabled(true);

      // Platform returns a fused fix, but permission is denied (pm revoke case).
      var getCurrentCalls = 0;
      svc.accessGate = LocationAccessGate(
        servicesEnabled: () async => true,
        checkGeoPermission: () async => LocationPermission.denied,
        requestGeoPermission: () async => LocationPermission.denied,
        whenInUseStatus: () async => ph.PermissionStatus.denied,
        fineStatus: () async => ph.PermissionStatus.denied,
        requestWhenInUse: () async => ph.PermissionStatus.denied,
        locationAccuracy: () async => LocationAccuracyStatus.reduced,
      );
      // Gate must refuse before success — getCurrent must not unlock publish.
      svc.debugGetCurrentPosition = () async {
        getCurrentCalls++;
        return Position(
          longitude: 44.1910,
          latitude: 15.3694,
          timestamp: DateTime.now(),
          accuracy: 12,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      };

      final beforePublish = svc.lastSuccessfulPublishAt;
      final pos = await svc.acquireCurrentPosition();
      expect(pos, isNull);
      expect(svc.lastError, LocationSharingService.errPermissionDenied);
      expect(svc.lastSuccessfulPublishAt, beforePublish);

      // publishOnce must also fail without claiming GPS success.
      final published = await svc.publishOnce(manual: true);
      expect(published, isFalse);
      expect(svc.lastError, LocationSharingService.errPermissionDenied);
      expect(svc.lastSuccessfulPublishAt, isNull);
      // Denied before read → getCurrent never consulted for success.
      expect(getCurrentCalls, 0);
    });

    test('post-fix revoke: position discarded when re-check denies', () async {
      final svc = LocationSharingService.instance;
      await svc.clearLocalState();
      svc.debugSetServerSharingEnabled(true);

      var geoPerm = LocationPermission.whileInUse;
      var whenInUse = ph.PermissionStatus.granted;
      var fine = ph.PermissionStatus.granted;

      svc.accessGate = LocationAccessGate(
        servicesEnabled: () async => true,
        checkGeoPermission: () async => geoPerm,
        requestGeoPermission: () async => geoPerm,
        whenInUseStatus: () async => whenInUse,
        fineStatus: () async => fine,
        requestWhenInUse: () async => whenInUse,
        locationAccuracy: () async => LocationAccuracyStatus.precise,
      );
      svc.debugGetCurrentPosition = () async {
        // Simulate mid-flight revoke after fused provider returns a fix.
        geoPerm = LocationPermission.denied;
        whenInUse = ph.PermissionStatus.denied;
        fine = ph.PermissionStatus.denied;
        return Position(
          longitude: 44.1910,
          latitude: 15.3694,
          timestamp: DateTime.now(),
          accuracy: 12,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      };

      final pos = await svc.acquireCurrentPosition();
      expect(pos, isNull);
      expect(svc.lastError, LocationSharingService.errPermissionDenied);
      expect(svc.lastKnownPosition, isNull);
    });

    test('approximate-only is allowed with Arabic warning (not deny)', () async {
      final svc = LocationSharingService.instance;
      await svc.clearLocalState();
      svc.debugSetServerSharingEnabled(true);

      svc.accessGate = LocationAccessGate(
        servicesEnabled: () async => true,
        checkGeoPermission: () async => LocationPermission.whileInUse,
        requestGeoPermission: () async => LocationPermission.whileInUse,
        whenInUseStatus: () async => ph.PermissionStatus.granted,
        fineStatus: () async => ph.PermissionStatus.denied,
        requestWhenInUse: () async => ph.PermissionStatus.granted,
        locationAccuracy: () async => LocationAccuracyStatus.reduced,
      );
      svc.debugGetCurrentPosition = () async => Position(
            longitude: 44.1910,
            latitude: 15.3694,
            timestamp: DateTime.now(),
            accuracy: 500,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );

      final pos = await svc.acquireCurrentPosition();
      expect(pos, isNotNull);
      expect(svc.lastError, isNull);
      expect(svc.lastWarning, LocationSharingService.errApproximateOnly);
    });
  });

  group('P2.4 unread EXIT status', () {
    test('Arabic غير مقروء is treated as unread for EXIT UI', () {
      // Mirror caregiver unread gate used for EXIT banner.
      bool isUnread(String status) =>
          status == 'unread' ||
          status == 'Unread' ||
          status == 'جديد' ||
          status == 'غير مقروء' ||
          status == 'Active' ||
          status.isEmpty;
      expect(isUnread('غير مقروء'), isTrue);
      expect(isUnread('read'), isFalse);
      expect(
        LocationAlertCategory.classify(eventType: 'safe_zone_exit'),
        LocationAlertCategory.zoneExit,
      );
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
    tearDown(() {
      OsmTileProvider.overrideApiKey = null;
      OsmTileProvider.overrideUrlTemplate = null;
    });

    testWidgets('missing CARTO key shows Arabic configuration error',
        (tester) async {
      OsmTileProvider.overrideApiKey = '';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: YusrMapView(
              latitude: 15.3694,
              longitude: 44.1910,
              height: 200,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(OsmTileProvider.missingKeyErrorArabic), findsOneWidget);
      expect(find.textContaining('غير معروف'), findsNothing);
    });

    testWidgets('shows unknown overlay when no coordinates', (tester) async {
      OsmTileProvider.overrideApiKey = 'test-carto-key';
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
      OsmTileProvider.overrideApiKey = 'test-carto-key';
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
