import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/core/location/elderly_location_observation.dart';
import 'package:yusr1/core/location/location_freshness.dart';

/// P2.4 — elderly `_loadLastKnownFromServer` UTC freshness (tests A–H).
///
/// Exercises [ElderlyLocationServerSnapshot.mergeFromServer], the pure form of
/// the elderly load path (prefer `observed_at_utc` → `L_UpdateTime`, UTC parse,
/// no `DateTime.now()` fabrication, no older-overwrite).
void main() {
  const lat = '15.3694';
  const lng = '44.1910';

  Map<String, dynamic> serverLoc({
    String? observedAtUtc,
    String? updateTime,
    String latitude = lat,
    String longitude = lng,
    String? accuracy = '12.5',
  }) {
    return {
      'L_Latitude': latitude,
      'L_Longitude': longitude,
      if (accuracy != null) 'L_AccuracyMeters': accuracy,
      if (observedAtUtc != null) 'observed_at_utc': observedAtUtc,
      if (updateTime != null) 'L_UpdateTime': updateTime,
    };
  }

  group('P2.4 elderly load-path UTC freshness A–H', () {
    test('A — fresh UTC Z stays fresh (not قديم)', () {
      final now = DateTime.utc(2026, 11, 21, 15, 0, 30);
      final snap = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(observedAtUtc: '2026-11-21T15:00:00.000000Z'),
      );
      expect(snap.lat, closeTo(15.3694, 0.0001));
      expect(snap.lng, closeTo(44.1910, 0.0001));
      expect(snap.updatedAt, isNotNull);
      expect(snap.updatedAt!.isUtc, isTrue);
      final code = LocationFreshness.resolve(
        capturedAt: snap.updatedAt,
        hasCoordinates: true,
        now: now,
      );
      expect(code, LocationFreshness.fresh);
      expect(LocationFreshness.arabicLabel(code), 'تم تحديث الموقع مؤخرًا');
      expect(LocationFreshness.formatAge(snap.updatedAt, now: now),
          isNot(contains('3 ساعة')));
    });

    test('B — fresh naive Laravel UTC stays fresh', () {
      final now = DateTime.utc(2026, 11, 21, 15, 0, 30);
      final snap = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(updateTime: '2026-11-21 15:00:00'),
      );
      expect(snap.updatedAt, isNotNull);
      expect(snap.updatedAt!.isUtc, isTrue);
      expect(
        LocationFreshness.fromTimestamp(snap.updatedAt, now: now),
        LocationFreshness.fresh,
      );
      // Prefer observed_at_utc when both present
      final preferZ = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(
          observedAtUtc: '2026-11-21T15:00:00Z',
          updateTime: '2026-11-21 12:00:00', // older legacy must not win
        ),
      );
      expect(
        preferZ.updatedAt!.toUtc(),
        DateTime.utc(2026, 11, 21, 15, 0),
      );
    });

    test('C — Asia/Aden UTC+3 must not age a fresh UTC stamp as ~3h / قديم', () {
      // Aden wall 18:00 == UTC 15:00. Fresh publish stored as naive UTC 15:00.
      final nowUtc = DateTime.utc(2026, 11, 21, 15, 0);
      const naiveUtc = '2026-11-21 15:00:00';
      final snap = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(updateTime: naiveUtc),
      );
      final caregiverAt = LocationFreshness.parseObservationTime(naiveUtc);
      expect(snap.updatedAt, caregiverAt);
      expect(snap.updatedAt!.isUtc, isTrue);

      final code = LocationFreshness.resolve(
        capturedAt: snap.updatedAt,
        hasCoordinates: true,
        now: nowUtc,
      );
      expect(code, LocationFreshness.fresh);
      expect(
        LocationFreshness.arabicBannerTitle(code),
        isNot(equals('الموقع قديم')),
      );
      expect(LocationFreshness.formatAge(snap.updatedAt, now: nowUtc),
          'العمر: أقل من دقيقة');

      // Document the pre-fix bug: DateTime.tryParse(naive) as *local*.
      // When local offset is +3, that invents a 3h-old absolute time.
      final buggyLocal = DateTime.tryParse(naiveUtc);
      expect(buggyLocal, isNotNull);
      if (buggyLocal!.timeZoneOffset == const Duration(hours: 3)) {
        final buggyCode =
            LocationFreshness.fromTimestamp(buggyLocal, now: nowUtc);
        expect(buggyCode, LocationFreshness.stale);
        expect(LocationFreshness.formatAge(buggyLocal, now: nowUtc),
            'العمر: 3 ساعة');
      }
      // Fixed path must agree with caregiver regardless of host TZ.
      expect(
        LocationFreshness.fromTimestamp(caregiverAt, now: nowUtc),
        LocationFreshness.fresh,
      );
    });

    test('D — after API reload, same point stays consistent (no fabricated now)', () {
      final now = DateTime.utc(2026, 11, 21, 15, 1);
      final first = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(observedAtUtc: '2026-11-21T15:00:00Z'),
      );
      // Simulate post-publish reload of the same server row.
      final reloaded = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(
          observedAtUtc: '2026-11-21T15:00:00Z',
          updateTime: '2026-11-21 15:00:00',
        ),
        previousLat: first.lat,
        previousLng: first.lng,
        previousAccuracyM: first.accuracyM,
        previousUpdatedAt: first.updatedAt,
      );
      expect(reloaded.updatedAt, first.updatedAt);
      expect(
        LocationFreshness.resolve(
          capturedAt: reloaded.updatedAt,
          hasCoordinates: true,
          now: now,
        ),
        LocationFreshness.fresh,
      );
      expect(
        LocationFreshness.formatArabicDateTime(reloaded.updatedAt),
        isNot(contains('T')),
      );
    });

    test('E — reopen screen (no prior observation) loads UTC from server', () {
      final now = DateTime.utc(2026, 11, 21, 15, 0, 45);
      final snap = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(
          observedAtUtc: '2026-11-21T15:00:00Z',
          updateTime: '2026-11-21 15:00:00',
        ),
        previousUpdatedAt: null,
      );
      expect(snap.updatedAt, DateTime.utc(2026, 11, 21, 15, 0));
      expect(
        LocationFreshness.fromTimestamp(snap.updatedAt, now: now),
        LocationFreshness.fresh,
      );
    });

    test('F — stale 3h shows قديم (honest age)', () {
      final now = DateTime.utc(2026, 11, 21, 18, 0);
      final snap = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(observedAtUtc: '2026-11-21T15:00:00Z'),
      );
      final code = LocationFreshness.resolve(
        capturedAt: snap.updatedAt,
        hasCoordinates: true,
        now: now,
      );
      expect(code, LocationFreshness.stale);
      expect(LocationFreshness.arabicBannerTitle(code), 'الموقع قديم');
      expect(
        LocationFreshness.arabicLabel(code),
        isNot(contains('تم تحديث الموقع مؤخرًا')),
      );
      expect(LocationFreshness.formatAge(snap.updatedAt, now: now),
          'العمر: 3 ساعة');
    });

    test('G — invalid / missing observation keeps prior; never DateTime.now()', () {
      final prior = DateTime.utc(2026, 11, 21, 14, 55);
      final missing = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(), // no time fields
        previousLat: 1,
        previousLng: 2,
        previousAccuracyM: 9,
        previousUpdatedAt: prior,
      );
      expect(missing.updatedAt, prior);
      expect(missing.lat, closeTo(15.3694, 0.0001));

      final invalid = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(updateTime: 'not-a-time', observedAtUtc: ''),
        previousUpdatedAt: prior,
      );
      expect(invalid.updatedAt, prior);

      final emptyCoords = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: {
          'L_Latitude': 'x',
          'L_Longitude': 'y',
          'observed_at_utc': '2026-11-21T15:00:00Z',
        },
        previousLat: 10,
        previousLng: 20,
        previousUpdatedAt: prior,
      );
      expect(emptyCoords.lat, 10);
      expect(emptyCoords.lng, 20);
      expect(emptyCoords.updatedAt, prior);

      // Brand-new screen, garbage time → null (not fabricated now).
      final cold = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(updateTime: '—'),
      );
      expect(cold.updatedAt, isNull);
      expect(
        LocationFreshness.resolve(
          capturedAt: cold.updatedAt,
          hasCoordinates: cold.lat != null && cold.lng != null,
        ),
        LocationFreshness.unknown,
      );
    });

    test('H — older delayed server response must not overwrite newer observation', () {
      final newer = DateTime.utc(2026, 11, 21, 15, 5);
      final delayed = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(observedAtUtc: '2026-11-21T15:00:00Z'),
        previousLat: 15.3,
        previousLng: 44.2,
        previousUpdatedAt: newer,
      );
      expect(delayed.updatedAt, newer);
      // Equal timestamp is accepted (same point agreement).
      final equal = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(observedAtUtc: '2026-11-21T15:05:00Z'),
        previousUpdatedAt: newer,
      );
      expect(equal.updatedAt, DateTime.utc(2026, 11, 21, 15, 5));
      // Newer server advances.
      final advance = ElderlyLocationServerSnapshot.mergeFromServer(
        loc: serverLoc(observedAtUtc: '2026-11-21T15:10:00Z'),
        previousUpdatedAt: newer,
      );
      expect(advance.updatedAt, DateTime.utc(2026, 11, 21, 15, 10));
    });

    test('elderly and caregiver agree for the same observation point', () {
      final now = DateTime.utc(2026, 11, 21, 15, 2);
      for (final raw in [
        '2026-11-21T15:00:00.000000Z',
        '2026-11-21 15:00:00',
      ]) {
        final caregiverAt = LocationFreshness.parseObservationTime(raw);
        final elderly = ElderlyLocationServerSnapshot.mergeFromServer(
          loc: raw.contains('T')
              ? serverLoc(observedAtUtc: raw)
              : serverLoc(updateTime: raw),
        );
        expect(elderly.updatedAt, caregiverAt);
        expect(
          LocationFreshness.resolve(
            capturedAt: elderly.updatedAt,
            hasCoordinates: true,
            now: now,
          ),
          LocationFreshness.resolve(
            capturedAt: caregiverAt,
            hasCoordinates: true,
            now: now,
          ),
        );
      }
    });
  });
}
