import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/senior_selector_widget.dart';
import '../core/services/api_service.dart';
import '../core/services/senior_manager.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();

  /// Test hook — invalid calendar dates must not be treated as success.
  @visibleForTesting
  static bool isValidAppointmentDateForTest(String raw) =>
      _AppointmentsPageState._isValidAppointmentDate(raw);

  /// Test hook — never surface raw SQLSTATE to the caregiver.
  @visibleForTesting
  static String appointmentErrorMessageForTest(Map<String, dynamic> res) =>
      _AppointmentsPageState._appointmentErrorMessage(res);
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  String _selectedTab = 'القادمة'; // 'القادمة', 'الفائتة وغير المؤكدة', 'المكتملة والملغاة'
  List<Map<String, dynamic>> _allAppointments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    SeniorManager().addListener(_onSeniorChanged);
  }

  @override
  void dispose() {
    SeniorManager().removeListener(_onSeniorChanged);
    super.dispose();
  }

  void _onSeniorChanged() => _loadAppointments();

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final senior = SeniorManager().currentSenior;
      final int? seniorId = int.tryParse(senior.id);
      final list =
          await ApiService.instance.getAppointments(elderlyId: seniorId);
      final listErr = ApiService.lastListError;
      final prefs = await SharedPreferences.getInstance();

      if (mounted) {
        if (list.isEmpty && listErr != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                listErr,
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        final now = DateTime.now();
        final loaded = <Map<String, dynamic>>[];

        for (final a in list) {
          final id = a['Appointment_ID'];
          final dateStr = (a['A_Date'] ?? '').toString();
          final timeStr = (a['A_Time'] ?? '09:00:00').toString();

          final confKey = 'appt_confirmed_${seniorId}_$id';
          final cancelKey = 'appt_cancelled_${seniorId}_$id';
          final remKey = 'appt_advance_rem_${seniorId}_$id';

          final isConfirmed = prefs.getBool(confKey) ?? false;
          final isCancelled = prefs.getBool(cancelKey) ?? false;
          final advanceReminder =
              prefs.getString(remKey) ?? 'قبل الموعد بساعة';

          DateTime? apptDateTime;
          try {
            final cleanDate = dateStr.split('T').first.trim();
            final cleanTime = timeStr.trim();
            apptDateTime = DateTime.tryParse('$cleanDate $cleanTime');
            if (apptDateTime == null && cleanDate.isNotEmpty) {
              apptDateTime = DateTime.tryParse(cleanDate);
            }
          } catch (_) {}

          final bool isPast = apptDateTime != null
              ? now.isAfter(apptDateTime)
              : false;

          final bool isMissed = isPast && !isConfirmed && !isCancelled;

          loaded.add({
            'id': id,
            'title': a['A_DateType'] ?? 'موعد طبي',
            'time': timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr,
            'doctor': a['A_Note'] ?? '',
            'location': a['A_Location'] ?? 'المركز الطبي',
            'date': dateStr.split('T').first,
            'timeDetail': timeStr,
            'icon': _getIconForType(a['A_DateType']?.toString() ?? ''),
            'iconColor': isCancelled
                ? const Color(0xFF757575)
                : (isConfirmed
                    ? const Color(0xFF2E7D32)
                    : (isMissed
                        ? const Color(0xFFE53935)
                        : const Color(0xFF1976D2))),
            'type': a['A_DateType'] ?? 'موعد',
            'advanceReminder': advanceReminder,
            'isConfirmed': isConfirmed,
            'isCancelled': isCancelled,
            'isPast': isPast,
            'isMissed': isMissed,
            'dateTime': apptDateTime,
          });
        }

        setState(() {
          _allAppointments = loaded;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل المواعيد. تأكد من اتصالك بالشبكة.',
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

  /// True only for real calendar dates (rejects `2026-13-40`).
  static bool _isValidAppointmentDate(String raw) {
    final text = raw.trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return false;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return false;
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    final dt = DateTime.tryParse(text);
    if (dt == null) return false;
    return dt.year == year && dt.month == month && dt.day == day;
  }

  static String _appointmentErrorMessage(Map<String, dynamic> res) {
    final raw = res['message']?.toString().trim() ?? '';
    if (raw.isEmpty) return 'تعذّر حفظ الموعد على الخادم';
    // Never surface raw SQLSTATE / stack noise to the caregiver.
    if (raw.contains('SQLSTATE') ||
        raw.toLowerCase().contains('exception') ||
        raw.contains('Incorrect date')) {
      return 'تاريخ الموعد غير صالح أو تعذّر حفظه على الخادم.';
    }
    return raw;
  }

  IconData _getIconForType(String type) {
    if (type.contains('فحص') || type.contains('مختبر') || type.contains('تحليل')) {
      return Icons.biotech_rounded;
    }
    if (type.contains('اجتماع') || type.contains('زيارة') || type.contains('عائل')) {
      return Icons.groups_rounded;
    }
    if (type.contains('أسنان') || type.contains('سن')) {
      return Icons.medical_services_outlined;
    }
    if (type.contains('علاج طبيعي') || type.contains('تأهيل')) {
      return Icons.accessibility_new_rounded;
    }
    if (type.contains('قلب')) {
      return Icons.favorite_border_rounded;
    }
    return Icons.medical_services_rounded;
  }

  Future<void> _toggleConfirm(int index) async {
    final item = _currentList[index];
    final id = item['id'];
    final bool current = item['isConfirmed'] ?? false;
    final bool next = !current;

    final senior = SeniorManager().currentSenior;
    final int? seniorId = int.tryParse(senior.id);
    final prefs = await SharedPreferences.getInstance();
    final confKey = 'appt_confirmed_${seniorId}_$id';

    await prefs.setBool(confKey, next);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'تم تأكيد حضور وإتمام الموعد بنجاح ✅'
                : 'تم إلغاء تأكيد الموعد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor:
              next ? const Color(0xFF2E7D32) : AppColors.mainColor,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadAppointments();
    }
  }

  Future<void> _toggleCancel(int index) async {
    final item = _currentList[index];
    final id = item['id'];
    final bool current = item['isCancelled'] ?? false;
    final bool next = !current;

    final senior = SeniorManager().currentSenior;
    final int? seniorId = int.tryParse(senior.id);
    final prefs = await SharedPreferences.getInstance();
    final cancelKey = 'appt_cancelled_${seniorId}_$id';

    await prefs.setBool(cancelKey, next);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'تم إلغاء الموعد وتوثيقه في الأرشيف 🚫'
                : 'تمت استعادة الموعد كقادم نشط 🔄',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor:
              next ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadAppointments();
    }
  }

  Future<void> _openLocationInMaps(String location) async {
    if (location.isEmpty) return;
    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح الخرائط', style: GoogleFonts.cairo()),
          ),
        );
      }
    }
  }

  void _sendUrgentReminder(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'إرسال تذكير عاجل لموعد ($title) غير متاح على الخادم حالياً (مؤجّل).',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<Map<String, dynamic>> get _currentList {
    if (_selectedTab == 'القادمة') {
      return _allAppointments
          .where((a) =>
              a['isPast'] == false &&
              a['isConfirmed'] == false &&
              a['isCancelled'] == false)
          .toList();
    } else if (_selectedTab == 'الفائتة وغير المؤكدة') {
      return _allAppointments.where((a) => a['isMissed'] == true).toList();
    } else {
      // 'المكتملة والملغاة'
      return _allAppointments
          .where((a) =>
              a['isConfirmed'] == true ||
              a['isCancelled'] == true ||
              a['isPast'] == true)
          .toList();
    }
  }

  int get _missedCount =>
      _allAppointments.where((a) => a['isMissed'] == true).length;
  int get _upcomingCount => _allAppointments
      .where((a) =>
          a['isPast'] == false &&
          a['isConfirmed'] == false &&
          a['isCancelled'] == false)
      .length;

  @override
  Widget build(BuildContext context) {
    final list = _currentList;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.mainColor,
        appBar: const CustomSubAppBar(
          title: 'إدارة ومتابعة المواعيد',
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
              onRefresh: _loadAppointments,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SeniorSelectorWidget(showAddButton: false),
                    const SizedBox(height: 12),

                    // 1. بطاقة ملخص المواعيد والتنبيهات
                    _buildSummaryCard(),
                    const SizedBox(height: 12),

                    // 2. تنبيه بالمواعيد الفائتة
                    if (_missedCount > 0) ...[
                      _buildMissedAlertBanner(),
                      const SizedBox(height: 12),
                    ],

                    // 3. أزرار التبويب الثلاثية
                    _buildTabSwitcher(),
                    const SizedBox(height: 16),

                    // 4. قائمة المواعيد
                    _isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: CircularProgressIndicator(
                                  color: AppColors.mainColor),
                            ),
                          )
                        : list.isEmpty
                            ? Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40),
                                alignment: Alignment.center,
                                child: Text(
                                  _allAppointments.isEmpty
                                      ? 'لا توجد مواعيد مسجلة في قاعدة البيانات حالياً'
                                      : 'لا توجد مواعيد في هذا القسم',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: list.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = list[index];
                                  return _buildAppointmentCard(item, index);
                                },
                              ),

                    const SizedBox(height: 24),

                    // 5. زر إضافة موعد جديد
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddAppointmentDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: Text(
                          'إضافة موعد جديد',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== بطاقة ملخص المواعيد ====================
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            'مواعيد قادمة',
            '$_upcomingCount',
            Icons.upcoming_rounded,
            const Color(0xFF1976D2),
          ),
          Container(height: 36, width: 1, color: AppColors.cardBorderColor),
          _buildSummaryItem(
            'فائتة / غير مؤكدة',
            '$_missedCount',
            Icons.warning_amber_rounded,
            _missedCount > 0 ? const Color(0xFFE53935) : AppColors.textSecondary,
          ),
          Container(height: 36, width: 1, color: AppColors.cardBorderColor),
          _buildSummaryItem(
            'إجمالي المواعيد',
            '${_allAppointments.length}',
            Icons.calendar_month_rounded,
            AppColors.mainColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ==================== تنبيه بالمواعيد الفائتة ====================
  Widget _buildMissedAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE53935), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه: يوجد $_missedCount موعد طبي فائت لم يتم تأكيده!',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB71C1C),
                  ),
                ),
                Text(
                  'يرجى التواصل مع كبير السن أو العيادة للتحقق من الحضور أو إعادة الجدولة.',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== التبويبات ====================
  Widget _buildTabSwitcher() {
    return Row(
      children: [
        _buildTabButton('القادمة'),
        const SizedBox(width: 8),
        _buildTabButton('الفائتة وغير المؤكدة'),
        const SizedBox(width: 8),
        _buildTabButton('المكتملة والملغاة'),
      ],
    );
  }

  Widget _buildTabButton(String title) {
    final isSelected = _selectedTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.mainColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.mainColor
                  : AppColors.cardBorderColor,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== كارت الموعد ====================
  Widget _buildAppointmentCard(Map<String, dynamic> item, int index) {
    final bool isConfirmed = item['isConfirmed'] ?? false;
    final bool isCancelled = item['isCancelled'] ?? false;
    final bool isMissed = item['isMissed'] ?? false;
    final String advanceReminder = item['advanceReminder'] ?? '';

    Color badgeBg = const Color(0xFFE3F2FD);
    Color badgeColor = const Color(0xFF1976D2);
    String badgeText = 'موعد قادم - بانتظار الحضور';
    IconData badgeIcon = Icons.schedule_rounded;

    if (isCancelled) {
      badgeBg = const Color(0xFFF5F5F5);
      badgeColor = const Color(0xFF757575);
      badgeText = 'موعد ملغي';
      badgeIcon = Icons.cancel_outlined;
    } else if (isConfirmed) {
      badgeBg = const Color(0xFFE8F5E9);
      badgeColor = const Color(0xFF2E7D32);
      badgeText = 'تم تأكيد الحضور والإتمام بنجاح';
      badgeIcon = Icons.check_circle_rounded;
    } else if (isMissed) {
      badgeBg = const Color(0xFFFFEBEE);
      badgeColor = const Color(0xFFE53935);
      badgeText = 'موعد فائت - لم يتم تأكيد الحضور!';
      badgeIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMissed
              ? const Color(0xFFEF9A9A)
              : AppColors.cardBorderColor,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? const Color(0xFFEEEEEE)
                      : (isConfirmed
                          ? const Color(0xFFE8F5E9)
                          : (isMissed
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFE3F2FD))),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item['icon'] as IconData,
                  color: item['iconColor'] as Color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isCancelled
                            ? const Color(0xFF757575)
                            : AppColors.textPrimary,
                        decoration: isCancelled
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 13, color: AppColors.mainColor),
                        const SizedBox(width: 4),
                        Text(
                          '${item['date']}  الساعة ${item['time']}',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainColor,
                          ),
                        ),
                      ],
                    ),
                    if (advanceReminder.isNotEmpty &&
                        advanceReminder != 'بدون تذكير مسبق' &&
                        !isCancelled) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.alarm_on_rounded,
                              size: 13, color: Color(0xFFE65100)),
                          const SizedBox(width: 4),
                          Text(
                            'تذكير مسبق: $advanceReminder',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: const Color(0xFFE65100),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((item['doctor'] as String).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'المختص/الملاحظة: ${item['doctor']}',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((item['location'] as String).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () =>
                            _openLocationInMaps(item['location'] as String),
                        child: Row(
                          children: [
                            const Icon(Icons.place_outlined,
                                size: 13, color: Color(0xFF1976D2)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item['location'] as String,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: const Color(0xFF1976D2),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.mainColor, size: 20),
                    onPressed: () =>
                        _showEditAppointmentDialog(context, item, index),
                    tooltip: 'تعديل',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFE53935), size: 20),
                    onPressed: () =>
                        _confirmDeleteAppointment(context, item, index),
                    tooltip: 'حذف نهائي',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // شريط حالة الموعد
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(badgeIcon, color: badgeColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    badgeText,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // إجراءات مقدم الرعاية: تأكيد الإتمام / إلغاء الموعد / تذكير
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isConfirmed
                        ? AppColors.textSecondary
                        : const Color(0xFF2E7D32),
                    side: BorderSide(
                      color: isConfirmed
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF2E7D32),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onPressed: isCancelled ? null : () => _toggleConfirm(index),
                  icon: Icon(
                    isConfirmed
                        ? Icons.undo_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isConfirmed ? 'إلغاء التأكيد' : 'تأكيد الحضور',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // زر إلغاء الموعد أو استعادته
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isCancelled
                      ? const Color(0xFF1976D2)
                      : const Color(0xFFE65100),
                  side: BorderSide(
                    color: isCancelled
                        ? const Color(0xFF1976D2)
                        : const Color(0xFFE65100),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: () => _toggleCancel(index),
                icon: Icon(
                  isCancelled ? Icons.restore_rounded : Icons.cancel_outlined,
                  size: 16,
                ),
                label: Text(
                  isCancelled ? 'استعادة' : 'إلغاء الموعد',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!isConfirmed && !isCancelled) ...[
                const SizedBox(width: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMissed
                        ? const Color(0xFFE53935)
                        : const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    elevation: 0,
                  ),
                  onPressed: () =>
                      _sendUrgentReminder(item['title'] as String),
                  child: Text(
                    'تذكير المسن',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAddAppointmentDialog(BuildContext pageContext) {
    String selectedType = 'موعد طبيب';
    String selectedAdvance = 'قبل الموعد بساعة';
    final customTitleController = TextEditingController();
    final dateController = TextEditingController(
        text: DateTime.now().toIso8601String().split('T').first);
    final timeController = TextEditingController(text: '09:00');
    final doctorController = TextEditingController();
    final locationController = TextEditingController();
    // Capture page messenger before dialog — StatefulBuilder shadows `context`
    // and after Navigator.pop the dialog context is unmounted (silent fail).
    final pageMessenger = ScaffoldMessenger.of(pageContext);

    final appointmentTypes = [
      'موعد طبيب',
      'فحص مخبري / تحاليل',
      'زيارة اجتماعية / عائلية',
      'علاج طبيعي / تأهيل',
      'فحص دوري شامل',
      'أخرى',
    ];

    final advanceOptions = [
      'بدون تذكير مسبق',
      'قبل الموعد بـ 15 دقيقة',
      'قبل الموعد بـ 30 دقيقة',
      'قبل الموعد بساعة',
      'قبل الموعد بيوم واحد',
    ];

    showDialog(
      context: pageContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'إضافة موعد أو فحص جديد',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // اختيار نوع الموعد
                      Text(
                        'نوع الموعد أو الزيارة:',
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        items: appointmentTypes.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t,
                                style: GoogleFonts.cairo(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedType = v);
                          }
                        },
                      ),
                      if (selectedType == 'أخرى') ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: customTitleController,
                          style: GoogleFonts.cairo(fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'اكتب نوع الموعد المخصص',
                            labelStyle: GoogleFonts.cairo(
                                color: AppColors.mainColor),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // التاريخ
                      TextField(
                        controller: dateController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'تاريخ الموعد (YYYY-MM-DD)',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_rounded,
                                size: 18),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (d != null) {
                                dateController.text =
                                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // الوقت
                      TextField(
                        controller: timeController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'وقت الموعد (HH:MM)',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time_rounded,
                                size: 18),
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (t != null) {
                                timeController.text =
                                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ضبط تذكير مسبق
                      Text(
                        'ضبط تذكير مسبق:',
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: selectedAdvance,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        items: advanceOptions.map((opt) {
                          return DropdownMenuItem(
                            value: opt,
                            child: Text(opt,
                                style: GoogleFonts.cairo(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedAdvance = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: doctorController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'اسم الطبيب / الأخصائي / الملاحظة',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: locationController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'المكان / المستشفى / العيادة',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('إلغاء',
                        style:
                            GoogleFonts.cairo(color: AppColors.textSecondary)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final finalTitle = (selectedType == 'أخرى' &&
                              customTitleController.text.trim().isNotEmpty)
                          ? customTitleController.text.trim()
                          : selectedType;

                      final dateText = dateController.text.trim().isEmpty
                          ? DateTime.now()
                              .toIso8601String()
                              .split('T')
                              .first
                          : dateController.text.trim();
                      if (!_isValidAppointmentDate(dateText)) {
                        pageMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'تاريخ الموعد غير صالح. استخدم صيغة YYYY-MM-DD صحيحة.',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      final senior = SeniorManager().currentSenior;
                      final int? seniorId = int.tryParse(senior.id);
                      Map<String, dynamic> res;
                      try {
                        res = await ApiService.instance.addAppointment(
                          date: dateText,
                          time: timeController.text.trim().isEmpty
                              ? '09:00:00'
                              : '${timeController.text.trim()}:00',
                          dateType: finalTitle,
                          location: locationController.text.trim(),
                          note: doctorController.text.trim(),
                          elderlyId: seniorId,
                        );
                      } catch (_) {
                        pageMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'تعذّر حفظ الموعد على الخادم',
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                        return;
                      }

                      // Use page messenger — dialogContext is unmounted after pop.
                      if (res['status'] != 'success') {
                        pageMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              _appointmentErrorMessage(res),
                              style: GoogleFonts.cairo(),
                            ),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                        return;
                      }

                      final newId = res['data']?['Appointment_ID'] ??
                          res['Appointment_ID'];
                      if (newId != null) {
                        final prefs = await SharedPreferences.getInstance();
                        final remKey =
                            'appt_advance_rem_${seniorId}_$newId';
                        await prefs.setString(remKey, selectedAdvance);
                      }

                      if (!mounted) return;
                      await _loadAppointments();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                    ),
                    child: Text('إضافة الموعد',
                        style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditAppointmentDialog(
      BuildContext pageContext, Map<String, dynamic> item, int index) {
    String selectedType = item['title'] ?? 'موعد طبيب';
    String selectedAdvance = item['advanceReminder'] ?? 'قبل الموعد بساعة';
    final dateController = TextEditingController(text: item['date'] ?? '');
    final timeController = TextEditingController(text: item['time'] ?? '');
    final doctorController = TextEditingController(text: item['doctor'] ?? '');
    final locationController =
        TextEditingController(text: item['location'] ?? '');
    final pageMessenger = ScaffoldMessenger.of(pageContext);
    final appointmentId = int.tryParse(item['id']?.toString() ?? '');
    var isSaving = false;

    final appointmentTypes = [
      'موعد طبيب',
      'فحص مخبري / تحاليل',
      'زيارة اجتماعية / عائلية',
      'علاج طبيعي / تأهيل',
      'فحص دوري شامل',
      'أخرى',
    ];

    if (!appointmentTypes.contains(selectedType)) {
      appointmentTypes.add(selectedType);
    }

    final advanceOptions = [
      'بدون تذكير مسبق',
      'قبل الموعد بـ 15 دقيقة',
      'قبل الموعد بـ 30 دقيقة',
      'قبل الموعد بساعة',
      'قبل الموعد بيوم واحد',
    ];

    showDialog(
      context: pageContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'تعديل الموعد والتذكيرات',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نوع الموعد أو الزيارة:',
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        items: appointmentTypes.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t,
                                style: GoogleFonts.cairo(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: isSaving
                            ? null
                            : (v) {
                                if (v != null) {
                                  setDialogState(() => selectedType = v);
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: dateController,
                        enabled: !isSaving,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'تاريخ الموعد',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today_rounded,
                                size: 18),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );
                                    if (d != null) {
                                      dateController.text =
                                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: timeController,
                        enabled: !isSaving,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'الوقت',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.access_time_rounded,
                                size: 18),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final t = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          const TimeOfDay(hour: 9, minute: 0),
                                    );
                                    if (t != null) {
                                      timeController.text =
                                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'ضبط تذكير مسبق (محلي فقط):',
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: selectedAdvance,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        items: advanceOptions.map((opt) {
                          return DropdownMenuItem(
                            value: opt,
                            child: Text(opt,
                                style: GoogleFonts.cairo(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: isSaving
                            ? null
                            : (v) {
                                if (v != null) {
                                  setDialogState(() => selectedAdvance = v);
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: doctorController,
                        enabled: !isSaving,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'اسم الطبيب / الملاحظة',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: locationController,
                        enabled: !isSaving,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'المستشفى / العيادة',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      if (isSaving) ...[
                        const SizedBox(height: 12),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(ctx),
                    child: Text('إلغاء',
                        style:
                            GoogleFonts.cairo(color: AppColors.textSecondary)),
                  ),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (appointmentId == null) {
                              pageMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تعذّر تحديد رقم الموعد للتعديل',
                                    style: GoogleFonts.cairo(fontSize: 13),
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                              return;
                            }
                            final dateText = dateController.text.trim().isEmpty
                                ? DateTime.now()
                                    .toIso8601String()
                                    .split('T')
                                    .first
                                : dateController.text.trim();
                            if (!_isValidAppointmentDate(dateText)) {
                              pageMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تاريخ الموعد غير صالح. استخدم صيغة YYYY-MM-DD صحيحة.',
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                              return;
                            }

                            setDialogState(() => isSaving = true);
                            final senior = SeniorManager().currentSenior;
                            final int? seniorId = int.tryParse(senior.id);
                            final timeRaw = timeController.text.trim().isEmpty
                                ? '09:00'
                                : timeController.text.trim();
                            final timeNorm = timeRaw.length == 5
                                ? '$timeRaw:00'
                                : timeRaw;

                            Map<String, dynamic> res;
                            try {
                              res = await ApiService.instance
                                  .updateAppointment(
                                appointmentId: appointmentId,
                                date: dateText,
                                time: timeNorm,
                                dateType: selectedType,
                                location: locationController.text.trim(),
                                note: doctorController.text.trim(),
                              );
                            } catch (_) {
                              setDialogState(() => isSaving = false);
                              pageMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تعذّر حفظ تعديل الموعد على الخادم',
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                              return;
                            }

                            if (res['status'] != 'success') {
                              setDialogState(() => isSaving = false);
                              pageMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _appointmentErrorMessage(res),
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                              return;
                            }

                            // Local-only advance reminder preference (not P2.3).
                            if (seniorId != null) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final remKey =
                                  'appt_advance_rem_${seniorId}_$appointmentId';
                              await prefs.setString(remKey, selectedAdvance);
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            pageMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تم تحديث الموعد بنجاح',
                                  style: GoogleFonts.cairo(fontSize: 13),
                                ),
                                backgroundColor: Colors.green.shade700,
                              ),
                            );
                            if (mounted) await _loadAppointments();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                    ),
                    child: Text(
                        isSaving ? 'جاري الحفظ...' : 'حفظ التعديل',
                        style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteAppointment(
      BuildContext context, Map<String, dynamic> item, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'حذف الموعد نهائياً',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE53935),
            ),
          ),
          content: Text(
            'هل أنت متأكد من حذف موعد "${item['title']}" نهائياً من السجلات؟',
            style: GoogleFonts.cairo(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final appointmentId = item['id'];
                if (appointmentId == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تعذّر حذف الموعد: معرف غير صالح',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                  return;
                }
                final res = await ApiService.instance.deleteAppointment(
                  appointmentId is int
                      ? appointmentId
                      : int.parse(appointmentId.toString()),
                );
                if (!context.mounted) return;
                if (res['status'] != 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        res['message']?.toString() ?? 'تعذّر حذف الموعد',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                  return;
                }
                await _loadAppointments();
              },
              child: Text(
                'تأكيد الحذف',
                style: GoogleFonts.cairo(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
