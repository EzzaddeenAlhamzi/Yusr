/// P2.4 — separate SOS (A) from geofence EXIT (B) / ENTER (C).
class LocationAlertCategory {
  LocationAlertCategory._();

  static const String sos = 'sos';
  static const String zoneExit = 'zone_exit';
  static const String zoneEnter = 'zone_enter';
  static const String other = 'other';

  static String classify({
    String? eventType,
    String? nType,
    String? title,
    String? message,
  }) {
    final event = '${eventType ?? ''} ${nType ?? ''}'.toLowerCase();
    final t = title ?? '';
    final msg = message ?? '';

    final isExit = event.contains('safe_zone_exit') ||
        t.contains('خروج') ||
        msg.contains('خروج من المنطقة');
    if (isExit) return zoneExit;

    final isEnter = event.contains('safe_zone_enter') ||
        (t.contains('دخول') && t.contains('المنطقة'));
    if (isEnter) return zoneEnter;

    final isSos = event.contains('sos') ||
        event.contains('emergency') ||
        t.contains('طوارئ') ||
        t.contains('استغاثة') ||
        msg.contains('استغاثة') ||
        (msg.contains('طوارئ') && !msg.contains('المنطقة الآمنة'));
    if (isSos) return sos;

    return other;
  }
}
