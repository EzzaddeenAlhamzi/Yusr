import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/senior_selector_widget.dart';
import '../core/services/api_service.dart';
import '../core/services/senior_manager.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isDeviceConnected = false;
  String _deviceName = '';
  String _lastUpdateTime = '';
  Map<String, dynamic>? _latestRecord;
  List<Map<String, dynamic>> _allRecords = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
    SeniorManager().addListener(_onSeniorChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    SeniorManager().removeListener(_onSeniorChanged);
    super.dispose();
  }

  void _onSeniorChanged() => _loadAllData();

  Future<void> _loadAllData() async {
    if (!SeniorManager().hasSeniors) return;
    setState(() => _isLoading = true);
    try {
      final seniorId = int.tryParse(SeniorManager().currentSenior.id);
      final devices = await ApiService.instance.getDevices(elderlyId: seniorId);
      final activeDevice = devices.isNotEmpty ? devices.first : null;
      final records =
          await ApiService.instance.getHealthRecords(elderlyId: seniorId);

      if (mounted) {
        setState(() {
          _isDeviceConnected = activeDevice != null &&
              (activeDevice['Status'] ?? '').toString() == 'Active';
          _deviceName = activeDevice?['Device_Name']?.toString() ?? 'ساعة ذكية';
          _allRecords = records;
          _latestRecord = records.isNotEmpty ? records.first : null;
          if (_latestRecord != null) {
            final raw = (_latestRecord!['H_Date'] ??
                    _latestRecord!['created_at'] ??
                    '')
                .toString();
            _lastUpdateTime = raw.isNotEmpty ? raw : 'غير محدد';
          } else {
            _lastUpdateTime = '';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل سجل النشاط والصحة. يرجى التحقق من اتصال الشبكة.',
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

  String _val(Map<String, dynamic>? record, List<String> keys,
      [String fallback = '—']) {
    if (record == null) return fallback;
    for (final k in keys) {
      final v = record[k]?.toString().trim();
      if (v != null && v.isNotEmpty && v != 'null') return v;
    }
    return fallback;
  }

  bool _isManual(Map<String, dynamic>? record) {
    if (record == null) return false;
    final hType = (record['H_Type'] ?? '').toString();
    return hType.contains('يدوي');
  }

  String _formatRecordDate(Map<String, dynamic> record) {
    final d = (record['H_Date'] ?? record['created_at'] ?? '').toString();
    return d.isNotEmpty ? d : 'غير محدد';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.mainColor,
        appBar: const CustomSubAppBar(
          title: 'متابعة الحالة الصحية',
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
            child: Column(
              children: [
                const SizedBox(height: 12),
                const SeniorSelectorWidget(showAddButton: false),
                const SizedBox(height: 8),
                _buildDeviceStatusBar(),
                const SizedBox(height: 8),
                Container(
                  color: AppColors.backgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.mainColor,
                    indicatorWeight: 3,
                    labelColor: AppColors.mainColor,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
                    tabs: const [
                      Tab(text: 'آخر القراءات'),
                      Tab(text: 'السجل والمقارنة'),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mainColor,
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildLatestTab(),
                            _buildHistoryTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.mainColor,
          onPressed: _showManualEntryDialog,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'إدخال يدوي',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== شريط حالة الجهاز الذكي ====================
  Widget _buildDeviceStatusBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isDeviceConnected
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDeviceConnected
              ? const Color(0xFF4CAF50)
              : const Color(0xFFFF9800),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isDeviceConnected
                ? Icons.watch_outlined
                : Icons.portable_wifi_off_rounded,
            color: _isDeviceConnected
                ? const Color(0xFF2E7D32)
                : const Color(0xFFE65100),
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _isDeviceConnected
                          ? 'الساعة الذكية: متصلة ($_deviceName)'
                          : 'الساعة الذكية: غير متصلة',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _isDeviceConnected
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
                Text(
                  _lastUpdateTime.isNotEmpty
                      ? 'آخر تحديث للبيانات: $_lastUpdateTime'
                      : 'لا توجد قراءات مسجلة مؤخراً',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.mainColor, size: 22),
            onPressed: _loadAllData,
            tooltip: 'تحديث البيانات',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ==================== تبويب آخر القراءات ====================
  Widget _buildLatestTab() {
    final heartRate = _val(_latestRecord, ['Heart_Rate', 'heart_rate']);
    final bp = _val(_latestRecord, ['Blood_pressure', 'blood_pressure']);
    final oxygen = _val(_latestRecord, ['Oxyger', 'oxygen', 'Oxygen']);
    final temp = _val(_latestRecord, ['Temperature', 'temperature']);
    final steps = _val(_latestRecord, ['steps', 'Steps']);

    final hasData = _latestRecord != null;
    final isManual = _isManual(_latestRecord);

    return RefreshIndicator(
      color: AppColors.mainColor,
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // بانر توضيح مصدر البيانات
          _buildSourceBanner(hasData, isManual),
          const SizedBox(height: 14),

          // عنوان المؤشرات الحيوية
          Row(
            children: [
              const Icon(Icons.favorite_rounded,
                  color: AppColors.mainColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'المؤشرات الحيوية الأساسية',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // شبكة كروت المؤشرات الحيوية
          Row(
            children: [
              Expanded(
                child: _buildVitalCard(
                  title: 'نبض القلب',
                  value: heartRate,
                  unit: 'bpm',
                  icon: Icons.monitor_heart_rounded,
                  iconColor: const Color(0xFFE53935),
                  bgColor: const Color(0xFFFFEBEE),
                  evaluation: _evalHeartRate(heartRate),
                  sourceLabel: isManual ? 'يدوي' : (_isDeviceConnected ? 'ساعة' : 'سجل'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalCard(
                  title: 'أكسجين الدم',
                  value: oxygen,
                  unit: '%',
                  icon: Icons.water_drop_rounded,
                  iconColor: const Color(0xFF1E88E5),
                  bgColor: const Color(0xFFE3F2FD),
                  evaluation: _evalOxygen(oxygen),
                  sourceLabel: isManual ? 'يدوي' : (_isDeviceConnected ? 'ساعة' : 'سجل'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildVitalCard(
                  title: 'ضغط الدم',
                  value: bp,
                  unit: 'mmHg',
                  icon: Icons.speed_rounded,
                  iconColor: const Color(0xFF8E24AA),
                  bgColor: const Color(0xFFF3E5F5),
                  evaluation: _evalBP(bp),
                  sourceLabel: isManual ? 'يدوي' : (_isDeviceConnected ? 'ساعة' : 'سجل'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVitalCard(
                  title: 'درجة الحرارة',
                  value: temp,
                  unit: '°C',
                  icon: Icons.thermostat_rounded,
                  iconColor: const Color(0xFFFB8C00),
                  bgColor: const Color(0xFFFFF3E0),
                  evaluation: _evalTemp(temp),
                  sourceLabel: isManual ? 'يدوي' : (_isDeviceConnected ? 'ساعة' : 'سجل'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // قسم بيانات الساعة الذكية (خطوات ونوم)
          Row(
            children: [
              const Icon(Icons.watch_rounded,
                  color: AppColors.mainColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'بيانات الساعة الذكية المتصلة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'تعتمد بيانات الخطوات والنوم حصرياً على اتصال الساعة وتوفر الحساسات الخاصة بها.',
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // كروت الخطوات والنوم
          _buildWatchFeatureCard(
            title: 'عدد الخطوات',
            icon: Icons.directions_walk_rounded,
            iconColor: const Color(0xFF00897B),
            bgColor: const Color(0xFFE0F2F1),
            isAvailable: _isDeviceConnected && steps != '—' && steps.isNotEmpty,
            valueDisplay: (_isDeviceConnected && steps != '—')
                ? '$steps خطوة'
                : 'غير متوفرة',
            note: _isDeviceConnected
                ? (steps != '—'
                    ? 'تم التحديث من الساعة الذكية'
                    : 'الساعة متصلة ولكن لم يتم استلام بيانات الخطوات بعد')
                : 'الساعة غير متصلة - يتطلب ساعة ذكية لحساب الخطوات بدقة',
          ),
          const SizedBox(height: 10),

          _buildWatchFeatureCard(
            title: 'متابعة النوم',
            icon: Icons.bedtime_rounded,
            iconColor: const Color(0xFF3949AB),
            bgColor: const Color(0xFFE8EAF6),
            isAvailable: false, // لا يوجد عمود للنوم حالياً في قاعدة البيانات
            valueDisplay: 'غير متوفر',
            note: _isDeviceConnected
                ? 'مستشعر النوم غير مفعل أو غير مدعوم في الساعة الحالية'
                : 'الساعة غير متصلة - يتطلب ساعة ذكية مزودة بخاصية تتبع النوم',
          ),
        ],
      ),
    );
  }

  // ==================== بانر مصدر البيانات ====================
  Widget _buildSourceBanner(bool hasData, bool isManual) {
    if (!hasData) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'لا توجد مؤشرات مسجلة حتى الآن. يمكنك إضافة قراءة عبر زر "إدخال يدوي" بالأسفل أو مزامنة الساعة.',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isManual) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFC107)),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_note_rounded,
                color: Color(0xFFF57F17), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تنبيه: قراءة مسجلة بإدخال يدوي',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF57F17),
                    ),
                  ),
                  Text(
                    'تم توثيق هذه القراءة يدوياً من قِبل مقدم الرعاية وليست قراءة مباشرة من ساعة أو جهاز طبي.',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: const Color(0xFF795548),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded,
              color: Color(0xFF2E7D32), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'مصدر البيانات: قراءة معتمدة من المستشعر / الساعة الذكية.',
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== كارت المؤشر الحيوي ====================
  Widget _buildVitalCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Map<String, dynamic> evaluation,
    required String sourceLabel,
  }) {
    final hasValue = value != '—' && value.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: sourceLabel == 'يدوي'
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sourceLabel,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: sourceLabel == 'يدوي'
                        ? const Color(0xFFE65100)
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                hasValue ? value : 'لا توجد قراءة',
                style: GoogleFonts.cairo(
                  fontSize: hasValue ? 20 : 13,
                  fontWeight: FontWeight.bold,
                  color: hasValue ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              if (hasValue && unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: evaluation['bg'] as Color? ?? const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              hasValue
                  ? (evaluation['text']?.toString() ?? 'طبيعي')
                  : 'غير مسجل',
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: evaluation['color'] as Color? ?? AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== كارت ميزات الساعة (خطوات ونوم) ====================
  Widget _buildWatchFeatureCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isAvailable,
    required String valueDisplay,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAvailable ? AppColors.cardColor : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAvailable
              ? AppColors.cardBorderColor
              : const Color(0xFFEEEEEE),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isAvailable ? bgColor : const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isAvailable ? iconColor : const Color(0xFF9E9E9E),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isAvailable
                            ? AppColors.textPrimary
                            : const Color(0xFF757575),
                      ),
                    ),
                    Text(
                      valueDisplay,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isAvailable
                            ? AppColors.mainColor
                            : const Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: isAvailable
                        ? AppColors.textSecondary
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== تبويب السجل والمقارنة ====================
  Widget _buildHistoryTab() {
    if (_allRecords.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded,
                  size: 48, color: Color(0xFFBDBDBD)),
              const SizedBox(height: 12),
              Text(
                'لا توجد سجلات سابقة للمقارنة',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'عند توفر قراءات مسجلة أو مدخلة يدوياً، ستظهر هنا مع مقارنة الفروقات بين كل قراءة والسابقة لها.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.mainColor,
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // كارت المقارنة بين آخر قراءتين
          if (_allRecords.length >= 2) ...[
            _buildComparisonCard(_allRecords[0], _allRecords[1]),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.mainColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يوجد قراءة واحدة مسجلة فقط. ستظهر المقارنة التلقائية فور إضافة قراءة ثانية.',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // قائمة كل السجلات التاريخية
          Row(
            children: [
              const Icon(Icons.format_list_bulleted_rounded,
                  color: AppColors.mainColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'سجل القراءات السابقة (${_allRecords.length})',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._allRecords.map((r) => _buildHistoryItemCard(r)),
        ],
      ),
    );
  }

  // ==================== كارت مقارنة آخر قراءتين ====================
  Widget _buildComparisonCard(
    Map<String, dynamic> latest,
    Map<String, dynamic> previous,
  ) {
    final hr1 = int.tryParse(_val(latest, ['Heart_Rate', 'heart_rate'], ''));
    final hr2 = int.tryParse(_val(previous, ['Heart_Rate', 'heart_rate'], ''));

    final ox1 = int.tryParse(_val(latest, ['Oxyger', 'oxygen', 'Oxygen'], ''));
    final ox2 =
        int.tryParse(_val(previous, ['Oxyger', 'oxygen', 'Oxygen'], ''));

    final bp1 = _val(latest, ['Blood_pressure', 'blood_pressure']);
    final bp2 = _val(previous, ['Blood_pressure', 'blood_pressure']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mainColor.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.mainColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  const Icon(Icons.compare_arrows_rounded,
                      color: AppColors.mainColor, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    'مقارنة آخر قراءتين',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainColor,
                    ),
                  ),
                ],
              ),
              Text(
                'الأحدث vs السابقة',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // مقارنة النبض
          _buildComparisonRow(
            title: 'نبض القلب',
            unit: 'bpm',
            val1: hr1?.toString() ?? '—',
            val2: hr2?.toString() ?? '—',
            delta: (hr1 != null && hr2 != null) ? (hr1 - hr2) : null,
          ),
          const SizedBox(height: 8),

          // مقارنة الأكسجين
          _buildComparisonRow(
            title: 'أكسجين الدم',
            unit: '%',
            val1: ox1?.toString() ?? '—',
            val2: ox2?.toString() ?? '—',
            delta: (ox1 != null && ox2 != null) ? (ox1 - ox2) : null,
          ),
          const SizedBox(height: 8),

          // مقارنة ضغط الدم
          _buildComparisonRow(
            title: 'ضغط الدم',
            unit: 'mmHg',
            val1: bp1,
            val2: bp2,
            delta: null, // نصي
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String title,
    required String unit,
    required String val1,
    required String val2,
    required int? delta,
  }) {
    Color deltaColor = AppColors.textSecondary;
    String deltaText = 'مستقر';
    IconData deltaIcon = Icons.remove_rounded;

    if (delta != null) {
      if (delta > 0) {
        deltaColor = const Color(0xFFE53935);
        deltaText = '+$delta $unit';
        deltaIcon = Icons.arrow_upward_rounded;
      } else if (delta < 0) {
        deltaColor = const Color(0xFF1E88E5);
        deltaText = '$delta $unit';
        deltaIcon = Icons.arrow_downward_rounded;
      }
    }

    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                val1,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainColor,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_back_rounded,
                  size: 14, color: Color(0xFFBDBDBD)),
              const SizedBox(width: 8),
              Text(
                val2,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (delta != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(deltaIcon, size: 12, color: deltaColor),
                const SizedBox(width: 2),
                Text(
                  deltaText,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: deltaColor,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            unit,
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  // ==================== كارت عنصر من السجل ====================
  Widget _buildHistoryItemCard(Map<String, dynamic> record) {
    final isManual = _isManual(record);
    final date = _formatRecordDate(record);
    final hr = _val(record, ['Heart_Rate', 'heart_rate']);
    final bp = _val(record, ['Blood_pressure', 'blood_pressure']);
    final ox = _val(record, ['Oxyger', 'oxygen', 'Oxygen']);
    final temp = _val(record, ['Temperature', 'temperature']);
    final result = _val(record, ['H_Result', 'result'], 'طبيعي');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isManual
                        ? Icons.edit_note_rounded
                        : Icons.watch_outlined,
                    size: 18,
                    color: isManual
                        ? const Color(0xFFF57F17)
                        : const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    date,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
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
                  color: isManual
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isManual ? 'إدخال يدوي' : 'ساعة ذكية',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isManual
                        ? const Color(0xFFE65100)
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (hr != '—') _buildMiniChip('النبض: $hr bpm', const Color(0xFFE53935)),
              if (bp != '—') _buildMiniChip('الضغط: $bp', const Color(0xFF8E24AA)),
              if (ox != '—') _buildMiniChip('الأكسجين: $ox%', const Color(0xFF1E88E5)),
              if (temp != '—') _buildMiniChip('الحرارة: $temp°C', const Color(0xFFFB8C00)),
            ],
          ),
          if (result.isNotEmpty && result != '—') ...[
            const SizedBox(height: 6),
            Text(
              'النتيجة: $result',
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ==================== تقييم المؤشرات الحيوية ====================
  Map<String, dynamic> _evalHeartRate(String val) {
    final v = int.tryParse(val);
    if (v == null) return {'text': 'غير محدد', 'color': AppColors.textSecondary, 'bg': const Color(0xFFF5F5F5)};
    if (v < 60) return {'text': 'منخفض', 'color': const Color(0xFFFB8C00), 'bg': const Color(0xFFFFF3E0)};
    if (v <= 100) return {'text': 'طبيعي', 'color': const Color(0xFF2E7D32), 'bg': const Color(0xFFE8F5E9)};
    return {'text': 'مرتفع', 'color': const Color(0xFFE53935), 'bg': const Color(0xFFFFEBEE)};
  }

  Map<String, dynamic> _evalOxygen(String val) {
    final v = int.tryParse(val);
    if (v == null) return {'text': 'غير محدد', 'color': AppColors.textSecondary, 'bg': const Color(0xFFF5F5F5)};
    if (v >= 95) return {'text': 'طبيعي', 'color': const Color(0xFF2E7D32), 'bg': const Color(0xFFE8F5E9)};
    if (v >= 90) return {'text': 'مقبول', 'color': const Color(0xFFFB8C00), 'bg': const Color(0xFFFFF3E0)};
    return {'text': 'منخفض', 'color': const Color(0xFFE53935), 'bg': const Color(0xFFFFEBEE)};
  }

  Map<String, dynamic> _evalBP(String val) {
    if (val.isEmpty || val == '—') {
      return {'text': 'غير محدد', 'color': AppColors.textSecondary, 'bg': const Color(0xFFF5F5F5)};
    }
    final parts = val.split('/');
    if (parts.length == 2) {
      final sys = int.tryParse(parts[0].trim());
      final dia = int.tryParse(parts[1].trim());
      if (sys != null && dia != null) {
        if (sys >= 140 || dia >= 90) {
          return {'text': 'مرتفع', 'color': const Color(0xFFE53935), 'bg': const Color(0xFFFFEBEE)};
        }
        if (sys <= 120 && dia <= 80) {
          return {'text': 'طبيعي', 'color': const Color(0xFF2E7D32), 'bg': const Color(0xFFE8F5E9)};
        }
        return {'text': 'تحت المتابعة', 'color': const Color(0xFFFB8C00), 'bg': const Color(0xFFFFF3E0)};
      }
    }
    return {'text': 'مسجل', 'color': AppColors.mainColor, 'bg': const Color(0xFFE0F2F1)};
  }

  Map<String, dynamic> _evalTemp(String val) {
    final v = double.tryParse(val);
    if (v == null) return {'text': 'غير محدد', 'color': AppColors.textSecondary, 'bg': const Color(0xFFF5F5F5)};
    if (v < 36.0) return {'text': 'منخفض', 'color': const Color(0xFFFB8C00), 'bg': const Color(0xFFFFF3E0)};
    if (v <= 37.5) return {'text': 'طبيعي', 'color': const Color(0xFF2E7D32), 'bg': const Color(0xFFE8F5E9)};
    return {'text': 'حمى / مرتفع', 'color': const Color(0xFFE53935), 'bg': const Color(0xFFFFEBEE)};
  }

  // ==================== حوار الإدخال اليدوي ====================
  void _showManualEntryDialog() {
    final hrCtrl = TextEditingController();
    final bpCtrl = TextEditingController();
    final oxCtrl = TextEditingController();
    final tempCtrl = TextEditingController();
    final stepsCtrl = TextEditingController();
    final resultCtrl = TextEditingController(text: 'طبيعي');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded,
                      color: AppColors.mainColor),
                  const SizedBox(width: 8),
                  Text(
                    'تسجيل قراءة صحية يدوية',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // تنبيه الشفافية والموثوقية
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB74D)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFE65100), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سيتم وسم هذه البيانات بـ (إدخال يدوي) ولن تُعرض كبيانات حية من الساعة الذكية.',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: const Color(0xFFE65100),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDialogField('نبض القلب (bpm)', hrCtrl,
                        keyboardType: TextInputType.number, hint: 'مثال: 75'),
                    const SizedBox(height: 8),
                    _buildDialogField('ضغط الدم (mmHg)', bpCtrl,
                        hint: 'مثال: 120/80'),
                    const SizedBox(height: 8),
                    _buildDialogField('أكسجين الدم (%)', oxCtrl,
                        keyboardType: TextInputType.number, hint: 'مثال: 98'),
                    const SizedBox(height: 8),
                    _buildDialogField('درجة الحرارة (°C)', tempCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        hint: 'مثال: 37.0'),
                    const SizedBox(height: 8),
                    _buildDialogField('عدد الخطوات (اختياري)', stepsCtrl,
                        keyboardType: TextInputType.number, hint: 'مثال: 2500'),
                    const SizedBox(height: 8),
                    _buildDialogField('ملاحظة أو تقييم', resultCtrl,
                        hint: 'مثال: طبيعي / فحص دوري'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.cairo(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final hr = int.tryParse(hrCtrl.text.trim());
                          final bp = bpCtrl.text.trim();
                          final ox = int.tryParse(oxCtrl.text.trim());
                          final temp = double.tryParse(tempCtrl.text.trim());
                          final steps = int.tryParse(stepsCtrl.text.trim());
                          final result = resultCtrl.text.trim();

                          if (hr == null &&
                              bp.isEmpty &&
                              ox == null &&
                              temp == null &&
                              steps == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'يرجى إدخال قيمة واحدة على الأقل',
                                  style: GoogleFonts.cairo(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          setDlgState(() => isSubmitting = true);
                          try {
                            final seniorId = int.tryParse(
                                SeniorManager().currentSenior.id);
                            final res =
                                await ApiService.instance.addHealthRecord(
                              heartRate: hr,
                              bloodPressure: bp.isNotEmpty ? bp : null,
                              oxygen: ox,
                              temperature: temp,
                              steps: steps,
                              type: 'إدخال يدوي',
                              result: result.isNotEmpty ? result : 'طبيعي',
                              elderlyId: seniorId,
                            );

                            if (mounted) {
                              nav.pop();
                              if (res['status'] == 'success' ||
                                  res['success'] == true) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تم حفظ القراءة اليدوية بنجاح',
                                      style: GoogleFonts.cairo(),
                                    ),
                                    backgroundColor: const Color(0xFF2E7D32),
                                  ),
                                );
                                _loadAllData();
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res['message']?.toString() ??
                                          'تعذر حفظ القراءة',
                                      style: GoogleFonts.cairo(),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'حدث خطأ أثناء الحفظ: $e',
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setDlgState(() => isSubmitting = false);
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'حفظ القراءة',
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
      ),
    );
  }

  Widget _buildDialogField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.cairo(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.cairo(
              fontSize: 12,
              color: const Color(0xFFBDBDBD),
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.mainColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}