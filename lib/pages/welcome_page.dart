import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

/// شاشة الترحيب والشعار (Welcome Screen)
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.00, 0.45, 0.95],
            colors: [
              AppColors.cream,
              AppColors.creamLight,
              AppColors.mainColor,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          // شعار التطبيق في المنتصف
                          Hero(
                            tag: 'app_logo',
                            child: Container(
                              constraints: BoxConstraints(
                                maxHeight: (size.height * 0.40).clamp(200.0, 340.0),
                                maxWidth: (size.width * 0.80).clamp(200.0, 340.0),
                              ),
                              child: Image.asset(
                                'assets/img/yusr-logo.jpeg',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.favorite_rounded,
                                    size: 100,
                                    color: AppColors.mainColor,
                                  );
                                },
                              ),
                            ),
                          ),

                          const Spacer(flex: 3),

                          // نصوص الترحيب والشعار أسفل فوق الزر
                          Column(
                            children: [
                              Text(
                                'معاً نهتم',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'بحياة أفضل لكبارنا',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 24,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // زر ابدأ الآن
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/onboarding');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.cream,
                                foregroundColor: AppColors.mainColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'ابدأ الآن',
                                style: GoogleFonts.cairo(
                                  color: AppColors.mainColor,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

