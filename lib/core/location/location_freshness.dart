/// P2.4 — honest foreground-only freshness (Arabic UI, no live-tracking claims).
///
/// Authoritative clock: observation timestamp + device [now].
/// Banner and detail card must use the same derived code from that pair.
class LocationFreshness {
  LocationFreshness._();

  static const String fresh = 'fresh';
  static const String recent = 'recent';
  static const String stale = 'stale';
  static const String old = 'old';
  static const String unknown = 'unknown';
  static const String sharingStopped = 'sharing_stopped';
  static const String noData = 'no_data';
  static const String updateFailed = 'update_failed';

  /// ≤2 min
  static const int freshMaxMinutes = 2;

  /// ≤30 min
  static const int recentMaxMinutes = 30;

  /// ≤24 h
  static const int staleMaxMinutes = 24 * 60;

  /// Parse server observation time.
  ///
  /// Laravel stores `L_UpdateTime` in app TZ (**UTC**). Naive strings
  /// (`2026-11-21 12:00:00`) are treated as UTC so age matches server.
  /// Strings with `Z` / offset keep that zone. Result is absolute time.
  static DateTime? parseObservationTime(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty || s == '—' || s == '-') return null;

    // Explicit offset / Z
    final withZone = DateTime.tryParse(s);
    if (s.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s) ||
        s.contains('T') && withZone != null && withZone.isUtc) {
      return withZone?.toUtc();
    }

    // MySQL / Laravel naive datetime → UTC
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    final utc = DateTime.tryParse('${normalized}Z');
    if (utc != null) return utc.toUtc();

    final localGuess = DateTime.tryParse(s);
    return localGuess?.toUtc();
  }

  /// Classify from observation timestamp vs [now].
  /// Future skew (>2 min ahead) → [unknown] (never treat as fresh).
  /// Does **not** invent live tracking.
  static String fromTimestamp(DateTime? capturedAt, {DateTime? now}) {
    if (capturedAt == null) return unknown;
    final clock = (now ?? DateTime.now()).toUtc();
    final at = capturedAt.toUtc();
    final delta = clock.difference(at);
    // Clock skew: observation in the future
    if (delta.isNegative && delta.abs().inMinutes > 2) {
      return unknown;
    }
    final mins = delta.abs().inMinutes;
    if (mins <= freshMaxMinutes) return fresh;
    if (mins <= recentMaxMinutes) return recent;
    if (mins <= staleMaxMinutes) return stale;
    return old;
  }

  /// Prefer timestamp over any server enum (server enum can be stale on client).
  static String resolve({
    DateTime? capturedAt,
    String? serverFreshness,
    bool sharingStoppedFlag = false,
    bool hasCoordinates = true,
    DateTime? now,
  }) {
    if (sharingStoppedFlag) return sharingStopped;
    if (!hasCoordinates) return noData;
    if (capturedAt != null) {
      return fromTimestamp(capturedAt, now: now);
    }
    return fromRawLabel(serverFreshness);
  }

  static String fromRawLabel(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    switch (v) {
      case fresh:
      case recent:
      case stale:
      case old:
      case unknown:
      case sharingStopped:
      case noData:
      case updateFailed:
        return v;
      default:
        return unknown;
    }
  }

  /// Arabic status — never expose English enum tokens in UI.
  static String arabicLabel(String code) {
    switch (fromRawLabel(code)) {
      case fresh:
        return 'تم تحديث الموقع مؤخرًا';
      case recent:
        return 'آخر موقع معروف';
      case stale:
        return 'الموقع قديم';
      case old:
        return 'الموقع قديم جدًا';
      case sharingStopped:
        return 'مشاركة الموقع متوقفة';
      case noData:
        return 'لا توجد بيانات موقع';
      case updateFailed:
        return 'تعذر تحديث الموقع';
      case unknown:
      default:
        return 'حالة الموقع غير معروفة';
    }
  }

  /// Short banner title (foreground-only honesty).
  static String arabicBannerTitle(String code) {
    switch (fromRawLabel(code)) {
      case fresh:
        return 'تم تحديث الموقع مؤخرًا';
      case recent:
        return 'آخر موقع معروف';
      case stale:
      case old:
        return 'الموقع قديم';
      case sharingStopped:
        return 'مشاركة الموقع متوقفة';
      case noData:
        return 'لا توجد بيانات موقع';
      case updateFailed:
        return 'تعذر تحديث الموقع';
      default:
        return 'آخر موقع معروف';
    }
  }

  static String arabicBannerSubtitle(String code) {
    switch (fromRawLabel(code)) {
      case fresh:
        return 'آخر قراءة GPS أثناء استخدام التطبيق (ليست تتبّعًا خلفيًا مستمرًا).';
      case recent:
        return 'آخر إحداثيات معروفة من جهاز كبير السن.';
      case stale:
      case old:
        return 'لم يُستلم تحديث حديث — اعرض الوقت والعمر أدناه.';
      case sharingStopped:
        return 'كبير السن أوقف مشاركة الموقع.';
      case noData:
        return 'لا إحداثيات مسجّلة حاليًا.';
      case updateFailed:
        return 'تعذّر جلب الموقع من الخادم أو الجهاز.';
      default:
        return 'تعذر تحديد حداثة الموقع.';
    }
  }

  /// Arabic-readable **local** timestamp (no raw ISO in UI).
  static String formatArabicDateTime(DateTime? dt) {
    if (dt == null) return 'غير متوفر';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String formatAge(DateTime? capturedAt, {DateTime? now}) {
    if (capturedAt == null) return 'العمر: غير معروف';
    final clock = (now ?? DateTime.now()).toUtc();
    final at = capturedAt.toUtc();
    var diff = clock.difference(at);
    if (diff.isNegative) {
      return 'العمر: غير متسق مع ساعة الجهاز';
    }
    if (diff.inMinutes < 1) return 'العمر: أقل من دقيقة';
    if (diff.inMinutes < 60) return 'العمر: ${diff.inMinutes} دقيقة';
    if (diff.inHours < 48) return 'العمر: ${diff.inHours} ساعة';
    return 'العمر: ${diff.inDays} يوم';
  }
}
