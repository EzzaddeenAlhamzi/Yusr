import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/senior_selector_widget.dart';
import '../core/services/senior_manager.dart';
import '../core/services/api_service.dart';

/// صفحة الطوارئ لمقدم الرعاية:
/// مركز استقبال ومتابعة تنبيهات الطوارئ، نداءات الاستغاثة SOS، ومخاطر القراءات الصحية غير الطبيعية
class EmergencyPage extends StatefulWidget {
  final bool showBottomNav;
  final bool isEmbedded;

  const EmergencyPage({
    super.key,
    this.showBottomNav = false,
    this.isEmbedded = false,
  });

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> with SingleTickerProviderStateMixin {
  // تصفية البلاغات: قيد المتابعة فقط أو تمت المعالجة فقط
  int _selectedFilterIndex = 0;
  final List<String> _filterTabs = [
    'قيد المتابعة',
    'تمت المعالجة',
  ];

  List<Map<String, dynamic>> _emergencyLogs = [];
  bool _isLoading = true;
  Timer? _autoRefreshTimer;

  late AnimationController _alertPulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _alertPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.03).animate(
      CurvedAnimation(parent: _alertPulseController, curve: Curves.easeInOut),
    );

    _loadAlerts();

    // تحديث دوري تلقائي كل 8 ثوانٍ لالتقاط أي نداء SOS جديد فوراً
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _loadAlerts(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _alertPulseController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      int? elderlyId;
      if (SeniorManager().hasSeniors) {
        elderlyId = int.tryParse(SeniorManager().currentSenior.id);
      }

      final logs = await ApiService.instance.getEmergencyLog(elderlyId: elderlyId);

      if (mounted) {
        setState(() {
          _emergencyLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل بلاغات الطوارئ. تأكد من اتصالك بالشبكة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // إجراء مكالمة هاتفية فورية
  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri url = Uri(scheme: 'tel', path: cleanPhone.isEmpty ? '997' : cleanPhone);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // فتح صفحة الموقع الجغرافي لكبير السن
  void _openSeniorLocation(Map<String, dynamic> log) {
    Navigator.pushNamed(context, '/location');
  }

  // تحديث حالة البلاغ (قيد المتابعة / تمت المعالجة) بتنسيق يطابق باقي نوافذ التطبيق
  Future<void> _showUpdateStatusDialog(Map<String, dynamic> log) async {
    final emergencyId = log['Emergency_ID'] as int?;
    if (emergencyId == null) return;

    String currentStatus = (log['E_State'] ?? 'نشط').toString();
    String newStatus = currentStatus.contains('معالجة') ? 'تمت المعالجة' : 'قيد المتابعة';
    final noteController = TextEditingController();
    bool isSubmitting = false;

    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.backgroundColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.mainColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: AppColors.mainColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'متابعة وتحديث حالة البلاغ',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mainColor,
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
                      Text(
                        'اختر حالة البلاغ:',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // خيارات الحالة بتنسيق أنيق وموحد
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => newStatus = 'قيد المتابعة'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: newStatus == 'قيد المتابعة'
                                      ? AppColors.mainColor.withValues(alpha: 0.12)
                                      : AppColors.cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: newStatus == 'قيد المتابعة'
                                        ? AppColors.mainColor
                                        : AppColors.cardBorderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sync_rounded,
                                      size: 18,
                                      color: newStatus == 'قيد المتابعة'
                                          ? AppColors.mainColor
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'قيد المتابعة',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: newStatus == 'قيد المتابعة'
                                            ? AppColors.mainColor
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDialogState(() => newStatus = 'تمت المعالجة'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: newStatus == 'تمت المعالجة'
                                      ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                                      : AppColors.cardColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: newStatus == 'تمت المعالجة'
                                        ? const Color(0xFF2E7D32)
                                        : AppColors.cardBorderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: newStatus == 'تمت المعالجة'
                                          ? const Color(0xFF2E7D32)
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'تمت المعالجة',
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: newStatus == 'تمت المعالجة'
                                            ? const Color(0xFF2E7D32)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'ملاحظات المتابعة والإجراء المتخذ:',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'مثال: تم التواصل مع كبير السن والاطمئنان على استقرار حالته الصحية',
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          fillColor: AppColors.cardColor,
                          filled: true,
                        ),
                        style: GoogleFonts.cairo(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() => isSubmitting = true);
                            final note = noteController.text.trim();
                            final res = await ApiService.instance.updateEmergencyStatus(
                              emergencyId: emergencyId,
                              state: newStatus,
                              note: note.isNotEmpty ? note : null,
                            );

                            if (ctx.mounted) Navigator.pop(ctx);
                            await _loadAlerts();

                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res['success'] == true
                                        ? 'تم تحديث حالة البلاغ إلى ($newStatus) بنجاح'
                                        : 'فشل تحديث حالة البلاغ',
                                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.right,
                                  ),
                                  backgroundColor: res['success'] == true
                                      ? const Color(0xFF2E7D32)
                                      : Colors.red.shade700,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('حفظ التحديث', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // عرض إعدادات الحدود الصحية المعتمدة بدون إيموجي
  void _showHealthThresholdsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.mainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: AppColors.mainColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'الحدود الصحية المعتمدة للتنبيهات',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.mainColor),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThresholdRow(Icons.favorite_rounded, 'نبض القلب الآمن', '60 - 100 نبضة/دقيقة', 'تنبيه إذا قل عن 55 أو زاد عن 105'),
                const Divider(height: 14),
                _buildThresholdRow(Icons.air_rounded, 'تشبع الأكسجين في الدم SpO2', '95% - 100%', 'تنبيه فوري إذا قل عن 94%'),
                const Divider(height: 14),
                _buildThresholdRow(Icons.speed_rounded, 'ضغط الدم الانقباضي', '90 - 130 mmHg', 'تنبيه بالارتفاع إذا زاد عن 140'),
                const Divider(height: 14),
                _buildThresholdRow(Icons.water_drop_rounded, 'سكر الدم الصائم', '70 - 130 mg/dL', 'تنبيه بالهبوط أقل من 70 أو الارتفاع فوق 180'),
                const Divider(height: 14),
                _buildThresholdRow(Icons.thermostat_rounded, 'درجة حرارة الجسم', '36.5°C - 37.5°C', 'تنبيه بالحمى إذا زادت عن 38.0°C'),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حسناً، فهمت ذلك', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdRow(IconData icon, String title, String normalRange, String alertCondition) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.mainColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text(normalRange, style: GoogleFonts.cairo(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(right: 22.0),
          child: Text(alertCondition, style: GoogleFonts.cairo(fontSize: 11, color: Colors.red.shade700)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // حساب أعداد البلاغات النشطة
    final activeSosList = _emergencyLogs.where((l) {
      final state = (l['E_State'] ?? '').toString();
      return !state.contains('معالجة') && !state.contains('تم الحل');
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFB71C1C),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: Container(
            color: const Color(0xFFB71C1C),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // زر الإعدادات والحدود المعتمدة
                        IconButton(
                          onPressed: _showHealthThresholdsDialog,
                          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 24),
                          tooltip: 'الحدود الصحية المعتمدة',
                        ),
                        // زر فحص الخادم
                        IconButton(
                          onPressed: () => ApiService.showServerConfigDialog(context),
                          icon: const Icon(Icons.dns_rounded, color: Colors.white, size: 22),
                          tooltip: 'حالة الخادم وقاعدة البيانات',
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'مركز استقبال الطوارئ والمخاطر',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'متابعة لحظية لبلاغات واستغاثات كبار السن',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 22),
                          tooltip: 'رجوع',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // مؤشر استقبال البلاغات النشطة بدون إيموجي
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: activeSosList.isNotEmpty ? Colors.amberAccent : Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            activeSosList.isNotEmpty
                                ? 'يوجد ${activeSosList.length} بلاغ بحاجة لتدخل ومتابعة'
                                : 'حالة المراقبة: مستقرة ولا توجد بلاغات حرجة حالياً',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
              onRefresh: () => _loadAlerts(),
              color: AppColors.mainColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // محدد كبير السن لاختيار وتصفية البلاغات
                    if (SeniorManager().hasSeniors) ...[
                      const SeniorSelectorWidget(showAddButton: false),
                      const SizedBox(height: 14),
                    ],

                    // 1. بانر الطوارئ الوامض عند وجود نداء SOS نشط
                    if (activeSosList.isNotEmpty) ...[
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: _buildActiveEmergencySosBanner(activeSosList.first),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 2. كروت إحصائيات البلاغات
                    _buildOverviewCounters(activeSosList.length),
                    const SizedBox(height: 16),

                    // 3. شريط تصفية التبويبات (فقط: قيد المتابعة - تمت المعالجة)
                    _buildFilterTabs(),
                    const SizedBox(height: 16),

                    // 4. محتوى البلاغات والتنبيهات
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: AppColors.mainColor),
                        ),
                      )
                    else
                      _buildAlertsContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // بانر نداء استغاثة نشط فوري بدون إيموجي
  Widget _buildActiveEmergencySosBanner(Map<String, dynamic> activeSos) {
    final senior = SeniorManager().currentSenior;
    final timeStr = '${activeSos['E_Time'] ?? 'الآن'} | ${activeSos['E_Date'] ?? ''}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66D32F2F),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نداء استغاثة طارئ نشط الآن',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'ضغط المسن (${senior.name}) على زر الاستغاثة',
                      style: GoogleFonts.cairo(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeStr,
                  style: GoogleFonts.cairo(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // الموقع المتاح للبلاغ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'الموقع: ${activeSos['E_Location'] ?? 'الموقع الجغرافي متاح'}',
                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openSeniorLocation(activeSos),
                  icon: const Icon(Icons.map_rounded, color: Colors.white, size: 16),
                  label: Text('عرض الخريطة', style: GoogleFonts.cairo(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(senior.phoneNumber),
                  icon: const Icon(Icons.call, size: 18),
                  label: Text('اتصال فوري بالمسن', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showUpdateStatusDialog(activeSos),
                  icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                  label: Text('متابعة البلاغ', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // كروت العدادات العلوية بدون إيموجي
  Widget _buildOverviewCounters(int activeCount) {
    final resolvedCount = _emergencyLogs.where((l) {
      final state = (l['E_State'] ?? '').toString();
      return state.contains('معالجة') || state.contains('تم الحل');
    }).length;

    return Row(
      children: [
        Expanded(
          child: _buildCounterTile(
            title: 'قيد المتابعة',
            count: activeCount.toString(),
            color: const Color(0xFFD32F2F),
            icon: Icons.sync_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCounterTile(
            title: 'تمت المعالجة',
            count: resolvedCount.toString(),
            color: const Color(0xFF2E7D32),
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildCounterTile(
            title: 'إجمالي البلاغات',
            count: _emergencyLogs.length.toString(),
            color: AppColors.mainColor,
            icon: Icons.history_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildCounterTile({
    required String title,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                count,
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // شريط التبويبات المقتصر على "قيد المتابعة" و"تمت المعالجة" فقط
  Widget _buildFilterTabs() {
    return Row(
      children: List.generate(_filterTabs.length, (index) {
        final isSelected = _selectedFilterIndex == index;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 8.0 : 0.0),
            child: ChoiceChip(
              label: Center(
                child: Text(
                  _filterTabs[index],
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.mainColor,
              backgroundColor: AppColors.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppColors.mainColor : AppColors.cardBorderColor,
                ),
              ),
              onSelected: (selected) {
                if (selected) setState(() => _selectedFilterIndex = index);
              },
            ),
          ),
        );
      }),
    );
  }

  // محتوى قائمة البلاغات حسب التصفية (قيد المتابعة أو تمت المعالجة)
  Widget _buildAlertsContent() {
    final senior = SeniorManager().currentSenior;

    List<Map<String, dynamic>> filteredSos = [];
    if (_selectedFilterIndex == 0) {
      // قيد المتابعة (غير معالجة)
      filteredSos = _emergencyLogs.where((l) {
        final state = (l['E_State'] ?? '').toString();
        return !state.contains('معالجة') && !state.contains('تم الحل');
      }).toList();
    } else {
      // تمت المعالجة
      filteredSos = _emergencyLogs.where((l) {
        final state = (l['E_State'] ?? '').toString();
        return state.contains('معالجة') || state.contains('تم الحل');
      }).toList();
    }

    if (filteredSos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorderColor),
        ),
        child: Column(
          children: [
            const Icon(Icons.verified_user_outlined, size: 54, color: Color(0xFF2E7D32)),
            const SizedBox(height: 12),
            Text(
              _selectedFilterIndex == 0
                  ? 'لا توجد بلاغات قيد المتابعة حالياً'
                  : 'لا توجد بلاغات تمت معالجتها بعد',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedFilterIndex == 0
                  ? 'جميع البلاغات مستقرة أو تمت معالجتها وتأمين كبير السن.'
                  : 'ستظهر هنا السجلات التي تم تأكيد معالجتها ومتابعتها.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedFilterIndex == 0
                  ? 'البلاغات قيد المتابعة (${filteredSos.length})'
                  : 'البلاغات التي تمت معالجتها (${filteredSos.length})',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: AppColors.mainColor),
              onPressed: () => _loadAlerts(),
              tooltip: 'تحديث البلاغات',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredSos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildSosReportCard(filteredSos[index], senior);
          },
        ),
      ],
    );
  }

  // كارت تفصيلي لبلاغ الاستغاثة بدون إيموجي
  Widget _buildSosReportCard(Map<String, dynamic> log, dynamic senior) {
    final state = (log['E_State'] ?? 'نشط').toString();
    final isResolved = state.contains('معالجة') || state.contains('تم الحل');
    final isInProgress = state.contains('متابعة');

    final dateStr = (log['E_Date'] ?? '').toString();
    final timeStr = (log['E_Time'] ?? '').toString();
    final location = (log['E_Location'] ?? 'الموقع الحالي المسجل').toString();
    final desc = (log['Descripion'] ?? 'نداء استغاثة طارئ').toString();

    final statusColor = isResolved
        ? const Color(0xFF2E7D32)
        : (isInProgress ? const Color(0xFFF57C00) : const Color(0xFFD32F2F));

    final statusLabel = isResolved
        ? 'تمت المعالجة'
        : (isInProgress ? 'قيد المتابعة' : 'جديد - بحاجة لتدخل');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isResolved ? AppColors.cardBorderColor : statusColor.withValues(alpha: 0.5),
          width: isResolved ? 1 : 1.6,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الرأس مع اسم المسن وحالة البلاغ
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emergency_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senior.name.isNotEmpty ? 'استغاثة: ${senior.name}' : 'نداء طوارئ لكبير السن',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                    Text(
                      '$dateStr | $timeStr',
                      style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // تفاصيل البلاغ والوصف
          Text(
            desc,
            style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 10),

          // الموقع الجغرافي للمسن
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFD32F2F), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location,
                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openSeniorLocation(log),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: Text('عرض الخريطة', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mainColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),

          // تفاصيل طبية هامة سريعة
          if (senior.bloodType != 'غير محدد' || senior.criticalMedications.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (senior.bloodType != 'غير محدد')
                  _buildTag('فصيلة الدم: ${senior.bloodType}', const Color(0xFFC62828)),
                if (senior.chronicDiseases.isNotEmpty)
                  _buildTag('الأمراض: ${senior.chronicDiseases.join('، ')}', const Color(0xFFE65100)),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.cardBorderColor),
          const SizedBox(height: 12),

          // أزرار الإجراءات والمتابعة
          Row(
            children: [
              // زر اتصال فوري بالمسن
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(senior.phoneNumber),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text('اتصال بالمسن', style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // زر تحديث ومتابعة البلاغ
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showUpdateStatusDialog(log),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: Text('متابعة البلاغ', style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mainColor,
                    side: const BorderSide(color: AppColors.mainColor),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
