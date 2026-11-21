import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusr1/core/geo/geofence_math.dart';
import 'package:yusr1/core/map/osm_tile_provider.dart';
import 'package:yusr1/core/services/location_sharing_service.dart';
import 'package:yusr1/core/widgets/yusr_map_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2.4 OsmTileProvider', () {
    test('uses real OSM geographic tile URL (not a fake painter)', () {
      expect(OsmTileProvider.urlTemplate, contains('openstreetmap.org'));
      expect(OsmTileProvider.urlTemplate, contains('{z}'));
      expect(OsmTileProvider.urlTemplate, contains('{x}'));
      expect(OsmTileProvider.urlTemplate, contains('{y}'));
      expect(OsmTileProvider.attributionText.toLowerCase(), contains('openstreetmap'));
      expect(OsmTileProvider.userAgentPackageName, isNotEmpty);
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
