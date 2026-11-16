import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';

/// الشاشة: "ربط الحساب بمقدم الرعاية" وعرض رمز الربط
class SeniorLinkCodePage extends StatefulWidget {
  const SeniorLinkCodePage({super.key});

  static const Color backgroundColor = Color(0xFFF7F5EE);
  static const Color primaryTeal = Color(0xFF125D73);
  static const Color codeBoxColor = Color(0xFFC7D7DA);
  static const Color textDark = Color(0xFF1E232A);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  State<SeniorLinkCodePage> createState() => _SeniorLinkCodePageState();
}

class _SeniorLinkCodePageState extends State<SeniorLinkCodePage> {
  int _remainingSeconds = 60; // دقيقة واحدة فقط
  Timer? _timer;
  bool _isChecking = false;

  String get linkCode {
    final id = AuthService().userId;
    if (id != null && id > 0) {
      return id.toString().padLeft(6, '0');
    }
    return '582416';
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _resetTimer() {
    setState(() {
      _remainingSeconds = 60;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _proceedToSuccess() {
    final args = ModalRoute.of(context)?.settings.arguments;
    Navigator.pushNamed(context, '/senior-link-success', arguments: args);
  }

  /// التحقق من قاعدة البيانات هل تم ربط مقدم الرعاية فعلياً
  Future<void> _checkPairingStatus() async {
    setState(() => _isChecking = true);
    try {
      final myId = AuthService().userId;
      if (myId != null && myId > 0) {
        final elderly = await ApiService.instance.getElderly(myId);
        if (elderly != null && elderly['caregiver'] != null) {
          if (!mounted) return;
          _proceedToSuccess();
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لم يقم مقدم الرعاية بإدخال الرمز بعد في قاعدة البيانات. يمكنك الانتظار أو الضغط على "الربط لاحقاً".',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.white),
          ),
          backgroundColor: SeniorLinkCodePage.primaryTeal,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر التحقق من حالة الربط حالياً، يرجى المحاولة ثانية',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// تخطي عملية الربط والمتابعة بحالة "مقدم الرعاية غير مرتبط"
  void _pairLater() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isSimple = args?['mode'] == 'simple';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم المتابعة - حالة الحساب: مقدم الرعاية غير مرتبط',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        duration: const Duration(seconds: 3),
      ),
    );

    if (isSimple) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/simple-home',
        (route) => false,
      );
    } else {
      Navigator.pushNamed(
        context,
        '/senior-notifications',
        arguments: {'role': 'senior'},
      );
    }
  }

  Future<void> _shareViaWhatsApp(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final text = 'رمز الربط الخاص بي في تطبيق يُسر هو: $linkCode';
    await Clipboard.setData(ClipboardData(text: linkCode));

    final Uri whatsappUri =
        Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final Uri webWhatsappUri =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else if (await canLaunchUrl(webWhatsappUri)) {
        await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت مشاركة الرمز! بانتظار إدخال مقدم الرعاية للرمز للربط الحقيقي.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.white),
          ),
          backgroundColor: SeniorLinkCodePage.primaryTeal,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _shareViaSms(BuildContext sheetContext) async {
    Navigator.pop(sheetContext);
    final text = 'رمز الربط الخاص بي في تطبيق يُسر هو: $linkCode';
    await Clipboard.setData(ClipboardData(text: linkCode));

    final Uri smsUri = Uri(
      scheme: 'sms',
      queryParameters: <String, String>{
        'body': text,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت مشاركة الرمز عبر SMS! بانتظار إدخال مقدم الرعاية للرمز للربط.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: Colors.white),
          ),
          backgroundColor: SeniorLinkCodePage.primaryTeal,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _copyCodeOnly(BuildContext sheetContext) {
    Clipboard.setData(ClipboardData(text: linkCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ الرمز $linkCode بنجاح! بانتظار إدخاله من قبل مقدم الرعاية.',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(color: Colors.white),
        ),
        backgroundColor: SeniorLinkCodePage.primaryTeal,
        duration: const Duration(seconds: 3),
      ),
    );

    Navigator.pop(sheetContext);
  }

  void _onShareCode() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // شريط السحب العلوي
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // عنوان النافذة
                  Text(
                    'مشاركة رمز الربط',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: SeniorLinkCodePage.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اختر وسيلة إرسال الرمز ($linkCode) إلى مقدم الرعاية',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      color: SeniorLinkCodePage.textMuted,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // خيار الواتساب
                  _buildShareOptionItem(
                    title: 'المشاركة عبر واتساب',
                    subtitle: 'إرسال الرمز مباشرة إلى محادثة واتساب',
                    icon: Icons.chat_rounded,
                    iconColor: const Color(0xFF25D366),
                    iconBgColor: const Color(0xFFE8F9EE),
                    onTap: () => _shareViaWhatsApp(bottomSheetContext),
                  ),

                  const SizedBox(height: 12),

                  // خيار الرسائل النصية
                  _buildShareOptionItem(
                    title: 'المشاركة عبر الرسائل النصية (SMS)',
                    subtitle: 'إرسال الرمز كرسالة نصية قصيرة',
                    icon: Icons.sms_rounded,
                    iconColor: const Color(0xFF1E88E5),
                    iconBgColor: const Color(0xFFE3F2FD),
                    onTap: () => _shareViaSms(bottomSheetContext),
                  ),

                  const SizedBox(height: 12),

                  // خيار نسخ الرمز
                  _buildShareOptionItem(
                    title: 'نسخ الرمز فقط',
                    subtitle: 'نسخ الرمز $linkCode إلى الحافظة يدوياً',
                    icon: Icons.copy_rounded,
                    iconColor: SeniorLinkCodePage.primaryTeal,
                    iconBgColor: const Color(0xFFE6EFF1),
                    onTap: () => _copyCodeOnly(bottomSheetContext),
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareOptionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: SeniorLinkCodePage.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: SeniorLinkCodePage.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SeniorLinkCodePage.backgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // العنوان الرئيسي
                    Text(
                      'ربط الحساب بمقدم الرعاية',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: SeniorLinkCodePage.textDark,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // النص التوضيحي
                    Text(
                      'اعط هذا الرمز لمقدم الرعاية ليتمكن\nمن الربط بحسابك',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: SeniorLinkCodePage.textMuted,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 35),

                    // صندوق رمز الربط
                    Container(
                      width: double.infinity,
                      height: 90,
                      decoration: BoxDecoration(
                        color: SeniorLinkCodePage.codeBoxColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: linkCode.split('').map((digit) {
                          return Text(
                            digit,
                            style: GoogleFonts.cairo(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: SeniorLinkCodePage.primaryTeal,
                              letterSpacing: 2,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // انتهاء الرمز
                    Text(
                      'سينتهي الرمز خلال',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        color: SeniorLinkCodePage.textMuted,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // المؤقت الزمني (دقيقة واحدة)
                    Text(
                      _formattedTime,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds > 0
                            ? SeniorLinkCodePage.primaryTeal
                            : Colors.red.shade700,
                      ),
                    ),

                    if (_remainingSeconds == 0) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _resetTimer,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          'تحديث الرمز والمؤقت',
                          style: GoogleFonts.cairo(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    // أزرار الإجراءات
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isChecking ? null : _checkPairingStatus,
                        icon: _isChecking 
                            ? const SizedBox(
                                width: 18, 
                                height: 18, 
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: Text(
                          _isChecking ? 'جارٍ التحقق...' : 'التحقق من اكتمال الربط',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SeniorLinkCodePage.primaryTeal,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _onShareCode,
                        icon: const Icon(Icons.share_rounded, color: SeniorLinkCodePage.primaryTeal),
                        label: Text(
                          'مشاركة الرمز',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: SeniorLinkCodePage.primaryTeal,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: SeniorLinkCodePage.primaryTeal),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: TextButton(
                        onPressed: _pairLater,
                        child: Text(
                          'الربط لاحقاً (تخطي)',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            decoration: TextDecoration.underline,
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
                    color: SeniorLinkCodePage.primaryTeal,
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
}
