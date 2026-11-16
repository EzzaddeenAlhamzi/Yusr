import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

/// شاشة تحديد الهوية: مقدم الرعاية أم كبير السن
class WhoAreYouPage extends StatefulWidget {
  const WhoAreYouPage({super.key});

  @override
  State<WhoAreYouPage> createState() => _WhoAreYouPageState();
}

class _WhoAreYouPageState extends State<WhoAreYouPage> {
  int selectedOption = 1; // 1 = مقدم الرعاية, 0 = كبير السن

  void _onContinue() {
    if (selectedOption == 0) {
      // إذا اختار المستخدم كبير سن، تكون الصفحة التالية اختيار الوضع
      Navigator.pushNamed(context, '/choose-mode', arguments: {'role': 'senior'});
    } else {
      // مقدم الرعاية يتوجه إلى تسجيل الدخول
      Navigator.pushNamed(context, '/login', arguments: {'role': 'caregiver'});
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
                            const SizedBox(height: 48),

                            // العنوان الرئيسي
                            Text(
                              'من أنت؟',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'اختر نوع حسابك للمتابعة في التطبيق',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 36),

                            // الخيار الأول: أنا كبير السن
                            _buildRoleOption(
                              index: 0,
                              title: 'أنا كبير السن',
                              description:
                                  'عائلتي تريد الاطمئنان علي، سأشارك موقعي وأرسل لهم رمزاً للربط',
                            ),
                            const SizedBox(height: 18),

                            // الخيار الثاني: أنا مقدم الرعاية
                            _buildRoleOption(
                              index: 1,
                              title: 'أنا مقدم الرعاية',
                              description:
                                  'لقد استلمت رمزاً وأريد متابعة والاطمئنان على أحد أحبائي',
                            ),

                            const Spacer(),
                            const SizedBox(height: 24),

                            // رابط لإنشاء حساب أو تسجيل الدخول
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  if (selectedOption == 0) {
                                    // كبير السن يختار الوضع أولاً ثم التسجيل
                                    Navigator.pushNamed(context, '/choose-mode',
                                        arguments: {'role': 'senior', 'target': 'register'});
                                  } else {
                                    Navigator.pushNamed(context, '/register',
                                        arguments: {'role': 'caregiver'});
                                  }
                                },
                                child: Text(
                                  selectedOption == 1
                                      ? 'ليس لديك حساب؟ إنشاء حساب مقدم رعاية'
                                      : 'ليس لديك حساب؟ إنشاء حساب كبير السن',
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.mainColor,
                                  ),
                                ),
                              ),
                            ),
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

            // زر الرجوع في الجهة اليسرى
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

  Widget _buildRoleOption({
    required int index,
    required String title,
    required String description,
  }) {
    final isSelected = selectedOption == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedOption = index;
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
