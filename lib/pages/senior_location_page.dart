import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/auth_service.dart';

/// الشاشة: "السماح بإستخدام الموقع" (iPhone 13 & 14 - 48)
class SeniorLocationPage extends StatelessWidget {
  const SeniorLocationPage({super.key});

  static const Color backgroundColor = Color(0xFFF7F5EE);
  static const Color primaryTeal = Color(0xFF125D73);
  static const Color cardBgColor = Color(0xFFDCE6E7);
  static const Color cardBorderColor = Color(0xFFA8C4C6);
  static const Color iconGreen = Color(0xFF267364);
  static const Color textDark = Color(0xFF1E232A);

  Future<void> _onEnableLocation(BuildContext context) async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final role = args?['role'] ?? 'senior';
    final mode = args?['mode'] ?? 'advanced';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('senior_location_allowed', true);
      await prefs.setString('senior_mode', mode);
      await prefs.setBool('senior_setup_done', true);
      final uid = AuthService().userId;
      if (uid != null) {
        await prefs.setString('senior_mode_$uid', mode);
        await prefs.setBool('senior_setup_done_$uid', true);
      }
    } catch (_) {}

    if (!context.mounted) return;

    final targetRoute = role == 'senior'
        ? (mode == 'simple' ? '/simple-home' : '/home-elderly')
        : '/main-caregiver';

    Navigator.pushNamedAndRemoveUntil(
      context,
      targetRoute,
      (route) => false,
    );
  }

  Future<void> _onLater(BuildContext context) async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final role = args?['role'] ?? 'senior';
    final mode = args?['mode'] ?? 'advanced';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('senior_location_allowed', false);
      await prefs.setString('senior_mode', mode);
      await prefs.setBool('senior_setup_done', true);
      final uid = AuthService().userId;
      if (uid != null) {
        await prefs.setString('senior_mode_$uid', mode);
        await prefs.setBool('senior_setup_done_$uid', true);
      }
    } catch (_) {}

    if (!context.mounted) return;

    final targetRoute = role == 'senior'
        ? (mode == 'simple' ? '/simple-home' : '/home-elderly')
        : '/main-caregiver';

    Navigator.pushNamedAndRemoveUntil(
      context,
      targetRoute,
      (route) => false,
    );
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
                      'السماح بإستخدام الموقع',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),

                    const SizedBox(height: 35),

                // بطاقة إذن الموقع المظللة مع الأيقونة والنقاط
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
                      // أيقونة الموقع الجغرافي
                      const Icon(
                        Icons.location_on_rounded,
                        color: iconGreen,
                        size: 50,
                      ),

                      const SizedBox(height: 34),

                      // النقطة الأولى
                      _buildBulletRow('يتم استخدام موقعك عند الحاجة فقط'),

                      const SizedBox(height: 24),

                      // النقطة الثانية
                      _buildBulletRow('لن يتم مشاركة موقعك مع اي جهة بدون اذنك'),

                      const SizedBox(height: 24),

                      // النقطة الثالثة
                      _buildBulletRow('يمكنك ايقاف او تغيير الإذن في أي وقت'),
                    ],
                  ),
                ),

                const Spacer(),

                // زر تفعيل الموقع (الزر الأساسي)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => _onEnableLocation(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'تفعيل الموقع',
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
              fontSize: 14.2,
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
