import 'package:flutter_map/flutter_map.dart';

/// P2.4 — CARTO Free raster tiles for [YusrMapView] (PO-selected provider).
///
/// **Only** active provider: CARTO Voyager via `basemaps.cartocdn.com` with a
/// CARTO-issued API key (`?key=`). OSM France and other public mirrors are
/// **not** used (auth-walled app screens; PO chose CARTO Free).
///
/// Key sources (never commit real keys; never log the key):
/// 1. `--dart-define=YUSR_CARTO_API_KEY=...` or `--dart-define-from-file=dart_defines.json`
/// 2. Test-only [overrideApiKey] / [overrideUrlTemplate]
///
/// See store docs: `P2_4_CARTO_KEY_SETUP_AR.md`, `P2_4_MAP_PROVIDER_COMPLIANCE.md`.
class OsmTileProvider {
  OsmTileProvider._();

  /// Compile-time key from `--dart-define=YUSR_CARTO_API_KEY=...`.
  static const String _envApiKey = String.fromEnvironment(
    'YUSR_CARTO_API_KEY',
    defaultValue: '',
  );

  /// Dart-define / env variable name (for docs and error UI).
  static const String apiKeyDefineName = 'YUSR_CARTO_API_KEY';

  /// Identifiable product UA.
  static const String httpUserAgent =
      'YusrMobile/1.0 (com.yusr.yusr1; Flutter; +https://github.com/EzzaddeenAlhamzi/Yusr)';

  static const String userAgentPackageName = 'com.yusr.yusr1';

  static const List<String> subdomains = ['a', 'b', 'c'];

  /// CARTO Voyager raster base (key appended when present).
  static const String cartoVoyagerPath =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';

  /// Required attribution (OSM data + CARTO basemap).
  static const String attributionText =
      '© OpenStreetMap contributors · © CARTO';

  /// Network / decode failure (tiles attempted).
  static const String tileLoadErrorArabic =
      'تعذر تحميل الخريطة، تحقق من اتصال الإنترنت وحاول مرة أخرى';

  /// Missing API key — configuration error (not a silent gray map).
  static const String missingKeyErrorArabic =
      'مفتاح خرائط CARTO غير مضبوط. أضِف YUSR_CARTO_API_KEY '
      '(ملف dart_defines.json أو --dart-define) ثم أعد تشغيل/بناء التطبيق.';

  /// Test-only URL override (null in production).
  static String? overrideUrlTemplate;

  /// Test-only API key override (null in production). Never commit real keys.
  static String? overrideApiKey;

  static String get apiKey {
    final o = overrideApiKey;
    if (o != null && o.trim().isNotEmpty) return o.trim();
    return _envApiKey.trim();
  }

  static bool get hasApiKey => apiKey.isNotEmpty;

  /// Active tile URL template — CARTO only. Empty key → empty template
  /// (UI must show [missingKeyErrorArabic], not fetch unauthenticated tiles).
  static String get urlTemplate {
    if (overrideUrlTemplate != null) return overrideUrlTemplate!;
    if (!hasApiKey) return '';
    // Key is query param required by CARTO Free; do not log this string.
    return '$cartoVoyagerPath?key=${Uri.encodeQueryComponent(apiKey)}';
  }

  /// No secondary provider (PO: CARTO only — remove OSM France fallback).
  static String? get fallbackUrl => null;

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

  /// Whether a URL/template string appears to embed a secret key param.
  /// Used in tests to assert production sources don't hardcode keys.
  static bool templateLooksLikeHardcodedSecret(String source) {
    final lower = source.toLowerCase();
    if (!lower.contains('key=')) return false;
    // Allow documentation / encodeQueryComponent patterns in this file's logic,
    // but flag long hex/uuid-like literals.
    return RegExp(r'key=[0-9a-fA-F-]{16,}').hasMatch(source);
  }
}
