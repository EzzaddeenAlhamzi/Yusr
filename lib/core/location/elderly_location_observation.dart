import 'location_freshness.dart';

/// Snapshot after applying a server `getLocation` payload onto elderly UI state.
///
/// Mirrors caregiver preference: `observed_at_utc` then `L_UpdateTime`, parsed
/// with [LocationFreshness.parseObservationTime] (naive = UTC). Never invents
/// [DateTime.now]. Never replaces a newer prior observation with an older
/// delayed server response.
class ElderlyLocationServerSnapshot {
  const ElderlyLocationServerSnapshot({
    this.lat,
    this.lng,
    this.accuracyM,
    this.updatedAt,
  });

  final double? lat;
  final double? lng;
  final double? accuracyM;
  final DateTime? updatedAt;

  /// Raw observation field selection — same order as caregiver location page.
  static String? observationRawFromServer(Map<dynamic, dynamic> loc) {
    final observed = loc['observed_at_utc']?.toString();
    if (observed != null) {
      final o = observed.trim();
      if (o.isNotEmpty && o != '—' && o != '-') return o;
    }
    final legacy = loc['L_UpdateTime']?.toString();
    if (legacy != null) {
      final t = legacy.trim();
      if (t.isNotEmpty && t != '—' && t != '-') return t;
    }
    return null;
  }

  /// Merge API location map into current elderly observation state.
  ///
  /// This is the pure form of `_loadLastKnownFromServer` so tests A–H exercise
  /// the real elderly load path without widget/API scaffolding.
  static ElderlyLocationServerSnapshot mergeFromServer({
    required Map<dynamic, dynamic> loc,
    double? previousLat,
    double? previousLng,
    double? previousAccuracyM,
    DateTime? previousUpdatedAt,
  }) {
    final lat = double.tryParse(
      (loc['L_Latitude'] ?? loc['latitude'])?.toString() ?? '',
    );
    final lng = double.tryParse(
      (loc['L_Longitude'] ?? loc['longitude'] ?? loc['Longitude'])
              ?.toString() ??
          '',
    );
    final acc = double.tryParse(
      (loc['L_AccuracyMeters'] ?? loc['accuracy_meters'])?.toString() ?? '',
    );

    if (lat == null || lng == null) {
      return ElderlyLocationServerSnapshot(
        lat: previousLat,
        lng: previousLng,
        accuracyM: previousAccuracyM,
        updatedAt: previousUpdatedAt,
      );
    }

    final raw = observationRawFromServer(loc);
    final parsed = LocationFreshness.parseObservationTime(raw);

    DateTime? nextUpdated = previousUpdatedAt;
    if (parsed != null) {
      final prev = previousUpdatedAt?.toUtc();
      // Keep previous when server observation is strictly older (delayed reply).
      if (prev == null || !parsed.toUtc().isBefore(prev)) {
        nextUpdated = parsed;
      }
    }
    // Invalid / missing observation time: keep previous; never DateTime.now().

    return ElderlyLocationServerSnapshot(
      lat: lat,
      lng: lng,
      accuracyM: acc ?? previousAccuracyM,
      updatedAt: nextUpdated,
    );
  }
}
