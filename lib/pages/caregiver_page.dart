import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import 'ai_page.dart';

class CaregiverPage extends StatefulWidget {
  final String? caregiverName;
  final String? caregiverPhoneNumber;

  const CaregiverPage({
    super.key,
    this.caregiverName,
    this.caregiverPhoneNumber,
  });

  @override
  State<CaregiverPage> createState() => _CaregiverPageState();
}

class _CaregiverPageState extends State<CaregiverPage> {
  late String _caregiverName;
  late String _caregiverPhoneNumber;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _caregiverName = widget.caregiverName ?? '';
    _caregiverPhoneNumber = widget.caregiverPhoneNumber ?? '';

    if (_caregiverName.isEmpty && _caregiverPhoneNumber.isEmpty) {
      _loadCaregiverData();
    }
  }

  Future<void> _loadCaregiverData() async {
    setState(() => _isLoading = true);
    try {
      final seniorId = AuthService().userId;
      if (seniorId != null) {
        final elderly = await ApiService.instance.getElderly(seniorId);
        if (mounted && elderly != null) {
          setState(() {
            if (elderly['caregiver'] != null) {
              _caregiverName = elderly['caregiver']['C_Name']?.toString() ?? 'مقدم الرعاية';
              _caregiverPhoneNumber = elderly['caregiver']['C_PhonNumber']?.toString() ?? '';
            } else {
              _caregiverName = 'غير مرتبط بمقدم رعاية';
              _caregiverPhoneNumber = 'غير مسجل';
            }
          });
          return;
        }
      }
      if (mounted) {
        setState(() {
          _caregiverName = 'غير مرتبط بمقدم رعاية';
          _caregiverPhoneNumber = 'غير مسجل';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _caregiverName = 'غير مرتبط بمقدم رعاية';
          _caregiverPhoneNumber = 'غير مسجل';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // دالة إجراء مكالمة هاتفية مع ولي الأمر
  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == 'غير مسجل') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يوجد رقم هاتف مسجل لمقدم الرعاية',
            style: GoogleFonts.tajawal(fontSize: 16),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'جاري الاتصال بـ $phoneNumber...',
              style: GoogleFonts.tajawal(fontSize: 16),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // دالة فتح تطبيق الرسائل النصية SMS
  Future<void> _sendSms(BuildContext context, String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == 'غير مسجل') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لا يوجد رقم هاتف مسجل لمقدم الرعاية',
            style: GoogleFonts.tajawal(fontSize: 16),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final Uri url = Uri(scheme: 'sms', path: phoneNumber);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'جاري فتح الرسائل النصية لـ $phoneNumber...',
              style: GoogleFonts.tajawal(fontSize: 16),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _caregiverName.isNotEmpty ? _caregiverName : 'غير مرتبط بمقدم رعاية';
    final displayPhone = _caregiverPhoneNumber.isNotEmpty ? _caregiverPhoneNumber : 'غير مسجل';

    return Scaffold(
      backgroundColor: appbarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // الشريط العلوي (CustomTopBar) مع عنوان "مقدم الرعاية"
            CustomTopBar(
              title: 'مقدم الرعاية',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // الجسم المنحني الرئيسي
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    // المحتوى القابل للتمرير في الصفحة
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: appbarColor))
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 24),

                                  // الصورة الشخصية (الأيقونة الرمزية لولي الأمر)
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: const BoxDecoration(
                                      color: appbarColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 100,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // اسم ولي الأمر
                                  Text(
                                    displayName,
                                    style: GoogleFonts.tajawal(
                                      color: Colors.black87,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // رقم الهاتف المعروض
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: appbarColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      displayPhone,
                                      style: GoogleFonts.tajawal(
                                        color: appbarColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  if (_caregiverPhoneNumber.isNotEmpty && _caregiverPhoneNumber != 'غير مسجل') ...[
                                    // زر اتصال (خلفية شفافة وحواف بلون التطبيق الأساسي)
                                    _buildActionButton(
                                      title: 'اتصال',
                                      icon: Icons.phone_rounded,
                                      onTap: () => _makePhoneCall(context, displayPhone),
                                    ),
                                    const SizedBox(height: 16),

                                    // زر رسالة نصية SMS (خلفية شفافة وحواف بلون التطبيق الأساسي)
                                    _buildActionButton(
                                      title: 'رسالة نصية SMS',
                                      icon: Icons.chat_bubble_rounded,
                                      onTap: () => _sendSms(context, displayPhone),
                                    ),
                                  ] else ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.link_off_rounded, size: 48, color: Colors.grey.shade600),
                                          const SizedBox(height: 10),
                                          Text(
                                            'لم يتم ربط مقدم رعاية بعد',
                                            style: GoogleFonts.tajawal(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'لا تتوفر أزرار الاتصال أو الرسائل النصية لعدم وجود مقدم رعاية مرتبط بحسابك في قاعدة البيانات.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.tajawal(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                    ),

                    // زر "اضغط للتحدث" في نهاية الصفحة
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
                      child: Container(
                        width: double.infinity,
                        height: 65,
                        decoration: BoxDecoration(
                          color: appbarColor,
                          borderRadius: BorderRadius.circular(20),
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
                          borderRadius: BorderRadius.circular(20),
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
                                  size: 34,
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

  // ودجت لبناء أزرار الإجراءات بخلفية شفافة وإطار وأيقونة بلون التطبيق الأساسي
  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 65,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appbarColor,
          width: 2.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: appbarColor.withValues(alpha: 0.12),
          highlightColor: appbarColor.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    color: appbarColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  icon,
                  color: appbarColor,
                  size: 34,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
