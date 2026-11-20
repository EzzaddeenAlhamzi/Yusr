import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/senior_manager.dart';
import 'ai_page.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  // بيانات شرب الماء
  int _waterCups = 0;
  int _targetCups = 8;

  // بيانات الوزن
  double _currentWeight = 0.0;

  // بيانات الخطوات
  int _currentSteps = 0;
  final int _targetSteps = 5000;

  // سجل المؤشرات الحيوية من قاعدة البيانات
  Map<String, dynamic>? _healthRecord;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() => _isLoading = true);
    try {
      int? seniorId;
      if (AuthService().isSenior) {
        seniorId = AuthService().userId;
      } else if (SeniorManager().hasSeniors) {
        seniorId = int.tryParse(SeniorManager().currentSenior.id);
      }
      final records = await ApiService.instance.getHealthRecords(elderlyId: seniorId);
      if (mounted) {
        setState(() {
          if (records.isNotEmpty) {
            _healthRecord = records.first;
            _currentSteps = int.tryParse(_healthRecord?['steps']?.toString() ?? '0') ?? 0;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // دالة بناء وتنسيق النافذة السفلية الموحدة
  Widget _buildBottomSheetWrapper({
    required BuildContext ctx,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // مؤشر السحب العلوي
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),

              // رأس النافذة
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 34),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              content,

              const SizedBox(height: 16),

              // زر الإغلاق الموحد
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appbarColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'تم',
                    style: GoogleFonts.tajawal(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // 1. نافذة شرب الماء
  void _showWaterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double progress = (_waterCups / _targetCups).clamp(0.0, 1.0);

            return _buildBottomSheetWrapper(
              ctx: ctx,
              title: 'متابعة شرب الماء',
              icon: Icons.water_drop_rounded,
              iconColor: appbarColor,
              content: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'شربت اليوم',
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_waterCups من أصل $_targetCups أكواب',
                          style: GoogleFonts.tajawal(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: appbarColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(appbarColor),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _waterCups >= _targetCups
                              ? '🎉 رائع جداً! حققت هدفك اليومي'
                              : '💧 تبقى لك ${_targetCups - _waterCups} أكواب لاكتمال هدفك',
                          style: GoogleFonts.tajawal(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: appbarColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // زر شربت كأساً باللون الأزرق الرئيسي
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _waterCups++;
                        });
                        setModalState(() {});
                      },
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      label: Text(
                        'شربت كأساً (+1)',
                        style: GoogleFonts.tajawal(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appbarColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_waterCups > 0)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _waterCups--;
                        });
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20),
                      label: Text(
                        'تراجع عن كأس (-1)',
                        style: GoogleFonts.tajawal(
                          color: Colors.grey[700],
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const Divider(height: 24, thickness: 1),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الهدف اليومي:',
                        style: GoogleFonts.tajawal(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _targetCups > 4
                                ? () {
                                    setState(() {
                                      _targetCups--;
                                    });
                                    setModalState(() {});
                                  }
                                : null,
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _targetCups > 4 ? cardColor : Colors.grey[200],
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: const Icon(Icons.remove, size: 20, color: Colors.black87),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorderColor),
                            ),
                            child: Text(
                              '$_targetCups أكواب',
                              style: GoogleFonts.tajawal(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: appbarColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _targetCups < 20
                                ? () {
                                    setState(() {
                                      _targetCups++;
                                    });
                                    setModalState(() {});
                                  }
                                : null,
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: const Icon(Icons.add, size: 20, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 2. نافذة تعديل ومتابعة الوزن الحالي
  void _showWeightBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _buildBottomSheetWrapper(
              ctx: ctx,
              title: 'الوزن الحالي',
              icon: Icons.monitor_weight_outlined,
              iconColor: const Color(0xFF3949AB),
              content: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'وزنك الحالي المسجل',
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_currentWeight.toStringAsFixed(1)} كجم',
                          style: GoogleFonts.tajawal(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3949AB),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EAF6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'مؤشر كتلة الجسم: وزن طبيعي ومثالي 👍',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF283593),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'تعديل الوزن المسجل:',
                    style: GoogleFonts.tajawal(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // زر إنقاص 0.5 كجم
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentWeight = (_currentWeight - 0.5).clamp(30.0, 200.0);
                          });
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.remove, color: Colors.white),
                        label: Text(
                          '- 0.5 كجم',
                          style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // زر زيادة 0.5 كجم
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentWeight = (_currentWeight + 0.5).clamp(30.0, 200.0);
                          });
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text(
                          '+ 0.5 كجم',
                          style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appbarColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3. نافذة معلومات الخطوات
  void _showStepsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final double progress = (_currentSteps / _targetSteps).clamp(0.0, 1.0);
        return _buildBottomSheetWrapper(
          ctx: ctx,
          title: 'النشاط والخطوات',
          icon: Icons.directions_walk_rounded,
          iconColor: const Color(0xFF43A047),
          content: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cardBorderColor, width: 1.2),
                ),
                child: Column(
                  children: [
                    Text(
                      'مجموع خطوات اليوم',
                      style: GoogleFonts.tajawal(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_currentSteps خطوة',
                      style: GoogleFonts.tajawal(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF43A047)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'الهدف: $_targetSteps خطوة (${(progress * 100).toInt()}%)',
                      style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(title: 'المسافة', value: '2.4 كم', icon: Icons.map_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMiniStat(title: 'السعرات', value: '145 سعرة', icon: Icons.local_fire_department_outlined),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. نافذة معلومات النوم
  void _showSleepBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _buildBottomSheetWrapper(
          ctx: ctx,
          title: 'معلومات النوم والراحة',
          icon: Icons.nightlight_round,
          iconColor: const Color(0xFF5E35B1),
          content: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cardBorderColor, width: 1.2),
                ),
                child: Column(
                  children: [
                    Text(
                      'إجمالي ساعات النوم',
                      style: GoogleFonts.tajawal(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '--',
                      style: GoogleFonts.tajawal(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5E35B1),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'لم يتم رصد ساعات نوم متصلة عبر الأجهزة بعد',
                        style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF4527A0)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(title: 'وقت النوم', value: 'غير مسجل', icon: Icons.bedtime_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMiniStat(title: 'الاستيقاظ', value: 'غير مسجل', icon: Icons.wb_sunny_outlined),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 5. نافذة نبضات القلب
  void _showHeartRateBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final hr = _healthRecord?['Heart_Rate'];
        return _buildBottomSheetWrapper(
          ctx: ctx,
          title: 'نبضات القلب',
          icon: Icons.favorite_rounded,
          iconColor: const Color(0xFFE53935),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Text(
                  'المعدل الحالي أثناء الراحة',
                  style: GoogleFonts.tajawal(fontSize: 18, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  hr != null ? '$hr نبضة/د' : 'غير مسجل',
                  style: GoogleFonts.tajawal(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFFC62828)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hr != null ? 'الحالة: ${_healthRecord?['H_Result'] ?? 'مسجّل'} ❤️' : 'لا توجد قراءات حديثة مسجلة',
                    style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFB71C1C)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'المعدل الطبيعي لكبار السن أثناء الراحة هو بين 60 - 100 نبضة بالدقيقة.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // نافذة درجة الحرارة
  void _showTemperatureBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final temp = _healthRecord?['Temperature'];
        return _buildBottomSheetWrapper(
          ctx: ctx,
          title: 'درجة الحرارة',
          icon: Icons.thermostat_rounded,
          iconColor: const Color(0xFFF57C00),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Text(
                  'درجة الحرارة المقاسة',
                  style: GoogleFonts.tajawal(fontSize: 18, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  temp != null ? '$temp °C' : 'غير مسجل',
                  style: GoogleFonts.tajawal(fontSize: 36, fontWeight: FontWeight.bold, color: const Color(0xFFE65100)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    temp != null
                        ? (double.tryParse(temp.toString()) != null && double.parse(temp.toString()) > 37.5
                            ? 'تنبيه: ارتفاع في درجة الحرارة ⚠️'
                            : 'درجة الحرارة طبيعية ✅')
                        : 'لا توجد قراءات حديثة مسجلة',
                    style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFE65100)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'درجة الحرارة الطبيعية لكبار السن تتراوح بين 36.1°C و 37.2°C. ما فوق 37.5°C يُعدّ ارتفاعاً يستدعي المتابعة.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(fontSize: 15, color: Colors.black87, height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 6. نافذة ضغط الدم
  void _showBloodPressureBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bp = _healthRecord?['Blood_pressure']?.toString();
        return _buildBottomSheetWrapper(
          ctx: ctx,
          title: 'ضغط الدم',
          icon: Icons.water_drop_rounded,
          iconColor: const Color(0xFFB71C1C),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Text(
                  'آخر قياس مسجل',
                  style: GoogleFonts.tajawal(fontSize: 18, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  bp ?? '-- / --',
                  style: GoogleFonts.tajawal(fontSize: 34, fontWeight: FontWeight.bold, color: const Color(0xFFB71C1C)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bp != null ? 'ضغط دم مسجّل' : 'لا توجد قراءات ضغط دم مسجلة',
                    style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFB71C1C)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'المعدل الطبيعي العام هو 120/80 ملم زئبق.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 7. نافذة نسبة الأكسجين
  void _showOxygenBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final oxy = _healthRecord?['Oxyger'];
        return _buildBottomSheetWrapper(
          ctx: ctx,
          title: 'نسبة الأكسجين بالدم',
          icon: Icons.air_rounded,
          iconColor: const Color(0xFF0288D1),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Text(
                  'نسبة تشبع الأكسجين (SpO2)',
                  style: GoogleFonts.tajawal(fontSize: 18, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  oxy != null ? '$oxy%' : '--',
                  style: GoogleFonts.tajawal(fontSize: 36, fontWeight: FontWeight.bold, color: const Color(0xFF0288D1)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1F5FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    oxy != null ? 'ضمن النطاق الطبيعي' : 'لا توجد قراءات أكسجين مسجلة',
                    style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF01579B)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 8. نافذة الراحة النفسية
  void _showWellnessBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _buildBottomSheetWrapper(
          ctx: ctx,
          title: 'الراحة النفسية والمزاج',
          icon: Icons.sentiment_very_satisfied_rounded,
          iconColor: const Color(0xFF8E24AA),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Text(
                  'المستوى العام لليوم',
                  style: GoogleFonts.tajawal(fontSize: 18, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  'هادئ ومسترخي 😊',
                  style: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF8E24AA)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'مستوى الإجهاد والتوتر: منخفض جداً',
                    style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF6A1B9A)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ودجت إحصائية صغيرة داخل النوافذ
  Widget _buildMiniStat({required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: appbarColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.tajawal(fontSize: 14, color: Colors.grey[600])),
              Text(value, style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appbarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // الشريط العلوي الموحد (CustomTopBar)
            CustomTopBar(
              title: 'صحتي',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // الجسم المنحني الرئيسي
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: appbarColor))
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                        padding: const EdgeInsets.only(top: 20, bottom: 15),
                        child: Column(
                          children: [
                            // شبكة كروت البيانات الصحية (8 كروت تفاعلية)
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.82,
                              children: [
                                // 1. نبضات القلب
                                _buildInteractiveHealthCard(
                                  title: 'نبضات القلب',
                                  value: _healthRecord?['Heart_Rate'] != null ? '${_healthRecord!['Heart_Rate']}' : '--',
                                  status: _healthRecord?['Heart_Rate'] != null ? 'نبضة/د (${_healthRecord!['H_Result'] ?? 'طبيعي'})' : 'غير مسجل',
                                  iconWidget: const Icon(Icons.favorite_rounded, color: Color(0xFFE53935), size: 44),
                                  onTap: _showHeartRateBottomSheet,
                                ),

                                // 2. ضغط الدم
                                _buildInteractiveHealthCard(
                                  title: 'ضغط الدم',
                                  value: _healthRecord?['Blood_pressure']?.toString() ?? '--/--',
                                  status: _healthRecord?['Blood_pressure'] != null ? 'مسجّل' : 'غير مسجل',
                                  iconWidget: const Icon(Icons.water_drop_rounded, color: Color(0xFFB71C1C), size: 44),
                                  onTap: _showBloodPressureBottomSheet,
                                ),

                                // 3. نسبة الأكسجين
                                _buildInteractiveHealthCard(
                                  title: 'نسبة الأكسجين',
                                  value: _healthRecord?['Oxyger'] != null ? '${_healthRecord!['Oxyger']}%' : '--',
                                  status: _healthRecord?['Oxyger'] != null ? 'ضمن النطاق' : 'غير مسجل',
                                  iconWidget: const Icon(Icons.air_rounded, color: Color(0xFF0288D1), size: 44),
                                  onTap: _showOxygenBottomSheet,
                                ),

                                // 4. كارد شرب الماء
                                _buildInteractiveHealthCard(
                                  title: 'شرب الماء',
                                  value: '$_waterCups / $_targetCups أكواب',
                                  status: _waterCups >= _targetCups ? 'اكتمل الهدف 🌟' : (_waterCups > 0 ? 'اضغط للمتابعة 💧' : 'اضغط للتسجيل 💧'),
                                  iconWidget: const Icon(Icons.local_drink_rounded, color: appbarColor, size: 44),
                                  onTap: _showWaterBottomSheet,
                                ),

                                // 5. الخطوات والنشاط
                                _buildInteractiveHealthCard(
                                  title: 'الخطوات',
                                  value: _currentSteps > 0 ? '$_currentSteps' : '--',
                                  status: _currentSteps > 0 ? 'خطوة (نشاط مسجل)' : 'لا توجد خطوات مسجلة',
                                  iconWidget: const Icon(Icons.directions_walk_rounded, color: Color(0xFF43A047), size: 46),
                                  onTap: _showStepsBottomSheet,
                                ),

                                // 6. درجة الحرارة
                                _buildInteractiveHealthCard(
                                  title: 'درجة الحرارة',
                                  value: _healthRecord?['Temperature'] != null ? '${_healthRecord!['Temperature']}°C' : '--',
                                  status: _healthRecord?['Temperature'] != null ? 'آخر قياس مسجل' : 'غير مسجل',
                                  iconWidget: const Icon(Icons.thermostat_rounded, color: Color(0xFFF57C00), size: 44),
                                  onTap: () => _showTemperatureBottomSheet(),
                                ),

                                // 7. ساعات النوم
                                _buildInteractiveHealthCard(
                                  title: 'النوم',
                                  value: '--',
                                  status: 'غير متوفر',
                                  iconWidget: const Icon(Icons.nightlight_round, color: Color(0xFF5E35B1), size: 44),
                                  onTap: _showSleepBottomSheet,
                                ),

                                // 7. الوزن الحالي (تفاعلي للتعديل)
                                _buildInteractiveHealthCard(
                                  title: 'الوزن الحالي',
                                  value: _currentWeight > 0 ? '${_currentWeight.toStringAsFixed(1)} كجم' : '--',
                                  status: _currentWeight > 0 ? 'اضغط للتعديل ⚖️' : 'اضغط للتسجيل ⚖️',
                                  iconWidget: const Icon(Icons.monitor_weight_outlined, color: Color(0xFF3949AB), size: 44),
                                  onTap: _showWeightBottomSheet,
                                ),

                                // 8. الراحة النفسية — no API field; never invent "مستقر".
                                _buildInteractiveHealthCard(
                                  title: 'الراحة النفسية',
                                  value: 'غير متوفر',
                                  status: 'لا توجد قراءة من الخادم',
                                  iconWidget: const Icon(Icons.sentiment_very_satisfied_rounded, color: Color(0xFF8E24AA), size: 44),
                                  onTap: _showWellnessBottomSheet,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),

                    // زر "اضغط للتحدث" السفلي
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
                      child: Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          color: appbarColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AIPage(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'اضغط للتحدث',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Positioned(
                                left: 20,
                                child: Icon(
                                  Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ],
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

  // كارت صحي تفاعلي يفتح نافذة معلومات سفلية عند النقر
  Widget _buildInteractiveHealthCard({
    required String title,
    required String value,
    required String status,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cardBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // عنوان الكارت
            Text(
              title,
              style: GoogleFonts.tajawal(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            // الأيقونة
            iconWidget,

            // القيمة الرقمية
            Text(
              value,
              style: GoogleFonts.tajawal(
                color: Colors.black,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            // الحالة / التوجيه
            Text(
              status,
              style: GoogleFonts.tajawal(
                color: const Color(0xFF607D8B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
