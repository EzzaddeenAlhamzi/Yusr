import 'package:flutter_map/flutter_map.dart';

/// P2.4 — geographic raster tiles for [YusrMapView].
///
/// Does **not** use `tile.openstreetmap.org` (OSMF public CDN is not an app
/// tile API; blocked responses are HTTP 200 blank PNGs — see
/// `P2_4_REAL_MAP_ROOT_CAUSE.md`).
///
/// Primary: OpenStreetMap France community tiles (OSM data).
/// Fallback: CARTO Voyager (OSM-derived; free raster, no API key).
///
/// Compliance: OSM France disallows login-walled maps; CARTO free needs an
/// API key — see store `P2_4_MAP_PROVIDER_COMPLIANCE.md` (PO DECISION for prod).
/// URLs stay configurable; do not ship paid billing credentials without PO.
class OsmTileProvider {
  OsmTileProvider._();

  /// Identifiable product UA (OSM / mirror courtesy).
  static const String httpUserAgent =
      'YusrMobile/1.0 (com.yusr.yusr1; Flutter; +https://github.com/EzzaddeenAlhamzi/Yusr)';

  /// Package id retained for flutter_map diagnostics.
  static const String userAgentPackageName = 'com.yusr.yusr1';

  /// OpenStreetMap France — legitimate community mirror for app use.
  static const String primaryUrlTemplate =
      'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png';

  /// CARTO Voyager — OSM-derived fallback (no billing key).
  static const String fallbackUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  static const List<String> subdomains = ['a', 'b', 'c'];

  /// Test-only override (null in production). When set, primary+fallback use it.
  static String? overrideUrlTemplate;

  static String get urlTemplate => overrideUrlTemplate ?? primaryUrlTemplate;

  static String? get fallbackUrl =>
      overrideUrlTemplate != null ? null : fallbackUrlTemplate;

  static const String attributionText =
      '© OpenStreetMap contributors · © CARTO';

  /// Exact Arabic copy required by PO REAL MAP gate.
  static const String tileLoadErrorArabic =
      'تعذر تحميل الخريطة، تحقق من اتصال الإنترنت وحاول مرة أخرى';

  /// Network provider with identifiable UA (mutable map — TileLayer may
  /// putIfAbsent; const maps throw UnsupportedError).
  static NetworkTileProvider createNetworkTileProvider() {
    return NetworkTileProvider(
      headers: <String, String>{
        'User-Agent': httpUserAgent,
      },
      silenceExceptions: false,
    );
  }
}
