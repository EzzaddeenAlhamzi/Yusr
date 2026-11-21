import 'dart:math' as math;

/// P2.4-B — client-side Haversine helpers (mirrors server GeofenceEngine).
/// Synthetic GPS tests should label themselves as synthetic.
class GeofenceMath {
  static const stateUnknown = 'UNKNOWN';
  static const stateInside = 'INSIDE';
  static const stateOutside = 'OUTSIDE';
  static const stateBoundaryUncertain = 'BOUNDARY_UNCERTAIN';

  static double haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earth = 6371000.0;
    final p1 = lat1 * math.pi / 180.0;
    final p2 = lat2 * math.pi / 180.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earth * math.asin(math.sqrt(a).clamp(0.0, 1.0));
  }

  static String classify({
    required double? lat,
    required double? lng,
    required double? accuracyMeters,
    required double centerLat,
    required double centerLng,
    required double radiusMeters,
  }) {
    if (lat == null || lng == null) return stateUnknown;
    if (lat.isNaN || lng.isNaN || lat.abs() > 90 || lng.abs() > 180) {
      return stateUnknown;
    }
    if (radiusMeters <= 0) return stateUnknown;

    final distance = haversineMeters(lat, lng, centerLat, centerLng);
    final accuracy =
        (accuracyMeters != null && accuracyMeters >= 0) ? accuracyMeters : 0.0;
    final inner = radiusMeters - accuracy;
    final outer = radiusMeters + accuracy;
    if (distance <= inner) return stateInside;
    if (distance >= outer) return stateOutside;
    return stateBoundaryUncertain;
  }
}
