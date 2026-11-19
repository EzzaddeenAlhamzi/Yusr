import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../shard/color.dart';
import '../shard/custom_header.dart';
import 'ai_page.dart';

class AddDateScreen extends StatefulWidget {
  const AddDateScreen({super.key});

  @override
  State<AddDateScreen> createState() => _AddDateScreenState();
}

// اسم بديل للتوافق
typedef AddAppointmentScreen = AddDateScreen;

class _AddDateScreenState extends State<AddDateScreen> {
  // State variables for inputs
  String _appointmentName = '';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Show dialog to input name with enlarged card size and fonts for seniors
  Future<void> _showNameDialog() async {
    final controller = TextEditingController(text: _appointmentName);
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorderColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'اسم الموعد',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  color: appbarColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                textAlign: TextAlign.right,
                style: GoogleFonts.tajawal(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'اكتب اسم الموعد...',
                  hintStyle: GoogleFonts.tajawal(
                    color: Colors.black38,
                    fontSize: 20,
                  ),
                  filled: true,
                  fillColor: backgroundColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: cardBorderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: cardBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: appbarColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: cardBorderColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'إلغاء',
                          style: GoogleFonts.tajawal(
                            color: Colors.black54,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appbarColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _appointmentName = controller.text.trim());
                          Navigator.pop(context);
                        },
                        child: Text(
                          'موافق',
                          style: GoogleFonts.tajawal(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة تحويل الأرقام إلى أرقام عربية (٠، ١، ٢...)
  String _toArabicDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  // دالة تنسيق التاريخ باللغة العربية بالكامل
  String _formatArabicDate(DateTime date) {
    const arabicMonths = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    const arabicWeekdays = [
      'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'
    ];
    final dayName = arabicWeekdays[date.weekday - 1];
    final monthName = arabicMonths[date.month - 1];
    final dayNumber = _toArabicDigits(date.day.toString());
    final yearNumber = _toArabicDigits(date.year.toString());
    return '$dayName، $dayNumber $monthName $yearNumber';
  }

  // دالة تحويل الوقت إلى نص عربي أنيق وأرقام عربية (مثال: ٠٨:٣٠ صباحاً)
  String _formatArabicTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final hourStr = _toArabicDigits(hour.toString());
    final minuteStr = _toArabicDigits(time.minute.toString().padLeft(2, '0'));
    final period = time.period == DayPeriod.am ? 'صباحاً' : 'مساءً';
    return '$hourStr:$minuteStr $period';
  }

  // Show date picker with customized theme, cardColor, and larger text for seniors
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: appbarColor,
              onPrimary: Colors.white,
              surface: cardColor,
              onSurface: Colors.black87,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: cardColor),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: cardColor,
              headerBackgroundColor: appbarColor,
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: GoogleFonts.tajawal(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              headerHelpStyle: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              dayStyle: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              weekdayStyle: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: appbarColor,
              ),
              yearStyle: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: cardBorderColor, width: 1.2),
              ),
              confirmButtonStyle: ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                foregroundColor: const WidgetStatePropertyAll(appbarColor),
              ),
              cancelButtonStyle: ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                foregroundColor: const WidgetStatePropertyAll(Colors.black54),
              ),
            ),
            textTheme: GoogleFonts.tajawalTextTheme(Theme.of(context).textTheme),
          ),
          child: Localizations.override(
            context: context,
            locale: const Locale('ar'),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // Show time picker with customized theme, cardColor, and larger dial/text for seniors
  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: appbarColor,
              onPrimary: Colors.white,
              surface: cardColor,
              onSurface: Colors.black87,
              secondary: appbarColor,
              onSecondary: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: cardColor),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: cardColor,
              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return appbarColor;
                }
                return backgroundColor;
              }),
              hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return appbarColor;
              }),
              hourMinuteTextStyle: GoogleFonts.tajawal(
                fontSize: 46,
                fontWeight: FontWeight.bold,
              ),
              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return appbarColor;
                }
                return backgroundColor;
              }),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return appbarColor;
              }),
              dayPeriodTextStyle: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              dialBackgroundColor: backgroundColor,
              dialHandColor: appbarColor,
              dialTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return Colors.black87;
              }),
              dialTextStyle: GoogleFonts.tajawal(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              entryModeIconColor: appbarColor,
              helpTextStyle: GoogleFonts.tajawal(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: appbarColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: cardBorderColor, width: 1.2),
              ),
              confirmButtonStyle: ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                foregroundColor: const WidgetStatePropertyAll(appbarColor),
              ),
              cancelButtonStyle: ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                foregroundColor: const WidgetStatePropertyAll(Colors.black54),
              ),
            ),
            textTheme: GoogleFonts.tajawalTextTheme(Theme.of(context).textTheme),
          ),
          child: Localizations.override(
            context: context,
            locale: const Locale('ar'),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // نافذة منبثقة وسط الصفحة: تم حفظ الموعد بنجاح + زر موافق
  Future<void> _showSuccessDialog(String result, Map<String, dynamic> appointmentData) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: cardBorderColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: iconColor,
                  size: 56,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'تم حفظ الموعد بنجاح',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  color: appbarColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor, width: 1),
                ),
                child: Text(
                  result,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    color: Colors.black87,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appbarColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // إغلاق النافذة المنبثقة
                    Navigator.pop(context, appointmentData); // الرجوع لصفحة المواعيد مع الموعد الجديد
                  },
                  child: Text(
                    'موافق',
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
            // الشريط العلوي المخصص من مجلد shard
            CustomTopBar(
              title: 'اضافة موعد جديد',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // جسم الصفحة الرئيسي المنحني من مجلد shard
            Expanded(
              child: CurvedBodyContainer(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          const SizedBox(height: 10),
                          // الأيقونة الدائرية العلوية (أيقونة التقويم مع علامة +)
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cardBorderColor,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.bottomLeft,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.calendar_month,
                                        color: iconColor,
                                        size: 42,
                                      ),
                                    ),
                                    Positioned(
                                      left: 2,
                                      bottom: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(1),
                                        decoration: const BoxDecoration(
                                          color: cardColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add_circle,
                                          color: iconColor,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // نصوص العنوان الفرعي
                          Text(
                            'اضف موعدك',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              color: appbarColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'لنذكرك في الوقت المناسب',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              color: Colors.black54,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 1. كارت اسم الموعد
                          _buildInputCard(
                            title: 'اسم الموعد',
                            subtitle: _appointmentName.isEmpty
                                ? 'مثلا:موعد طبيب او عائلي'
                                : _appointmentName,
                            icon: Icons.edit_note_rounded,
                            onTap: _showNameDialog,
                          ),
                          const SizedBox(height: 10),

                          // 2. كارت التاريخ
                          _buildInputCard(
                            title: 'التاريخ',
                            subtitle: _selectedDate == null
                                ? 'اختر التاريخ'
                                : _formatArabicDate(_selectedDate!),
                            icon: Icons.calendar_month_outlined,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 10),

                          // 3. كارت الوقت
                          _buildInputCard(
                            title: 'الوقت',
                            subtitle: _selectedTime == null
                                ? 'اختر الوقت'
                                : _formatArabicTime(_selectedTime!),
                            icon: Icons.access_time_filled_rounded,
                            onTap: _pickTime,
                          ),
                          const SizedBox(height: 10),

                          // 4. كارت التذكير
                          _buildInputCard(
                            title: 'سنذكرك في هذا الموعد',
                            subtitle: 'قبل الموعد بوقت مناسب',
                            icon: Icons.notifications_rounded,
                            onTap: () {},
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),

                    // زر "حفظ الموعد"
                    GestureDetector(
                      onTap: () async {
                        if (_appointmentName.isEmpty ||
                            _selectedDate == null ||
                            _selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'الرجاء ملء جميع الحقول',
                                style: GoogleFonts.tajawal(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                          return;
                        }
                        final seniorId = AuthService().userId;
                        if (seniorId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'يجب تسجيل الدخول لحفظ الموعد على الخادم',
                                style: GoogleFonts.tajawal(fontSize: 18),
                              ),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }
                        final isoDate =
                            '${_selectedDate!.year.toString().padLeft(4, '0')}-'
                            '${_selectedDate!.month.toString().padLeft(2, '0')}-'
                            '${_selectedDate!.day.toString().padLeft(2, '0')}';
                        final isoTime =
                            '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
                            '${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
                        final res = await ApiService.instance.addAppointment(
                          date: isoDate,
                          time: isoTime,
                          dateType: _appointmentName,
                          location: '',
                          note: '',
                          elderlyId: seniorId,
                        );
                        if (!context.mounted) return;
                        if (res['status'] != 'success') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res['message']?.toString() ??
                                    'تعذّر حفظ الموعد على الخادم',
                                style: GoogleFonts.tajawal(fontSize: 18),
                              ),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }
                        final dateStr = _formatArabicDate(_selectedDate!);
                        final timeStr = _formatArabicTime(_selectedTime!);
                        final result =
                            "$_appointmentName ،\n$dateStr ،الساعة $timeStr";
                        final appointmentData = {
                          'title': _appointmentName,
                          'day': dateStr,
                          'time': 'الساعة $timeStr',
                          'id': res['data']?['Appointment_ID']?.toString() ??
                              res['Appointment_ID']?.toString(),
                          'date': isoDate,
                        };
                        await _showSuccessDialog(result, appointmentData);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: appbarColor,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'حفظ الموعد',
                              style: GoogleFonts.tajawal(
                                color: appbarColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_rounded,
                              color: iconColor,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // زر "اضغط للتحدث"
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
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

  Widget _buildInputCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorderColor, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // النصوص على اليمين
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.tajawal(
                      color: Colors.black45,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // الأيقونة على اليسار
            Icon(
              icon,
              color: iconColor,
              size: 38,
            ),
          ],
        ),
      ),
    );
  }
}
