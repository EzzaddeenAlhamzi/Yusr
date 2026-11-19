import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'senior_manager.dart';
import 'token_storage.dart';

/// Result of [AuthService.restoreSession].
enum SessionRestoreOutcome {
  /// No token / corrupt / revoked / 401 — local session denied.
  unauthenticated,

  /// Token validated with Laravel; [AuthService] role/profile restored.
  authenticated,

  /// Token present but network failed — do NOT enter homes; do NOT clear token.
  networkUnavailable,
}

/// Result of [AuthService.logout].
class LogoutResult {
  const LogoutResult({
    required this.localCleared,
    required this.serverRevoked,
  });

  /// Secure storage + memory + role caches cleared; local access denied.
  final bool localCleared;

  /// True only when the server confirmed (or already had) token revocation.
  final bool serverRevoked;
}

/// إدارة صلاحيات الدخول وجلسة المستخدم الحالي في التطبيق
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isLoggedIn = false;
  String? _role; // 'caregiver' أو 'senior'
  int? _userId;
  String? _userName;
  String? _userPhone;
  String? _userEmail;
  int? _linkedSeniorId;
  bool _isRestoring = false;

  /// Optional remote revoke hook (set by ApiService to avoid circular imports).
  /// Returns true when server revocation succeeded or token was already gone.
  static Future<bool> Function()? remoteLogoutHook;

  /// Optional `/me` fetcher (set by ApiService).
  static Future<Map<String, dynamic>> Function()? meFetcher;

  /// Pref keys that must survive logout (device/network discovery only).
  static const Set<String> preservedPrefKeys = {
    'custom_api_url',
    'last_working_url',
  };

  // قراءة حالة تسجيل الدخول والصلاحيات
  bool get isLoggedIn => _isLoggedIn;
  bool get isRestoring => _isRestoring;
  String? get role => _role;
  bool get isCaregiver => _isLoggedIn && _role == 'caregiver';
  bool get isSenior => _isLoggedIn && _role == 'senior';
  int? get userId => _userId;
  String? get userName => _userName;
  String? get userPhone => _userPhone;
  String? get userEmail => _userEmail;
  int? get linkedSeniorId => _linkedSeniorId;
  int? get linkedElderlyId => _linkedSeniorId;

  /// Map backend role strings (`elderly`) to client role (`senior`).
  static String? normalizeClientRole(String? raw) {
    if (raw == null) return null;
    final r = raw.trim().toLowerCase();
    if (r.isEmpty) return null;
    if (r == 'elderly' || r == 'elder' || r == 'senior') return 'senior';
    if (r == 'caregiver' || r == 'carer') return 'caregiver';
    return null;
  }

  /// التحقق من صلاحية الوصول لدور محدد
  bool canAccess(String targetRole) {
    if (!_isLoggedIn) return false;
    final normalized = normalizeClientRole(targetRole) ?? targetRole;
    return _role == normalized;
  }

  /// تعيين جلسة مقدم الرعاية بعد التحقق من قاعدة البيانات
  void setCaregiverSession({
    required int id,
    required String name,
    required String phone,
    String? email,
    int? linkedElderlyId,
  }) {
    _isLoggedIn = true;
    _role = 'caregiver';
    _userId = id;
    _userName = name;
    _userPhone = phone;
    _userEmail = email;
    _linkedSeniorId = linkedElderlyId;
    if (linkedElderlyId == null || linkedElderlyId <= 0) {
      SeniorManager().clear();
    }
    notifyListeners();
  }

  /// تعيين جلسة كبير السن بعد التحقق من قاعدة البيانات
  void setSeniorSession({
    required int id,
    required String name,
    required String phone,
    String? email,
  }) {
    _isLoggedIn = true;
    _role = 'senior';
    _userId = id;
    _userName = name;
    _userPhone = phone;
    _userEmail = email;
    _linkedSeniorId = id;
    notifyListeners();
  }

  /// تحديث ربط كبير السن لمقدم الرعاية
  void linkSenior(int elderlyId) {
    _linkedSeniorId = elderlyId;
    notifyListeners();
  }

  /// مسح الجلسة المحلية فقط (بدون استدعاء شبكة) — يُستخدم عند 401.
  void clearSessionLocal() {
    _isLoggedIn = false;
    _role = null;
    _userId = null;
    _userName = null;
    _userPhone = null;
    _userEmail = null;
    _linkedSeniorId = null;
    SeniorManager().clear();
    notifyListeners();
  }

  /// Clear user-scoped SharedPreferences but keep discovery URLs.
  ///
  /// [includePerUserModeKeys]: when true (logout / hard switch), also remove
  /// `senior_mode_$uid` keys. When false, only clear globals + med/appt caches
  /// so a returning user can keep their simple/advanced preference.
  Future<void> clearUserScopedCaches({
    bool includePerUserModeKeys = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList(growable: false);
      for (final key in keys) {
        if (preservedPrefKeys.contains(key)) continue;
        // Global mode fallbacks always scrubbed — they leak across users (A4).
        if (key == 'senior_mode' ||
            key == 'senior_setup_done' ||
            key == 'senior_location_allowed' ||
            key == 'senior_notifications_allowed' ||
            key.startsWith('med_') ||
            key.startsWith('appt_')) {
          await prefs.remove(key);
          continue;
        }
        if (includePerUserModeKeys &&
            (key.startsWith('senior_mode_') ||
                key.startsWith('senior_setup_done_') ||
                key.startsWith('senior_location_allowed_') ||
                key.startsWith('senior_notifications_allowed_') ||
                key.startsWith('cg_notif_enabled_') ||
                key.startsWith('cg_biometric_pref_'))) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }

  /// Call before applying a new login when a different in-memory user exists.
  Future<void> prepareForUserSwitch({
    required String newRole,
    required int newUserId,
  }) async {
    final normalized = normalizeClientRole(newRole) ?? newRole;
    final switching = _isLoggedIn &&
        (_role != normalized || _userId != newUserId);
    if (switching) {
      await clearUserScopedCaches(includePerUserModeKeys: true);
      SeniorManager().clear();
      clearSessionLocal();
    } else {
      // Still drop global fallbacks / shared confirmation noise.
      await clearUserScopedCaches(includePerUserModeKeys: false);
    }
  }

  /// Apply a validated `/me` (or login) payload into memory. Returns false if malformed.
  bool applyValidatedProfile(Map<String, dynamic> res) {
    if (res['status'] != 'success') return false;
    final role = normalizeClientRole(res['role']?.toString());
    if (role == 'caregiver') {
      final caregiver = res['caregiver'];
      if (caregiver is! Map) return false;
      final id = int.tryParse(caregiver['Caregivers_ID']?.toString() ?? '');
      if (id == null || id <= 0) return false;
      final rawName = caregiver['C_Name']?.toString().trim() ?? '';
      final validName =
          (rawName.isEmpty || RegExp(r'^[\?\s]+$').hasMatch(rawName))
              ? 'مقدم الرعاية'
              : rawName;
      final linked = caregiver['Eldery_ID'] != null
          ? int.tryParse(caregiver['Eldery_ID'].toString())
          : null;
      setCaregiverSession(
        id: id,
        name: validName,
        phone: caregiver['C_PhonNumber']?.toString() ?? '',
        email: caregiver['C_Email']?.toString(),
        linkedElderlyId: linked,
      );
      return true;
    }
    if (role == 'senior') {
      final elderly = res['elderly'];
      if (elderly is! Map) return false;
      final id = int.tryParse(elderly['Eldery_ID']?.toString() ?? '');
      if (id == null || id <= 0) return false;
      final rawName = elderly['E_Name']?.toString().trim() ?? '';
      final validName =
          (rawName.isEmpty || RegExp(r'^[\?\s]+$').hasMatch(rawName))
              ? 'كبير السن'
              : rawName;
      setSeniorSession(
        id: id,
        name: validName,
        phone: elderly['E_PhonNumber']?.toString() ?? '',
        email: elderly['E_Email']?.toString(),
      );
      return true;
    }
    return false;
  }

  /// Cold-start restore: require secure token + Laravel validation before homes.
  Future<SessionRestoreOutcome> restoreSession() async {
    _isRestoring = true;
    notifyListeners();
    try {
      final token = await TokenStorage.instance.readToken();
      if (token == null || token.trim().isEmpty) {
        await TokenStorage.instance.clear();
        clearSessionLocal();
        return SessionRestoreOutcome.unauthenticated;
      }

      final fetcher = meFetcher;
      if (fetcher == null) {
        // Fail closed: cannot validate without network hook.
        await TokenStorage.instance.clear();
        clearSessionLocal();
        return SessionRestoreOutcome.unauthenticated;
      }

      final res = await fetcher();
      if (res['is_connection_error'] == true ||
          res['error_type'] == 'connection_error') {
        // Keep token for retry; never open protected UI.
        clearSessionLocal();
        return SessionRestoreOutcome.networkUnavailable;
      }

      if (res['http_status'] == 401 ||
          res['error_type'] == 'unauthenticated' ||
          res['status'] != 'success') {
        await TokenStorage.instance.clear();
        clearSessionLocal();
        return SessionRestoreOutcome.unauthenticated;
      }

      final ok = applyValidatedProfile(res);
      if (!ok) {
        await TokenStorage.instance.clear();
        clearSessionLocal();
        return SessionRestoreOutcome.unauthenticated;
      }

      // Refresh stored role in client-normalized form (best-effort on test/hosts).
      final normalized = normalizeClientRole(res['role']?.toString());
      try {
        await TokenStorage.instance.saveToken(token, role: normalized);
      } catch (_) {}
      return SessionRestoreOutcome.authenticated;
    } catch (_) {
      clearSessionLocal();
      return SessionRestoreOutcome.networkUnavailable;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// Home route for a validated session (senior mode prefs are user-scoped).
  Future<String> homeRouteForSession() async {
    if (!_isLoggedIn || _role == null) return '/welcome';
    if (_role == 'caregiver') return '/main-caregiver';
    if (_role == 'senior') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final uid = _userId?.toString() ?? '';
        final savedMode =
            uid.isEmpty ? null : prefs.getString('senior_mode_$uid');
        if (savedMode == 'simple') return '/simple-home';
        if (savedMode == 'advanced') return '/home-elderly';
      } catch (_) {}
      return '/choose-mode';
    }
    return '/welcome';
  }

  /// تسجيل الخروج: إبطال التوكن (إن أمكن) + مسح التخزين الآمن + الجلسة + الكاش.
  /// لا يدّعي إبطال الخادم عند فشل الشبكة؛ يمنع الوصول المحلي دائماً.
  Future<LogoutResult> logout() async {
    var serverRevoked = false;
    try {
      final hook = remoteLogoutHook;
      if (hook != null) {
        serverRevoked = await hook();
      }
    } catch (_) {
      serverRevoked = false;
    }
    await TokenStorage.instance.clear();
    await clearUserScopedCaches();
    clearSessionLocal();
    return LogoutResult(localCleared: true, serverRevoked: serverRevoked);
  }

  @visibleForTesting
  void resetForTest() {
    clearSessionLocal();
    _isRestoring = false;
    remoteLogoutHook = null;
    meFetcher = null;
  }
}
