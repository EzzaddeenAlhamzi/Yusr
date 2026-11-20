/// P2.2 client helpers for server-authoritative dose adherence (A1/B1).
/// SharedPreferences must never be treated as adherence SoT.
class MedicationAdherenceHelper {
  MedicationAdherenceHelper._();

  static const int graceMinutes = 30;

  static String civilDateToday([DateTime? now]) {
    final n = now ?? DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  static String displayLabelAr(String? displayState) {
    switch (displayState) {
      case 'upcoming':
        return 'قادم';
      case 'due':
        return 'مستحق';
      case 'overdue_not_confirmed':
        return 'متأخر — غير مؤكد';
      case 'taken':
        return 'تم التناول';
      case 'late_confirmed':
        return 'تأكيد متأخر';
      default:
        return 'غير مؤكد';
    }
  }

  static bool isConfirmedState(String? displayState) {
    return displayState == 'taken' || displayState == 'late_confirmed';
  }

  static bool isOverdueNotConfirmed(String? displayState) {
    return displayState == 'overdue_not_confirmed';
  }

  /// Offline / connection failure must never look like confirm success.
  static String offlineConfirmBlockedMessage() {
    return 'يلزم الاتصال بالإنترنت لتأكيد تناول الدواء على الخادم. لم يُسجَّل التأكيد.';
  }

  static String outdatedCacheBanner() {
    return 'عرض مخزّن مؤقتاً — قد يكون قديماً. الالتزام المعتمد يتطلب اتصالاً بالخادم.';
  }

  static String caregiverReadOnlyMessage() {
    return 'الاطلاع فقط: تأكيد الجرعة يتم من حساب كبير السن على الخادم.';
  }

  /// True when the API payload indicates network/backend unavailable.
  static bool isConnectionFailure(Map<String, dynamic>? res) {
    if (res == null) return true;
    return res['is_connection_error'] == true ||
        res['error_type'] == 'connection_error';
  }

  /// Server confirm success only — never invent local Taken.
  static bool isConfirmSuccess(Map<String, dynamic>? res) {
    return res != null && res['status'] == 'success';
  }

  /// Arabic failure copy for a confirm attempt (offline → explicit blocked text).
  static String confirmFailureMessage(Map<String, dynamic>? res) {
    if (isConnectionFailure(res)) {
      return offlineConfirmBlockedMessage();
    }
    final msg = res?['message']?.toString();
    if (msg != null && msg.trim().isNotEmpty) return msg;
    return 'تعذّر تأكيد الجرعة';
  }
}
