/// P2.4 — honest foreground-only freshness labels (Arabic UI, no live-tracking claims).
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

  /// Classify from a capture timestamp. Never invents "live tracking".
  static String fromTimestamp(DateTime? capturedAt, {DateTime? now}) {
    if (capturedAt == null) return unknown;
    final mins = (now ?? DateTime.now()).difference(capturedAt).inMinutes.abs();
    if (mins <= 2) return fresh;
    if (mins <= 30) return recent;
    if (mins <= 24 * 60) return stale;
    return old;
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

  /// Arabic-readable local timestamp (no raw ISO in UI).
  static String formatArabicDateTime(DateTime? dt) {
    if (dt == null) return 'غير متوفر';
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String formatAge(DateTime? capturedAt, {DateTime? now}) {
    if (capturedAt == null) return 'العمر: غير معروف';
    final diff = (now ?? DateTime.now()).difference(capturedAt).abs();
    if (diff.inMinutes < 1) return 'العمر: أقل من دقيقة';
    if (diff.inMinutes < 60) return 'العمر: ${diff.inMinutes} دقيقة';
    if (diff.inHours < 48) return 'العمر: ${diff.inHours} ساعة';
    return 'العمر: ${diff.inDays} يوم';
  }
}
