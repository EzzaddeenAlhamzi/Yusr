import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/senior_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _phoneHasError = false;
  bool _passwordHasError = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _phoneHasError = phone.isEmpty;
      _passwordHasError = password.isEmpty;
    });

    if (phone.isEmpty || password.isEmpty) {
      return;
    }

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final role = args?['role'] ?? 'caregiver';

    setState(() => _isLoading = true);

    try {
      if (role == 'senior') {
        // التحقق من جدول كبار السن elderly في قاعدة البيانات
        final res = await ApiService.instance.loginElderly(
          phone: phone,
          password: password,
        );
        if (!mounted) return;

        if (res['status'] == 'success') {
          final elderly = res['elderly'];
          final rawName = elderly['E_Name']?.toString().trim() ?? '';
          final validName = (rawName.isEmpty || RegExp(r'^[\?\s]+$').hasMatch(rawName)) ? 'كبير السن' : rawName;
          AuthService().setSeniorSession(
            id: elderly['Eldery_ID'] ?? 0,
            name: validName,
            phone: elderly['E_PhonNumber'] ?? phone,
            email: elderly['E_Email'],
          );
          await SeniorManager().fetchSeniorsFromDatabase();
          if (!mounted) return;

          // التحقق من الوضع المحفوظ مسبقاً (البسيط أو المتقدم) لتفادي إعادة شاشة اختيار الوضع والموقع والتنبيهات
          final prefs = await SharedPreferences.getInstance();
          if (!mounted) return;
          final seniorId = elderly['Eldery_ID']?.toString() ?? '';
          final savedMode = prefs.getString('senior_mode_$seniorId') ?? prefs.getString('senior_mode');

          if (savedMode == 'simple') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/simple-home',
              (route) => false,
            );
          } else if (savedMode == 'advanced') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home-elderly',
              (route) => false,
            );
          } else {
            // أول تسجيل فقط يُعرض اختيار الوضع
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/choose-mode',
              (route) => false,
            );
          }
        } else {
          final errorMsg = res['message']?.toString() ?? 'لا يوجد حساب مسجل بهذا الرقم في قاعدة البيانات';
          final isNotFound = res['error_type'] == 'user_not_found' || errorMsg.contains('لا يوجد حساب');
          final isConnError = res['is_connection_error'] == true || errorMsg.contains('تعذّر الاتصال') || errorMsg.contains('تعذر الاتصال');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg, style: GoogleFonts.cairo()),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
              action: isConnError
                  ? SnackBarAction(
                      label: 'إعادة المحاولة',
                      textColor: Colors.yellowAccent,
                      onPressed: _onLogin,
                    )
                  : (isNotFound
                      ? SnackBarAction(
                          label: 'إنشاء حساب',
                          textColor: Colors.white,
                          onPressed: () => Navigator.pushNamed(context, '/register', arguments: {'role': 'senior'}),
                        )
                      : null),
            ),
          );
        }
      } else {
        // التحقق من جدول مقدمي الرعاية caregivers في قاعدة البيانات
        final res = await ApiService.instance.loginCaregiver(
          phone: phone,
          password: password,
        );
        if (!mounted) return;

        if (res['status'] == 'success') {
          final caregiver = res['caregiver'];
          final int? linkedId = caregiver['Eldery_ID'] != null ? int.tryParse(caregiver['Eldery_ID'].toString()) : null;
          final rawName = caregiver['C_Name']?.toString().trim() ?? '';
          final validName = (rawName.isEmpty || RegExp(r'^[\?\s]+$').hasMatch(rawName)) ? 'مقدم الرعاية' : rawName;
          AuthService().setCaregiverSession(
            id: caregiver['Caregivers_ID'] ?? 0,
            name: validName,
            phone: caregiver['C_PhonNumber'] ?? phone,
            email: caregiver['C_Email'],
            linkedElderlyId: linkedId,
          );
          await SeniorManager().fetchSeniorsFromDatabase();
          if (!mounted) return;

          // الانتقال المباشر للواجهة الرئيسية بدون عرض صفحات الربط أو الأذونات
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/main-caregiver',
            (route) => false,
          );
        } else {
          final errorMsg = res['message']?.toString() ?? 'لا يوجد حساب مسجل بهذا الرقم في قاعدة البيانات';
          final isNotFound = res['error_type'] == 'user_not_found' || errorMsg.contains('لا يوجد حساب');
          final isConnError = res['is_connection_error'] == true || errorMsg.contains('تعذّر الاتصال') || errorMsg.contains('تعذر الاتصال');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg, style: GoogleFonts.cairo()),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
              action: isConnError
                  ? SnackBarAction(
                      label: 'إعادة المحاولة',
                      textColor: Colors.yellowAccent,
                      onPressed: _onLogin,
                    )
                  : (isNotFound
                      ? SnackBarAction(
                          label: 'إنشاء حساب',
                          textColor: Colors.white,
                          onPressed: () => Navigator.pushNamed(context, '/register', arguments: {'role': 'caregiver'}),
                        )
                      : null),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر الاتصال بالخادم. يرجى التحقق من اتصال الشبكة', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordSheet(BuildContext context, String role) {
    final TextEditingController emailController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(Icons.mark_email_read_outlined,
                          color: AppColors.mainColor, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'استعادة كلمة المرور',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'أدخل بريدك الإلكتروني المسجل، وسيتم التواصل معك لإرسال تعليمات إعادة تعيين كلمة المرور.',
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'example@email.com',
                      prefixIcon: const Icon(Icons.email_outlined,
                          size: 20, color: AppColors.mainColor),
                      fillColor: AppColors.cardColor,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'يرجى إدخال بريد إلكتروني صحيح',
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                              return;
                            }
                            setModalState(() => isSubmitting = true);
                            try {
                              final res = await ApiService.instance.forgotPassword(
                                email: email,
                                role: role,
                              );
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res['message'] ??
                                          'تم استلام طلبك وسيتم التواصل معك عبر البريد الإلكتروني',
                                      style: GoogleFonts.cairo(),
                                    ),
                                    backgroundColor: AppColors.mainColor,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('خطأ: $e', style: GoogleFonts.cairo()),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              }
                            } finally {
                              setModalState(() => isSubmitting = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'إرسال وإتمام التواصل',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final role = args?['role'] ?? 'caregiver';

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 48),

                            // العنوان الرئيسي
                            Text(
                              role == 'senior' ? 'تسجيل دخول كبير السن' : 'تسجيل الدخول',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'مرحباً بعودتك إلى تطبيق يُسر',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 36),

                            // حقل رقم الجوال أو البريد الإلكتروني مع نجمة التحقق
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'رقم الجوال أو البريد الإلكتروني',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _phoneHasError
                                        ? Colors.red.shade700
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  ' *',
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.emailAddress,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.cairo(fontSize: 14),
                              onChanged: (_) {
                                if (_phoneHasError) {
                                  setState(() => _phoneHasError = false);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: '05xxxxxxxx أو البريد الإلكتروني',
                                prefixIcon: const Icon(Icons.person_outline, size: 20, color: AppColors.mainColor),
                                fillColor: _phoneHasError
                                    ? Colors.red.shade50
                                    : AppColors.cardColor,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _phoneHasError
                                        ? Colors.red.shade700
                                        : AppColors.cardBorderColor,
                                    width: _phoneHasError ? 1.5 : 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _phoneHasError
                                        ? Colors.red.shade700
                                        : AppColors.mainColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // حقل كلمة المرور مع نجمة التحقق
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'كلمة المرور',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _passwordHasError
                                        ? Colors.red.shade700
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  ' *',
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: GoogleFonts.cairo(fontSize: 14),
                              onChanged: (_) {
                                if (_passwordHasError) {
                                  setState(() => _passwordHasError = false);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                fillColor: _passwordHasError
                                    ? Colors.red.shade50
                                    : AppColors.cardColor,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.textPrimary,
                                    size: 20,
                                  ),
                                  tooltip: _obscurePassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _passwordHasError
                                        ? Colors.red.shade700
                                        : AppColors.cardBorderColor,
                                    width: _passwordHasError ? 1.5 : 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _passwordHasError
                                        ? Colors.red.shade700
                                        : AppColors.mainColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // نسيت كلمة المرور
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => _showForgotPasswordSheet(context, role),
                                child: Text(
                                  'نسيت كلمة المرور؟',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: AppColors.mainColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(),
                            const SizedBox(height: 24),

                            // زر تسجيل الدخول
                            ElevatedButton(
                              onPressed: _isLoading ? null : _onLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mainColor,
                                foregroundColor: AppColors.textLight,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'تسجيل الدخول',
                                      style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 20),

                            // فاصل أو
                            Row(
                              children: [
                                const Expanded(
                                  child: Divider(
                                    color: AppColors.cardBorderColor,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'أو',
                                    style: GoogleFonts.cairo(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: Divider(
                                    color: AppColors.cardBorderColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // زر إنشاء حساب جديد
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/register', arguments: {'role': role});
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.mainColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: AppColors.mainColor,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                role == 'senior'
                                    ? 'إنشاء حساب جديد لكبير السن'
                                    : 'إنشاء حساب جديد',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // زر الرجوع في الجهة اليسرى
            Positioned(
              left: 16,
              top: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.mainColor,
                  size: 26,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
