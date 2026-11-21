/// P2.4 — configurable OpenStreetMap-based tile provider (no Google billing).
///
/// Follows OSM tile usage policy: identify User-Agent, no bulk download,
/// attribution required on map UI.
class OsmTileProvider {
  OsmTileProvider._();

  /// Standard OSM raster tiles. Override in tests via [overrideUrlTemplate].
  static String urlTemplate =
      overrideUrlTemplate ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Package name used by flutter_map as User-Agent identity.
  static const String userAgentPackageName = 'com.yusr.yusr1';

  static const String attributionText = '© OpenStreetMap contributors';

  /// Test-only override (null in production).
  static String? overrideUrlTemplate;
}
