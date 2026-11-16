import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';

/// شاشة اختيار الوضع: الوضع البسيط أم الوضع المتقدم لكبير السن
class ChooseModePage extends StatefulWidget {
  const ChooseModePage({super.key});

  @override
  State<ChooseModePage> createState() => _ChooseModePageState();
}

class _ChooseModePageState extends State<ChooseModePage> {
  // 0 = الوضع البسيط, 1 = الوضع المتقدم (افتراضياً الوضع البسيط مطابق للصورة 77)
  int selectedMode = 0;

  Future<void> _onContinue() async {
    final modeStr = selectedMode == 0 ? 'simple' : 'advanced';
    
    // حفظ الوضع المختار وإعدادات المستخدم في التخزين الدائم
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('senior_mode', modeStr);
      final uid = AuthService().userId;
      if (uid != null) {
        await prefs.setString('senior_mode_$uid', modeStr);
        await prefs.setBool('senior_setup_done_$uid', true);
      }
      await prefs.setBool('senior_location_allowed', true);
      await prefs.setBool('senior_notifications_allowed', true);
    } catch (_) {}

    if (!mounted) return;

    // إذا كان المستخدم قد سجل دخوله بالفعل، يتم توجيهه مباشرة لواجهته بدون تكرار شاشات الإعداد
    if (AuthService().isLoggedIn) {
      if (selectedMode == 0) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/simple-home',
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home-elderly',
          (route) => false,
        );
      }
      return;
    }

    // المستخدم لم يسجل دخوله بعد (قادم من شاشة من أنت) -> التوجيه لصفحات التسجيل والإنشاء
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final target = args?['target'];

    if (target == 'register') {
      Navigator.pushNamed(
        context,
        '/register',
        arguments: {'role': 'senior', 'mode': modeStr},
      );
    } else {
      Navigator.pushNamed(
        context,
        '/login',
        arguments: {'role': 'senior', 'mode': modeStr},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 52),

                            // العنوان الرئيسي مطابق للتصميم
                            Text(
                              'اختر الوضع الذي يناسبك',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 38),

                            // الخيار الأول: الوضع البسيط
                            _buildModeOption(
                              index: 0,
                              title: 'الوضع البسيط',
                              description:
                                  'أيقونات كبيرة وواجهة مبسطة تعتمد على الصوت والصورة بدون نصوص معقدة',
                            ),
                            const SizedBox(height: 18),

                            // الخيار الثاني: الوضع المتقدم
                            _buildModeOption(
                              index: 1,
                              title: 'الوضع المتقدم',
                              description:
                                  'واجهة مفصلة مع نصوص وإرشادات وإمكانية قراءة تقارير وميزات إضافية',
                            ),

                            const Spacer(),
                            const SizedBox(height: 24),

                            // رابط لدي حساب بالفعل / إنشاء حساب لكبير السن (يختفي إذا كان قد سجل الدخول بالفعل)
                            if (!AuthService().isLoggedIn) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/login',
                                          arguments: {'role': 'senior'});
                                    },
                                    child: Text(
                                      'تسجيل الدخول',
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.mainColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '•',
                                    style: TextStyle(color: Colors.grey.shade400),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/register',
                                          arguments: {'role': 'senior'});
                                    },
                                    child: Text(
                                      'إنشاء حساب لكبير السن',
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.mainColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 12),

                            // زر متابعة
                            ElevatedButton(
                              onPressed: _onContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mainColor,
                                foregroundColor: AppColors.textLight,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'متابعة',
                                style: GoogleFonts.cairo(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // زر الرجوع في الجهة اليسرى (كما في who_are_you_page)
            Positioned(
              left: 16,
              top: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.mainColor,
                  size: 26,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required int index,
    required String title,
    required String description,
  }) {
    final isSelected = selectedMode == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMode = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.mainColor : AppColors.cardBorderColor,
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.mainColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.mainColor : AppColors.dotInactive,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
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
}
