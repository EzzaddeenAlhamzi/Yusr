import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/senior_selector_widget.dart';
import '../core/services/api_service.dart';
import '../core/services/medication_adherence_helper.dart';
import '../core/services/senior_manager.dart';

class MedicinesPage extends StatefulWidget {
  const MedicinesPage({super.key});

  @override
  State<MedicinesPage> createState() => _MedicinesPageState();
}

class _MedicinesPageState extends State<MedicinesPage> {
  String _selectedFilter = 'الكل'; // 'الكل', 'غير المؤكدة', 'تم تأكيدها'
  List<Map<String, dynamic>> _medicines = [];
  bool _isLoading = false;
  bool _adherenceFromCache = false;
  String? _adherenceError;

  @override
  void initState() {
    super.initState();
    _loadMedicinesFromDb();
    SeniorManager().addListener(_onSeniorChanged);
  }

  @override
  void dispose() {
    SeniorManager().removeListener(_onSeniorChanged);
    super.dispose();
  }

  void _onSeniorChanged() => _loadMedicinesFromDb();

  Future<void> _loadMedicinesFromDb() async {
    setState(() {
      _isLoading = true;
      _adherenceFromCache = false;
      _adherenceError = null;
    });
    try {
      final senior = SeniorManager().currentSenior;
      final int? seniorId = int.tryParse(senior.id);
      final list =
          await ApiService.instance.getMedications(elderlyId: seniorId);
      final listErr = ApiService.lastListError;
      if (list.isEmpty && listErr != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              listErr,
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Server SoT for adherence (P2.2 B1). Prefs are NOT authoritative.
      final civil = MedicationAdherenceHelper.civilDateToday();
      final doseRes = await ApiService.instance.getTodayMedicationDoses(
        elderlyId: seniorId,
        civilDate: civil,
      );
      final Map<dynamic, Map<String, dynamic>> doseByMed = {};
      bool dosesOk = doseRes['status'] == 'success' && doseRes['data'] is List;
      if (dosesOk) {
        for (final raw in (doseRes['data'] as List)) {
          if (raw is Map) {
            final row = Map<String, dynamic>.from(raw);
            doseByMed[row['Medicayion_ID']] = row;
          }
        }
      } else {
        _adherenceError = doseRes['message']?.toString() ??
            'تعذّر جلب حالة الالتزام من الخادم';
        _adherenceFromCache = doseRes['is_connection_error'] == true ||
            doseRes['error_type'] == 'connection_error';
      }

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      if (mounted) {
        setState(() {
          _medicines = list.map((m) {
            final medId = m['Medicayion_ID'];
            final remKey = 'med_reminder_active_${seniorId}_$medId';
            final startKey = 'med_start_date_${seniorId}_$medId';
            final endKey = 'med_end_date_${seniorId}_$medId';

            final isReminderActive = prefs.getBool(remKey) ?? true;
            final startDate = prefs.getString(startKey) ??
                '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            final endDate = prefs.getString(endKey) ?? '';

            bool isExpired = false;
            if (endDate.isNotEmpty) {
              final endDt = DateTime.tryParse(endDate);
              if (endDt != null &&
                  now.isAfter(endDt.add(const Duration(days: 1)))) {
                isExpired = true;
              }
            }

            final rep = (m['M_RepatTime'] ?? '').toString();
            final dose = (m['M_much'] ?? '1 حبة').toString();
            final serverDose = doseByMed[medId];
            final displayState = serverDose?['display_state']?.toString();
            final isConfirmed =
                MedicationAdherenceHelper.isConfirmedState(displayState);
            final isOverdue = MedicationAdherenceHelper.isOverdueNotConfirmed(
              displayState,
            );
            final confTime = serverDose?['confirmed_at']?.toString() ?? '';
            final labelAr = serverDose != null
                ? (serverDose['display_label_ar']?.toString() ??
                    MedicationAdherenceHelper.displayLabelAr(displayState))
                : (dosesOk ? 'غير مؤكد' : 'حالة غير متاحة دون اتصال');
            final scheduledTime = serverDose?['scheduled_time']?.toString() ??
                _extractTime(rep);

            return {
              'id': medId,
              'title': m['M_Name'] ?? 'دواء',
              'time': scheduledTime,
              'dosage': dose,
              'frequency': rep.isNotEmpty ? rep : 'يومياً',
              'startDate': startDate,
              'endDate': endDate,
              'isReminderActive': isReminderActive,
              'isExpired': isExpired,
              'icon': Icons.medication_rounded,
              'iconColor': isConfirmed
                  ? const Color(0xFF2E7D32)
                  : (isOverdue
                      ? const Color(0xFFE53935)
                      : const Color(0xFF00ACC1)),
              'isConfirmed': isConfirmed,
              'confirmedTime': confTime,
              'isMissed': isOverdue, // UI flag only — means overdue_not_confirmed
              'displayState': displayState,
              'displayLabelAr': labelAr,
              'occurrenceKey': serverDose?['occurrence_key'],
              'lastConfirmedAt': confTime,
              'serverBacked': dosesOk,
            };
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر تحميل الأدوية. تأكد من اتصالك بالإنترنت أو الشبكة المحلية.',
              style: const TextStyle(fontFamily: 'Cairo'),
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

  String _extractTime(String rep) {
    if (rep.contains('صباح') || rep.contains('فطور')) return '08:00 صباحاً';
    if (rep.contains('ظهر') || rep.contains('غداء')) return '01:30 ظهراً';
    if (rep.contains('مساء') || rep.contains('عشاء') || rep.contains('ليل')) {
      return '08:30 مساءً';
    }
    if (rep.contains(':')) return rep;
    return '08:00 صباحاً';
  }

  /// Caregiver is READ-ONLY for adherence (P2.2). Never write SP as SoT.
  Future<void> _showCaregiverReadOnlyNotice() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          MedicationAdherenceHelper.caregiverReadOnlyMessage(),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.mainColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _toggleReminder(int index) async {
    final med = _medicines[index];
    final medId = med['id'];
    final bool current = med['isReminderActive'] ?? true;
    final bool next = !current;

    final senior = SeniorManager().currentSenior;
    final int? seniorId = int.tryParse(senior.id);
    final prefs = await SharedPreferences.getInstance();
    final remKey = 'med_reminder_active_${seniorId}_$medId';

    await prefs.setBool(remKey, next);

    if (mounted) {
      setState(() {
        _medicines[index]['isReminderActive'] = next;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'تم تفعيل تذكيرات دواء (${med['title']}) 🔔'
                : 'تم إيقاف تذكيرات دواء (${med['title']}) مؤقتاً 🔕',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor:
              next ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _sendUrgentReminder(String medName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم إرسال تذكير عاجل للمسن بتناول ($medName) 🔔',
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

  List<Map<String, dynamic>> get _filteredMedicines {
    if (_selectedFilter == 'تم تأكيدها') {
      return _medicines.where((m) => m['isConfirmed'] == true).toList();
    } else if (_selectedFilter == 'غير المؤكدة') {
      return _medicines.where((m) => m['isConfirmed'] != true).toList();
    }
    return _medicines;
  }

  int get _confirmedCount =>
      _medicines.where((m) => m['isConfirmed'] == true).length;
  int get _missedCount =>
      _medicines.where((m) => m['isMissed'] == true).length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMedicines;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.mainColor,
        appBar: const CustomSubAppBar(
          title: 'إدارة ومتابعة الأدوية',
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
              onRefresh: _loadMedicinesFromDb,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SeniorSelectorWidget(showAddButton: false),
                    const SizedBox(height: 12),

                    // 1. بطاقة متابعة الالتزام الدوائي اليومي
                    _buildAdherenceProgressCard(),
                    const SizedBox(height: 14),

                    if (_adherenceFromCache || _adherenceError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF9A825)),
                        ),
                        child: Text(
                          _adherenceFromCache
                              ? MedicationAdherenceHelper.outdatedCacheBanner()
                              : (_adherenceError ??
                                  MedicationAdherenceHelper
                                      .outdatedCacheBanner()),
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF57F17),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],

                    // 2. تنبيه الجرعات المتأخرة غير المؤكدة (ليس دليلاً طبياً)
                    if (_missedCount > 0) ...[
                      _buildMissedAlertBanner(),
                      const SizedBox(height: 14),
                    ],

                    // 3. أزرار الفلترة السريعة (الكل / غير المؤكدة / المؤكدة)
                    _buildFilterTabs(),
                    const SizedBox(height: 16),

                    // 4. قائمة الأدوية
                    _isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: CircularProgressIndicator(
                                  color: AppColors.mainColor),
                            ),
                          )
                        : filtered.isEmpty
                            ? Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40),
                                alignment: Alignment.center,
                                child: Text(
                                  _medicines.isEmpty
                                      ? 'لا توجد أدوية مسجلة في قاعدة البيانات حالياً'
                                      : 'لا توجد أدوية مطابقة لهذا الفلتر',
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
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final med = filtered[index];
                                  final originalIndex = _medicines.indexOf(med);
                                  return _buildMedicineCard(med, originalIndex);
                                },
                              ),

                    const SizedBox(height: 20),

                    // 5. زر إضافة دواء جديد
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddMedicineDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        label: Text(
                          'إضافة دواء جديد',
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

  // ==================== بطاقة الالتزام الدوائي ====================
  Widget _buildAdherenceProgressCard() {
    final total = _medicines.length;
    final ratio = total > 0 ? (_confirmedCount / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check_rounded,
                      color: AppColors.mainColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'متابعة تناول الأدوية لليوم',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ratio == 1.0
                      ? const Color(0xFFE8F5E9)
                      : AppColors.mainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_confirmedCount من $total جرعات مؤكدة',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ratio == 1.0
                        ? const Color(0xFF2E7D32)
                        : AppColors.mainColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? ratio : 0.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFEEEEEE),
              color: ratio == 1.0
                  ? const Color(0xFF2E7D32)
                  : AppColors.mainColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== بانر تنبيه الجرعات الفائتة ====================
  Widget _buildMissedAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE53935), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه: يوجد $_missedCount جرعة متأخرة وغير مؤكدة من الخادم (ليست دليلاً طبياً على عدم التناول).',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB71C1C),
                  ),
                ),
                Text(
                  'يرجى التواصل مع كبير السن للتأكد من أخذ الجرعة بالوقت المناسب.',
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

  // ==================== أزرار الفلترة ====================
  Widget _buildFilterTabs() {
    return Row(
      children: [
        _buildFilterChip('الكل'),
        const SizedBox(width: 8),
        _buildFilterChip('غير المؤكدة'),
        const SizedBox(width: 8),
        _buildFilterChip('تم تأكيدها'),
      ],
    );
  }

  Widget _buildFilterChip(String title) {
    final isSelected = _selectedFilter == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = title),
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

  // ==================== كارت الدواء ====================
  Widget _buildMedicineCard(Map<String, dynamic> med, int originalIndex) {
    final bool isConfirmed = med['isConfirmed'] ?? false;
    final bool isMissed = med['isMissed'] ?? false;
    final bool isReminderActive = med['isReminderActive'] ?? true;
    final bool isExpired = med['isExpired'] ?? false;
    final String confTime = med['confirmedTime'] ?? '';
    final String startDate = med['startDate'] ?? '';
    final String endDate = med['endDate'] ?? '';

    final String displayLabel =
        (med['displayLabelAr'] ?? 'في انتظار تأكيد المسن').toString();
    Color badgeBg = const Color(0xFFFFF3E0);
    Color badgeColor = const Color(0xFFE65100);
    String badgeText = displayLabel;
    IconData badgeIcon = Icons.hourglass_top_rounded;

    if (isExpired) {
      badgeBg = const Color(0xFFF5F5F5);
      badgeColor = const Color(0xFF757575);
      badgeText = 'كورس العلاج منتهٍ';
      badgeIcon = Icons.event_busy_rounded;
    } else if (isConfirmed) {
      badgeBg = const Color(0xFFE8F5E9);
      badgeColor = const Color(0xFF2E7D32);
      final late = med['displayState'] == 'late_confirmed';
      badgeText = confTime.isNotEmpty
          ? (late
              ? 'تأكيد متأخر من المسن ($confTime)'
              : 'تم التأكيد من الخادم ($confTime)')
          : displayLabel;
      badgeIcon = Icons.check_circle_rounded;
    } else if (isMissed) {
      badgeBg = const Color(0xFFFFEBEE);
      badgeColor = const Color(0xFFE53935);
      badgeText = 'متأخر — غير مؤكد (من الخادم)';
      badgeIcon = Icons.error_outline_rounded;
    } else if (med['serverBacked'] != true) {
      badgeBg = const Color(0xFFFFF8E1);
      badgeColor = const Color(0xFFF57F17);
      badgeText = 'حالة الالتزام غير متاحة — يلزم الاتصال';
      badgeIcon = Icons.cloud_off_rounded;
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
                  color: isConfirmed
                      ? const Color(0xFFE8F5E9)
                      : (isMissed
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE0F7FA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  med['icon'] as IconData,
                  color: med['iconColor'] as Color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            med['title'] as String,
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // زر تفعيل/إيقاف التذكير
                        InkWell(
                          onTap: () => _toggleReminder(originalIndex),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isReminderActive
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isReminderActive
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_off_rounded,
                                  size: 14,
                                  color: isReminderActive
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFE65100),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isReminderActive ? 'مفعّل' : 'متوقف',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isReminderActive
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFE65100),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 13, color: AppColors.mainColor),
                        const SizedBox(width: 4),
                        Text(
                          med['time'] as String,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '•  الجرعة: ${med['dosage']}',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (startDate.isNotEmpty || endDate.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.date_range_rounded,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            endDate.isNotEmpty
                                ? 'الفترة: $startDate إلى $endDate'
                                : 'تاريخ البدء: $startDate (مستمر)',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
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
                        _showEditMedicineDialog(context, originalIndex),
                    tooltip: 'تعديل',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFE53935), size: 20),
                    onPressed: () =>
                        _confirmDeleteMedicine(context, originalIndex),
                    tooltip: 'حذف',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // شريط حالة التأكيد
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

          // P2.2: المرافق قراءة فقط للالتزام + تذكير محلي (P2.3 مؤجّل)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: Color(0xFFBDBDBD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onPressed: _showCaregiverReadOnlyNotice,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(
                    'اطلاع فقط — التأكيد من المسن',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!isConfirmed && !isExpired) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 0,
                    ),
                    onPressed: () =>
                        _sendUrgentReminder(med['title'] as String),
                    icon: const Icon(Icons.notifications_active_rounded,
                        size: 16),
                    label: Text(
                      'تذكير عاجل (محلي)',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _showAddMedicineDialog(BuildContext context) {
    final titleController = TextEditingController();
    final timeController = TextEditingController(text: '08:00 صباحاً');
    final dosageController = TextEditingController(text: '1 قرص');
    final startDateController = TextEditingController(
      text:
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
    );
    final endDateController = TextEditingController();
    bool reminderActive = true;

    showDialog(
      context: context,
      builder: (ctx) {
        bool showTitleError = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'إضافة دواء وجدول علاجي جديد',
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
                    children: [
                      TextField(
                        controller: titleController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        onChanged: (val) {
                          if (showTitleError && val.trim().isNotEmpty) {
                            setDialogState(() => showTitleError = false);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'اسم الدواء *',
                          labelStyle: GoogleFonts.cairo(
                            color: showTitleError
                                ? const Color(0xFFD32F2F)
                                : AppColors.mainColor,
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: dosageController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'الجرعة (مثال: 1 قرص بعد الإفطار)',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: timeController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'وقت التناول (مثال: 08:00 صباحاً)',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: startDateController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'تاريخ بدء الدواء (YYYY-MM-DD)',
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
                                startDateController.text =
                                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: endDateController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'تاريخ الانتهاء (اختياري للكورسات)',
                          hintText: 'اتركه فارغاً إذا كان العلاج مستمراً',
                          hintStyle: GoogleFonts.cairo(
                              fontSize: 11, color: Colors.grey),
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.event_available_rounded,
                                size: 18),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now()
                                    .add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2035),
                              );
                              if (d != null) {
                                endDateController.text =
                                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: Text(
                          'تفعيل تذكيرات هذا الدواء',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'إرسال تنبيهات لمقدم الرعاية والمسن عند موعد الجرعة',
                          style: GoogleFonts.cairo(fontSize: 11),
                        ),
                        value: reminderActive,
                        activeThumbColor: AppColors.mainColor,
                        onChanged: (v) =>
                            setDialogState(() => reminderActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.cairo(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) {
                        setDialogState(() => showTitleError = true);
                        return;
                      }
                      Navigator.pop(ctx);
                      final senior = SeniorManager().currentSenior;
                      final int? seniorId = int.tryParse(senior.id);
                      final res = await ApiService.instance.addMedication(
                        name: titleController.text.trim(),
                        dose: dosageController.text.trim().isEmpty
                            ? '1 حبة'
                            : dosageController.text.trim(),
                        repeatTime: timeController.text.trim().isEmpty
                            ? 'يومياً'
                            : timeController.text.trim(),
                        elderlyId: seniorId,
                      );

                      // حفظ تاريخ البدء والانتهاء وحالة التذكير
                      final newId = res['data']?['Medicayion_ID'] ??
                          res['Medicayion_ID'];
                      if (newId != null) {
                        final prefs = await SharedPreferences.getInstance();
                        final startKey = 'med_start_date_${seniorId}_$newId';
                        final endKey = 'med_end_date_${seniorId}_$newId';
                        final remKey =
                            'med_reminder_active_${seniorId}_$newId';

                        await prefs.setString(
                            startKey, startDateController.text.trim());
                        if (endDateController.text.trim().isNotEmpty) {
                          await prefs.setString(
                              endKey, endDateController.text.trim());
                        }
                        await prefs.setBool(remKey, reminderActive);
                      }

                      await _loadMedicinesFromDb();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                    ),
                    child: Text(
                      'إضافة الدواء',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _showEditMedicineDialog(BuildContext context, int index) {
    final med = _medicines[index];
    final medId = med['id'];
    final titleController = TextEditingController(text: med['title'] ?? '');
    final timeController = TextEditingController(text: med['time'] ?? '');
    final dosageController = TextEditingController(text: med['dosage'] ?? '');
    final startDateController =
        TextEditingController(text: med['startDate'] ?? '');
    final endDateController = TextEditingController(text: med['endDate'] ?? '');
    bool reminderActive = med['isReminderActive'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        bool showTitleError = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'تعديل بيانات الدواء والتذكيرات',
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
                    children: [
                      TextField(
                        controller: titleController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        onChanged: (val) {
                          if (showTitleError && val.trim().isNotEmpty) {
                            setDialogState(() => showTitleError = false);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'اسم الدواء *',
                          labelStyle: GoogleFonts.cairo(
                            color: showTitleError
                                ? const Color(0xFFD32F2F)
                                : AppColors.mainColor,
                          ),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: dosageController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'الجرعة',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: timeController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'وقت التناول',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: startDateController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'تاريخ البدء',
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
                                startDateController.text =
                                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: endDateController,
                        style: GoogleFonts.cairo(fontSize: 13),
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'تاريخ الانتهاء (اتركه فارغاً للمستمر)',
                          labelStyle:
                              GoogleFonts.cairo(color: AppColors.mainColor),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.event_available_rounded,
                                size: 18),
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now()
                                    .add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2035),
                              );
                              if (d != null) {
                                endDateController.text =
                                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: Text(
                          'تفعيل التذكيرات',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          reminderActive
                              ? 'التنبيهات نشطة حالياً'
                              : 'التنبيهات متوقفة لهذا الدواء',
                          style: GoogleFonts.cairo(fontSize: 11),
                        ),
                        value: reminderActive,
                        activeThumbColor: AppColors.mainColor,
                        onChanged: (v) =>
                            setDialogState(() => reminderActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.cairo(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) {
                        setDialogState(() => showTitleError = true);
                        return;
                      }
                      Navigator.pop(ctx);
                      final int? mId = medId is int
                          ? medId as int?
                          : int.tryParse(medId?.toString() ?? '');
                      if (mId != null) {
                        await ApiService.instance.updateMedication(
                          medicationId: mId,
                          name: titleController.text.trim(),
                          dose: dosageController.text.trim(),
                          repeatTime: timeController.text.trim(),
                        );

                        final senior = SeniorManager().currentSenior;
                        final int? seniorId = int.tryParse(senior.id);
                        final prefs = await SharedPreferences.getInstance();
                        final startKey = 'med_start_date_${seniorId}_$mId';
                        final endKey = 'med_end_date_${seniorId}_$mId';
                        final remKey =
                            'med_reminder_active_${seniorId}_$mId';

                        await prefs.setString(
                            startKey, startDateController.text.trim());
                        if (endDateController.text.trim().isNotEmpty) {
                          await prefs.setString(
                              endKey, endDateController.text.trim());
                        } else {
                          await prefs.remove(endKey);
                        }
                        await prefs.setBool(remKey, reminderActive);

                        await _loadMedicinesFromDb();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                    ),
                    child: Text(
                      'حفظ التعديلات',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _confirmDeleteMedicine(BuildContext context, int index) {
    final med = _medicines[index];
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
            'حذف الدواء',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE53935),
            ),
          ),
          content: Text(
            'هل أنت متأكد من حذف دواء "${med['title']}" نهائياً من قائمة الأدوية؟',
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
                final int? medId = med['id'] is int
                    ? med['id'] as int?
                    : int.tryParse(med['id']?.toString() ?? '');
                if (medId != null) {
                  await ApiService.instance.deleteMedication(medId);
                  await _loadMedicinesFromDb();
                }
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
