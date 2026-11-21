import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../location/location_access_gate.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// P2.4-A — foreground-only location sharing (L1/L2).
///
/// Updates at most every 60s while the app is resumed and sharing is enabled.
/// Never fabricates GPS. No background tracking.
///
/// A position fix is accepted only after [LocationAccessGate] confirms
/// services + permission (Geolocator **and** permission_handler). Mid-session
/// revoke must not claim «تم تحديث الموقع من GPS».
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
  String? _lastWarning;
  DateTime? _lastSuccessfulPublishAt;
  Position? _lastKnownPosition;

  /// Injectable for tests — production uses real platform APIs.
  LocationAccessGate accessGate = LocationAccessGate();

  /// Optional override for getCurrentPosition (tests).
  Future<Position> Function()? debugGetCurrentPosition;

  bool get serverSharingEnabled => _serverSharingEnabled;
  String? get lastError => _lastError;
  String? get lastWarning => _lastWarning;
  DateTime? get lastSuccessfulPublishAt => _lastSuccessfulPublishAt;
  Position? get lastKnownPosition => _lastKnownPosition;
  bool get isForegroundLoopRunning => _timer != null;

  // Aliases kept for existing call sites / tests.
  static const String errServicesOff = LocationAccessMessages.servicesOff;
  static const String errPermissionDenied = LocationAccessMessages.denied;
  static const String errPermissionPermanentlyDenied =
      LocationAccessMessages.permanentlyDenied;
  static const String errGpsUnavailable = LocationAccessMessages.gpsUnavailable;
  static const String errApproximateOnly =
      LocationAccessMessages.approximateOnly;

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

  /// Request while-in-use permission only (no background).
  Future<LocationPermission> ensureForegroundPermission() async {
    final snap = await accessGate.ensure(requestIfDenied: true);
    _applyAccessSnapshot(snap, allowApproximateWarning: true);
    return snap.geolocatorPermission ?? LocationPermission.denied;
  }

  void _applyAccessSnapshot(
    LocationAccessSnapshot snap, {
    required bool allowApproximateWarning,
  }) {
    _lastWarning = null;
    if (snap.kind == LocationAccessKind.servicesOff ||
        snap.kind == LocationAccessKind.denied ||
        snap.kind == LocationAccessKind.permanentlyDenied) {
      _lastError = snap.arabicMessage;
      return;
    }
    if (snap.kind == LocationAccessKind.okApproximate &&
        allowApproximateWarning) {
      _lastWarning = snap.arabicMessage;
    }
    if (snap.allowsFix) {
      _lastError = null;
    }
  }

  /// Acquire a fix only when access gate allows it — before **and** after read.
  Future<Position?> acquireCurrentPosition() async {
    final before = await accessGate.ensure(requestIfDenied: true);
    _applyAccessSnapshot(before, allowApproximateWarning: true);
    if (!before.allowsFix) {
      return null;
    }

    Position pos;
    try {
      if (debugGetCurrentPosition != null) {
        pos = await debugGetCurrentPosition!();
      } else {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      }
    } catch (e) {
      _lastError = errGpsUnavailable;
      return null;
    }

    // Critical: re-check after the platform returns a fix (handles pm revoke /
    // cached fused locations while dumpsys granted=false).
    final after = await accessGate.evaluate();
    _applyAccessSnapshot(after, allowApproximateWarning: true);
    if (!after.allowsFix) {
      // Do NOT bump _lastKnownPosition or claim a new update.
      return null;
    }

    _lastKnownPosition = pos;
    return pos;
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

      // Final gate immediately before treating publish as GPS success.
      final finalGate = await accessGate.evaluate();
      _applyAccessSnapshot(finalGate, allowApproximateWarning: true);
      if (!finalGate.allowsFix) {
        return false;
      }

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
    _lastWarning = null;
    accessGate = LocationAccessGate();
    debugGetCurrentPosition = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyForUser());
    } catch (_) {}
  }

  @visibleForTesting
  void debugSetServerSharingEnabled(bool enabled) {
    _serverSharingEnabled = enabled;
  }
}
