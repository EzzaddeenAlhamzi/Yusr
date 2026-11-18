import 'package:flutter/material.dart';
import 'senior_manager.dart';
import 'token_storage.dart';

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

  /// Optional remote revoke hook (set by ApiService to avoid circular imports).
  static Future<void> Function()? remoteLogoutHook;

  // قراءة حالة تسجيل الدخول والصلاحيات
  bool get isLoggedIn => _isLoggedIn;
  String? get role => _role;
  bool get isCaregiver => _isLoggedIn && _role == 'caregiver';
  bool get isSenior => _isLoggedIn && _role == 'senior';
  int? get userId => _userId;
  String? get userName => _userName;
  String? get userPhone => _userPhone;
  String? get userEmail => _userEmail;
  int? get linkedSeniorId => _linkedSeniorId;
  int? get linkedElderlyId => _linkedSeniorId;

  /// التحقق من صلاحية الوصول لدور محدد
  bool canAccess(String targetRole) {
    if (!_isLoggedIn) return false;
    return _role == targetRole;
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

  /// تسجيل الخروج: إبطال التوكن (إن وُجد) + مسح التخزين الآمن + الجلسة.
  Future<void> logout() async {
    try {
      final hook = remoteLogoutHook;
      if (hook != null) {
        await hook();
      }
    } catch (_) {}
    await TokenStorage.instance.clear();
    clearSessionLocal();
  }
}
