import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/location/location_alert_category.dart';
import '../core/location/location_freshness.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/senior_selector_widget.dart';
import '../core/widgets/yusr_map_view.dart';
import '../core/services/senior_manager.dart';
import '../core/services/api_service.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  bool _isHistoryExpanded = false;
  bool _isLoading = false;
  String _lastUpdatedTime = '';
  String _currentLocationName = '';
  double? _latitude;
  double? _longitude;
  double? _accuracyMeters;
  bool _sharingEnabled = true;
  bool _sharingStopped = false;
  String _freshness = LocationFreshness.unknown;
  DateTime? _capturedAt;
  /// A = manual SOS · B = safe-zone EXIT · C = ENTER (informational).
  bool _hasActiveSos = false;
  String _sosDetails = '';
  bool _hasZoneExit = false;
  String _zoneExitTitle = '';
  String _zoneExitDetails = '';
  String _zoneExitTime = '';
  List<Map<String, String>> _movementHistory = [];
  List<YusrMapZone> _zones = [];

  @override
  void initState() {
    super.initState();
    _loadLocationData();
    SeniorManager().addListener(_onSeniorChanged);
  }

  @override
  void dispose() {
    SeniorManager().removeListener(_onSeniorChanged);
    super.dispose();
  }

  void _onSeniorChanged() => _loadLocationData();

  Future<void> _loadLocationData() async {
    if (!SeniorManager().hasSeniors) return;
    final senior = SeniorManager().currentSenior;
    final int? seniorId = int.tryParse(senior.id);
    if (seniorId == null) return;

    setState(() => _isLoading = true);

    try {
      // Sharing status (honest caregiver message when stopped).
      Map<String, dynamic> sharing = {};
      try {
        sharing =
            await ApiService.instance.getLocationSharing(elderlyId: seniorId);
      } catch (_) {}

      final loc = await ApiService.instance.getLocation(elderlyId: seniorId);
      final history =
          await ApiService.instance.getLocationHistory(elderlyId: seniorId);
      final notifs =
          await ApiService.instance.getNotifications(elderlyId: seniorId);
      List<Map<String, dynamic>> zones = [];
      try {
        zones = await ApiService.instance.getSafeZones(elderlyId: seniorId);
      } catch (_) {}

      final classified = _classifyLocationAlerts(notifs);

      if (mounted) {
        double? lat;
        double? lng;
        double? acc;
        String updateTime = '';
        DateTime? capturedAt;
        String freshness = LocationFreshness.unknown;
        final sharingKnown = sharing.containsKey('location_sharing_enabled') ||
            sharing.containsKey('sharing_enabled');
        final sharingOn = !sharingKnown
            ? true
            : (sharing['location_sharing_enabled'] == true ||
                sharing['sharing_enabled'] == true);

        if (loc != null && loc is Map) {
          lat = double.tryParse(loc['L_Latitude']?.toString() ??
              loc['latitude']?.toString() ??
              '');
          lng = double.tryParse(loc['L_Longitude']?.toString() ??
              loc['longitude']?.toString() ??
              loc['Longitude']?.toString() ??
              '');
          acc = double.tryParse(loc['L_AccuracyMeters']?.toString() ??
              loc['accuracy_meters']?.toString() ??
              '');
          updateTime = loc['L_UpdateTime']?.toString() ??
              loc['created_at']?.toString() ??
              '';
          capturedAt = DateTime.tryParse(updateTime);
          freshness = LocationFreshness.fromRawLabel(
            loc['freshness']?.toString(),
          );
          if (freshness == LocationFreshness.unknown && capturedAt != null) {
            freshness = LocationFreshness.fromTimestamp(capturedAt);
          }
        } else if (!sharingOn && sharingKnown) {
          freshness = LocationFreshness.sharingStopped;
        } else {
          freshness = LocationFreshness.noData;
        }

        final mapZones = <YusrMapZone>[];
        for (final z in zones) {
          if ((z['approval_status']?.toString() ?? '') != 'approved') continue;
          if (z['is_active'] == false) continue;
          final zLat = double.tryParse(
            (z['center_lat'] ?? z['latitude'])?.toString() ?? '',
          );
          final zLng = double.tryParse(
            (z['center_lng'] ?? z['longitude'])?.toString() ?? '',
          );
          final zR = double.tryParse(
            (z['radius_meters'] ?? z['Z_Limit'])?.toString() ?? '',
          );
          if (zLat == null || zLng == null || zR == null) continue;
          mapZones.add(YusrMapZone(
            center: LatLng(zLat, zLng),
            radiusMeters: zR,
            label: z['Z_Name']?.toString() ?? z['name']?.toString(),
          ));
        }

        setState(() {
          _sharingEnabled = sharingOn;
          _sharingStopped = sharingKnown && !sharingOn;
          _latitude = _sharingStopped ? null : lat;
          _longitude = _sharingStopped ? null : lng;
          _accuracyMeters = _sharingStopped ? null : acc;
          _capturedAt = _sharingStopped ? null : capturedAt;
          _freshness = _sharingStopped
              ? LocationFreshness.sharingStopped
              : freshness;
          _hasActiveSos = classified.sos;
          _sosDetails = classified.sosDetails;
          _hasZoneExit = classified.zoneExit;
          _zoneExitTitle = classified.zoneExitTitle;
          _zoneExitDetails = classified.zoneExitDetails;
          _zoneExitTime = classified.zoneExitTime;
          _zones = mapZones;

          if (_sharingStopped) {
            _currentLocationName = 'مشاركة الموقع متوقفة';
            _lastUpdatedTime = '—';
          } else if (lat != null && lng != null) {
            _currentLocationName =
                'خط العرض: ${lat.toStringAsFixed(4)} ، خط الطول: ${lng.toStringAsFixed(4)}';
            _lastUpdatedTime = LocationFreshness.formatArabicDateTime(capturedAt);
          } else {
            _currentLocationName = 'لا توجد بيانات موقع';
            _lastUpdatedTime = 'غير متوفر';
            _freshness = LocationFreshness.noData;
          }

          _movementHistory = _sharingStopped
              ? []
              : history.map((h) {
                  final hLat = h['L_Latitude']?.toString() ?? '';
                  final hLng = h['L_Longitude']?.toString() ?? '';
                  final hTimeRaw = h['L_UpdateTime']?.toString() ??
                      h['created_at']?.toString() ??
                      '';
                  final hDt = DateTime.tryParse(hTimeRaw);
                  final accM = h['L_AccuracyMeters'] ?? h['accuracy_meters'];
                  final status = accM != null
                      ? 'دقة: $accM م'
                      : 'دقة: غير متوفرة';
                  return {
                    'location': (hLat.isNotEmpty && hLng.isNotEmpty)
                        ? 'إحداثيات: $hLat, $hLng'
                        : 'موقع مسجل',
                    'time': LocationFreshness.formatArabicDateTime(hDt),
                    'status': status,
                    'icon': '📍',
                  };
                }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحديث بيانات الموقع. تأكد من اتصال الخادم والإنترنت.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Split SOS (A) from geofence EXIT (B) / ENTER (C). Never escalate EXIT to SOS.
  ({
    bool sos,
    String sosDetails,
    bool zoneExit,
    String zoneExitTitle,
    String zoneExitDetails,
    String zoneExitTime,
  }) _classifyLocationAlerts(List<dynamic> notifs) {
    bool sos = false;
    String sosDetails = '';
    bool zoneExit = false;
    String zoneExitTitle = 'تنبيه: خروج من المنطقة الآمنة';
    String zoneExitDetails = '';
    String zoneExitTime = '';

    for (final raw in notifs) {
      if (raw is! Map) continue;
      final n = Map<String, dynamic>.from(raw);
      final title = (n['N_Title'] ?? '').toString();
      final msg = (n['N_Message'] ?? '').toString();
      final status = (n['N_Status'] ?? '').toString();
      final unread = status == 'unread' ||
          status == 'Unread' ||
          status == 'جديد' ||
          status.isEmpty;
      final kind = LocationAlertCategory.classify(
        eventType: n['event_type']?.toString(),
        nType: n['N_Type']?.toString(),
        title: title,
        message: msg,
      );

      if (kind == LocationAlertCategory.zoneExit && unread && !zoneExit) {
        zoneExit = true;
        final zoneName = _extractZoneName(title, msg);
        zoneExitTitle = zoneName.isEmpty
            ? 'تنبيه: خروج من المنطقة الآمنة'
            : 'تنبيه: خروج من المنطقة الآمنة — $zoneName';
        zoneExitDetails = msg.isNotEmpty
            ? msg
            : 'غادر كبير السن المنطقة الآمنة. ليست بلاغ طوارئ تلقائي.';
        final t = n['created_at']?.toString() ??
            '${n['N_Date'] ?? ''} ${n['N_Time'] ?? ''}'.trim();
        zoneExitTime = LocationFreshness.formatArabicDateTime(
          DateTime.tryParse(t),
        );
      } else if (kind == LocationAlertCategory.sos && unread && !sos) {
        sos = true;
        sosDetails = msg.isNotEmpty
            ? msg
            : 'تم استلام بلاغ طوارئ يدوي من كبير السن.';
      }
    }

    return (
      sos: sos,
      sosDetails: sosDetails,
      zoneExit: zoneExit,
      zoneExitTitle: zoneExitTitle,
      zoneExitDetails: zoneExitDetails,
      zoneExitTime: zoneExitTime,
    );
  }

  String _extractZoneName(String title, String msg) {
    final fromMsg = RegExp(r'«([^»]+)»').firstMatch(msg);
    if (fromMsg != null) return fromMsg.group(1)!.trim();
    final fromTitle = RegExp(r'—\s*(.+)$').firstMatch(title);
    if (fromTitle != null) return fromTitle.group(1)!.trim();
    return '';
  }

  Future<void> _openGoogleMaps({bool isEmergency = false}) async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا توجد إحداثيات موقع دقيقة للفتح في الخريطة',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final query = '$_latitude,$_longitude';
    // في حالة الطوارئ نفتح وضع الملاحة المباشرة Google Navigation
    final navUri = Uri.parse(
        'google.navigation:q=${Uri.encodeComponent(query)}&mode=d');
    final webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(query)}');

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تعذر فتح تطبيق الخرائط',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.mainColor,
        appBar: const CustomSubAppBar(
          title: 'الموقع الجغرافي',
          height: 95,
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            child: RefreshIndicator(
              color: AppColors.mainColor,
              onRefresh: _loadLocationData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SeniorSelectorWidget(showAddButton: false),
                    const SizedBox(height: 12),

                    // 1a. Manual SOS only (category A) — never for geofence EXIT.
                    if (_hasActiveSos) ...[
                      _buildEmergencyAlertBanner(),
                      const SizedBox(height: 12),
                    ],
                    // 1b. Safe-zone EXIT (category B) — separate from SOS.
                    if (_hasZoneExit) ...[
                      _buildZoneExitBanner(),
                      const SizedBox(height: 12),
                    ],

                    // 2. Honest foreground-only freshness (no live-tracking claims)
                    _buildLocationStatusBanner(),
                    const SizedBox(height: 12),

                    // 3. حاوية الخريطة التفاعلية مع الماركر التوضيحي
                    _buildMapContainer(),
                    const SizedBox(height: 14),

                    // 4. تفاصيل العنوان ووقت آخر تحديث
                    _buildLocationDetailsCard(),
                    const SizedBox(height: 16),

                    // 5. زر الوصول للموقع / توجيه خرائط Google
                    _buildQuickNavigationButton(),
                    const SizedBox(height: 10),

                    // 6. زر مشاركة الموقع
                    _buildShareLocationButton(),
                    const SizedBox(height: 12),

                    // 7. زر وقائمة سجل الحركة والتنقلات
                    _buildHistoryToggleButton(),
                    if (_isHistoryExpanded) ...[
                      const SizedBox(height: 12),
                      _buildMovementHistoryList(),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== بانر طوارئ يدوي (SOS) فقط ====================
  Widget _buildEmergencyAlertBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE53935), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بلاغ طوارئ نشط من كبير السن!',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB71C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _sosDetails.isNotEmpty
                ? _sosDetails
                : 'تم استلام بلاغ طوارئ يدوي. توجه إلى الموقع فوراً.',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: const Color(0xFFC62828),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _openGoogleMaps(isEmergency: true),
              icon: const Icon(Icons.navigation_rounded, size: 20),
              label: Text(
                'الوصول الفوري للموقع (توجيه Google Maps)',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Category B — geofence EXIT (not SOS / not auto-emergency).
  Widget _buildZoneExitBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF9A825), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.login_outlined, color: Color(0xFFF57F17), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _zoneExitTitle,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _zoneExitDetails,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: const Color(0xFF6D4C41),
            ),
          ),
          if (_zoneExitTime.isNotEmpty && _zoneExitTime != 'غير متوفر') ...[
            const SizedBox(height: 4),
            Text(
              'وقت التنبيه: $_zoneExitTime',
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: const Color(0xFF8D6E63),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _sharingStopped || _latitude == null
                ? 'آخر موقع معروف: غير متاح حاليًا'
                : 'آخر موقع معروف معروض على الخريطة أدناه',
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5D4037),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE65100),
                side: const BorderSide(color: Color(0xFFF9A825)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _openGoogleMaps(isEmergency: false),
              icon: const Icon(Icons.map_outlined, size: 20),
              label: Text(
                'عرض آخر موقع معروف',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== شريط حداثة الموقع (بدون ادّعاء تتبّع حي) ====================
  Widget _buildLocationStatusBanner() {
    final sharingOff = _sharingStopped || !_sharingEnabled;
    final code = sharingOff
        ? LocationFreshness.sharingStopped
        : (_latitude == null || _longitude == null)
            ? LocationFreshness.noData
            : _freshness;
    final isOk = code == LocationFreshness.fresh || code == LocationFreshness.recent;
    final bg = sharingOff || code == LocationFreshness.stale || code == LocationFreshness.old
        ? const Color(0xFFFFF3E0)
        : isOk
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFF5F5F5);
    final border = sharingOff || code == LocationFreshness.stale || code == LocationFreshness.old
        ? const Color(0xFFFF9800)
        : isOk
            ? const Color(0xFF4CAF50)
            : const Color(0xFFE0E0E0);
    final fg = sharingOff || code == LocationFreshness.stale || code == LocationFreshness.old
        ? const Color(0xFFE65100)
        : isOk
            ? const Color(0xFF1B5E20)
            : const Color(0xFF616161);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(
            sharingOff
                ? Icons.location_disabled_rounded
                : (_latitude == null
                    ? Icons.location_off_rounded
                    : Icons.place_outlined),
            color: fg,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocationFreshness.arabicBannerTitle(code),
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
                Text(
                  LocationFreshness.arabicBannerSubtitle(code),
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== خريطة الموقع التفاعلية (OSM حقيقية) ====================
  Widget _buildMapContainer() {
    return Stack(
      children: [
        YusrMapView(
          latitude: _latitude,
          longitude: _longitude,
          accuracyMeters: _accuracyMeters,
          height: 260,
          zones: _zones,
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'refresh_loc_btn',
            onPressed: _loadLocationData,
            backgroundColor: Colors.white,
            elevation: 3,
            tooltip: 'تحديث الموقع الآن',
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.mainColor,
                    ),
                  )
                : const Icon(
                    Icons.my_location,
                    color: AppColors.mainColor,
                    size: 20,
                  ),
          ),
        ),
        Positioned(
          top: 12,
          left: 56,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: IconButton(
              tooltip: 'فتح في خرائط خارجية',
              onPressed: () => _openGoogleMaps(),
              icon: const Icon(Icons.open_in_new, color: AppColors.mainColor),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== كارت تفاصيل الموقع ووقت التحديث ====================
  Widget _buildLocationDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  color: AppColors.mainColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentLocationName,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: AppColors.textSecondary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'وقت آخر تحديث للموقع:',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                _lastUpdatedTime.isNotEmpty ? _lastUpdatedTime : 'غير متوفر',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الدقة الأفقية:',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _accuracyMeters != null
                    ? '${_accuracyMeters!.toStringAsFixed(1)} م'
                    : 'غير متوفرة',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${LocationFreshness.arabicLabel(_freshness)} · ${LocationFreshness.formatAge(_capturedAt)}',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== زر الوصول السريع للموقع (خرائط Google) ====================
  Widget _buildQuickNavigationButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mainColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 1,
        ),
        onPressed: () => _openGoogleMaps(),
        icon: const Icon(Icons.directions_rounded, size: 22),
        label: Text(
          'الوصول إلى الموقع (الاتجاهات في الخرائط)',
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==================== زر مشاركة الموقع ====================
  Widget _buildShareLocationButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showShareOptionsModal(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.share_outlined,
                    color: AppColors.mainColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'مشاركة إحداثيات الموقع',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== زر تبديل عرض السجل ====================
  Widget _buildHistoryToggleButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _isHistoryExpanded = !_isHistoryExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        color: AppColors.mainColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'سجل التنقلات والمواقع السابقة',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainColor,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isHistoryExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.mainColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== قائمة سجل التحركات ====================
  Widget _buildMovementHistoryList() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سجل تحركات اليوم لكبير السن',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 16),
          if (_movementHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'لا توجد سجلات تنقل سابقة مسجلة اليوم.',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _movementHistory.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 14, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final item = _movementHistory[index];
                return Row(
                  children: [
                    Text(item['icon'] ?? '📍',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['location'] ?? '',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            item['status'] ?? '',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item['time'] ?? '',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.mainColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _showShareOptionsModal(BuildContext context) {
    final query = (_latitude != null && _longitude != null)
        ? '$_latitude,$_longitude'
        : '';
    final mapsUrl = query.isNotEmpty
        ? 'https://www.google.com/maps/search/?api=1&query=$query'
        : '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'مشاركة إحداثيات موقع كبير السن',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.map_outlined,
                      color: Color(0xFF1976D2)),
                  title: Text(
                    'فتح ومشاركة عبر خرائط Google',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openGoogleMaps();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded,
                      color: Color(0xFF2E7D32)),
                  title: Text(
                    'مشاركة رابط الموقع عبر الرسائل/واتساب',
                    style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    if (mapsUrl.isNotEmpty) {
                      final waUri = Uri.parse(
                          'whatsapp://send?text=${Uri.encodeComponent('موقع كبير السن عبر تطبيق يُسر:\n$mapsUrl')}');
                      if (await canLaunchUrl(waUri)) {
                        await launchUrl(waUri);
                      } else {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'رابط الموقع: $mapsUrl',
                                style: GoogleFonts.cairo(),
                              ),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

