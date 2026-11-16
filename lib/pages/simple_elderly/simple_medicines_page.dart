import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// شاشة الأدوية للوضع البسيط (Simple Medicines Screen)
/// مطابقة 100% وبدقة تامة لصورة الشاشة المرفقة من المستخدم:
/// - شريط علوي أبيض:
///   * على أقصى اليمين: سهم الرجوع ">"
///   * في المنتصف: أيقونة المربع البنفسجي مع علامة الزائد (+) على اليسار وكلمة "الأدوية" بجانبها
/// - قائمة البطاقات:
///   * بطاقة دواء الفطور (صباحاً):
///     - عنوان "دواء الضغط" وبجانبه بادج مربع أبيض بداخله أيقونة اللقاحات/الحقنة والدواء باللون البرتقالي
///     - التوجيه باللون الكحلي/الزيتي الغامق: "حبة واحدة \n بعد الفطور"
///     - شريط التوقيت باللون البيج بأسفل البطاقة: "كل يوم" على اليسار، شمس ☀️ بالمنتصف، "8:00" على اليمين
///   * بطاقة دواء العشاء (مساءً):
///     - نفس التفاصيل مع التوجيه "حبة واحدة \n بعد العشاء"
///     - شريط التوقيت: "كل يوم" على اليسار، هلال أزرق 🌙 بالمنتصف، "8:00" على اليمين
import '../../core/services/api_service.dart';
import '../../core/services/senior_manager.dart';

class SimpleMedicinesPage extends StatefulWidget {
  const SimpleMedicinesPage({super.key});

  @override
  State<SimpleMedicinesPage> createState() => _SimpleMedicinesPageState();
}

class _SimpleMedicinesPageState extends State<SimpleMedicinesPage> {
  List<Map<String, dynamic>> _medicines = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);
    try {
      final senior = SeniorManager().currentSenior;
      final int? seniorId = int.tryParse(senior.id);
      final list = await ApiService.instance.getMedications(elderlyId: seniorId);
      if (mounted) {
        setState(() {
          _medicines = list.map((m) {
            return {
              'title': m['M_Name'] ?? 'دواء',
              'instructionLine1': m['M_much'] ?? '1 حبة',
              'instructionLine2': m['M_RepatTime'] ?? 'يومياً',
              'time': '8:00',
              'period': 'كل يوم',
              'isNight': false,
            };
          }).toList();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل قائمة الأدوية. يرجى التأكد من الاتصال بالشبكة.',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16),
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. الشريط العلوي المطابق للصورة تماماً
            _buildTopAppBar(context),

            const SizedBox(height: 8),

            // 2. قائمة بطاقات الأدوية أو رسالة فارغة
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF5E35B1)))
                  : _medicines.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد أدوية مسجلة حالياً',
                                  style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          itemCount: _medicines.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 18),
                          itemBuilder: (context, index) {
                            final med = _medicines[index];
                            return _buildMedicineCard(
                              title: med['title'],
                              line1: med['instructionLine1'],
                              line2: med['instructionLine2'],
                              time: med['time'],
                              period: med['period'],
                              isNight: med['isNight'],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// الشريط العلوي:
  /// في المنتصف: المربع البنفسجي مع (+) وبجانبه "الأدوية"
  /// على اليمين: سهم الرجوع >
  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // العنوان في المنتصف: [المربع البنفسجي +] ثم [الأدوية]
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // المربع البنفسجي مع علامة الزائد البيضاء داخلها
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF992AAD), // بنفسجي مطابق للصورة
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'الأدوية',
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // سهم الرجوع على أقصى اليمين ( > )
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF555555),
                size: 26,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة الدواء المطابقة بدقة للصورة
  Widget _buildMedicineCard({
    required String title,
    required String line1,
    required String line2,
    required String time,
    required String period,
    required bool isNight,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE4E4E4), // الرمادي الفاتح المطابق لخلفية البطاقة
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCCCCCC), width: 1.0),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. الصف العلوي: اسم الدواء وبجانبه بادج أيقونة الحقنة والزجاجة
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 14),
                // البادج الأبيض مع الأيقونة البرتقالية
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD4D4D4), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.vaccines,
                      color: Color(0xFFE64A19), // برتقالي مائل للأحمر مطابق للصورة
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. التعليمات في المنتصف باللون الأزرق الداكن / البترولي
          Text(
            line1, // "حبة واحدة"
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0C5365), // كحلي بترولي داكن مطابق للصورة
              height: 1.25,
            ),
          ),
          Text(
            line2, // "بعد الفطور" أو "بعد العشاء"
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0C5365),
              height: 1.25,
            ),
          ),

          const SizedBox(height: 20),

          // 3. شريط التوقيت السفلي بلونه البيج: "كل يوم" على اليسار، والأيقونة بالمنتصف، و "8:00" على اليمين
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE4DCD2), // لون بيج مطابق للصورة تماماً
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF9E9E9E), width: 1.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // اليسار: "كل يوم"
                  Text(
                    period,
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  // المنتصف: شمس صباحاً ☀️ أو هلال مساءً 🌙
                  Icon(
                    isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    color: isNight ? const Color(0xFF274A78) : const Color(0xFFD49000),
                    size: 28,
                  ),

                  // اليمين: التوقيت "8:00"
                  Text(
                    time,
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
