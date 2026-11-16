import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../core/widgets/elderly_bottom_nav_bar.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import 'ai_page.dart';
import 'caregiver_page.dart';
import 'dates.dart';
import 'medicines_page_elderly.dart';

class ProfilePageElderly extends StatefulWidget {
  const ProfilePageElderly({super.key});

  @override
  State<ProfilePageElderly> createState() => _ProfilePageElderlyState();
}

class _ProfilePageElderlyState extends State<ProfilePageElderly> {
  // بيانات الملف الشخصي القابلة للتعديل
  String _userName = 'كبير السن';
  String _userAge = 'غير محدد';
  String _bloodType = 'غير محدد';
  String _phoneNumber = '';
  String _email = '';
  String _emergencyName = 'جهة الطوارئ';
  String _emergencyPhone = '997';
  String _caregiverName = 'مقدم الرعاية';
  String _caregiverPhone = '';

  @override
  void initState() {
    super.initState();
    _userName = AuthService().userName ?? 'كبير السن';
    _phoneNumber = AuthService().userPhone ?? '';
    _email = AuthService().userEmail ?? '';
    _loadElderlyDataFromDb();
  }

  Future<void> _loadElderlyDataFromDb() async {
    try {
      final id = AuthService().userId;
      if (id != null) {
        final elderly = await ApiService.instance.getElderly(id);
        if (elderly != null && mounted) {
          setState(() {
            _userName = elderly['E_Name']?.toString() ?? _userName;
            _phoneNumber = elderly['E_PhonNumber']?.toString() ?? _phoneNumber;
            _email = elderly['E_Email']?.toString() ?? _email;
            if (elderly['caregiver'] != null) {
              _caregiverName = elderly['caregiver']['C_Name']?.toString() ?? 'مقدم الرعاية';
              _caregiverPhone = elderly['caregiver']['C_PhonNumber']?.toString() ?? '';
            } else {
              _caregiverName = 'غير مرتبط بمقدم رعاية';
              _caregiverPhone = 'غير مسجل';
            }
          });
        }
        final contacts = await ApiService.instance.getEmergencyContacts(elderlyId: id);
        if (contacts.isNotEmpty && mounted) {
          setState(() {
            _emergencyName = contacts.first['contact_Name']?.toString() ?? _emergencyName;
            _emergencyPhone = contacts.first['Phone_Number']?.toString() ?? _emergencyPhone;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _persistElderlyData() async {
    try {
      final id = AuthService().userId;
      if (id != null) {
        await ApiService.instance.updateElderly(
          elderlyId: id,
          name: _userName,
          sex: 'ذكر',
          phone: _phoneNumber,
        );
        AuthService().setSeniorSession(
          id: id,
          name: _userName,
          phone: _phoneNumber,
        );
      }
    } catch (_) {}
  }

  // دالة إجراء مكالمة هاتفية سريعة
  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
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
              'جاري الاتصال بـ $phoneNumber...',
              style: GoogleFonts.tajawal(fontSize: 16),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // إشعار نجاح الحفظ
  void _showSavedSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: appbarColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // نافذة تعديل حقل نصي فردي (الاسم، العمر، رقم الهاتف)
  void _showEditFieldDialog({
    required String title,
    required String initialValue,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required Function(String) onSave,
  }) {
    final controller = TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: cardBorderColor, width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: appbarColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: appbarColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.tajawal(
                    color: appbarColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: TextField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.tajawal(color: Colors.black38, fontSize: 16),
                filled: true,
                fillColor: backgroundColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: cardBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: appbarColor, width: 2),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.tajawal(
                    color: Colors.black54,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appbarColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    setState(() {
                      onSave(text);
                    });
                    _persistElderlyData();
                    Navigator.pop(ctx);
                    _showSavedSnackBar('تم حفظ التعديل بنجاح');
                  }
                },
                child: Text(
                  'حفظ',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // نافذة تعديل فصيلة الدم
  void _showEditBloodTypeDialog() {
    final bloodTypes = [
      'O+ (موجب)',
      'O- (سالب)',
      'A+ (موجب)',
      'A- (سالب)',
      'B+ (موجب)',
      'B- (سالب)',
      'AB+ (موجب)',
      'AB- (سالب)',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: cardBorderColor, width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bloodtype_rounded,
                    color: Color(0xFFE53935),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'اختيار فصيلة الدم',
                  style: GoogleFonts.tajawal(
                    color: appbarColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: bloodTypes.map((type) {
                    final isSelected = _bloodType == type;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _bloodType = type;
                        });
                        Navigator.pop(ctx);
                        _showSavedSnackBar('تم تحديث فصيلة الدم إلى $type');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? appbarColor.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? appbarColor : cardBorderColor.withValues(alpha: 0.5),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              type,
                              style: GoogleFonts.tajawal(
                                fontSize: 18,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? appbarColor : Colors.black87,
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: appbarColor,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.tajawal(
                    color: Colors.black54,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // نافذة تعديل جهة اتصال الطوارئ (الاسم والرقم)
  void _showEditEmergencyDialog() {
    final nameController = TextEditingController(text: _emergencyName);
    final phoneController = TextEditingController(text: _emergencyPhone);

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: cardBorderColor, width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.contact_phone_rounded,
                    color: Color(0xFFE65100),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'تعديل جهة اتصال الطوارئ',
                  style: GoogleFonts.tajawal(
                    color: appbarColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الاسم أو صلة القرابة',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'مثال: الابن محمد',
                      filled: true,
                      fillColor: backgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: appbarColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'رقم الهاتف',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'مثال: 0509876543',
                      filled: true,
                      fillColor: backgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: appbarColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.tajawal(
                    color: Colors.black54,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appbarColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  final phone = phoneController.text.trim();
                  if (name.isNotEmpty && phone.isNotEmpty) {
                    setState(() {
                      _emergencyName = name;
                      _emergencyPhone = phone;
                    });
                    Navigator.pop(ctx);
                    _showSavedSnackBar('تم تحديث جهة اتصال الطوارئ بنجاح');
                  }
                },
                child: Text(
                  'حفظ',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // نافذة تأكيد تسجيل الخروج
  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تسجيل الخروج',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.red.shade800),
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج من حساب كبير السن؟',
          style: GoogleFonts.tajawal(fontSize: 16),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AuthService().logout();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
                arguments: {'role': 'senior'},
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(
              'تسجيل الخروج',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // نافذة تعديل بيانات مقدم الرعاية
  void _showEditCaregiverDialog() {
    final nameController = TextEditingController(text: _caregiverName);
    final phoneController = TextEditingController(text: _caregiverPhone);

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: cardBorderColor, width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: appbarColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.family_restroom_rounded,
                    color: appbarColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'تعديل بيانات مقدم الرعاية',
                  style: GoogleFonts.tajawal(
                    color: appbarColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اسم مقدم الرعاية',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'مثال: نهى نبيل',
                      filled: true,
                      fillColor: backgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: appbarColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'رقم هاتف مقدم الرعاية',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'مثال: 785145432',
                      filled: true,
                      fillColor: backgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: cardBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: appbarColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.tajawal(
                    color: Colors.black54,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appbarColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () {
                  final name = nameController.text.trim();
                  final phone = phoneController.text.trim();
                  if (name.isNotEmpty && phone.isNotEmpty) {
                    setState(() {
                      _caregiverName = name;
                      _caregiverPhone = phone;
                    });
                    Navigator.pop(ctx);
                    _showSavedSnackBar('تم تحديث بيانات مقدم الرعاية بنجاح');
                  }
                },
                child: Text(
                  'حفظ',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // نافذة سفلية شاملة لتعديل كل بيانات الملف الشخصي معاً
  void _showEditAllSheet() {
    final nameCtrl = TextEditingController(text: _userName);
    final ageCtrl = TextEditingController(text: _userAge);
    final bloodCtrl = TextEditingController(text: _bloodType);
    final phoneCtrl = TextEditingController(text: _phoneNumber);
    final emNameCtrl = TextEditingController(text: _emergencyName);
    final emPhoneCtrl = TextEditingController(text: _emergencyPhone);
    final cgNameCtrl = TextEditingController(text: _caregiverName);
    final cgPhoneCtrl = TextEditingController(text: _caregiverPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: const BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // شريط السحب الرمادي
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تعديل جميع البيانات',
                        style: GoogleFonts.tajawal(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: appbarColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 28, color: Colors.black54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('البيانات الشخصية للمستخدم'),
                        _buildSheetField('الاسم الكامل', nameCtrl, Icons.person_rounded),
                        _buildSheetField('العمر', ageCtrl, Icons.cake_rounded),
                        _buildSheetField('فصيلة الدم', bloodCtrl, Icons.bloodtype_rounded),
                        _buildSheetField('رقم الهاتف', phoneCtrl, Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),

                        _buildSectionHeader('جهة اتصال الطوارئ'),
                        _buildSheetField('اسم جهة الطوارئ', emNameCtrl, Icons.contact_phone_rounded),
                        _buildSheetField('رقم هاتف الطوارئ', emPhoneCtrl, Icons.phone_in_talk_rounded, keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),

                        _buildSectionHeader('مقدم الرعاية / المشرف'),
                        _buildSheetField('اسم مقدم الرعاية', cgNameCtrl, Icons.family_restroom_rounded),
                        _buildSheetField('رقم هاتف مقدم الرعاية', cgPhoneCtrl, Icons.phone_rounded, keyboardType: TextInputType.phone),
                        const SizedBox(height: 24),

                        // زر الحفظ الشامل
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appbarColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () {
                              setState(() {
                                if (nameCtrl.text.trim().isNotEmpty) _userName = nameCtrl.text.trim();
                                if (ageCtrl.text.trim().isNotEmpty) _userAge = ageCtrl.text.trim();
                                if (bloodCtrl.text.trim().isNotEmpty) _bloodType = bloodCtrl.text.trim();
                                if (phoneCtrl.text.trim().isNotEmpty) _phoneNumber = phoneCtrl.text.trim();
                                if (emNameCtrl.text.trim().isNotEmpty) _emergencyName = emNameCtrl.text.trim();
                                if (emPhoneCtrl.text.trim().isNotEmpty) _emergencyPhone = emPhoneCtrl.text.trim();
                                if (cgNameCtrl.text.trim().isNotEmpty) _caregiverName = cgNameCtrl.text.trim();
                                if (cgPhoneCtrl.text.trim().isNotEmpty) _caregiverPhone = cgPhoneCtrl.text.trim();
                              });
                              Navigator.pop(ctx);
                              _showSavedSnackBar('تم حفظ كافة البيانات بنجاح');
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save_rounded, color: Colors.white, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  'حفظ التعديلات',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: GoogleFonts.tajawal(
          color: appbarColor,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSheetField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.tajawal(color: Colors.black54),
          prefixIcon: Icon(icon, color: appbarColor, size: 22),
          filled: true,
          fillColor: cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: cardBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: appbarColor, width: 1.8),
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
            // الشريط العلوي مع زر الرجوع وزر تعديل سريع
            CustomTopBar(
              title: 'الملف الشخصي',
              onBack: () => Navigator.maybePop(context),
              trailing: IconButton(
                icon: const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                tooltip: 'تعديل البيانات',
                onPressed: _showEditAllSheet,
              ),
            ),
            const SizedBox(height: 10),

            // الجسم المنحني الرئيسي
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),

                            // الصورة الشخصية للمستخدم مع إمكانية التعديل
                            Center(
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: appbarColor,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 85,
                                        color: appbarColor,
                                      ),
                                    ),
                                  ),
                                  // زر تعديل الاسم بالضغط على الأيقونة
                                  InkWell(
                                    onTap: () {
                                      _showEditFieldDialog(
                                        title: 'تعديل الاسم الكامل',
                                        initialValue: _userName,
                                        hintText: 'أدخل الاسم الجديد',
                                        icon: Icons.person_rounded,
                                        onSave: (val) => _userName = val,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: iconColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // اسم المستخدم مع زر تعديل
                            InkWell(
                              onTap: () {
                                _showEditFieldDialog(
                                  title: 'تعديل الاسم الكامل',
                                  initialValue: _userName,
                                  hintText: 'أدخل الاسم الجديد',
                                  icon: Icons.person_rounded,
                                  onSave: (val) => _userName = val,
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _userName,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.tajawal(
                                        color: Colors.black87,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.edit_rounded,
                                      color: appbarColor,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // زر صريح لتعديل الملف بالكامل
                            InkWell(
                              onTap: _showEditAllSheet,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: appbarColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: appbarColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit_note_rounded, color: appbarColor, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      'اضغط هنا لتعديل أي من المعلومات',
                                      style: GoogleFonts.tajawal(
                                        color: appbarColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // كارت العمر (قابل للتعديل)
                            _buildEditableInfoCard(
                              icon: Icons.cake_rounded,
                              iconColor: appbarColor,
                              title: 'العمر',
                              value: _userAge,
                              onEditTap: () {
                                _showEditFieldDialog(
                                  title: 'تعديل العمر',
                                  initialValue: _userAge,
                                  hintText: 'مثال: 68 سنة',
                                  icon: Icons.cake_rounded,
                                  onSave: (val) => _userAge = val,
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // كارت فصيلة الدم (قابل للتعديل من قائمة)
                            _buildEditableInfoCard(
                              icon: Icons.bloodtype_rounded,
                              iconColor: const Color(0xFFE53935),
                              title: 'فصيلة الدم',
                              value: _bloodType,
                              onEditTap: _showEditBloodTypeDialog,
                            ),
                            const SizedBox(height: 12),

                             // كارت رقم الهاتف (قابل للتعديل)
                            _buildEditableInfoCard(
                              icon: Icons.phone_android_rounded,
                              iconColor: iconColor,
                              title: 'رقم الهاتف',
                              value: _phoneNumber,
                              onEditTap: () {
                                _showEditFieldDialog(
                                  title: 'تعديل رقم الهاتف',
                                  initialValue: _phoneNumber,
                                  hintText: 'مثال: 0551234567',
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                  onSave: (val) => _phoneNumber = val,
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // كارت البريد الإلكتروني (للتواصل واستعادة كلمة المرور)
                            _buildEditableInfoCard(
                              icon: Icons.email_rounded,
                              iconColor: appbarColor,
                              title: 'البريد الإلكتروني',
                              value: _email.isNotEmpty ? _email : 'غير مسجل (للتواصل واستعادة الحساب)',
                              onEditTap: () {
                                _showEditFieldDialog(
                                  title: 'تعديل البريد الإلكتروني',
                                  initialValue: _email,
                                  hintText: 'example@email.com',
                                  icon: Icons.email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  onSave: (val) => _email = val,
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // كارت جهة اتصال الطوارئ (قابل للتعديل + زر اتصال مباشر)
                            _buildEditableInfoCard(
                              icon: Icons.contact_phone_rounded,
                              iconColor: const Color(0xFFE65100),
                              title: 'جهة اتصال الطوارئ',
                              value: '$_emergencyName ($_emergencyPhone)',
                              onEditTap: _showEditEmergencyDialog,
                              trailingWidget: IconButton(
                                icon: const Icon(
                                  Icons.phone_in_talk_rounded,
                                  color: iconColor,
                                  size: 28,
                                ),
                                onPressed: () => _makeCall(_emergencyPhone),
                                tooltip: 'اتصال سريع بجهة الطوارئ',
                              ),
                            ),
                            const SizedBox(height: 12),

                            // كارت المشرف / ولي الأمر (يعرض الاسم ورقم الهاتف 785145432 وقابل للتعديل)
                            _buildCaregiverCard(),
                            const SizedBox(height: 12),

                            // كارت الأدوية المسجلة
                            _buildNavigationCard(
                              context: context,
                              icon: Icons.medication_rounded,
                              title: 'الأدوية المسجلة',
                              subtitle: 'متابعة أوقات الجرعات والعلب',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MedicinesPageElderly(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // كارت المواعيد والزيارات
                            _buildNavigationCard(
                              context: context,
                              icon: Icons.calendar_month_rounded,
                              title: 'المواعيد والزيارات',
                              subtitle: 'جدول المواعيد القادمة والماضية',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DatesScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // كارت التبديل إلى الوضع البسيط
                            _buildNavigationCard(
                              context: context,
                              icon: Icons.grid_view_rounded,
                              title: 'التبديل إلى الوضع البسيط',
                              subtitle: 'واجهة مبسطة مع أيقونات كبيرة واضحة لكبير السن',
                              onTap: () {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/simple-home',
                                  (route) => false,
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // كارت تسجيل الخروج
                            _buildNavigationCard(
                              context: context,
                              icon: Icons.logout_rounded,
                              title: 'تسجيل الخروج',
                              subtitle: 'تسجيل الخروج من الحساب الحالي لكبير السن',
                              onTap: _showLogoutConfirmDialog,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // زر "اضغط للتحدث" في الأسفل
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
      bottomNavigationBar: const ElderlyBottomNavBar(currentIndex: 2),
    );
  }

  // ودجت كارت المعلومة القابل للتعديل
  Widget _buildEditableInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onEditTap,
    Widget? trailingWidget,
  }) {
    return InkWell(
      onTap: onEditTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      color: Colors.black54,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.tajawal(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              trailingWidget,
              const SizedBox(width: 4),
            ],
            // أيقونة التعديل
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: appbarColor,
                size: 22,
              ),
              onPressed: onEditTap,
              tooltip: 'تعديل $title',
            ),
          ],
        ),
      ),
    );
  }

  // كارت خاص بولي الأمر / مقدم الرعاية يعرض بياناته ورقم الهاتف (785145432)
  Widget _buildCaregiverCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // زر الانتقال إلى صفحة ولي الأمر
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CaregiverPage(
                    caregiverName: _caregiverName,
                    caregiverPhoneNumber: _caregiverPhone,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: appbarColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: appbarColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CaregiverPage(
                      caregiverName: _caregiverName,
                      caregiverPhoneNumber: _caregiverPhone,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        'مقدم الرعاية',
                        style: GoogleFonts.tajawal(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _caregiverPhone,
                          style: GoogleFonts.tajawal(
                            color: iconColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$_caregiverName (متابعة الصحة والتنبيهات)',
                    style: GoogleFonts.tajawal(
                      color: Colors.black54,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // زر تعديل بيانات مقدم الرعاية
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: appbarColor,
              size: 22,
            ),
            onPressed: _showEditCaregiverDialog,
            tooltip: 'تعديل بيانات مقدم الرعاية',
          ),
          const Icon(
            Icons.family_restroom_rounded,
            color: iconColor,
            size: 28,
          ),
        ],
      ),
    );
  }

  // ودجت كارت التنقل للأقسام المساعدة
  Widget _buildNavigationCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: appbarColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: appbarColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      color: Colors.black87,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.tajawal(
                      color: Colors.black54,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              icon,
              color: iconColor,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}
