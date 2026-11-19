import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/senior_manager.dart';
import '../services/auth_service.dart';

/// القائمة الجانبية الموحدة والاحترافية لتطبيق يُسر (Navigation Drawer)
class CustomAppDrawer extends StatelessWidget {
  const CustomAppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Drawer(
      width: (screenWidth * 0.84).clamp(290.0, 360.0),
      backgroundColor: AppColors.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // 1. رأس القائمة الجانبية (Header)
            _buildDrawerHeader(context),

            // 2. قائمة الخيارات والتنقل
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('الخدمات الرئيسية'),
                    const SizedBox(height: 6),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.home_rounded,
                      iconColor: AppColors.mainColor,
                      title: 'الرئيسية',
                      subtitle: 'لوحة التحكم ومتابعة الرعاية',
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.people_alt_rounded,
                      iconColor: const Color(0xFF0288D1),
                      title: 'ملفات كبار السن',
                      subtitle: 'البيانات الشخصية والحالة الصحية',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/senior-data');
                      },
                    ),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.watch_rounded,
                      iconColor: const Color(0xFF00897B),
                      title: 'الساعات والأجهزة الذكية',
                      subtitle: 'حالة الاتصال والبطارية والاستشعار',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/devices');
                      },
                    ),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.sos_rounded,
                      iconColor: const Color(0xFFD32F2F),
                      title: 'طوارئ SOS المباشرة',
                      subtitle: 'الاتصال بالإسعاف وأرقام الطوارئ',
                      badge: 'طوارئ',
                      badgeColor: const Color(0xFFD32F2F),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/emergency');
                      },
                    ),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.medication_rounded,
                      iconColor: const Color(0xFF7B1FA2),
                      title: 'جدول الأدوية والجرعات',
                      subtitle: 'مواعيد وتنبيهات الأدوية اليومية',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/medicines');
                      },
                    ),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.calendar_month_rounded,
                      iconColor: const Color(0xFFE65100),
                      title: 'المواعيد والزيارات الطبية',
                      subtitle: 'مواعيد الأطباء والفحوصات',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/appointments');
                      },
                    ),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFF2E7D32),
                      title: 'الموقع المباشر والمناطق الآمنة',
                      subtitle: 'تتبع الموقع الجغرافي ونطاق الأمان',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/location');
                      },
                    ),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.history_rounded,
                      iconColor: const Color(0xFF455A64),
                      title: 'سجل النشاطات اليومية',
                      subtitle: 'ملخص الحركة والفحوصات والمهام',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/activity-log');
                      },
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.cardBorderColor),
                    const SizedBox(height: 12),

                    _buildSectionTitle('الإعدادات والدعم'),
                    const SizedBox(height: 6),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.tune_rounded,
                      iconColor: AppColors.mainColor,
                      title: 'إعدادات التنبيهات',
                      subtitle: 'تخصيص تنبيهات السقوط والطوارئ',
                      onTap: () {
                        Navigator.pop(context);
                        _showNotificationSettingsDialog(context);
                      },
                    ),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.support_agent_rounded,
                      iconColor: const Color(0xFF00ACC1),
                      title: 'المساعدة والدعم الفني',
                      subtitle: 'تواصل مع فريق منصة يُسر',
                      onTap: () {
                        Navigator.pop(context);
                        _showSupportDialog(context);
                      },
                    ),

                    _buildDrawerItem(
                      context: context,
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF5E35B1),
                      title: 'عن تطبيق يُسر',
                      subtitle: 'معلومات الإصدار ورؤية التطبيق',
                      onTap: () {
                        Navigator.pop(context);
                        _showAboutDialog(context);
                      },
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // 3. أسفل القائمة: زر تسجيل الخروج + رقم الإصدار
            _buildDrawerFooter(context),
          ],
        ),
      ),
    );
  }

  // رأس القائمة الجانبية
  Widget _buildDrawerHeader(BuildContext context) {
    return ListenableBuilder(
      listenable: SeniorManager(),
      builder: (context, _) {
        final currentSenior = SeniorManager().currentSenior;
        final totalSeniors = SeniorManager().seniors.length;
        final hasSeniors = SeniorManager().hasSeniors;
        final caregiverName = AuthService().userName ?? 'مقدم الرعاية';

        final topPadding = MediaQuery.of(context).padding.top;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(18, topPadding + 14, 18, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.mainColor,
                Color(0xFF0F5A66),
              ],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // صورة مقدم الرعاية
                  Stack(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 36,
                          color: AppColors.mainColor,
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // بيانات مقدم الرعاية
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          caregiverName,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'مقدم رعاية مسجل',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // شارة كبير السن النشط
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasSeniors
                            ? 'كبير السن النشط: ${currentSenior.relationship} (${currentSenior.name.split(' ').first})'
                            : 'لا يوجد كبير سن مسجل حالياً',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalSeniors ملفات',
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mainColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // عنوان القسم
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // عنصر القائمة الجانبية
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.mainColor.withValues(alpha: 0.08),
          highlightColor: AppColors.mainColor.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // أيقونة بدون خلفية أو ظل ملون
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                // العناوين
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: GoogleFonts.cairo(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? AppColors.mainColor).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor ?? AppColors.mainColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // أسفل القائمة: زر تسجيل الخروج + الإصدار
  Widget _buildDrawerFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.cardBorderColor.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // زر تسجيل الخروج
          Material(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _confirmLogout(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFD32F2F),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'تسجيل الخروج',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD32F2F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // الإصدار
          Text(
            'تطبيق يُسر • الإصدار 1.0.0',
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // نافذة تأكيد تسجيل الخروج
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFD32F2F), size: 24),
              const SizedBox(width: 8),
              Text(
                'تسجيل الخروج',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await AuthService().logout();
                if (!context.mounted) return;
                if (!result.serverRevoked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تسجيل الخروج محلياً. تعذّر تأكيد إلغاء الجلسة على الخادم بسبب الشبكة.',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: Colors.orange.shade800,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
                // Welcome — not caregiver-default /login — so either role can sign in.
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/welcome',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
              ),
              child: Text(
                'خروج',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // نافذة إعدادات التنبيهات
  void _showNotificationSettingsDialog(BuildContext context) {
    bool fallAlert = true;
    bool geofenceAlert = true;
    bool medReminder = true;
    bool loudSos = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.mainColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'إعدادات التنبيهات',
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.mainColor,
                  title: Text('تنبيهات استشعار السقوط',
                      style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  subtitle: Text('إشعار فوري عند رصد سقوط مفاجئ',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
                  value: fallAlert,
                  onChanged: (val) => setDialogState(() => fallAlert = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.mainColor,
                  title: Text('تنبيهات المنطقة الآمنة',
                      style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  subtitle: Text('إشعار عند مغادرة النطاق الجغرافي المحدد',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
                  value: geofenceAlert,
                  onChanged: (val) => setDialogState(() => geofenceAlert = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.mainColor,
                  title: Text('تذكيرات الأدوية',
                      style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  subtitle: Text('تنبيه مقدم الرعاية عند موعد جرعة الدواء',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
                  value: medReminder,
                  onChanged: (val) => setDialogState(() => medReminder = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: const Color(0xFFD32F2F),
                  title: Text('صوت إنذار الطوارئ SOS',
                      style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.bold)),
                  subtitle: Text('تشغيل صوت عالي حتى في الوضع الصامت',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
                  value: loudSos,
                  onChanged: (val) => setDialogState(() => loudSos = val),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم حفظ إعدادات التنبيهات بنجاح',
                        style: GoogleFonts.cairo(color: Colors.white),
                      ),
                      backgroundColor: AppColors.mainColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.mainColor),
                child: Text('حفظ', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // نافذة الدعم الفني
  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: AppColors.mainColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'المساعدة والدعم الفني',
                style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.mainColor),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'فريق دعم منصة يُسر متاح لخدمتكم على مدار الساعة:',
                style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textColor),
              ),
              const SizedBox(height: 12),
              _buildSupportContactRow(Icons.phone_in_talk, 'الهاتف المباشر', '920001234'),
              const SizedBox(height: 8),
              _buildSupportContactRow(Icons.chat_bubble_outline, 'واتساب الدعم', '+966 50 123 4567'),
              const SizedBox(height: 8),
              _buildSupportContactRow(Icons.email_outlined, 'البريد الإلكتروني', 'support@yusr-app.com'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إغلاق', style: GoogleFonts.cairo(color: AppColors.mainColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportContactRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorderColor, width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mainColor),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textColor),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  // نافذة عن التطبيق
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, color: AppColors.mainColor, size: 48),
              const SizedBox(height: 12),
              Text(
                'تطبيق يُسر (Yusr)',
                style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mainColor),
              ),
              Text(
                'الإصدار 1.0.0',
                style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                'منظومة متكاملة لرعاية ومتابعة كبار السن عن بُعد عبر الساعات الذكية والتنبيهات الفورية لحماية أحبائنا أينما كانوا.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textColor, height: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'جميع الحقوق محفوظة © 2026',
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('حسناً', style: GoogleFonts.cairo(color: AppColors.mainColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
