import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Outcome of a foreground location access check (services + permission).
enum LocationAccessKind {
  okPrecise,
  okApproximate,
  servicesOff,
  denied,
  permanentlyDenied,
}

class LocationAccessSnapshot {
  const LocationAccessSnapshot({
    required this.kind,
    required this.arabicMessage,
    this.geolocatorPermission,
    this.whenInUseStatus,
    this.fineStatus,
  });

  final LocationAccessKind kind;
  final String arabicMessage;
  final LocationPermission? geolocatorPermission;
  final ph.PermissionStatus? whenInUseStatus;
  final ph.PermissionStatus? fineStatus;

  bool get allowsFix =>
      kind == LocationAccessKind.okPrecise ||
      kind == LocationAccessKind.okApproximate;

  bool get isDenied =>
      kind == LocationAccessKind.denied ||
      kind == LocationAccessKind.permanentlyDenied ||
      kind == LocationAccessKind.servicesOff;
}

/// Arabic copy for GPS / permission UI (shared with [LocationSharingService]).
class LocationAccessMessages {
  LocationAccessMessages._();

  static const servicesOff =
      'خدمات الموقع مطفأة على الجهاز — فعّلها ثم أعد المحاولة';
  static const denied =
      'تم رفض إذن الموقع — اسمح بالوصول أثناء استخدام التطبيق';
  static const permanentlyDenied =
      'إذن الموقع مرفوض نهائيًا — افتح إعدادات التطبيق وفعّل الموقع';
  static const approximateOnly =
      'يتوفر الموقع التقريبي فقط — إذن الموقع الدقيق غير ممنوح';
  static const gpsUnavailable =
      'تعذر الحصول على موقع GPS حالياً — سيُعرض آخر موقع معروف إن وُجد';
}

/// Evaluates whether a new GPS fix may be treated as success.
///
/// Cross-checks [Geolocator] with [permission_handler] so a mid-session
/// `pm revoke` (Geolocator cache / OEM quirk) cannot claim a successful update.
class LocationAccessGate {
  LocationAccessGate({
    Future<bool> Function()? servicesEnabled,
    Future<LocationPermission> Function()? checkGeoPermission,
    Future<LocationPermission> Function()? requestGeoPermission,
    Future<ph.PermissionStatus> Function()? whenInUseStatus,
    Future<ph.PermissionStatus> Function()? fineStatus,
    Future<ph.PermissionStatus> Function()? requestWhenInUse,
    Future<LocationAccuracyStatus> Function()? locationAccuracy,
  })  : _servicesEnabled =
            servicesEnabled ?? Geolocator.isLocationServiceEnabled,
        _checkGeoPermission =
            checkGeoPermission ?? Geolocator.checkPermission,
        _requestGeoPermission =
            requestGeoPermission ?? Geolocator.requestPermission,
        _whenInUseStatus = whenInUseStatus ??
            (() => ph.Permission.locationWhenInUse.status),
        _fineStatus = fineStatus ?? (() => ph.Permission.location.status),
        _requestWhenInUse = requestWhenInUse ??
            (() => ph.Permission.locationWhenInUse.request()),
        _locationAccuracy =
            locationAccuracy ?? Geolocator.getLocationAccuracy;

  final Future<bool> Function() _servicesEnabled;
  final Future<LocationPermission> Function() _checkGeoPermission;
  final Future<LocationPermission> Function() _requestGeoPermission;
  final Future<ph.PermissionStatus> Function() _whenInUseStatus;
  final Future<ph.PermissionStatus> Function() _fineStatus;
  final Future<ph.PermissionStatus> Function() _requestWhenInUse;
  final Future<LocationAccuracyStatus> Function() _locationAccuracy;

  /// Read-only evaluation (does not prompt the user).
  Future<LocationAccessSnapshot> evaluate() async {
    final servicesOn = await _servicesEnabled();
    if (!servicesOn) {
      return const LocationAccessSnapshot(
        kind: LocationAccessKind.servicesOff,
        arabicMessage: LocationAccessMessages.servicesOff,
      );
    }

    final geo = await _checkGeoPermission();
    final whenInUse = await _whenInUseStatus();
    final fine = await _fineStatus();

    // Trust deny from either API — never claim success when either says no.
    final geoDeniedForever = geo == LocationPermission.deniedForever;
    final phDeniedForever = whenInUse.isPermanentlyDenied ||
        whenInUse.isRestricted ||
        fine.isPermanentlyDenied;

    if (geoDeniedForever || phDeniedForever) {
      return LocationAccessSnapshot(
        kind: LocationAccessKind.permanentlyDenied,
        arabicMessage: LocationAccessMessages.permanentlyDenied,
        geolocatorPermission: geo,
        whenInUseStatus: whenInUse,
        fineStatus: fine,
      );
    }

    final geoGranted = geo == LocationPermission.whileInUse ||
        geo == LocationPermission.always;
    final phGranted = whenInUse.isGranted || whenInUse.isLimited;

    if (!geoGranted || !phGranted) {
      return LocationAccessSnapshot(
        kind: LocationAccessKind.denied,
        arabicMessage: LocationAccessMessages.denied,
        geolocatorPermission: geo,
        whenInUseStatus: whenInUse,
        fineStatus: fine,
      );
    }

    // Approximate-only: when-in-use granted but fine/precise not available.
    var approximate = fine.isDenied ||
        fine.isPermanentlyDenied ||
        fine.isRestricted;
    try {
      final accuracy = await _locationAccuracy();
      if (accuracy == LocationAccuracyStatus.reduced) {
        approximate = true;
      }
    } catch (_) {
      // getLocationAccuracy unsupported on some platforms — ignore.
    }

    if (approximate) {
      return LocationAccessSnapshot(
        kind: LocationAccessKind.okApproximate,
        arabicMessage: LocationAccessMessages.approximateOnly,
        geolocatorPermission: geo,
        whenInUseStatus: whenInUse,
        fineStatus: fine,
      );
    }

    return LocationAccessSnapshot(
      kind: LocationAccessKind.okPrecise,
      arabicMessage: '',
      geolocatorPermission: geo,
      whenInUseStatus: whenInUse,
      fineStatus: fine,
    );
  }

  /// Prompt once when soft-denied, then re-evaluate.
  Future<LocationAccessSnapshot> ensure({bool requestIfDenied = true}) async {
    var snap = await evaluate();
    if (snap.kind == LocationAccessKind.denied && requestIfDenied) {
      await _requestGeoPermission();
      try {
        await _requestWhenInUse();
      } catch (_) {}
      snap = await evaluate();
    }
    return snap;
  }
}
