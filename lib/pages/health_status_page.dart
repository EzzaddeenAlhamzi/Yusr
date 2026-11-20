import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/date_filter_dropdown.dart';
import '../core/widgets/senior_selector_widget.dart';
import '../core/services/senior_manager.dart';
import '../core/services/api_service.dart';

class HealthStatusPage extends StatefulWidget {
  const HealthStatusPage({super.key});

  @override
  State<HealthStatusPage> createState() => _HealthStatusPageState();
}

class _HealthStatusPageState extends State<HealthStatusPage> {
  String _selectedFilter = 'اليوم';
  Map<String, dynamic>? _latestRecord;
  List<Map<String, dynamic>> _healthAlerts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
    SeniorManager().addListener(_onSeniorChanged);
  }

  @override
  void dispose() {
    SeniorManager().removeListener(_onSeniorChanged);
    super.dispose();
  }

  void _onSeniorChanged() {
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    if (!SeniorManager().hasSeniors) return;
    setState(() => _isLoading = true);
    try {
      final senior = SeniorManager().currentSenior;
      final seniorId = int.tryParse(senior.id);
      final records = await ApiService.instance.getHealthRecords(elderlyId: seniorId);
      final alerts = await ApiService.instance.getHealthAlerts(elderlyId: seniorId);
      if (mounted) {
        setState(() {
          _latestRecord = records.isNotEmpty ? records.first : null;
          _healthAlerts = alerts;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل البيانات الصحية. تأكد من اتصالك بالشبكة.',
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.mainColor,
        appBar: const CustomSubAppBar(
          title: 'الحالة الصحية',
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
            child: ListenableBuilder(
              listenable: SeniorManager(),
              builder: (context, _) {
                final hasSenior = SeniorManager().hasSeniors;

                if (!hasSenior) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.mainColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.health_and_safety_outlined,
                              size: 70,
                              color: AppColors.mainColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'لا توجد بيانات صحية مسجلة',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'لم تقم بربط أي كبير سن بحسابك بعد. قم بربط كبير السن لعرض مؤشراته الحيوية والتقارير الصحية.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/link-senior');
                            },
                            icon: const Icon(Icons.link, color: Colors.white),
                            label: Text(
                              'ربط كبير سن جديد',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mainColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (_isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.mainColor),
                  );
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SeniorSelectorWidget(showAddButton: false),
                      const SizedBox(height: 14),

                      // 1. فلتر التاريخ الموحد
                      DateFilterDropdown(
                        selectedValue: _selectedFilter,
                        onSelected: (value) {
                          setState(() {
                            _selectedFilter = value;
                          });
                        },
                        items: const [
                          DateFilterItem(title: 'اليوم', icon: Icons.today_rounded),
                          DateFilterItem(title: 'أمس', icon: Icons.history_rounded),
                          DateFilterItem(title: 'الأسبوع الماضي', icon: Icons.date_range_rounded),
                        ],
                      ),

                      const SizedBox(height: 14),

                  // 2. شبكة كروت المؤشرات الصحية
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildMetricCard(
                        title: 'ضغط الدم',
                        value: _latestRecord?['Blood_pressure']?.toString() ?? '--/--',
                        unit: _latestRecord?['Blood_pressure'] != null ? 'ملم زئبق' : 'غير مسجل',
                        time: _latestRecord?['H_Date']?.toString() ?? 'لا توجد قراءات',
                        icon: Icons.water_drop,
                        iconColor: const Color(0xFFE53935),
                        statusTag: _latestRecord?['H_Result']?.toString() ?? 'غير متوفر',
                      ),
                      _buildMetricCard(
                        title: 'نبض القلب',
                        value: _latestRecord?['Heart_Rate']?.toString() ?? '--',
                        unit: 'نبضة / دقيقة',
                        time: _latestRecord?['H_Date']?.toString() ?? 'لا توجد قراءات',
                        icon: Icons.favorite,
                        iconColor: const Color(0xFF00ACC1),
                        statusTag: _latestRecord?['Heart_Rate'] != null ? (_latestRecord!['H_Result']?.toString() ?? 'طبيعي') : 'غير متوفر',
                      ),
                      _buildMetricCard(
                        title: 'الخطوات',
                        value: _latestRecord?['steps']?.toString() ?? '--',
                        unit: 'خطوة',
                        time: _latestRecord?['H_Date']?.toString() ?? 'لا توجد قراءات',
                        icon: Icons.directions_walk,
                        iconColor: const Color(0xFFE65100),
                        statusTag: _latestRecord?['steps'] != null ? 'نشاط مسجل' : 'غير متوفر',
                      ),
                      _buildMetricCard(
                        title: 'الأكسجين',
                        value: _latestRecord?['Oxyger']?.toString() ?? '--',
                        unit: '%',
                        time: _latestRecord?['H_Date']?.toString() ?? 'لا توجد قراءات',
                        icon: Icons.bar_chart,
                        iconColor: const Color(0xFF0288D1),
                        statusTag: _latestRecord?['Oxyger'] != null ? 'مسجّل' : 'غير متوفر',
                      ),
                      _buildMetricCard(
                        title: 'درجة الحرارة',
                        value: _latestRecord?['Temperature']?.toString() ?? '--',
                        unit: _latestRecord?['Temperature'] != null ? '°C' : 'غير مسجل',
                        time: _latestRecord?['H_Date']?.toString() ?? 'لا توجد قراءات',
                        icon: Icons.thermostat_rounded,
                        iconColor: const Color(0xFFF57C00),
                        statusTag: _latestRecord?['Temperature'] != null
                            ? (double.tryParse(_latestRecord!['Temperature'].toString()) != null &&
                                    double.parse(_latestRecord!['Temperature'].toString()) > 37.5
                                ? 'ارتفاع ⚠️'
                                : 'طبيعي ✅')
                            : 'غير متوفر',
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // قسم التنبيهات الصحية (health_alerts)
                  _buildHealthAlertsSection(),

                  const SizedBox(height: 14),

                  // 3. كارت التقرير اليومي السريع
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
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
                            Text(
                              'ساعات النوم والراحة',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.mainColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'غير مسجل',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '--',
                          style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainColor,
                          ),
                        ),
                        Text(
                          'لم يتم رصد ساعات نوم متصلة عبر الأجهزة بعد',
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. زر عرض التقرير الكامل
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'جاري تحميل التقرير الطبي الشامل 📊',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            backgroundColor: AppColors.mainColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'عرض التقرير الكامل',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    ),
  ),
);
}

  Widget _buildHealthAlertsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFE53935), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'التنبيهات والملاحظات الصحية',
                    style: GoogleFonts.cairo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _healthAlerts.isEmpty
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _healthAlerts.isEmpty ? 'طبيعي' : '${_healthAlerts.length} تنبيه',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _healthAlerts.isEmpty
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.cardBorderColor),
          const SizedBox(height: 10),
          if (_healthAlerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Color(0xFF2E7D32), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا توجد تنبيهات صحية حرجة مسجلة، المؤشرات ضمن النطاق المقبول.',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._healthAlerts.map((a) {
              final type = a['A_Type']?.toString() ?? 'تنبيه صحي';
              final desc = a['A_Description']?.toString() ?? '';
              final level = a['A_Level']?.toString() ?? 'متوسط';
              final date = a['A_Date']?.toString() ?? '';
              final isHigh = level == 'عالي' || level == 'حرج';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isHigh
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isHigh
                        ? const Color(0xFFFFCDD2)
                        : const Color(0xFFFFECB3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isHigh ? Icons.error_outline : Icons.info_outline,
                      color: isHigh
                          ? const Color(0xFFC62828)
                          : const Color(0xFFF57F17),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                type,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isHigh
                                      ? const Color(0xFFB71C1C)
                                      : const Color(0xFFE65100),
                                ),
                              ),
                              Text(
                                date,
                                style: GoogleFonts.cairo(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.textColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String time,
    required IconData icon,
    required Color iconColor,
    required String statusTag,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusTag,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainColor,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Text(
            time,
            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

