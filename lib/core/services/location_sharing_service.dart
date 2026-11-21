import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_service.dart';

/// P2.4-A — foreground-only location sharing (L1/L2).
///
/// Updates at most every 60s while the app is resumed and sharing is enabled.
/// Never fabricates GPS. No background tracking.
class LocationSharingService with WidgetsBindingObserver {
  LocationSharingService._();
  static final LocationSharingService instance = LocationSharingService._();

  static const Duration updateInterval = Duration(seconds: 60);
  static const String _prefKeyPrefix = 'yusr_location_sharing_local_';

  Timer? _timer;
  bool _busy = false;
  bool _observing = false;
  bool _serverSharingEnabled = false;
  String? _lastError;
  DateTime? _lastSuccessfulPublishAt;
  Position? _lastKnownPosition;

  bool get serverSharingEnabled => _serverSharingEnabled;
  String? get lastError => _lastError;
  DateTime? get lastSuccessfulPublishAt => _lastSuccessfulPublishAt;
  Position? get lastKnownPosition => _lastKnownPosition;
  bool get isForegroundLoopRunning => _timer != null;

  Future<void> ensureLifecycleObserver() async {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_serverSharingEnabled) {
        unawaited(startForegroundLoop());
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      stopForegroundLoop();
    }
  }

  String _prefKeyForUser() {
    final uid = AuthService().userId;
    return '$_prefKeyPrefix${uid ?? 'anon'}';
  }

  Future<bool> refreshSharingFromServer() async {
    try {
      final res = await ApiService.instance.getLocationSharing();
      final enabled = res['location_sharing_enabled'] == true ||
          res['sharing_enabled'] == true;
      _serverSharingEnabled = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyForUser(), enabled);
      return enabled;
    } catch (e) {
      _lastError = e.toString();
      return _serverSharingEnabled;
    }
  }

  Future<bool> setSharingEnabled(bool enabled) async {
    final res = await ApiService.instance.setLocationSharing(enabled: enabled);
    if (res['status'] != 'success') {
      _lastError = res['message']?.toString() ?? 'تعذّر تحديث مشاركة الموقع';
      throw StateError(_lastError!);
    }
    _serverSharingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyForUser(), enabled);
    if (enabled) {
      await ensureLifecycleObserver();
      await startForegroundLoop();
    } else {
      stopForegroundLoop();
    }
    return enabled;
  }

  Future<void> startForegroundLoop() async {
    await ensureLifecycleObserver();
    stopForegroundLoop();
    if (!_serverSharingEnabled) return;
    await publishOnce(manual: false);
    _timer = Timer.periodic(updateInterval, (_) {
      unawaited(publishOnce(manual: false));
    });
  }

  void stopForegroundLoop() {
    _timer?.cancel();
    _timer = null;
  }

  /// GPS / permission outcome for honest Arabic UI (never claim success).
  static const String errServicesOff =
      'خدمات الموقع مطفأة على الجهاز — فعّلها ثم أعد المحاولة';
  static const String errPermissionDenied =
      'تم رفض إذن الموقع — اسمح بالوصول أثناء استخدام التطبيق';
  static const String errPermissionPermanentlyDenied =
      'إذن الموقع مرفوض نهائيًا — افتح إعدادات التطبيق وفعّل الموقع';
  static const String errGpsUnavailable =
      'تعذر الحصول على موقع GPS حالياً — سيُعرض آخر موقع معروف إن وُجد';

  /// Request while-in-use permission only (no background).
  Future<LocationPermission> ensureForegroundPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _lastError = errServicesOff;
      return LocationPermission.denied;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      _lastError = errPermissionDenied;
    } else if (permission == LocationPermission.deniedForever) {
      _lastError = errPermissionPermanentlyDenied;
    }
    return permission;
  }

  Future<Position?> acquireCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _lastError = errServicesOff;
      return null;
    }

    final permission = await ensureForegroundPermission();
    if (permission == LocationPermission.deniedForever) {
      _lastError = errPermissionPermanentlyDenied;
      return null;
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      _lastError = errPermissionDenied;
      return null;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _lastKnownPosition = pos;
      _lastError = null;
      return pos;
    } catch (e) {
      _lastError = errGpsUnavailable;
      return null;
    }
  }

  Future<bool> publishOnce({bool manual = true}) async {
    if (_busy) return false;
    _busy = true;
    try {
      if (!_serverSharingEnabled) {
        final ok = await refreshSharingFromServer();
        if (!ok) {
          _lastError = 'مشاركة الموقع متوقفة';
          return false;
        }
      }

      final pos = await acquireCurrentPosition();
      if (pos == null) return false;

      final elderlyId = AuthService().userId;
      if (elderlyId == null) {
        _lastError = 'لا يوجد معرّف مستخدم مسجّل';
        return false;
      }

      final res = await ApiService.instance.updateLocation(
        elderlyId: elderlyId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyMeters: pos.accuracy,
      );
      if (res['status'] == 'success') {
        _lastSuccessfulPublishAt = DateTime.now();
        _lastError = null;
        return true;
      }
      if (res['error_type'] == 'sharing_disabled') {
        _serverSharingEnabled = false;
        stopForegroundLoop();
      }
      _lastError = res['message']?.toString() ?? 'فشل نشر الموقع';
      return false;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Clear local sharing prefs on account switch / logout.
  Future<void> clearLocalState() async {
    stopForegroundLoop();
    _serverSharingEnabled = false;
    _lastKnownPosition = null;
    _lastSuccessfulPublishAt = null;
    _lastError = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyForUser());
    } catch (_) {}
  }
}
