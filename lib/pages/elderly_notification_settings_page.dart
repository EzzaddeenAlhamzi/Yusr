import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/local_notification_ids.dart';
import '../core/services/local_notification_service.dart';
import '../core/widgets/quiet_hours_prefs_section.dart';
import '../shard/color.dart';

/// إعدادات تنبيهات كبير السن — ساعات الهدوء واضحة وقابلة للوصول (P2.3 s08).
class ElderlyNotificationSettingsPage extends StatefulWidget {
  const ElderlyNotificationSettingsPage({super.key});

  @override
  State<ElderlyNotificationSettingsPage> createState() =>
      _ElderlyNotificationSettingsPageState();
}

class _ElderlyNotificationSettingsPageState
    extends State<ElderlyNotificationSettingsPage> {
  bool _busy = false;
  String? _permissionHint;

  Future<void> _requestPermission() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await LocalNotificationService.instance.initialize();
      final granted =
          await LocalNotificationService.instance.requestPermissionHonest();
      if (!mounted) return;
      setState(() {
        _permissionHint = granted
            ? 'إذن النظام مفعّل — يمكن جدولة تذكيرات الجهاز.'
            : 'لم يُمنح إذن الإشعارات. فعّله من إعدادات النظام حتى تصل التذكيرات.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _permissionHint = 'تعذّر طلب إذن الإشعارات على هذا الجهاز.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: appbarColor,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'إعدادات التنبيهات',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text(
                'تذكيرات الدواء والمواعيد',
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E232A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                QuietHoursPolicy.arabicMedExceptionCopy,
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF267364),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              const QuietHoursPrefsSection(),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appbarColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.notifications_active_rounded,
                          color: Colors.white),
                  label: Text(
                    'تفعيل إذن إشعارات النظام',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (_permissionHint != null) ...[
                const SizedBox(height: 12),
                Text(
                  _permissionHint!,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
