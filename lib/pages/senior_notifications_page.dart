import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// الشاشة: "التنبيهات تساعدك وتساعد عائلتك" (iPhone 13 & 14 - 36)
class SeniorNotificationsPage extends StatelessWidget {
  const SeniorNotificationsPage({super.key});

  static const Color backgroundColor = Color(0xFFF7F5EE);
  static const Color primaryTeal = Color(0xFF125D73);
  static const Color cardBgColor = Color(0xFFDCE6E7);
  static const Color cardBorderColor = Color(0xFFA8C4C6);
  static const Color iconGreen = Color(0xFF267364);
  static const Color textDark = Color(0xFF1E232A);

  void _onEnableNotifications(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    Navigator.pushNamed(context, '/senior-location', arguments: args);
  }

  void _onLater(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    Navigator.pushNamed(context, '/senior-location', arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),

                    // العنوان الرئيسي
                    Text(
                      'التنبيهات تساعدك وتساعد عائلتك',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 22.5,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),

                    const SizedBox(height: 35),

                // بطاقة التنبيهات المظللة مع الأيقونة والنقاط
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 32.0),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cardBorderColor,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // أيقونة جرس التنبيهات النشط
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: iconGreen,
                        size: 48,
                      ),

                      const SizedBox(height: 34),

                      // النقطة الأولى
                      _buildBulletRow('تذكير بوقت الأدوية في موعدها المحدد'),

                      const SizedBox(height: 24),

                      // النقطة الثانية
                      _buildBulletRow('اطمئنان سريع وتفقد دوري من عائلتك'),

                      const SizedBox(height: 24),

                      // النقطة الثالثة
                      _buildBulletRow('رسائل وتحديثات مباشرة من عائلتك'),
                    ],
                  ),
                ),

                const Spacer(),

                // زر تفعيل التنبيهات (الزر الأساسي)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _onEnableNotifications(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'تفعيل التنبيهات',
                      style: GoogleFonts.cairo(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // زر لاحقاً (الزر الثانوي المفرغ)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => _onLater(context),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(
                        color: primaryTeal,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'لاحقا',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryTeal,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // زر الرجوع في الجهة اليسرى
          Positioned(
            left: 16,
            top: 8,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: primaryTeal,
                size: 26,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildBulletRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // النقطة الخضراء الدائرية
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: iconGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        // النص بجانب النقطة
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: textDark,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
