import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/auth_service.dart';
import '../core/services/local_notification_ids.dart';
import '../core/services/local_notification_service.dart';

/// الشاشة: "التنبيهات تساعدك وتساعد عائلتك" — P2.3 يطلب إذن النظام بصدق.
class SeniorNotificationsPage extends StatefulWidget {
  const SeniorNotificationsPage({super.key});

  @override
  State<SeniorNotificationsPage> createState() => _SeniorNotificationsPageState();
}

class _SeniorNotificationsPageState extends State<SeniorNotificationsPage> {
  static const Color backgroundColor = Color(0xFFF7F5EE);
  static const Color primaryTeal = Color(0xFF125D73);
  static const Color cardBgColor = Color(0xFFDCE6E7);
  static const Color cardBorderColor = Color(0xFFA8C4C6);
  static const Color iconGreen = Color(0xFF267364);
  static const Color textDark = Color(0xFF1E232A);

  bool _busy = false;

  Future<void> _goNext() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (!mounted) return;
    Navigator.pushNamed(context, '/senior-location', arguments: args);
  }

  Future<void> _onEnableNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await LocalNotificationService.instance.initialize();
      final granted =
          await LocalNotificationService.instance.requestPermissionHonest();
      final prefs = await SharedPreferences.getInstance();
      final uid = AuthService().userId;
      if (uid != null) {
        await prefs.setBool('senior_notifications_allowed_$uid', granted);
      }
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لم يُمنح إذن الإشعارات. لن تصل تذكيرات الجهاز حتى تفعّلها من إعدادات النظام.',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFE65100),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تفعيل إذن الإشعارات. ${QuietHoursPolicy.arabicMedExceptionCopy}',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر طلب إذن الإشعارات على هذا الجهاز.',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _goNext();
    }
  }

  Future<void> _onLater() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = AuthService().userId;
    if (uid != null) {
      // Explicit: user deferred — do not claim enabled.
      await prefs.setBool('senior_notifications_allowed_$uid', false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'يمكنك تفعيل التنبيهات لاحقاً من الإعدادات. بدون إذن النظام لن تُجدول تذكيرات الجهاز.',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF546E7A),
        duration: const Duration(seconds: 3),
      ),
    );
    await _goNext();
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 32.0),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorderColor, width: 1.2),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            color: iconGreen,
                            size: 48,
                          ),
                          const SizedBox(height: 34),
                          _buildBulletRow('تذكير بوقت الأدوية في موعدها المحدد'),
                          const SizedBox(height: 24),
                          _buildBulletRow('اطمئنان سريع وتفقد دوري من عائلتك'),
                          const SizedBox(height: 24),
                          _buildBulletRow(QuietHoursPolicy.arabicMedExceptionCopy),
                        ],
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _onEnableNotifications,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
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
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _onLater,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primaryTeal, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'لاحقاً',
                          style: GoogleFonts.cairo(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: primaryTeal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 8, color: iconGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textDark,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
