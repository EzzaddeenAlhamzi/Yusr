import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// الشاشة الثالثة في وضع كبير السن: "تم الربط بنجاح"
class SeniorLinkSuccessPage extends StatelessWidget {
  const SeniorLinkSuccessPage({super.key});

  static const Color backgroundColor = Color(0xFFF7F5EE);
  static const Color primaryTeal = Color(0xFF125D73);
  static const Color successGreen = Color(0xFF267364);
  static const Color textDark = Color(0xFF1E232A);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 70),

                // العنوان الرئيسي
                Text(
                  'تم الربط بنجاح',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),

                const Spacer(flex: 2),

                // دائرة النجاح الخضراء مع علامة الصح البيضاء
                Container(
                  width: 155,
                  height: 155,
                  decoration: const BoxDecoration(
                    color: successGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 90,
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                // النص التوضيحي
                Text(
                  'يمكن لمقدم الرعاية الآن متابعة\nتذكيراتك وحالتك الصحية',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 14.5,
                    color: textMuted,
                    height: 1.6,
                  ),
                ),

                const Spacer(flex: 3),

                // زر التالي (الانتقال للرئيسية)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final args = ModalRoute.of(context)?.settings.arguments
                          as Map<String, dynamic>?;
                      final isSimple = args?['mode'] == 'simple';

                      if (isSimple) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/simple-home',
                          (route) => false,
                        );
                      } else {
                        Navigator.pushNamed(
                          context,
                          '/senior-notifications',
                          arguments: {'role': 'senior'},
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'التالي',
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
