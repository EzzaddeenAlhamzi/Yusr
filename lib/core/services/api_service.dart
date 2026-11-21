import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'location_sharing_service.dart';
import 'token_storage.dart';

/// خدمة الاتصال بقاعدة البيانات المحلية MySQL/phpMyAdmin عبر واجهة PHP و PDO
/// ترتبط بـ db.php و index.php وتقبل الاتصال من أي جهاز أو شبكة
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// Callback when API returns 401 (optional UI navigation hook).
  /// Receives last known client role (may be null) for login navigation.
  static void Function(String? role)? onUnauthorized;

  static bool _hooksWired = false;

  /// Last list/get helper failure message (null when last helper succeeded).
  /// Callers must not treat an empty list as success when this is set.
  static String? lastListError;

  /// True when [lastListError] came from a connection/timeout failure.
  static bool lastListConnectionError = false;

  static void _clearListError() {
    lastListError = null;
    lastListConnectionError = false;
  }

  static void _setListErrorFrom(Map<String, dynamic> res) {
    lastListError = res['message']?.toString() ??
        'تعذّر جلب البيانات من الخادم';
    lastListConnectionError = res['is_connection_error'] == true ||
        res['error_type'] == 'connection_error';
  }

  /// Parse a list payload honestly: success+list → data; otherwise record error.
  static List<Map<String, dynamic>> listDataOrEmpty(Map<String, dynamic> res) {
    if (res['status'] == 'success' && res['data'] is List) {
      _clearListError();
      return List<Map<String, dynamic>>.from(res['data'] as List);
    }
    _setListErrorFrom(res);
    return [];
  }

  /// Wire logout revoke + /me hooks once (avoids AuthService ↔ ApiService cycles).
  void _ensureAuthHooks() {
    if (_hooksWired) return;
    _hooksWired = true;
    AuthService.remoteLogoutHook = logoutRemote;
    AuthService.meFetcher = fetchCurrentUser;
    // P2.4 M-P24-2 — clear foreground location sharing on logout / account switch.
    AuthService.sessionCleanupHook =
        () => LocationSharingService.instance.clearLocalState();
  }

  /// Public alias for cold-start bootstrap.
  void ensureAuthHooksForSession() => _ensureAuthHooks();

  static const String officeLANBaseUrl =
      'http://192.168.0.252/yusr_api/index.php';
  static const String officeLANPort8000 =
      'http://192.168.0.252:8000/api/legacy';
  static const String officeLANPort8088 =
      'http://192.168.0.252:8088/api/legacy';
  static const String baseUrl = 'http://localhost/yusr_api/index.php';
  static const String emulatorBaseUrl = 'http://10.0.2.2/yusr_api/index.php';
  static const String emulatorPort8000 = 'http://10.0.2.2:8000/api/legacy';
  static const String emulatorPort8088 = 'http://10.0.2.2:8088/api/legacy';
  static const String loopbackBaseUrl = 'http://127.0.0.1/yusr_api/index.php';
  static const String loopbackPort8000 = 'http://127.0.0.1:8000/api/legacy';
  /// Preferred lab artisan port when :8000 is reserved (e.g. YOGC).
  static const String loopbackPort8088 = 'http://127.0.0.1:8088/api/legacy';
  static const String usbAdbBaseUrl =
      'http://127.0.0.1:8080/yusr_api/index.php';
  static const String usbAdbLocalhost =
      'http://localhost:8080/yusr_api/index.php';
  static const String usbAdbPort8088 = 'http://127.0.0.1:8088/api/legacy';

  static final List<String> _candidateUrls = [
    // Prefer dedicated Yusr lab port 8088 before :8000 (kickoff: never claim YOGC :8000).
    loopbackPort8088,
    officeLANPort8088,
    officeLANBaseUrl, // http://192.168.0.252/yusr_api/index.php (Apache Gateway Port 80)
    officeLANPort8000, // http://192.168.0.252:8000/api/legacy
    if (Platform.isAndroid) ...[
      emulatorPort8088,
      usbAdbPort8088,
      emulatorBaseUrl, // http://10.0.2.2/yusr_api/index.php
      emulatorPort8000, // http://10.0.2.2:8000/api/legacy
      usbAdbLocalhost,
    ],
    loopbackBaseUrl,
    loopbackPort8000,
    baseUrl,
  ];

  static String? _workingUrl;
  static bool _isDiscovering = false;

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);

  /// جلب الرابط النشط حالياً
  static String? get workingUrl => _workingUrl;

  /// Reset discovery state for unit tests only.
  @visibleForTesting
  static void resetDiscoveryStateForTest() {
    _workingUrl = null;
    _isDiscovering = false;
  }

  /// Explicit trusted Yusr origins (scheme+host+port). Lab policy.
  /// Bearer is attached only when origin matches AND path is a Yusr API path.
  @visibleForTesting
  static const Set<String> trustedBearerOrigins = {
    'http://127.0.0.1:8088',
    'http://localhost:8088',
    'http://10.0.2.2:8088',
    'http://192.168.0.252:8088',
    // Apache yusr_api on default HTTP port 80
    'http://127.0.0.1',
    'http://localhost',
    'http://10.0.2.2',
    'http://192.168.0.252',
    // USB ADB reverse (non-8000)
    'http://127.0.0.1:8080',
    'http://localhost:8080',
  };

  /// Build canonical origin string: scheme://host[:port] (omit default 80/443).
  @visibleForTesting
  static String? originOf(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    final host = uri.host.toLowerCase();
    final port = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 80);
    if ((scheme == 'http' && port == 80) || (scheme == 'https' && port == 443)) {
      return '$scheme://$host';
    }
    return '$scheme://$host:$port';
  }

  /// True only when this attempt would attach Authorization Bearer.
  ///
  /// Session invalidation on HTTP 401 must use this — not mere token presence —
  /// so a 401 from `:8000` / untrusted hosts (where Bearer is never sent) cannot
  /// clear a valid local session or force Welcome/logout navigation.
  @visibleForTesting
  static bool wouldAttachBearer({
    required bool attachBearer,
    required String? token,
    required String url,
  }) {
    return attachBearer &&
        token != null &&
        token.trim().isNotEmpty &&
        isTrustedBearerUrl(url);
  }

  /// Whether Authorization Bearer may be attached for [url].
  /// Strict: scheme+host+port must match [trustedBearerOrigins]; path must be
  /// `/api/legacy` or `yusr_api`. Never attaches to `:8000`, redirects' foreign
  /// hosts, discovery noise, or misleading hostnames/paths/ports.
  @visibleForTesting
  static bool isTrustedBearerUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return false;

    // Reject userinfo (http://attacker@127.0.0.1:8088/...) and fragments tricks.
    if (uri.userInfo.isNotEmpty) return false;

    if (uri.port == 8000) return false;
    if (RegExp(r':8000(/|$)').hasMatch(trimmed)) return false;

    final origin = originOf(uri);
    if (origin == null || !trustedBearerOrigins.contains(origin)) {
      return false;
    }

    final path = uri.path.toLowerCase();
    final isLegacy = path == '/api/legacy' || path.startsWith('/api/legacy/');
    final isYusrApi = path.contains('yusr_api');
    if (!isLegacy && !isYusrApi) return false;

    // Lab artisan path must stay on :8088 (or other explicitly trusted non-80 origins).
    if (isLegacy && uri.port == 8000) return false;

    return true;
  }

  Future<void> _persistTokenFromAuthResponse(Map<String, dynamic> res) async {
    _ensureAuthHooks();
    if (res['status'] != 'success') return;
    final token = res['token']?.toString();
    if (token == null || token.isEmpty) return;
    // Infer role from payload when register omits it; normalize elderly→senior.
    String? role = AuthService.normalizeClientRole(res['role']?.toString());
    role ??= res['caregiver'] != null
        ? 'caregiver'
        : (res['elderly'] != null ? 'senior' : null);
    await TokenStorage.instance.saveToken(token, role: role);
  }

  /// تعيين عنوان خادم مخصص يدوياً (لأي شبكة أو جهاز جديد)
  Future<bool> setCustomServer(String ipOrUrl) async {
    String cleanUrl = ipOrUrl.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    // Artisan lab on :8088 (or explicit /api/legacy) — do not force Apache yusr_api path.
    final isLegacyArtisan = cleanUrl.contains('/api/legacy') ||
        RegExp(r':8088(/|$)').hasMatch(cleanUrl);
    if (isLegacyArtisan) {
      cleanUrl = cleanUrl.replaceAll(RegExp(r'/+$'), '');
      if (!cleanUrl.contains('/api/legacy')) {
        cleanUrl = '$cleanUrl/api/legacy';
      }
    } else if (!cleanUrl.endsWith('index.php')) {
      if (!cleanUrl.endsWith('/')) cleanUrl = '$cleanUrl/';
      if (!cleanUrl.contains('yusr_api')) {
        cleanUrl = '${cleanUrl}yusr_api/index.php';
      } else {
        cleanUrl = '${cleanUrl}index.php';
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_api_url', cleanUrl);
      _workingUrl = cleanUrl;
      final ping = await testConnection();
      if (ping['status'] == 'success') {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// كشف الخادم النشط.
  ///
  /// If [custom_api_url] is configured and reachable, it wins **before** any
  /// parallel candidate race (avoids :8000 beating lab :8088). When custom is
  /// missing or unreachable, falls back to racing candidates.
  ///
  /// [ping] may be injected in unit tests; production uses [_pingSingleUrl].
  Future<String?> discoverWorkingServer({
    Future<bool> Function(String url)? ping,
  }) async {
    if (_isDiscovering) return _workingUrl;
    _isDiscovering = true;
    final doPing = ping ?? _pingSingleUrl;

    try {
      String? savedCustom;
      String? lastWorking;

      try {
        final prefs = await SharedPreferences.getInstance();
        savedCustom = prefs.getString('custom_api_url');
        lastWorking = prefs.getString('last_working_url');
      } catch (_) {}

      // 1. Prefer reachable custom_api_url BEFORE racing candidates.
      if (savedCustom != null && savedCustom.isNotEmpty) {
        try {
          if (await doPing(savedCustom)) {
            _workingUrl = savedCustom;
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('last_working_url', savedCustom);
            } catch (_) {}
            _isDiscovering = false;
            return savedCustom;
          }
        } catch (_) {}
      }

      // 2. Fallback race: last_working + static candidates + LAN probe.
      final Set<String> candidates = {};
      if (lastWorking != null && lastWorking.isNotEmpty) {
        candidates.add(lastWorking);
      }
      candidates.addAll(_candidateUrls);

      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) {
              final parts = addr.address.split('.');
              if (parts.length == 4) {
                final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
                for (final host in [
                  182,
                  100,
                  101,
                  102,
                  105,
                  110,
                  2,
                  10,
                  50,
                  200,
                  252,
                ]) {
                  candidates.add('http://$prefix$host/yusr_api/index.php');
                  candidates.add('http://$prefix$host:8088/api/legacy');
                  candidates.add('http://$prefix$host:8000/api/legacy');
                }
              }
            }
          }
        }
      } catch (_) {}

      // Do not re-race a custom URL that already failed the prefer check.
      if (savedCustom != null && savedCustom.isNotEmpty) {
        candidates.remove(savedCustom);
      }

      final candidateList = candidates.toList();
      if (candidateList.isEmpty) {
        _isDiscovering = false;
        return _workingUrl;
      }

      final completer = Completer<String?>();
      int remaining = candidateList.length;

      for (final url in candidateList) {
        doPing(url)
            .then((isWorking) {
              if (isWorking && !completer.isCompleted) {
                completer.complete(url);
              }
            })
            .catchError((_) {})
            .whenComplete(() {
              remaining--;
              if (remaining == 0 && !completer.isCompleted) {
                completer.complete(null);
              }
            });
      }

      final winner = await completer.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );

      if (winner != null) {
        _workingUrl = winner;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_working_url', winner);
        } catch (_) {}
        _isDiscovering = false;
        return winner;
      }
    } catch (_) {}

    _isDiscovering = false;
    return _workingUrl;
  }

  Future<bool> _pingSingleUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final req = await _client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'action': 'ping'}));
      final res = await req.close().timeout(const Duration(seconds: 4));
      final body = await res.transform(utf8.decoder).join();
      if (body.contains('"status":"success"') ||
          body.contains('yusr_application') ||
          body.contains('Laravel')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// التحقق السريع من صحة الاتصال
  Future<bool> isConnected() async {
    try {
      final res = await testConnection();
      return res['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  List<String> get _orderedUrls {
    if (_workingUrl != null) {
      return [_workingUrl!, ..._candidateUrls.where((u) => u != _workingUrl)];
    }
    return _candidateUrls;
  }

  /// فحص الاتصال بقاعدة البيانات yusr_application
  Future<Map<String, dynamic>> testConnection() async {
    return _sendRequest({'action': 'ping'});
  }

  // ==================== مصادقة مقدم الرعاية ====================

  /// تسجيل مقدم الرعاية (جدول caregivers)
  Future<Map<String, dynamic>> registerCaregiver({
    required String name,
    required String phone,
    required String relationship,
    String email = '',
    String password = '',
  }) async {
    if (password.trim().isEmpty) {
      return {
        'status': 'error',
        'error_type': 'password_required',
        'message': 'كلمة المرور مطلوبة لإنشاء الحساب',
      };
    }
    final res = await _sendRequest({
      'action': 'register_caregiver',
      'C_Name': name,
      'C_PhonNumber': phone,
      'C_Relationship': relationship,
      'C_Email': email,
      'C_Password': password,
    }, attachBearer: false);
    await _persistTokenFromAuthResponse(res);
    return res;
  }

  /// تسجيل دخول مقدم الرعاية برقم الهاتف أو البريد الإلكتروني
  Future<Map<String, dynamic>> loginCaregiver({
    required String phone,
    String password = '',
  }) async {
    if (password.trim().isEmpty) {
      return {
        'status': 'error',
        'error_type': 'wrong_password',
        'message': 'كلمة المرور غير صحيحة، يرجى التأكد والمحاولة مرة أخرى',
      };
    }
    final res = await _sendRequest({
      'action': 'login_caregiver',
      'C_PhonNumber': phone,
      'C_Email': phone,
      'C_Password': password,
    }, attachBearer: false);
    await _persistTokenFromAuthResponse(res);
    return res;
  }

  /// جلب بيانات مقدم الرعاية من جدول caregivers
  Future<Map<String, dynamic>?> getCaregiver(int id) async {
    final res = await _sendRequest({
      'action': 'get_caregiver',
      'Caregivers_ID': id,
    });
    if (res['status'] == 'success' && res['data'] != null) {
      _clearListError();
      return Map<String, dynamic>.from(res['data']);
    }
    _setListErrorFrom(res);
    return null;
  }

  /// تحديث بيانات مقدم الرعاية في جدول caregivers
  Future<Map<String, dynamic>> updateCaregiver({
    required int caregiverId,
    required String name,
    required String phone,
    String email = '',
    String relationship = '',
  }) async {
    return _sendRequest({
      'action': 'update_caregiver',
      'Caregivers_ID': caregiverId,
      'C_Name': name,
      'C_PhonNumber': phone,
      'C_Email': email,
      'C_Relationship': relationship,
    });
  }

  // ==================== مصادقة وبيانات كبير السن ====================

  /// تسجيل كبير السن (جدول elderly)
  Future<Map<String, dynamic>> registerElderly({
    required String name,
    String sex = 'ذكر',
    String phone = '',
    String email = '',
    String password = '',
  }) async {
    if (password.trim().isEmpty) {
      return {
        'status': 'error',
        'error_type': 'password_required',
        'message': 'كلمة المرور مطلوبة لإنشاء الحساب',
      };
    }
    final res = await _sendRequest({
      'action': 'register_elderly',
      'E_Name': name,
      'E_sex': sex,
      'E_PhonNumber': phone,
      'E_Email': email,
      'E_Password': password,
    }, attachBearer: false);
    await _persistTokenFromAuthResponse(res);
    return res;
  }

  /// تسجيل دخول كبير السن برقم الهاتف أو البريد الإلكتروني
  Future<Map<String, dynamic>> loginElderly({
    required String phone,
    String password = '',
  }) async {
    if (password.trim().isEmpty) {
      return {
        'status': 'error',
        'error_type': 'wrong_password',
        'message': 'كلمة المرور غير صحيحة، يرجى التأكد والمحاولة مرة أخرى',
      };
    }
    final res = await _sendRequest({
      'action': 'login_elderly',
      'E_PhonNumber': phone,
      'E_Email': phone,
      'E_Password': password,
    }, attachBearer: false);
    await _persistTokenFromAuthResponse(res);
    return res;
  }

  /// طلب استعادة كلمة المرور عبر البريد الإلكتروني
  Future<Map<String, dynamic>> forgotPassword({
    required String email,
    String role = '',
  }) async {
    return _sendRequest({
      'action': 'forgot_password',
      'email': email,
      'role': role,
    }, attachBearer: false);
  }

  /// إبطال التوكن على الخادم.
  /// Returns true when revocation succeeded or token was already invalid.
  /// Returns false on network/connection failure (do not claim server revoke).
  Future<bool> logoutRemote() async {
    final existing = await TokenStorage.instance.readToken();
    if (existing == null || existing.trim().isEmpty) {
      return true;
    }
    try {
      final res = await _sendRequest({'action': 'logout'}, attachBearer: true);
      if (res['status'] == 'success') return true;
      if (res['http_status'] == 401 ||
          res['error_type'] == 'unauthenticated') {
        return true;
      }
      if (res['is_connection_error'] == true ||
          res['error_type'] == 'connection_error') {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// P1.3: validate Sanctum session via legacy `me` / REST-equivalent.
  Future<Map<String, dynamic>> fetchCurrentUser() async {
    return _sendRequest({'action': 'me'}, attachBearer: true);
  }

  /// جلب قائمة كبار السن المسجلين في قاعدة البيانات
  Future<List<Map<String, dynamic>>> getElderlyList() async {
    final res = await _sendRequest({'action': 'get_elderly'});
    return listDataOrEmpty(res);
  }

  /// جلب بيانات كبير سن محدد بالمعرف
  Future<Map<String, dynamic>?> getElderly(int id) async {
    final res = await _sendRequest({'action': 'get_elderly', 'Eldery_ID': id});
    if (res['status'] == 'success' && res['data'] != null) {
      _clearListError();
      // Single-object success (not a list dump).
      if (res['data'] is Map) {
        return Map<String, dynamic>.from(res['data'] as Map);
      }
      // Accessible-list shape without id filter — unexpected for get-by-id.
      if (res['data'] is List && (res['data'] as List).isNotEmpty) {
        final first = (res['data'] as List).first;
        if (first is Map) return Map<String, dynamic>.from(first);
      }
    }
    _setListErrorFrom(res);
    return null;
  }

  /// تحديث بيانات كبير السن في قاعدة البيانات
  Future<Map<String, dynamic>> updateElderly({
    required int elderlyId,
    required String name,
    required String sex,
    required String phone,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'action': 'update_elderly',
      'Eldery_ID': elderlyId,
      'E_Name': name,
      'E_sex': sex,
      'E_PhonNumber': phone,
    };
    if (email != null) {
      body['E_Email'] = email;
    }
    return _sendRequest(body);
  }

  /// إنشاء رمز ربط مؤقت (كبير السن فقط — 6 أرقام، 10 دقائق)
  Future<Map<String, dynamic>> generateLinkingCode() async {
    return _sendRequest({'action': 'generate_linking_code'});
  }

  /// ربط مقدم الرعاية بكبير السن عبر رمز الربط المؤقت (ليس عبر المعرف المباشر)
  Future<Map<String, dynamic>> linkElderly({
    required int caregiverId,
    required String linkingCode,
  }) async {
    return _sendRequest({
      'action': 'link_elderly',
      'Caregivers_ID': caregiverId,
      'linking_code': linkingCode,
    });
  }

  /// @Deprecated — direct-ID linking is blocked server-side; use [linkElderly] with code.
  @Deprecated('Use linkElderly with linkingCode')
  Future<Map<String, dynamic>> linkElderlyById({
    required int caregiverId,
    required int elderlyId,
  }) async {
    return _sendRequest({
      'action': 'link_elderly',
      'Caregivers_ID': caregiverId,
      'Eldery_ID': elderlyId,
    });
  }

  // ==================== الأدوية (medications) ====================

  /// جلب الأدوية من قاعدة البيانات
  Future<List<Map<String, dynamic>>> getMedications({int? elderlyId}) async {
    final body = <String, dynamic>{'action': 'get_medications'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  /// إضافة دواء إلى قاعدة البيانات
  Future<Map<String, dynamic>> addMedication({
    required String name,
    required String dose,
    required String repeatTime,
    int? elderlyId,
  }) async {
    return _sendRequest({
      'action': 'add_medication',
      'M_Name': name,
      'M_much': dose,
      'M_RepatTime': repeatTime,
      'Elderly_ID': elderlyId,
    });
  }

  /// حذف دواء من قاعدة البيانات
  Future<Map<String, dynamic>> deleteMedication(int medicationId) async {
    return _sendRequest({
      'action': 'delete_medication',
      'Medicayion_ID': medicationId,
    });
  }

  /// تحديث دواء موجود في قاعدة البيانات
  Future<Map<String, dynamic>> updateMedication({
    required int medicationId,
    required String name,
    required String dose,
    required String repeatTime,
  }) async {
    return _sendRequest({
      'action': 'update_medication',
      'Medicayion_ID': medicationId,
      'M_Name': name,
      'M_much': dose,
      'M_RepatTime': repeatTime,
    });
  }

  /// P2.2 — جرعات اليوم من الخادم (مصدر الحقيقة للالتزام)
  Future<Map<String, dynamic>> getTodayMedicationDoses({
    int? elderlyId,
    String? civilDate,
  }) async {
    final body = <String, dynamic>{'action': 'get_medication_doses_today'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    if (civilDate != null && civilDate.isNotEmpty) {
      body['civil_date'] = civilDate;
    }
    return _sendRequest(body);
  }

  /// P2.2 — سجل الالتزام من الخادم (أفق محدود)
  Future<Map<String, dynamic>> getMedicationAdherenceHistory({
    int? elderlyId,
    String? from,
    String? to,
  }) async {
    final body = <String, dynamic>{
      'action': 'get_medication_adherence_history',
    };
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    if (from != null && from.isNotEmpty) body['from'] = from;
    if (to != null && to.isNotEmpty) body['to'] = to;
    return _sendRequest(body);
  }

  /// P2.2 — تأكيد جرعة على الخادم (كبير السن فقط؛ يتطلب اتصالاً)
  Future<Map<String, dynamic>> confirmMedicationDose({
    required int medicationId,
    String? civilDate,
    String? occurrenceKey,
    String? clientConfirmId,
  }) async {
    final body = <String, dynamic>{
      'action': 'confirm_medication_dose',
      'Medicayion_ID': medicationId,
    };
    if (civilDate != null && civilDate.isNotEmpty) {
      body['civil_date'] = civilDate;
    }
    if (occurrenceKey != null && occurrenceKey.isNotEmpty) {
      body['occurrence_key'] = occurrenceKey;
    }
    if (clientConfirmId != null && clientConfirmId.isNotEmpty) {
      body['client_confirm_id'] = clientConfirmId;
    }
    return _sendRequest(body);
  }

  // ==================== المواعيد (appointments) ====================

  /// جلب المواعيد من قاعدة البيانات
  Future<List<Map<String, dynamic>>> getAppointments({int? elderlyId}) async {
    final body = <String, dynamic>{'action': 'get_appointments'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  /// إضافة موعد جديد إلى قاعدة البيانات
  Future<Map<String, dynamic>> addAppointment({
    required String date,
    required String time,
    required String dateType,
    required String location,
    String note = '',
    int? elderlyId,
  }) async {
    return _sendRequest({
      'action': 'add_appointment',
      'A_Date': date,
      'A_Time': time,
      'A_DateType': dateType,
      'A_Location': location,
      'A_Note': note,
      'Elderly_ID': elderlyId,
    });
  }

  /// تحديث موعد موجود (نفس Appointment_ID — لا حذف وإعادة إنشاء)
  Future<Map<String, dynamic>> updateAppointment({
    required int appointmentId,
    required String date,
    required String time,
    required String dateType,
    required String location,
    String note = '',
  }) async {
    return _sendRequest({
      'action': 'update_appointment',
      'Appointment_ID': appointmentId,
      'A_Date': date,
      'A_Time': time,
      'A_DateType': dateType,
      'A_Location': location,
      'A_Note': note,
    });
  }

  /// حذف موعد من قاعدة البيانات
  Future<Map<String, dynamic>> deleteAppointment(int appointmentId) async {
    return _sendRequest({
      'action': 'delete_appointment',
      'Appointment_ID': appointmentId,
    });
  }

  // ==================== جهات اتصال الطوارئ (emergency_contacts) ====================

  /// جلب جهات الاتصال من قاعدة البيانات
  Future<List<Map<String, dynamic>>> getEmergencyContacts({
    int? elderlyId,
  }) async {
    final body = <String, dynamic>{'action': 'get_emergency_contacts'};
    if (elderlyId != null) body['Eldery_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  /// إضافة جهة اتصال طوارئ
  Future<Map<String, dynamic>> addEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
    int priority = 1,
    int? elderlyId,
  }) async {
    return _sendRequest({
      'action': 'add_emergency_contact',
      'contact_Name': name,
      'Phone_Number': phone,
      'Relationship': relationship,
      'Priority': priority,
      'Eldery_ID': elderlyId,
    });
  }

  /// حذف جهة اتصال طوارئ
  Future<Map<String, dynamic>> deleteEmergencyContact(int contactId) async {
    return _sendRequest({
      'action': 'delete_emergency_contact',
      'contact_ID': contactId,
    });
  }

  // ==================== الأجهزة (devices) ====================

  /// جلب الأجهزة المرتبطة بكبير السن من قاعدة البيانات
  Future<List<Map<String, dynamic>>> getDevices({int? elderlyId}) async {
    final body = <String, dynamic>{'action': 'get_devices'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  /// إضافة جهاز إلى جدول devices
  Future<Map<String, dynamic>> addDevice({
    String? type,
    String? number,
    String? deviceType,
    String? deviceName,
    String? status,
    int? elderlyId,
  }) async {
    final finalType = deviceType ?? type ?? deviceName ?? 'ساعة ذكية';
    // Never invent YS-* serials — require a real number from the caller.
    final finalNumber = (number ?? deviceName ?? '').trim();
    if (finalNumber.isEmpty) {
      return {
        'status': 'error',
        'success': false,
        'message': 'الرقم التعريفي للجهاز مطلوب',
        'error_type': 'validation',
      };
    }
    final res = await _sendRequest({
      'action': 'add_device',
      'D_Type': finalType,
      'T_Number': finalNumber,
      'Elderly_ID': elderlyId,
    });
    return {...res, 'success': res['status'] == 'success'};
  }

  /// فك اقتران أو حذف جهاز من قاعدة البيانات
  Future<Map<String, dynamic>> deleteDevice({
    int? deviceId,
    int? elderlyId,
  }) async {
    final res = await _sendRequest({
      'action': 'delete_device',
      'Devices_ID': deviceId,
      'Elderly_ID': elderlyId,
    });
    return {...res, 'success': res['status'] == 'success'};
  }

  // ==================== المؤشرات الحيوية والصحة (health_monitoring) ====================

  /// جلب سجلات المراقبة الصحية
  Future<List<Map<String, dynamic>>> getHealthRecords({int? elderlyId}) async {
    final body = <String, dynamic>{'action': 'get_health_monitoring'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  /// إضافة سجل مؤشرات حيوية جديد
  Future<Map<String, dynamic>> addHealthRecord({
    int? heartRate,
    String? bloodPressure,
    int? oxygen,
    double? temperature,
    int? steps,
    String? type,
    String? result,
    int? elderlyId,
  }) async {
    return _sendRequest({
      'action': 'add_health_record',
      'Heart_Rate': heartRate,
      'Blood_pressure': bloodPressure,
      'Oxyger': oxygen,
      'Temperature': temperature,
      'steps': steps,
      'H_Type': type ?? 'فحص عام',
      'H_Result': result ?? 'طبيعي',
      'Elderly_ID': elderlyId,
    });
  }

  // ==================== الموقع الجغرافي (location_tracking) ====================

  /// جلب موقع كبير السن
  Future<dynamic> getLocation({int? elderlyId}) async {
    final body = <String, dynamic>{'action': 'get_location'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return res['data'];
  }

  /// تحديث الموقع الجغرافي لكبير السن في جدول location_tracking
  /// [accuracyMeters] = دقة GPS الأفقية الحقيقية بالمتر (لا تُختلق).
  Future<Map<String, dynamic>> updateLocation({
    required int elderlyId,
    required double latitude,
    required double longitude,
    String location = '',
    double? accuracyMeters,
  }) async {
    return _sendRequest({
      'action': 'update_location',
      'Elderly_ID': elderlyId,
      'latitude': latitude,
      'Longitude': longitude,
      'E_Location': location,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      if (accuracyMeters != null) 'L_AccuracyMeters': accuracyMeters,
    });
  }

  /// P2.4 — حالة موافقة مشاركة الموقع (خادم).
  Future<Map<String, dynamic>> getLocationSharing({int? elderlyId}) async {
    final body = <String, dynamic>{'action': 'get_location_sharing'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    if (res['status'] == 'success' && res['data'] is Map) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    return res;
  }

  /// P2.4 — تفعيل/إيقاف مشاركة الموقع (كبير السن فقط).
  Future<Map<String, dynamic>> setLocationSharing({
    required bool enabled,
    int? elderlyId,
  }) async {
    return _sendRequest({
      'action': 'set_location_sharing',
      'location_sharing_enabled': enabled,
      if (elderlyId != null) 'Elderly_ID': elderlyId,
    });
  }

  /// P2.4-B — جلب المناطق الآمنة.
  Future<List<Map<String, dynamic>>> getSafeZones({int? elderlyId}) async {
    final body = <String, dynamic>{'action': 'get_safe_zones'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  Future<Map<String, dynamic>> createSafeZone({
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    int? elderlyId,
  }) async {
    return _sendRequest({
      'action': 'add_safe_zone',
      'name': name,
      'center_lat': latitude,
      'center_lng': longitude,
      'radius_meters': radiusMeters,
      if (elderlyId != null) 'Elderly_ID': elderlyId,
    });
  }

  Future<Map<String, dynamic>> approveSafeZone(int zoneId) async {
    return _sendRequest({
      'action': 'approve_safe_zone',
      'Zone_ID': zoneId,
    });
  }

  Future<Map<String, dynamic>> rejectSafeZone(int zoneId) async {
    return _sendRequest({
      'action': 'reject_safe_zone',
      'Zone_ID': zoneId,
    });
  }

  Future<Map<String, dynamic>> deleteSafeZone(int zoneId) async {
    return _sendRequest({
      'action': 'delete_safe_zone',
      'Zone_ID': zoneId,
    });
  }

  // ==================== التنبيهات (notifications) ====================

  /// جلب التنبيهات
  Future<List<Map<String, dynamic>>> getNotifications({
    int? elderlyId,
    int? caregiverId,
  }) async {
    final body = <String, dynamic>{'action': 'get_notifications'};
    if (elderlyId != null) body['Eldery_ID'] = elderlyId;
    if (caregiverId != null) body['Caregiver_ID'] = caregiverId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  /// إضافة تنبيه جديد إلى قاعدة البيانات
  Future<Map<String, dynamic>> addNotification({
    required String title,
    required String message,
    String type = 'alert',
    int? elderlyId,
    int? caregiverId,
  }) async {
    return _sendRequest({
      'action': 'add_notification',
      'N_Title': title,
      'N_Message': message,
      'N_Type': type,
      'Eldery_ID': elderlyId,
      if (caregiverId != null) 'Caregiver_ID': caregiverId,
    });
  }

  /// P2.3 — mark notification read (legacy + REST bridge).
  Future<Map<String, dynamic>> markNotificationRead(int notificationId) async {
    return _sendRequest({
      'action': 'mark_notification_read',
      'Notifications_ID': notificationId,
      'id': notificationId,
    });
  }

  // ==================== سجلات الطوارئ والاستغاثة (emergency_log) ====================

  /// جلب سجلات الطوارئ لكبير السن من قاعدة البيانات
  Future<List<Map<String, dynamic>>> getEmergencyLog({int? elderlyId}) async {
    final body = <String, dynamic>{'action': 'get_emergency_log'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  /// الاسم البديل لجلب سجلات الطوارئ
  Future<List<Map<String, dynamic>>> getEmergencyLogs({int? elderlyId}) =>
      getEmergencyLog(elderlyId: elderlyId);

  /// تسجيل استغاثة طوارئ جديدة في جدول emergency_log
  Future<Map<String, dynamic>> addEmergencyLog({
    String type = 'نداء استغاثة طارئ SOS',
    String location = 'الموقع الحالي',
    double? latitude,
    double? longitude,
    String state = 'نشط - قيد المتابعة',
    String? status,
    String description = 'تم إرسال نداء استغاثة فوري',
    int? elderlyId,
  }) async {
    return _sendRequest({
      'action': 'add_emergency_log',
      'E_Type': type,
      'E_Location': location,
      'latitude': latitude,
      'Longitude': longitude,
      'E_State': status ?? state,
      'Descripion': description,
      'Elderly_ID': elderlyId,
    });
  }

  /// تحديث حالة بلاغ الطوارئ (قيد المتابعة / تمت المعالجة)
  Future<Map<String, dynamic>> updateEmergencyStatus({
    required int emergencyId,
    required String state,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'action': 'update_emergency_status',
      'Emergency_ID': emergencyId,
      'E_State': state,
    };
    if (note != null && note.isNotEmpty) {
      body['Descripion'] = note;
    }
    final res = await _sendRequest(body);
    return {...res, 'success': res['status'] == 'success'};
  }

  // ==================== نوع الرعاية (type_of_care) ====================

  /// جلب نوع الرعاية
  Future<List<Map<String, dynamic>>> getTypeOfCare({
    int? elderlyId,
    int? caregiverId,
  }) async {
    final body = <String, dynamic>{'action': 'get_type_of_care'};
    if (elderlyId != null) body['Eldery_ID'] = elderlyId;
    if (caregiverId != null) body['Caregivers_ID'] = caregiverId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  /// إضافة نوع رعاية جديد
  Future<Map<String, dynamic>> addTypeOfCare({
    required String careType,
    int? caregiverId,
    int? elderlyId,
  }) async {
    return _sendRequest({
      'action': 'add_type_of_care',
      'Care_Type': careType,
      'Caregivers_ID': caregiverId,
      'Eldery_ID': elderlyId,
    });
  }

  // ==================== سجل التحركات والموقع ====================

  /// جلب سجل تحركات كبير السن
  Future<List<Map<String, dynamic>>> getLocationHistory({
    int? elderlyId,
  }) async {
    final body = <String, dynamic>{'action': 'get_location_history'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  // ==================== الخدمات وطلبات الخدمات (services & services_request) ====================

  /// جلب قائمة الخدمات المتاحة
  Future<List<Map<String, dynamic>>> getServices() async {
    final res = await _sendRequest({'action': 'get_services'});
    return listDataOrEmpty(res);
  }

  /// تقديم طلب خدمة جديدة
  Future<Map<String, dynamic>> requestService({
    required int serviceId,
    int? caregiverId,
    int? elderlyId,
    String note = '',
  }) async {
    return _sendRequest({
      'action': 'request_service',
      'Service_ID': serviceId,
      'Caregivers_id': caregiverId,
      'Elderly_ID': elderlyId,
      'Requst_Note': note,
    });
  }

  /// جلب طلبات الخدمات المقدمة
  Future<List<Map<String, dynamic>>> getServiceRequests({
    int? caregiverId,
    int? elderlyId,
  }) async {
    final body = <String, dynamic>{'action': 'get_service_requests'};
    if (caregiverId != null) body['Caregivers_id'] = caregiverId;
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  // ==================== التنبيهات الصحية (health_alerts) ====================

  /// جلب التنبيهات الصحية
  Future<List<Map<String, dynamic>>> getHealthAlerts({int? elderlyId}) async {
    final body = <String, dynamic>{'action': 'get_health_alerts'};
    if (elderlyId != null) body['Elderly_ID'] = elderlyId;
    final res = await _sendRequest(body);
    return listDataOrEmpty(res);
  }

  /// تسجيل تنبيه صحي جديد
  Future<Map<String, dynamic>> addHealthAlert({
    required String type,
    required String description,
    String level = 'متوسط',
    String status = 'نشط',
    int? hRecordId,
  }) async {
    return _sendRequest({
      'action': 'add_health_alert',
      'A_Type': type,
      'A_Description': description,
      'A_Level': level,
      'A_Status': status,
      'H_Record_ID': hRecordId,
    });
  }

  // ==================== المساعد الصوتي والذكاء الاصطناعي (Gemini) ====================

  /// استدعاء المساعد الصوتي الذكي المدعوم بـ Gemini عبر خادم Laravel API
  Future<Map<String, dynamic>> askAiVoiceAssistant({
    required String prompt,
    int? elderlyId,
  }) async {
    return _sendRequest({
      'action': 'voice_assistant',
      'prompt': prompt,
      if (elderlyId != null) 'elderly_id': elderlyId,
    });
  }

  // ==================== إرسال الطلب الداخلي ====================
  Future<Map<String, dynamic>> _sendRequest(
    Map<String, dynamic> body, {
    bool attachBearer = true,
  }) async {
    _ensureAuthHooks();
    // 1. إذا لم يتم تحديد خادم نشط بعد، قم بالكشف التلقائي
    if (_workingUrl == null) {
      await discoverWorkingServer();
    }

    dynamic lastError;
    final token =
        attachBearer ? await TokenStorage.instance.readToken() : null;

    // 2. المحاولة على العناوين بالترتيب بدءاً من الخادم النشط
    for (final url in _orderedUrls) {
      try {
        final uri = Uri.parse(url);
        final request = await _client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');

        // Bearer only on trusted Yusr API URLs — never :8000 / unrelated candidates.
        final bearerAttached = wouldAttachBearer(
          attachBearer: attachBearer,
          token: token,
          url: url,
        );
        if (bearerAttached) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }

        request.write(jsonEncode(body));

        final response = await request.close().timeout(
          const Duration(seconds: 15),
        );
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 401) {
          // Invalidate session ONLY when Bearer was actually attached to a
          // trusted authenticated API. A 401 from :8000 / untrusted hosts (or
          // attachBearer:false probes) must never clear a valid local session.
          if (bearerAttached) {
            final lastRole = AuthService().role;
            await TokenStorage.instance.clear();
            AuthService().clearSessionLocal();
            onUnauthorized?.call(lastRole);
          }
          Map<String, dynamic> data = {
            'status': 'error',
            'error_type': 'unauthenticated',
            'message': 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى',
            'http_status': 401,
          };
          if (responseBody.isNotEmpty) {
            try {
              final parsed = jsonDecode(responseBody);
              if (parsed is Map<String, dynamic>) {
                data = {
                  ...parsed,
                  'http_status': 401,
                  'error_type':
                      parsed['error_type'] ?? 'unauthenticated',
                };
              }
            } catch (_) {}
          }
          return data;
        }

        if (responseBody.isNotEmpty) {
          final decoded = jsonDecode(responseBody);
          if (decoded is! Map<String, dynamic>) {
            return {
              'status': 'error',
              'message': 'استجابة غير متوقعة من الخادم',
              'http_status': response.statusCode,
            };
          }
          final data = Map<String, dynamic>.from(decoded);
          _workingUrl = url;
          // Normalize non-success HTTP / missing status (e.g. Laravel 500 SQLSTATE)
          // so callers never treat raw exceptions as empty success.
          if (response.statusCode >= 400 && data['status'] != 'error') {
            data['status'] = 'error';
            data['http_status'] = response.statusCode;
            data['message'] ??= 'تعذّر إتمام العملية على الخادم';
          } else if (data['status'] == null && response.statusCode >= 400) {
            data['status'] = 'error';
            data['http_status'] = response.statusCode;
            data['message'] ??= 'تعذّر إتمام العملية على الخادم';
          }
          return data;
        }
      } catch (e) {
        lastError = e;
        if (url == _workingUrl) {
          _workingUrl = null; // إعادة الفحص عند انقطاع الاتصال
        }
      }
    }

    final bool isTimeout = lastError is TimeoutException ||
        (lastError != null &&
            lastError.toString().toLowerCase().contains('timed out'));
    final String errorMsg = isTimeout
        ? 'تعذّر الاتصال بالخادم (انتهت مهلة الانتظار)، يُرجى التحقق من اتصال الشبكة والمحاولة مرة أخرى'
        : 'تعذّر الاتصال بالخادم، يُرجى التأكد من اتصال الهاتف بالشبكة والمحاولة مرة أخرى';

    return {
      'status': 'error',
      'is_connection_error': true,
      'error_type': 'connection_error',
      'message': errorMsg,
      'raw_error': '$lastError',
      'hint':
          'تأكد من تشغيل Apache و MySQL في XAMPP وتواجد الهاتف على نفس شبكة الحاسوب (192.168.8.182)',
    };
  }

  /// نافذة منبثقة لإعداد وفحص الاتصال بالخادم وقاعدة البيانات من أي جهاز
  static Future<void> showServerConfigDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl =
        prefs.getString('custom_api_url') ?? _workingUrl ?? officeLANBaseUrl;
    final controller = TextEditingController(text: savedUrl);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isTesting = false;
        String? testMessage;
        bool? isSuccess;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B434D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.dns_rounded,
                        color: Color(0xFF1B434D),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'إعدادات الاتصال بقاعدة البيانات',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1B434D),
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // شريط حالة الخادم النشط
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: (_workingUrl != null)
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_workingUrl != null)
                                ? Colors.green.shade300
                                : Colors.orange.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _workingUrl != null
                                  ? Icons.check_circle
                                  : Icons.warning_amber_rounded,
                              color: _workingUrl != null
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _workingUrl != null
                                    ? 'متصل حالياً عبر:\n$_workingUrl'
                                    : 'لم يتم التأكد من الاتصال بعد',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _workingUrl != null
                                      ? Colors.green.shade900
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'عنوان IP أو رابط الخادم:',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: controller,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: '192.168.0.252 أو الرابط الكامل',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(Icons.link, size: 20),
                        ),
                        style: GoogleFonts.sourceCodePro(fontSize: 13),
                      ),
                      const SizedBox(height: 10),

                      // خيارات سريعة شائعة
                      Text(
                        'عناوين شائعة وسريعة:',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            label: Text(
                              'واي فاي الحالية (192.168.0.252)',
                              style: GoogleFonts.cairo(fontSize: 11),
                            ),
                            onPressed: () => setDialogState(
                              () => controller.text = '192.168.0.252',
                            ),
                          ),
                          ActionChip(
                            label: Text(
                              'كابل USB (8088 lab)',
                              style: GoogleFonts.cairo(fontSize: 11),
                            ),
                            onPressed: () => setDialogState(
                              () => controller.text = '127.0.0.1:8088',
                            ),
                          ),
                          ActionChip(
                            label: Text(
                              'كابل USB (8080)',
                              style: GoogleFonts.cairo(fontSize: 11),
                            ),
                            onPressed: () => setDialogState(
                              () => controller.text = '127.0.0.1:8080',
                            ),
                          ),
                          ActionChip(
                            label: Text(
                              'محاكي أندرويد (10.0.2.2)',
                              style: GoogleFonts.cairo(fontSize: 11),
                            ),
                            onPressed: () => setDialogState(
                              () => controller.text = '10.0.2.2',
                            ),
                          ),
                          ActionChip(
                            label: Text(
                              'المحلي (localhost)',
                              style: GoogleFonts.cairo(fontSize: 11),
                            ),
                            onPressed: () => setDialogState(
                              () => controller.text = 'localhost',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (testMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSuccess == true
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSuccess == true
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSuccess == true
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: isSuccess == true
                                    ? Colors.green
                                    : Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  testMessage!,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSuccess == true
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // زر الكشف التلقائي
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isTesting
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isTesting = true;
                                    testMessage =
                                        'جاري البحث عن الخادم في الشبكة...';
                                    isSuccess = null;
                                  });
                                  final discovered = await instance
                                      .discoverWorkingServer();
                                  setDialogState(() {
                                    isTesting = false;
                                    if (discovered != null) {
                                      controller.text = discovered;
                                      testMessage =
                                          'تم العثور على الخادم بنجاح والاتصال به!';
                                      isSuccess = true;
                                    } else {
                                      testMessage =
                                          'تعذر العثور على خادم تلقائياً. يرجى إدخال عنوان IP يدوياً.';
                                      isSuccess = false;
                                    }
                                  });
                                },
                          icon: const Icon(Icons.radar, size: 18),
                          label: Text(
                            'كشف تلقائي وبحث في الشبكة',
                            style: GoogleFonts.cairo(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('إغلاق', style: GoogleFonts.cairo()),
                  ),
                  ElevatedButton(
                    onPressed: isTesting
                        ? null
                        : () async {
                            setDialogState(() {
                              isTesting = true;
                              testMessage = 'جاري حفظ وتجربة الرابط...';
                              isSuccess = null;
                            });
                            final ok = await instance.setCustomServer(
                              controller.text,
                            );
                            setDialogState(() {
                              isTesting = false;
                              if (ok) {
                                testMessage =
                                    'تم الاتصال بقاعدة البيانات بنجاح وحفظ الإعدادات! 🎉';
                                isSuccess = true;
                              } else {
                                testMessage =
                                    'فشل الاتصال بالرابط المحدد. تأكد من تشغيل Apache و MySQL في XAMPP.';
                                isSuccess = false;
                              }
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B434D),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'حفظ واختبار',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
