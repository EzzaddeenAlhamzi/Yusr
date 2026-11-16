import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../shard/appointment_item.dart';
import 'ai_page.dart';
import 'dates.dart';

class PastDatesScreen extends StatefulWidget {
  const PastDatesScreen({super.key});

  @override
  State<PastDatesScreen> createState() => _PastDatesScreenState();
}

class _PastDatesScreenState extends State<PastDatesScreen> {
  final List<AppointmentItem> _pastAppointments = [
    AppointmentItem(
      title: 'زيارة عائلية',
      day: 'الجمعة الماضي',
      time: 'الساعة 5 مساءً',
    ),
    AppointmentItem(
      title: 'موعد فحص عيون',
      day: 'الثلاثاء الماضي',
      time: 'الساعة 10 صباحاً',
    ),
    AppointmentItem(
      title: 'تجديد رخصة القيادة',
      day: 'الخميس الماضي',
      time: 'الساعة 11 صباحاً',
    ),
    AppointmentItem(
      title: 'حضور مناسبة خاصة',
      day: 'الأحد الماضي',
      time: 'الساعة 8 مساءً',
    ),
  ];

  // دالة حذف الموعد الماضي مع نافذة تأكيد كبيرة وواضحة
  void _deleteAppointment(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorderColor, width: 1.4),
        ),
        title: Text(
          'حذف الموعد',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: const Color(0xFFE53935),
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذا الموعد من السجل؟',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: Colors.black87,
            fontSize: 20,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              'تراجع',
              style: GoogleFonts.tajawal(
                color: Colors.grey[700],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _pastAppointments.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم حذف الموعد بنجاح',
                    style: GoogleFonts.tajawal(fontSize: 18),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'حذف',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
            // الشريط العلوي المخصص من مجلد shard
            CustomTopBar(
              title: 'المواعيد',
              onBack: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, anim1, anim2) => const DatesScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // جسم الصفحة الرئيسي المنحني من مجلد shard
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 22.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // زر التنقل الثنائي (القادمة / الماضية)
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: cardBorderColor, width: 1),
                      ),
                      child: Row(
                        children: [
                          // القادمة (غير محددة في صفحة الماضية)
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, anim1, anim2) =>
                                        const DatesScreen(),
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'القادمة',
                                  style: GoogleFonts.tajawal(
                                    color: appbarColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // الماضية (محددة بلون الـ AppBar)
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: appbarColor,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'الماضية',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // قائمة المواعيد الماضية
                    Expanded(
                      child: _pastAppointments.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 70,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'لا توجد مواعيد سابقة',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 22,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              itemCount: _pastAppointments.length,
                              itemBuilder: (context, index) {
                                return _buildAppointmentCard(
                                  _pastAppointments[index],
                                  index,
                                );
                              },
                            ),
                    ),

                    // زر "اضغط للتحدث"
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
                      child: Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          color: appbarColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AIPage(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'اضغط للتحدث',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Positioned(
                                left: 20,
                                child: Icon(
                                  Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ودجت كارت الموعد مع زر الحذف
  Widget _buildAppointmentCard(AppointmentItem item, int index) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // تفاصيل الموعد
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // السطر الأول: اسم الزيارة
                Text(
                  item.title,
                  style: GoogleFonts.tajawal(
                    color: Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // السطر الثاني: يوم الزيارة بلون ثاني (iconColor)
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.day,
                        style: GoogleFonts.tajawal(
                          color: iconColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // السطر الثالث: ساعة الزيارة بلون ثالث مناسب ومنظم
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: Color(0xFF526E7A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.time,
                        style: GoogleFonts.tajawal(
                          color: const Color(0xFF526E7A),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // زر حذف الموعد
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFE53935),
              size: 26,
            ),
            onPressed: () => _deleteAppointment(index),
            tooltip: 'حذف الموعد',
          ),
        ],
      ),
    );
  }
}
