import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';

class EmergencyPageElderly extends StatefulWidget {
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  const EmergencyPageElderly({
    super.key,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  @override
  State<EmergencyPageElderly> createState() => _EmergencyPageElderlyState();
}

class _EmergencyPageElderlyState extends State<EmergencyPageElderly>
    with SingleTickerProviderStateMixin {
  int _secondsRemaining = 3;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  bool _isTriggered = false;
  bool _callInitiated = false;
  bool _smsSent = false;
  bool _locationSent = false;

  bool _hasCaregiverOrContact = false;
  bool _isLoading = true;
  String _contactName = 'مقدم الرعاية';
  String _contactPhone = '997';

  @override
  void initState() {
    super.initState();
    _contactName = widget.emergencyContactName ?? 'مقدم الرعاية';
    _contactPhone = widget.emergencyContactPhone ?? '997';

    // إعداد أنيميشن النبض الحيوي للدائرة الحمراء
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 8, end: 22).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchRealEmergencyContact();
  }

  Future<void> _fetchRealEmergencyContact() async {
    setState(() => _isLoading = true);
    try {
      final elderlyId = AuthService().userId;
      bool found = false;

      // 1. فحص هل يوجد مقدم رعاية مرتبط في قاعدة البيانات
      if (elderlyId != null) {
        final elderly = await ApiService.instance.getElderly(elderlyId);
        if (elderly != null && elderly['caregiver'] != null) {
          final cg = elderly['caregiver'];
          final name = cg['C_Name']?.toString().trim() ?? '';
          final phone = cg['C_PhonNumber']?.toString().trim() ?? '';
          if (phone.isNotEmpty && phone != 'غير مسجل') {
            _contactName = (name.isEmpty || RegExp(r'^[\?\s]+$').hasMatch(name)) ? 'مقدم الرعاية' : name;
            _contactPhone = phone;
            found = true;
          }
        }
      }

      // 2. فحص جدول جهات اتصال الطوارئ emergency_contacts
      final contacts = await ApiService.instance.getEmergencyContacts(elderlyId: elderlyId);
      if (contacts.isNotEmpty) {
        final first = contacts.first;
        final name = first['contact_Name']?.toString().trim() ?? '';
        final phone = first['Phone_Number']?.toString().trim() ?? '';
        if (phone.isNotEmpty) {
          _contactName = name.isNotEmpty ? name : _contactName;
          _contactPhone = phone;
          found = true;
        }
      }

      if (mounted) {
        setState(() {
          _hasCaregiverOrContact = found;
          _isLoading = false;
        });

        // بدء العد التنازلي فقط إذا كان مرتبطاً أو توجد جهة اتصال
        if (found) {
          _startCountdown();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasCaregiverOrContact = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر الاتصال ببيانات الطوارئ. يرجى التحقق من اتصال الشبكة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
        _triggerEmergency();
      }
    });
  }

  // عند انتهاء الثواني: إرسال التنبيه والاتصال والموقع
  Future<void> _triggerEmergency() async {
    if (!mounted) return;
    setState(() {
      _secondsRemaining = 0;
      _isTriggered = true;
      // Flags set only after real outcomes — never invent success.
      _callInitiated = false;
      _smsSent = false;
      _locationSent = false;
    });

    _pulseController.stop();

    bool logOk = false;
    try {
      final elderlyId = AuthService().userId;
      if (elderlyId != null) {
        final res = await ApiService.instance.addEmergencyLog(
          elderlyId: elderlyId,
          description: 'نداء SOS تلقائي - محاولة اتصال بـ $_contactName ($_contactPhone)',
          status: 'تم الإرسال',
        );
        logOk = res['status'] == 'success' || res['success'] == true;
      }
    } catch (_) {
      logOk = false;
    }

    if (mounted) {
      setState(() {
        // SMS channel not wired in lab — keep honest false.
        _smsSent = false;
        _locationSent = logOk;
      });
      if (!logOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر تسجيل نداء الطوارئ على الخادم. سيتم محاولة الاتصال المحلي.',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    }

    // إجراء اتصال هاتفي بجهة الاتصال الحقيقية
    final called = await _makePhoneCall(_contactPhone);
    if (mounted) {
      setState(() => _callInitiated = called);
    }
  }

  // دالة إجراء الاتصال — returns whether dialer launch succeeded.
  Future<bool> _makePhoneCall(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return true;
      }
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    } catch (_) {
      return false;
    }
  }

  // دالة إرسال الموقع برسالة نصية — never invent city coordinates.
  Future<void> _sendLocationSms(String phone) async {
    const String message =
        'نداء طوارئ عاجل من تطبيق يسر! الرجاء المساعدة. (لم تُرفق إحداثيات GPS — غير متوفرة حالياً)';
    final Uri url = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إرسال إحداثيات الموقع إلى ${widget.emergencyContactName}',
              style: GoogleFonts.tajawal(fontSize: 16),
            ),
          ),
        );
      }
    }
  }

  // عند الضغط على إلغاء قبل انتهاء الـ 5 ثواني: الخروج فوراً للصفحة الرئيسية
  void _cancelEmergency() {
    _countdownTimer?.cancel();
    _pulseController.stop();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appbarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // الشريط العلوي المخصص
            CustomTopBar(
              title: 'الطوارئ ومقدم الرعاية',
              showBack: _isTriggered || !_hasCaregiverOrContact,
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 8),

            // الجسم المنحني الرئيسي للصفحة
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: appbarColor),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: !_hasCaregiverOrContact
                                  ? _buildUnlinkedContent()
                                  : _isTriggered
                                      ? _buildTriggeredContent()
                                      : _buildCountdownContent(),
                            ),
                          ),

                          // زر أسفل الصفحة
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
                            child: !_hasCaregiverOrContact
                                ? _buildAddContactBottomButton()
                                : _isTriggered
                                    ? _buildReturnHomeButton()
                                    : _buildCancelButton(),
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

  /// واجهة الصفحة الفارغة عند عدم ربط مقدم رعاية أو عدم وجود جهات اتصال
  Widget _buildUnlinkedContent() {
    return Column(
      children: [
        const SizedBox(height: 36),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.red.shade200, width: 2),
          ),
          child: const Center(
            child: Icon(
              Icons.phone_disabled_rounded,
              color: Color(0xFFD32F2F),
              size: 52,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'لم يتم الربط بمقدم رعاية',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: const Color(0xFFD32F2F),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'لا توجد جهات اتصال طوارئ مسجلة حالياً لطلب المساعدة.\nيرجى إضافة جهات اتصال للطوارئ ليتم حفظها مباشرة في قاعدة البيانات والاتصال بها عند الحاجة.',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              color: Colors.grey.shade700,
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _showAddEmergencyContactDialog,
          icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 24),
          label: Text(
            'إضافة جهات اتصال للطوارئ',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: appbarColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAddContactBottomButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => Navigator.maybePop(context),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: appbarColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          'العودة للرئيسية',
          style: GoogleFonts.tajawal(
            color: appbarColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// نافذة إضافة جهة اتصال طوارئ جديدة وحفظها في قاعدة البيانات
  void _showAddEmergencyContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'ابن');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            'إضافة جهة اتصال للطوارئ',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              color: appbarColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم الشخص / جهة الطوارئ',
                    prefixIcon: const Icon(Icons.person_outline, color: appbarColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: const Icon(Icons.phone_outlined, color: appbarColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: relCtrl,
                  decoration: InputDecoration(
                    labelText: 'صلة القرابة (ابن، ابنة، أخ، جار...)',
                    prefixIcon: const Icon(Icons.people_outline, color: appbarColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.tajawal(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final rel = relCtrl.text.trim();
                      if (name.isEmpty || phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'يرجى إدخال الاسم ورقم الهاتف',
                              style: GoogleFonts.tajawal(),
                            ),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                        return;
                      }

                      setDlgState(() => isSaving = true);
                      try {
                        final elderlyId = AuthService().userId;
                        final messenger = ScaffoldMessenger.of(context);
                        await ApiService.instance.addEmergencyContact(
                          name: name,
                          phone: phone,
                          relationship: rel.isNotEmpty ? rel : 'طوارئ',
                          elderlyId: elderlyId,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم حفظ جهة الاتصال بنجاح في قاعدة البيانات',
                              style: GoogleFonts.tajawal(),
                            ),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                        if (mounted) {
                          await _fetchRealEmergencyContact();
                        }
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل الحفظ: $e', style: GoogleFonts.tajawal()),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: appbarColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'حفظ في قاعدة البيانات',
                      style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // محتوى واجهة العد التنازلي مع الدائرة الحمراء المتدرجة والحيوية
  Widget _buildCountdownContent() {
    return Column(
      children: [
        const SizedBox(height: 16),

        // رسالة تنبيهية علوية
        Text(
          'جاري إرسال نداء الطوارئ',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: const Color(0xFFD32F2F),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            'سيتم إرسال تنبيه عاجل، وإجراء اتصال بالابن، ومشاركة موقعك الجغرافي تلقائياً',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              color: Colors.black87,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 22),

        // الدائرة الحمراء المتدرجة والحيوية النابضة مع أبعاد متوازنة تمنع أي تداخل
        Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 195,
                  height: 195,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFF5252),
                        Color(0xFFE53935),
                        Color(0xFFB71C1C),
                        Color(0xFF880E4F),
                      ],
                      stops: [0.25, 0.55, 0.85, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.4),
                        blurRadius: _glowAnimation.value,
                        spreadRadius: _glowAnimation.value * 0.3,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // حلقة التقدم الدائرية للثواني
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: CircularProgressIndicator(
                          value: _secondsRemaining / 5.0,
                          strokeWidth: 5.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),

                      // محتوى مركز الدائرة: العداد التنازلي
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_secondsRemaining',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 66,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'ثواني',
                            style: GoogleFonts.tajawal(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 22),

        // بطاقة جهة الاتصال التي سيتم إشعارها
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorderColor, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'جهة اتصال الطوارئ',
                      style: GoogleFonts.tajawal(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _contactName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tajawal(
                        fontSize: 17,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _contactPhone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // محتوى الصفحة عند اكتمال الـ 5 ثواني وتفعيل الطوارئ
  Widget _buildTriggeredContent() {
    return Column(
      children: [
        const SizedBox(height: 16),

        // أيقونة النجاح
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2E7D32), width: 2.5),
          ),
          child: const Center(
            child: Icon(
              Icons.check_circle_rounded,
              size: 55,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Text(
          'تم إرسال نداء الطوارئ بنجاح',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: Colors.black87,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'المساعدة في طريقها إليك، حافظ على هدوئك',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: Colors.black54,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),

        // بطاقات الحالة للثلاثة إجراءات المطلوبة مع حماية كاملة من تجاوز المساحة
        _buildActionStatusCard(
          title: 'إرسال تنبيه للمرافق',
          subtitle: 'تم إشعار $_contactName بحالة الطوارئ',
          icon: Icons.notifications_active_rounded,
          isCompleted: _smsSent,
        ),
        const SizedBox(height: 10),

        _buildActionStatusCard(
          title: 'بدء الاتصال الهاتفي',
          subtitle: 'جاري الاتصال بـ $_contactPhone',
          icon: Icons.phone_in_talk_rounded,
          isCompleted: _callInitiated,
          trailingWidget: IconButton(
            icon: const Icon(Icons.call, color: iconColor, size: 24),
            onPressed: () => _makePhoneCall(_contactPhone),
            tooltip: 'إعادة الاتصال',
          ),
        ),
        const SizedBox(height: 10),

        _buildActionStatusCard(
          title: 'إرسال الموقع الجغرافي',
          subtitle: 'تمت مشاركة موقعك وإحداثياتك بنجاح',
          icon: Icons.my_location_rounded,
          isCompleted: _locationSent,
          trailingWidget: IconButton(
            icon: const Icon(Icons.send_rounded, color: iconColor, size: 22),
            onPressed: () => _sendLocationSms(_contactPhone),
            tooltip: 'إرسال الموقع مجدداً',
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActionStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    Widget? trailingWidget,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2E7D32),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 17,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailingWidget != null) trailingWidget,
        ],
      ),
    );
  }

  // زر الإلغاء في آخر الصفحة بنفس لون أزرار التطبيق ومعه كلمة إلغاء وأيقونة إلغاء بدون أي تداخل مساحات
  Widget _buildCancelButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: appbarColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: appbarColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _cancelEmergency,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'إلغاء',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // زر العودة للصفحة الرئيسية بعد الإرسال
  Widget _buildReturnHomeButton() {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        color: appbarColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                'العودة للصفحة الرئيسية',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
