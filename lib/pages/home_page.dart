import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// استدعاء ملفات الـ shard بناءً على هيكلية المشروع
import '../shard/color.dart';
import '../core/widgets/elderly_bottom_nav_bar.dart';
import '../core/services/auth_service.dart';
import 'ai_page.dart';
import 'dates.dart';
import 'emergency_page_elderly.dart';
import 'health_page.dart';
import 'medicines_page_elderly.dart';
import 'profile_page_elderly.dart';
import 'return_home_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // دالة عرض نافذة الإشعارات
  void _showNotificationsDialog(BuildContext context) {
    // قائمة الإشعارات (فارغة حالياً حسب المطلوب)
    final List<Map<String, dynamic>> notifications = [];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: cardBorderColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: appbarColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: appbarColor,
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'الإشعارات',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  color: appbarColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (notifications.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardBorderColor, width: 1),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 46,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد إشعارات حالياً',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'سيتم تنبيهك هنا عند وجود أي تذكير بموعد أو دواء',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          color: Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 10,
                              color: appbarColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                notif['text'] ?? '',
                                style: GoogleFonts.tajawal(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appbarColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'حسناً',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appbarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // الجزء العلوي: صورة المستخدم واسمه جهة اليمين، والإشعارات على اليسار
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // جهة اليمين (الصورة مع نص الترحيب) - قابلة للنقر لفتح صفحة الملف الشخصي
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfilePageElderly(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 42,
                            color: appbarColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مرحبا بك',
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              AuthService().userName != null &&
                                      AuthService().userName!.isNotEmpty
                                  ? AuthService().userName!
                                  : 'كبير السن',
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // جهة اليسار (أيقونة الإشعارات)
                  IconButton(
                    onPressed: () => _showNotificationsDialog(context),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                    tooltip: 'الإشعارات',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // جسم الصفحة: كارت حالة اليوم ثابت في الأعلى وبقية العناصر قابلة للتمرير
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. الخلفية المنحنية تبدأ من مسافة 40 نزولاً ليعطي شكل التداخل الأنيق
                  Positioned.fill(
                    top: 40,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                      ),
                    ),
                  ),

                  // 2. المحتوى: الكارت الثابت في الأعلى + باقي الكروت القابلة للتمرير
                  Column(
                    children: [
                      // كارت حالة اليوم (ثابت ولا يتحرك مع التمرير)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18.0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: cardBorderColor,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حالة اليوم',
                                style: GoogleFonts.tajawal(
                                  color: const Color(0xFF4A6572),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF1B6B7A),
                                    size: 38,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'كل الامور جيدة',
                                    style: GoogleFonts.tajawal(
                                      color: Colors.black87,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Text(
                                  'تابع صحتك دائما',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.grey[600],
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // باقي العناصر قابلة للتمرير والسحب
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          child: Column(
                            children: [
                              // مدخل واضح لرمز ربط العائلة بعد تسجيل الدخول
                              InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/senior-link-code',
                                    arguments: {
                                      'mode': 'advanced',
                                      'role': 'senior',
                                      'from': 'home-elderly',
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF125D73),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.link_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'رمز ربط العائلة',
                                          style: GoogleFonts.tajawal(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // شبكة الخيارات والخدمات (Grid 2x3)
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.98,
                                children: [
                                  _buildGridCard(
                                    title: 'المواعيد',
                                    icon: Icons.calendar_month_outlined,
                                    iconColor: const Color(0xFF1B6B7A),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const DatesScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildGridCard(
                                    title: 'الأدوية',
                                    icon: Icons.medication_liquid_outlined,
                                    iconColor: const Color(0xFF8E24AA),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const MedicinesPageElderly(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildGridCard(
                                    title: 'الموقع',
                                    customIconWidget: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 66,
                                          height: 66,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF1B6B7A,
                                            ).withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF1B6B7A),
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.home_rounded,
                                            size: 40,
                                            color: Color(0xFF1B6B7A),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF1B6B7A),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.location_on_rounded,
                                              size: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ReturnHomePage(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildGridCard(
                                    title: 'الطوارئ',
                                    customIconWidget: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 66,
                                          height: 66,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFE53935),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 8,
                                                offset: Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'SOS',
                                            style: GoogleFonts.tajawal(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 24,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black26,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.person_rounded,
                                              size: 16,
                                              color: Color(0xFFE53935),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const EmergencyPageElderly(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildGridCard(
                                    title: 'المساعد الصوتي',
                                    icon: Icons.mic_rounded,
                                    iconColor: const Color(0xFF7E57C2),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AIPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildGridCard(
                                    title: 'صحتي',
                                    icon: Icons.favorite_rounded,
                                    iconColor: const Color(0xFFE53935),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const HealthPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),
                              const SizedBox(height: 35),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ElderlyBottomNavBar(currentIndex: 0),
    );
  }

  // ودجت بناء الكروت المصغرة داخل الشبكة مع تكبير الأيقونات والخطوط
  Widget _buildGridCard({
    required String title,
    IconData? icon,
    Widget? customIconWidget,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorderColor, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIconWidget != null)
              customIconWidget
            else
              Icon(icon, size: 54, color: iconColor),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.tajawal(
                  color: Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
