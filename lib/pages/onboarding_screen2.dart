import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

/// الشاشة الثانية للتعريف - المنطقة الآمنة (Safe Zone Screen)
class SafeZoneScreen extends StatelessWidget {
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;
  final VoidCallback? onAlreadyHaveAccount;
  final bool isStandalone;
  final bool showControls;

  const SafeZoneScreen({
    super.key,
    this.onContinue,
    this.onSkip,
    this.onAlreadyHaveAccount,
    this.isStandalone = true,
    this.showControls = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final content = Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        // مسافة لإبعاد الصورة عن السهم العلوي
                        const SizedBox(height: 38),

                        // الصورة الرئيسية
                        Container(
                          height: (size.height * 0.28).clamp(160.0, 230.0),
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/img/img2.jpg',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.cardColor,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 50,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // مسافة لتنزيل الكلام لوسط الصفحة
                        const SizedBox(height: 24),

                        // العنوان الرئيسي
                        Text(
                          'المنطقة الآمنة لتبقى على اطلاع',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // الوصف
                        Text(
                          'قم بتحديد الأماكن المهمة عندما يغادر أفراد عائلتك أو يصلون للمنزل ستتلقى تنبيهاً فوراً',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),

                        const SizedBox(height: 22),

                        // كرت التنبيه الأول
                        _buildInfoCard(
                          text: 'احصل على إشعار عندما يغادرون المنطقة الآمنة',
                          icon: Icons.warning_amber_rounded,
                        ),

                        const SizedBox(height: 10),

                        // كرت التنبيه الثاني
                        _buildInfoCard(
                          text: 'احصل على إشعار عند الوصول للمنزل بسلام',
                          icon: Icons.check_circle_outline,
                        ),

                        if (showControls) ...[
                          const Spacer(),
                          const SizedBox(height: 16),

                          // رابط تسجيل الدخول
                          TextButton(
                            onPressed: onAlreadyHaveAccount ??
                                () => Navigator.pushNamed(context, '/login'),
                            child: Text(
                              'لدي حساب بالفعل',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mainColor,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // أزرار التحكم
                          Row(
                            children: [
                              // زر متابعة
                              Expanded(
                                child: FilledButton(
                                  onPressed: onContinue ??
                                      () => Navigator.pushNamed(
                                          context, '/who-are-you'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.mainColor,
                                    foregroundColor: AppColors.textLight,
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'متابعة',
                                    style: GoogleFonts.cairo(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // زر تخطي
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: onSkip ??
                                      () => Navigator.pushNamed(
                                          context, '/who-are-you'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.mainColor,
                                    minimumSize: const Size.fromHeight(52),
                                    side: const BorderSide(
                                      color: AppColors.mainColor,
                                      width: 1.6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'تخطي',
                                    style: GoogleFonts.cairo(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // مؤشر النقاط من اليسار إلى اليمين (الصفحة الثانية نشطة في الوسط)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            textDirection: TextDirection.ltr,
                            children: [
                              _buildDot(isActive: false),
                              const SizedBox(width: 6),
                              _buildDot(isActive: true),
                              const SizedBox(width: 6),
                              _buildDot(isActive: false),
                            ],
                          ),

                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (isStandalone) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: content,
      );
    }

    return content;
  }

  Widget _buildInfoCard({required String text, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.iconColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isActive ? 26 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: isActive ? AppColors.mainColor : AppColors.dotInactive,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
