import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import 'onboarding_screen2.dart';
import 'onboarding_screen3.dart';

/// الشاشة الرئيسية الموحدة للتعريف بالمميزات (Onboarding Flow)
/// مع انتقالات فائقة السلاسة ومؤشر متحرك ثابت
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _onSkip() {
    Navigator.pushNamed(context, '/who-are-you');
  }

  void _onContinue() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pushNamed(context, '/who-are-you');
    }
  }

  void _onLogin() {
    Navigator.pushNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _totalPages - 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // 1. الشريط العلوي: زر الرجوع وزر التخطي مع تأثير ظهور واختفاء ناعم
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // زر الرجوع في اليسار في الاتجاه العربي (يظهر فقط إذا لم نكن في الصفحة الأولى)
                    AnimatedOpacity(
                      opacity: _currentPage > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: IgnorePointer(
                        ignoring: _currentPage == 0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.mainColor,
                            size: 22,
                          ),
                          onPressed: () {
                            if (_currentPage > 0) {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeInOutCubic,
                              );
                            }
                          },
                          tooltip: 'السابق',
                        ),
                      ),
                    ),

                    // زر تخطي السريع في الأعلى
                    AnimatedOpacity(
                      opacity: !isLastPage ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: IgnorePointer(
                        ignoring: isLastPage,
                        child: TextButton(
                          onPressed: _onSkip,
                          child: Text(
                            'تخطي',
                            style: GoogleFonts.cairo(
                              color: AppColors.mainColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. محتوى الصفحات التعريفية القابل للسحب بسلاسة
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  children: [
                    // الشريحة 1: الاطمئنان والمميزات الرئيسية
                    const _OnboardingSlideOne(),

                    // الشريحة 2: المنطقة الآمنة
                    const SafeZoneScreen(
                      isStandalone: false,
                      showControls: false,
                    ),

                    // الشريحة 3: كيفية الاستخدام
                    const HowToUseScreen(
                      isStandalone: false,
                      showControls: false,
                    ),
                  ],
                ),
              ),

              // 3. شريط التحكم السفلي الثابت والموحد لمنع الاهتزاز والقفز
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // مؤشر الصفحات الحديث بنمط كبسولة متمددة وسلسة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      textDirection: TextDirection.ltr,
                      children: List.generate(_totalPages, (index) {
                        final isSelected = _currentPage == index;
                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeInOutCubic,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeInOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isSelected ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.mainColor
                                  : AppColors.mainColor.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    // أزرار التحكم: زر تخطي وزر متابعة بنفس الحجم تماماً
                    Row(
                      children: [
                        // زر تخطي
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _onSkip,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.mainColor,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'تخطي',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mainColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // زر المتابعة الرئيسي بنفس الحجم
                        Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _onContinue,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.mainColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  isLastPage ? 'ابدأ الآن' : 'متابعة',
                                  key: ValueKey<bool>(isLastPage),
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // رابط تسجيل الدخول
                    TextButton(
                      onPressed: _onLogin,
                      child: Text(
                        'لدي حساب بالفعل',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mainColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الشريحة الأولى التعريفية المركزة فقط على المحتوى التوضيحي
class _OnboardingSlideOne extends StatelessWidget {
  const _OnboardingSlideOne();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // الصورة العلوية
          Container(
            height: (size.height * 0.28).clamp(160.0, 230.0),
            width: double.infinity,
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/img/img1.jpg',
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

          const SizedBox(height: 22),

          // العنوان الرئيسي
          Text(
            'ماذا لو كان بإمكانك الاطمئنان عليهم\nدون الحاجة للاتصال',
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
            'يشارك فرد عائلتك موقعه معك، وتابع بكل راحة بال',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 22),

          // بطاقات الميزات الثلاث
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _FeatureItem(
                icon: Icons.location_on,
                title: 'تتبع الموقع\nالمباشر',
              ),
              _FeatureItem(
                icon: Icons.notifications,
                title: 'تنبيهات\nتلقائية',
              ),
              _FeatureItem(
                icon: Icons.medication,
                title: 'تذكيرات\nبالأدوية',
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FeatureItem({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderColor, width: 1.2),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.iconColor.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
