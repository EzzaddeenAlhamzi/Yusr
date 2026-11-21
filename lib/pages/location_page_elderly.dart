import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../core/location/location_freshness.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/location_sharing_service.dart';
import '../core/widgets/yusr_map_view.dart';
import '../shard/color.dart';
import '../shard/custom_header.dart';
import 'ai_page.dart';

/// P2.4 — شاشة «مشاركة موقعي» لكبير السن (موافقة + GPS أمامي + خريطة حقيقية).
class LocationPageElderly extends StatefulWidget {
  const LocationPageElderly({super.key});

  @override
  State<LocationPageElderly> createState() => _LocationPageElderlyState();
}

class _LocationPageElderlyState extends State<LocationPageElderly> {
  final _sharing = LocationSharingService.instance;

  bool _loading = true;
  bool _sharingEnabled = false;
  bool _busyToggle = false;
  String _statusText = 'جاري التحميل...';
  double? _lat;
  double? _lng;
  double? _accuracyM;
  DateTime? _updatedAt;
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _pending = [];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    // Keep server consent; stop local timer when leaving screen is OK —
    // service lifecycle observer continues only while sharing enabled & app resumed.
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await _sharing.ensureLifecycleObserver();
      final enabled = await _sharing.refreshSharingFromServer();
      _sharingEnabled = enabled;
      if (enabled) {
        await _sharing.startForegroundLoop();
        final pos = _sharing.lastKnownPosition;
        if (pos != null) {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _accuracyM = pos.accuracy;
          _updatedAt = DateTime.now();
        }
      }
      await _loadLastKnownFromServer();
      await _loadZones();
      _statusText = enabled
          ? 'مشاركة الموقع مفعّلة (أثناء استخدام التطبيق فقط)'
          : 'مشاركة الموقع متوقفة';
    } catch (e) {
      _statusText = 'تعذّر تحميل حالة المشاركة';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLastKnownFromServer() async {
    final elderlyId = AuthService().userId;
    if (elderlyId == null) return;
    try {
      final loc = await ApiService.instance.getLocation(elderlyId: elderlyId);
      if (loc is Map) {
        final lat = double.tryParse(
          (loc['L_Latitude'] ?? loc['latitude'])?.toString() ?? '',
        );
        final lng = double.tryParse(
          (loc['L_Longitude'] ?? loc['longitude'] ?? loc['Longitude'])
                  ?.toString() ??
              '',
        );
        final acc = double.tryParse(
          (loc['L_AccuracyMeters'] ?? loc['accuracy_meters'])?.toString() ??
              '',
        );
        final t = loc['L_UpdateTime']?.toString();
        if (lat != null && lng != null) {
          _lat = lat;
          _lng = lng;
          _accuracyM = acc;
          _updatedAt = t != null ? DateTime.tryParse(t) : _updatedAt;
        }
      }
    } catch (_) {}
  }

  Future<void> _loadZones() async {
    final elderlyId = AuthService().userId;
    if (elderlyId == null) return;
    try {
      final zones = await ApiService.instance.getSafeZones(elderlyId: elderlyId);
      _zones = zones;
      _pending = zones
          .where((z) => (z['approval_status']?.toString() ?? '') == 'pending')
          .toList();
    } catch (_) {}
  }

  Future<void> _toggleSharing(bool value) async {
    setState(() => _busyToggle = true);
    try {
      if (value) {
        final perm = await _sharing.ensureForegroundPermission();
        if (perm.toString().contains('denied')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'يلزم إذن الموقع «أثناء الاستخدام» لتفعيل المشاركة.',
                  style: GoogleFonts.tajawal(),
                ),
                backgroundColor: Colors.orange.shade800,
              ),
            );
          }
          return;
        }
      }
      await _sharing.setSharingEnabled(value);
      _sharingEnabled = value;
      if (value) {
        final ok = await _sharing.publishOnce(manual: true);
        final pos = _sharing.lastKnownPosition;
        if (pos != null) {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _accuracyM = pos.accuracy;
          _updatedAt = DateTime.now();
        }
        _statusText = ok
            ? 'تم نشر الموقع — تحديث كل 60 ثانية أثناء فتح التطبيق'
            : (_sharing.lastError ?? 'تعذّر نشر الموقع');
      } else {
        _statusText = 'مشاركة الموقع متوقفة';
      }
    } catch (e) {
      _statusText = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_statusText, style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyToggle = false);
    }
  }

  Future<void> _manualRefresh() async {
    setState(() => _loading = true);
    try {
      if (!_sharingEnabled) {
        _statusText = 'مشاركة الموقع متوقفة — فعّل الموافقة أولاً';
        return;
      }
      final ok = await _sharing.publishOnce(manual: true);
      if (ok) {
        final pos = _sharing.lastKnownPosition;
        if (pos != null) {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _accuracyM = pos.accuracy;
          _updatedAt = DateTime.now();
        }
        _statusText = 'تم تحديث الموقع من GPS';
      } else {
        // Keep last-known coords if any; do NOT bump _updatedAt (no new GPS).
        final err = _sharing.lastError ??
            LocationSharingService.errGpsUnavailable;
        _statusText = err;
        if (_lat != null && _lng != null) {
          _statusText =
              '$err — يُعرض آخر موقع معروف (${LocationFreshness.formatAge(_updatedAt)})';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err, style: GoogleFonts.tajawal()),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createZoneAt(LatLng point) async {
    final nameCtrl = TextEditingController(text: 'منطقة آمنة');
    final radiusCtrl = TextEditingController(text: '150');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إنشاء منطقة آمنة', style: GoogleFonts.cairo()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            TextField(
              controller: radiusCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'نصف القطر (متر)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final radius = int.tryParse(radiusCtrl.text.trim()) ?? 150;
    final res = await ApiService.instance.createSafeZone(
      name: nameCtrl.text.trim().isEmpty ? 'منطقة آمنة' : nameCtrl.text.trim(),
      latitude: point.latitude,
      longitude: point.longitude,
      radiusMeters: radius,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['message']?.toString() ??
              (res['status'] == 'success' ? 'تم' : 'فشل'),
          style: GoogleFonts.tajawal(),
        ),
      ),
    );
    await _loadZones();
    setState(() {});
  }

  Future<void> _resolvePending(Map<String, dynamic> zone, bool approve) async {
    final id = int.tryParse(zone['Zone_ID']?.toString() ?? '');
    if (id == null) return;
    final res = approve
        ? await ApiService.instance.approveSafeZone(id)
        : await ApiService.instance.rejectSafeZone(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['message']?.toString() ?? 'تم',
          style: GoogleFonts.tajawal(),
        ),
      ),
    );
    await _loadZones();
    setState(() {});
  }

  List<YusrMapZone> get _mapZones {
    final out = <YusrMapZone>[];
    for (final z in _zones) {
      if ((z['approval_status']?.toString() ?? '') != 'approved') continue;
      if (z['is_active'] == false) continue;
      final lat = double.tryParse(
        (z['center_lat'] ?? z['latitude'])?.toString() ?? '',
      );
      final lng = double.tryParse(
        (z['center_lng'] ?? z['longitude'])?.toString() ?? '',
      );
      final r = double.tryParse(
        (z['radius_meters'] ?? z['Z_Limit'])?.toString() ?? '',
      );
      if (lat == null || lng == null || r == null) continue;
      out.add(YusrMapZone(
        center: LatLng(lat, lng),
        radiusMeters: r,
        label: z['Z_Name']?.toString() ?? z['name']?.toString(),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appbarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CustomTopBar(
              title: 'مشاركة موقعي',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            YusrMapView(
                              latitude: _lat,
                              longitude: _lng,
                              accuracyMeters: _accuracyM,
                              height: 260,
                              zones: _mapZones,
                              onTap: _sharingEnabled ? _createZoneAt : null,
                            ),
                            const SizedBox(height: 16),
                            _consentCard(),
                            const SizedBox(height: 12),
                            _statusCard(),
                            if (_pending.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _pendingCard(),
                            ],
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _loading ? null : _manualRefresh,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appbarColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                label: Text(
                                  'تحديث موقعي الآن',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Separate return-home flow (not the primary location surface).
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/return-home');
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: appbarColor,
                                  side: const BorderSide(
                                    color: appbarColor,
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.home_rounded),
                                label: Text(
                                  'العودة للمنزل (توجيه)',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appbarColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AIPage(),
                              ),
                            );
                          },
                          child: Text(
                            'اضغط للتحدث',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _consentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'موافقة مشاركة الموقع',
            style: GoogleFonts.tajawal(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'موافقة صريحة وقابلة للإلغاء. المشاركة أثناء استخدام التطبيق فقط — لا تتبّع خلفي في هذا الإصدار.',
            style: GoogleFonts.tajawal(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _sharingEnabled ? 'مشاركة موقعي: مفعّلة' : 'مشاركة موقعي: متوقفة',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: appbarColor,
              ),
            ),
            value: _sharingEnabled,
            onChanged: _busyToggle ? null : _toggleSharing,
            activeThumbColor: appbarColor,
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final acc = _accuracyM;
    final coords = (_lat != null && _lng != null)
        ? '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
        : 'غير معروف';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.4),
      ),
      child: Column(
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: appbarColor),
            ),
          Text(_statusText,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            LocationFreshness.arabicLabel(
              LocationFreshness.resolve(
                capturedAt: _updatedAt,
                sharingStoppedFlag: !_sharingEnabled,
                hasCoordinates: _lat != null && _lng != null,
              ),
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: appbarColor,
            ),
          ),
          Text('الإحداثيات: $coords',
              style: GoogleFonts.tajawal(fontSize: 15, color: appbarColor)),
          Text(
            acc != null
                ? 'الدقة الأفقية: ${acc.toStringAsFixed(1)} م'
                : 'الدقة: غير متوفرة (لم تُختلق)',
            style: GoogleFonts.tajawal(fontSize: 15),
          ),
          Text(
            'آخر تحديث: ${LocationFreshness.formatArabicDateTime(_updatedAt)}',
            style: GoogleFonts.tajawal(fontSize: 14),
          ),
          Text(
            LocationFreshness.formatAge(_updatedAt),
            style: GoogleFonts.tajawal(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _pendingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade300, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مقترحات مناطق من المرافق',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          for (final z in _pending) ...[
            const SizedBox(height: 8),
            Text(
              '${z['Z_Name'] ?? z['name'] ?? 'منطقة'} — نصف قطر ${z['radius_meters'] ?? z['Z_Limit'] ?? '?'} م',
              style: GoogleFonts.tajawal(fontSize: 15),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => _resolvePending(z, true),
                  child: Text('موافقة', style: GoogleFonts.cairo(color: Colors.green.shade800)),
                ),
                TextButton(
                  onPressed: () => _resolvePending(z, false),
                  child: Text('رفض', style: GoogleFonts.cairo(color: Colors.red.shade800)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
