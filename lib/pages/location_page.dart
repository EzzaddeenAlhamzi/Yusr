import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/senior_selector_widget.dart';
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
  bool _isLiveLocation = false;
  bool _hasActiveEmergency = false;
  String _emergencyDetails = '';
  List<Map<String, String>> _movementHistory = [];

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
      final loc = await ApiService.instance.getLocation(elderlyId: seniorId);
      final history =
          await ApiService.instance.getLocationHistory(elderlyId: seniorId);
      final notifs =
          await ApiService.instance.getNotifications(elderlyId: seniorId);

      // فحص بلاغات الطوارئ الحديثة
      final emergencyNotif = notifs.firstWhere(
        (n) =>
            (n['N_Type'] ?? '').toString().contains('طوارئ') ||
            (n['N_Message'] ?? '').toString().contains('استغاثة') ||
            (n['N_Message'] ?? '').toString().contains('طوارئ') ||
            (n['N_Status'] ?? '').toString() == 'Active',
        orElse: () => {},
      );

      final hasEmerg = emergencyNotif.isNotEmpty;
      final emergMsg = emergencyNotif['N_Message']?.toString() ??
          'تم استلام إشارة طوارئ من كبير السن!';

      if (mounted) {
        double? lat;
        double? lng;
        String updateTime = '';
        bool isLive = false;

        if (loc != null && loc is Map) {
          lat = double.tryParse(loc['L_Latitude']?.toString() ?? '');
          lng = double.tryParse(loc['L_Longitude']?.toString() ?? '');
          updateTime = loc['L_UpdateTime']?.toString() ??
              loc['created_at']?.toString() ??
              '';

          // التحقق مما إذا كان الموقع حديثاً (مباشر) أم موقع أخير معروف
          isLive = _checkIfLive(updateTime, loc['Status']?.toString());
        }

        setState(() {
          _latitude = lat;
          _longitude = lng;
          _isLiveLocation = isLive;
          _hasActiveEmergency = hasEmerg;
          _emergencyDetails = emergMsg;

          if (lat != null && lng != null) {
            _currentLocationName =
                'خط العرض: ${lat.toStringAsFixed(4)} ، خط الطول: ${lng.toStringAsFixed(4)}';
            _lastUpdatedTime =
                updateTime.isNotEmpty ? updateTime : 'الآن تقريباً';
          } else {
            _currentLocationName = senior.location.isNotEmpty &&
                    senior.location != 'الموقع غير محدد'
                ? senior.location
                : 'لا توجد إحداثيات GPS مسجلة حالياً';
            _lastUpdatedTime = 'غير متوفر';
            _isLiveLocation = false;
          }

          _movementHistory = history.map((h) {
            final hLat = h['L_Latitude']?.toString() ?? '';
            final hLng = h['L_Longitude']?.toString() ?? '';
            final hTime = h['L_UpdateTime']?.toString() ??
                h['created_at']?.toString() ??
                '';
            final scor = h['L_Scor']?.toString() ?? '100';
            return {
              'location': (hLat.isNotEmpty && hLng.isNotEmpty)
                  ? 'إحداثيات: $hLat, $hLng'
                  : 'موقع مسجل',
              'time': hTime.isNotEmpty ? hTime : 'سجل سابق',
              'status': 'دقة الإشارة: $scor%',
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

  bool _checkIfLive(String? timeStr, String? status) {
    if (status == 'Active' || status == 'Live') return true;
    if (timeStr == null || timeStr.isEmpty) return false;
    try {
      final dt = DateTime.tryParse(timeStr);
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        // إذا كان التحديث خلال آخر 20 دقيقة نعتبره مباشر
        return diff.inMinutes.abs() <= 20;
      }
    } catch (_) {}
    return true; // في حال تعذر التحليل نعتمد على توفر الإحداثية
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

                    // 1. كارت بلاغ الطوارئ (عند وجود طوارئ نشطة)
                    if (_hasActiveEmergency) ...[
                      _buildEmergencyAlertBanner(),
                      const SizedBox(height: 12),
                    ],

                    // 2. شريط التمييز بين (الموقع الحالي المباشر) و(الموقع الأخير المعروف)
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

  // ==================== بانر طوارئ نشط ====================
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
            _emergencyDetails.isNotEmpty
                ? _emergencyDetails
                : 'تم استلام طلب نجدة أو تنبيه طوارئ. توجه إلى الموقع فوراً.',
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

  // ==================== شريط التمييز بين المباشر والأخير المعروف ====================
  Widget _buildLocationStatusBanner() {
    final hasCoords = _latitude != null && _longitude != null;

    if (!hasCoords) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded,
                color: Color(0xFF757575), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'الموقع غير متاح: بانتظار استلام إحداثيات GPS حديثة من جهاز كبير السن.',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: const Color(0xFF616161),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLiveLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الموقع الحالي المباشر (متصل الآن)',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                  Text(
                    'يتم استقبال إحداثيات GPS بشكل حي ومباشر.',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.sensors_rounded,
                color: Color(0xFF2E7D32), size: 22),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF9800), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.sensors_off_rounded,
                color: Color(0xFFE65100), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الموقع الأخير المعروف (انقطع الاتصال)',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE65100),
                    ),
                  ),
                  Text(
                    'تعذر تحديث الإشارة المباشرة. هذا هو آخر موقع مسجل قبل انقطاع الاتصال.',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: const Color(0xFF8D6E63),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ==================== خريطة الموقع التفاعلية ====================
  Widget _buildMapContainer() {
    final hasCoords = _latitude != null && _longitude != null;
    final pinColor = _isLiveLocation
        ? const Color(0xFF2E7D32)
        : (_hasActiveEmergency
            ? const Color(0xFFE53935)
            : const Color(0xFFE65100));

    return Container(
      width: double.infinity,
      height: 230,
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // خلفية رسم الخريطة التوضيحية
            CustomPaint(
              size: const Size(double.infinity, 230),
              painter: MapPainter(),
            ),

            // زر التحديث اليدوي داخل الخريطة
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

            // زر التكبير/فتح في خرائط Google مباشرة من الخريطة
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openGoogleMaps(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_new_rounded,
                            size: 15, color: AppColors.mainColor),
                        const SizedBox(width: 4),
                        Text(
                          'Google Maps',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ماركر الموقع في منتصف الخريطة
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: pinColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: pinColor,
                      size: 42,
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      hasCoords
                          ? (_isLiveLocation
                              ? 'الموقع المباشر الآن'
                              : 'آخر موقع معروف')
                          : 'الموقع غير محدد',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: pinColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                  color: _isLiveLocation
                      ? const Color(0xFF2E7D32)
                      : AppColors.mainColor,
                ),
              ),
            ],
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

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF2F0EB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final parkPaint = Paint()..color = const Color(0xFFD4EAD6);
    final parkPath1 = Path()
      ..moveTo(size.width * 0.4, size.height * 0.2)
      ..lineTo(size.width * 0.65, size.height * 0.25)
      ..lineTo(size.width * 0.6, size.height * 0.5)
      ..lineTo(size.width * 0.35, size.height * 0.45)
      ..close();
    canvas.drawPath(parkPath1, parkPaint);

    final parkPath2 = Path()
      ..moveTo(size.width * 0.1, size.height * 0.6)
      ..lineTo(size.width * 0.3, size.height * 0.65)
      ..lineTo(size.width * 0.25, size.height * 0.9)
      ..lineTo(size.width * 0.05, size.height * 0.8)
      ..close();
    canvas.drawPath(parkPath2, parkPaint);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke;

    final secondaryRoadPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;

    final mainRoad = Path()
      ..moveTo(size.width * 0.1, 0)
      ..lineTo(size.width * 0.7, size.height);
    canvas.drawPath(mainRoad, roadPaint);

    final crossRoad = Path()
      ..moveTo(0, size.height * 0.4)
      ..lineTo(size.width, size.height * 0.4);
    canvas.drawPath(crossRoad, roadPaint);

    final subRoad1 = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.9, size.height * 0.8);
    canvas.drawPath(subRoad1, secondaryRoadPaint);

    final subRoad2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..lineTo(size.width, size.height * 0.75);
    canvas.drawPath(subRoad2, secondaryRoadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
