import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../shard/appointment_item.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/senior_manager.dart';
import 'ai_page.dart';
import 'past_dates.dart';
import 'add_date.dart';

class DatesScreen extends StatefulWidget {
  const DatesScreen({super.key});

  @override
  State<DatesScreen> createState() => _DatesScreenState();
}

// الاسم البديل للتوافق
typedef AppointmentsScreen = DatesScreen;

class _DatesScreenState extends State<DatesScreen> {
  List<AppointmentItem> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final int? seniorId = AuthService().isSenior
          ? AuthService().userId
          : int.tryParse(SeniorManager().currentSenior.id);

      final list = await ApiService.instance.getAppointments(elderlyId: seniorId);
      final items = <AppointmentItem>[];
      for (final a in list) {
        final timeRaw = (a['A_Time'] ?? 'غير محدد').toString();
        final timeFormatted = timeRaw.length >= 5 ? timeRaw.substring(0, 5) : timeRaw;
        items.add(AppointmentItem(
          id: a['Appointment_ID']?.toString(),
          title: a['A_DateType'] ?? 'موعد',
          day: a['A_Date'] ?? 'قريباً',
          time: timeFormatted,
          date: a['A_Date']?.toString(),
          notes: a['A_Note']?.toString(),
        ));
      }
      if (mounted) {
        setState(() {
          _appointments = items;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل المواعيد. يرجى التأكد من اتصال الخادم والإنترنت.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // الانتقال لصفحة إضافة موعد جديد
  void _navigateToAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDateScreen()),
    );
    if (result != null) {
      await _loadAppointments();
    }
  }

  // دالة حذف الموعد مع نافذة تأكيد
  void _deleteAppointment(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: cardBorderColor, width: 1.2),
        ),
        title: Text(
          'حذف الموعد',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: const Color(0xFFE53935),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذا الموعد؟',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'تراجع',
              style: GoogleFonts.tajawal(
                color: Colors.grey[700],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final item = _appointments[index];
              Navigator.pop(ctx);
              setState(() {
                _appointments.removeAt(index);
              });
              if (item.id.isNotEmpty && int.tryParse(item.id) != null) {
                try {
                  await ApiService.instance.deleteAppointment(int.parse(item.id));
                } catch (_) {}
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حذف الموعد بنجاح',
                      style: GoogleFonts.tajawal(fontSize: 16),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              'حذف',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة تعديل الموعد
  void _editAppointment(int index) {
    final item = _appointments[index];
    final titleController = TextEditingController(text: item.title);
    final dayController = TextEditingController(text: item.day);
    final timeController = TextEditingController(text: item.time);

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
          'تعديل الموعد',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: appbarColor,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(ctx).size.width * 0.92,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'اسم الزيارة',
                    labelStyle: GoogleFonts.tajawal(
                      color: appbarColor,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: 'مثال: موعد مشفى',
                    hintStyle: GoogleFonts.tajawal(fontSize: 18),
                    filled: true,
                    fillColor: backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: cardBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: appbarColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dayController,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'يوم الزيارة',
                    labelStyle: GoogleFonts.tajawal(
                      color: iconColor,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: 'مثال: يوم الأحد',
                    hintStyle: GoogleFonts.tajawal(fontSize: 18),
                    filled: true,
                    fillColor: backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: cardBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: iconColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeController,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'ساعة الزيارة',
                    labelStyle: GoogleFonts.tajawal(
                      color: const Color(0xFF526E7A),
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: 'مثال: الساعة 9 صباحاً',
                    hintStyle: GoogleFonts.tajawal(fontSize: 18),
                    filled: true,
                    fillColor: backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: cardBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF526E7A), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(
                color: Colors.grey[700],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appbarColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              final newTitle = titleController.text.trim();
              final newDay = dayController.text.trim();
              final newTime = timeController.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  _appointments[index] = AppointmentItem(
                    title: newTitle,
                    day: newDay.isNotEmpty ? newDay : item.day,
                    time: newTime.isNotEmpty ? newTime : item.time,
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم تعديل الموعد بنجاح',
                      style: GoogleFonts.tajawal(fontSize: 18),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              'حفظ التعديل',
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
              onBack: () => Navigator.maybePop(context),
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
                          // القادمة
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: appbarColor,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'القادمة',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // الماضية
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, anim1, anim2) =>
                                        const PastDatesScreen(),
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
                                  'الماضية',
                                  style: GoogleFonts.tajawal(
                                    color: appbarColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    // قائمة المواعيد
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: appbarColor),
                            )
                          : _appointments.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'لا توجد مواعيد مضافة حالياً',
                                        style: GoogleFonts.tajawal(
                                          color: Colors.grey[700],
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'يمكنك إضافة موعدك الجديد من الزر بالأسفل',
                                        style: GoogleFonts.tajawal(
                                          color: Colors.grey[500],
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  itemCount: _appointments.length,
                                  itemBuilder: (context, index) {
                                    return _buildAppointmentCard(_appointments[index], index);
                                  },
                                ),
                    ),
                    const SizedBox(height: 10),
                    // كارت إضافة موعد جديد
                    GestureDetector(
                      onTap: _navigateToAdd,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorderColor, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'اضافة موعد جديد',
                              style: GoogleFonts.tajawal(
                                color: appbarColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.add,
                              color: appbarColor,
                              size: 28,
                            ),
                          ],
                        ),
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

  // ودجت كارت الموعد مع أزرار التعديل والحذف
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
          // تفاصيل الموعد المقسمة على أسطر مخصصة
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
                // السطر الثاني: يوم الزيارة بلون ثاني
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
                // السطر الثالث: ساعة الزيارة بسطر مستقل ولون مناسب
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
          // أزرار الإجراءات: تعديل وحذف
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: appbarColor,
                  size: 26,
                ),
                onPressed: () => _editAppointment(index),
                tooltip: 'تعديل',
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE53935),
                  size: 26,
                ),
                onPressed: () => _deleteAppointment(index),
                tooltip: 'حذف',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
