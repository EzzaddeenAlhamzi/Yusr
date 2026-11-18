import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/senior_manager.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _relationshipController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String _selectedGender = 'ذكر';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _nameHasError = false;
  bool _phoneHasError = false;
  bool _emailHasError = false;
  bool _passwordHasError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _relationshipController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final relationship = _relationshipController.text.trim();
    final password = _passwordController.text.trim();

    final bool emailValid = email.isEmpty || RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\-]+').hasMatch(email);

    setState(() {
      _nameHasError = name.isEmpty;
      _phoneHasError = phone.isEmpty && email.isEmpty;
      _emailHasError = !emailValid;
      _passwordHasError = password.isEmpty;
    });

    if (name.isEmpty || (phone.isEmpty && email.isEmpty) || password.isEmpty || _emailHasError) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final role = args?['role'] ?? 'caregiver';

    try {
      if (role == 'caregiver') {
        final res = await ApiService.instance.registerCaregiver(
          name: name,
          phone: phone,
          email: email,
          password: password,
          relationship: relationship.isNotEmpty ? relationship : 'مقدم رعاية',
        );

        if (!mounted) return;

        if (res['status'] == 'success') {
          final caregiver = res['caregiver'];
          final caregiverId =
              int.tryParse(caregiver['Caregivers_ID']?.toString() ?? '') ?? 0;
          await AuthService().prepareForUserSwitch(
            newRole: 'caregiver',
            newUserId: caregiverId,
          );
          AuthService().setCaregiverSession(
            id: caregiverId,
            name: name,
            phone: phone,
            email: email,
            linkedElderlyId: null,
          );
          Navigator.pushNamed(context, '/link-senior');
        } else {
          final errorMsg = res['message']?.toString() ?? 'فشل إنشاء الحساب';
          final alreadyExists = errorMsg.contains('مسجل بالفعل');
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
                      onPressed: _onRegister,
                    )
                  : (alreadyExists
                      ? SnackBarAction(
                          label: 'تسجيل الدخول',
                          textColor: Colors.white,
                          onPressed: () => Navigator.pushNamed(context, '/login', arguments: {'role': 'caregiver'}),
                        )
                      : null),
            ),
          );
        }
      } else {
        final res = await ApiService.instance.registerElderly(
          name: name,
          phone: phone,
          email: email,
          password: password,
          sex: _selectedGender,
        );

        if (!mounted) return;

        if (res['status'] == 'success') {
          final elderly = res['elderly'];
          final seniorIdInt =
              int.tryParse(elderly['Eldery_ID']?.toString() ?? '') ?? 0;
          await AuthService().prepareForUserSwitch(
            newRole: 'senior',
            newUserId: seniorIdInt,
          );
          AuthService().setSeniorSession(
            id: seniorIdInt,
            name: name,
            phone: phone,
            email: email,
          );
          await SeniorManager().fetchSeniorsFromDatabase();
          final prefs = await SharedPreferences.getInstance();
          if (!mounted) return;
          final seniorId = elderly['Eldery_ID']?.toString() ?? '';
          final savedMode =
              seniorId.isEmpty ? null : prefs.getString('senior_mode_$seniorId');
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
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/choose-mode',
              (route) => false,
            );
          }
        } else {
          final errorMsg = res['message']?.toString() ?? 'فشل إنشاء الحساب';
          final alreadyExists = errorMsg.contains('مسجل بالفعل');
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
                      onPressed: _onRegister,
                    )
                  : (alreadyExists
                      ? SnackBarAction(
                          label: 'تسجيل الدخول',
                          textColor: Colors.white,
                          onPressed: () => Navigator.pushNamed(context, '/login', arguments: {'role': 'senior'}),
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
            content: Text('خطأ أثناء إنشاء الحساب: $e', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final role = args?['role'] ?? 'caregiver';
    final isSenior = role == 'senior';

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
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                              isSenior ? 'إنشاء حساب كبير السن' : 'إنشاء حساب جديد',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'أهلاً بك معنا في تطبيق يُسر',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // حقل الاسم
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'الاسم كامل',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _nameHasError
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
                              controller: _nameController,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.cairo(fontSize: 14),
                              onChanged: (_) {
                                if (_nameHasError) {
                                  setState(() => _nameHasError = false);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'أدخل اسمك الكامل',
                                fillColor: _nameHasError
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
                                    color: _nameHasError
                                        ? Colors.red.shade700
                                        : AppColors.cardBorderColor,
                                    width: _nameHasError ? 1.5 : 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _nameHasError
                                        ? Colors.red.shade700
                                        : AppColors.mainColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // حقل رقم الهاتف
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'رقم الهاتف',
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
                              keyboardType: TextInputType.phone,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.cairo(fontSize: 14),
                              onChanged: (_) {
                                if (_phoneHasError) {
                                  setState(() => _phoneHasError = false);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: '05xxxxxxxx',
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
                            const SizedBox(height: 16),

                            // حقل البريد الإلكتروني (للتواصل واستعادة كلمة المرور)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'البريد الإلكتروني',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _emailHasError
                                        ? Colors.red.shade700
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  ' (للتواصل عند نسيان كلمة المرور)',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.cairo(fontSize: 14),
                              onChanged: (_) {
                                if (_emailHasError) {
                                  setState(() => _emailHasError = false);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'example@email.com',
                                prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.mainColor),
                                fillColor: _emailHasError
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
                                    color: _emailHasError
                                        ? Colors.red.shade700
                                        : AppColors.cardBorderColor,
                                    width: _emailHasError ? 1.5 : 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _emailHasError
                                        ? Colors.red.shade700
                                        : AppColors.mainColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (!isSenior) ...[
                              // حقل صلة القرابة (C_Relationship في قاعدة البيانات)
                              Text(
                                'صلة القرابة بكبير السن',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _relationshipController,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.cairo(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'مثال: ابن، ابنة، زوج/ة، حفيد...',
                                  fillColor: AppColors.cardColor,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.cardBorderColor,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.mainColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ] else ...[
                              // اختيار الجنس لكبير السن
                              Text(
                                'الجنس',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _selectedGender = 'ذكر'),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _selectedGender == 'ذكر'
                                              ? AppColors.mainColor.withValues(alpha: 0.12)
                                              : AppColors.cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _selectedGender == 'ذكر'
                                                ? AppColors.mainColor
                                                : AppColors.cardBorderColor,
                                            width: _selectedGender == 'ذكر' ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.male,
                                              color: _selectedGender == 'ذكر'
                                                  ? AppColors.mainColor
                                                  : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'ذكر',
                                              style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.bold,
                                                color: _selectedGender == 'ذكر'
                                                    ? AppColors.mainColor
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _selectedGender = 'أنثى'),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _selectedGender == 'أنثى'
                                              ? AppColors.mainColor.withValues(alpha: 0.12)
                                              : AppColors.cardColor,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _selectedGender == 'أنثى'
                                                ? AppColors.mainColor
                                                : AppColors.cardBorderColor,
                                            width: _selectedGender == 'أنثى' ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.female,
                                              color: _selectedGender == 'أنثى'
                                                  ? AppColors.mainColor
                                                  : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'أنثى',
                                              style: GoogleFonts.cairo(
                                                fontWeight: FontWeight.bold,
                                                color: _selectedGender == 'أنثى'
                                                    ? AppColors.mainColor
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            // حقل كلمة المرور
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
                            const SizedBox(height: 16),

                            // حقل تأكيد كلمة المرور
                            Text(
                              'تأكيد كلمة المرور',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: GoogleFonts.cairo(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                fillColor: AppColors.cardColor,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.textPrimary,
                                    size: 20,
                                  ),
                                  tooltip: _obscureConfirmPassword ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.cardBorderColor,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppColors.mainColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // الموافقة على الشروط
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: () => _showTermsAndConditions(context),
                                  child: Text(
                                    'الشروط والأحكام',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      color: AppColors.mainColor,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.mainColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'أوافق على',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _agreeToTerms,
                                    activeColor: AppColors.mainColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.cardBorderColor,
                                      width: 1.5,
                                    ),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _agreeToTerms = value ?? false;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),
                            const SizedBox(height: 24),

                            // زر إنشاء الحساب
                            ElevatedButton(
                              onPressed: _onRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mainColor,
                                foregroundColor: AppColors.textLight,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'إنشاء الحساب',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // تسجيل الدخول إذا كان لديه حساب
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/login',
                                    arguments: {'role': role},
                                  );
                                },
                                child: Text(
                                  'لدي حساب بالفعل؟ تسجيل الدخول',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.mainColor,
                                  ),
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

  // =========================================================================
  // نص الشروط والأحكام (السطور التي يمكنك كتابة وتعديل الشروط والأحكام فيها)
  // =========================================================================
  static const String _termsAndConditionsText = ''' الشروط والأحكام وسياسة الخصوصية لمنصة "يسر"
تاريخ آخر تحديث: [أدخل التاريخ هنا]
مرحباً بكم في منصة "يسر" للرعاية والعناية بكبار السن. يُرجى قراءة هذه الشروط والأحكام وسياسة الخصوصية بعناية قبل استخدام التطبيق؛ حيث يُعد استخدامك للتطبيق أو تسجيك فيه موافقة صريحة وكاملة على هذه البنود.
أولاً: الشروط والأحكام (Terms of Service)
1. تعريف الخدمة
تطبيق "يسر" هو منصة تقنية تُيسّر التواصل والمتابعة بين كبار السن ومُقدمي الرعاية (المرافقين/العائلة)، من خلال تقديم ميزات تتبع الموقع الجغرافي، التذكير بالمواعيد والأدوية، وسجل النشاطات، وزر بلاغ الطوارئ (SOS).
2. حدود المسؤولية والخدمات الطبية
 ليس بديلاً عن الرعاية الطبية الفورية: منصة "يسر" هي أداة مساعدة وتنظيمية فقط، ولا تُقدم استشارات طبية ولا تُعد بديلاً عن المستشفيات أو فرق الطوارئ الرسمية (مثل الإسعاف).
 إشعارات الطوارئ (SOS): عند استخدام زر الطوارئ، يقوم النظام بإرسال تنبيهات لمُقدمي الرعاية المحددين في حساب كبير السن. التطبيق غير مسؤول عن عدم استجابة المرافقين أو وجود انقطاع في شبكة الاتصال أو الإنترنت لدى أيّ من الأطراف.
3. حسابات المستخدمين والتصريح
 أهلية الاستخدام: يُقر مُقدم الرعاية بأنه يملك التفويض أو الصفة القانونية/العائلية التي تخوله إنشاء إدارة حساب لكبير السن ومتابعة حالته.
 دقة البيانات: يلتزم المستخدمون (كبار السن ومُقدمو الرعاية) بإدخال بيانات صحية وشخصية وأرقام هواتف طوارئ صحيحة ودقيقة، وتحديثها بشكل دوري.
 أمان الحساب: يتحمل المستخدم مسؤولية الحفاظ على سرية معلومات الدخول والرموز السرية الخاصة بحسابه.
4. الاستخدام المقبول
يُحظر استخدام التطبيق في أي أغراض غير قانونية، أو تجسسية، أو تتبع أشخاص دون موافقتهم الصريحة والتفويض القانوني اللازم.
ثانياً: سياسة الخصوصية وحماية البيانات (Privacy Policy)
1. البيانات التي نجمعها
لتقديم خدماتنا بكفاءة، نجمع البيانات التالية بموافقتك:
 المعلومات الشخصية: الاسم، العمر، صلة القرابة، ومعلومات الاتصال.
 البيانات الصحية واليومية: السجلات الصحية المدخلة (مثل الضغط والسكر)، جداول الأدوية، والملاحظات اليومية.
 بيانات الموقع الجغرافي (GPS): نجمع ونعالج بيانات الموقع الدقيق لكبير السن (حتى في الخلفية) لتفعيل ميزات "التتبع المباشر" و"المنطقة الآمنة (Geofencing)".
 بيانات الجهاز والاستخدام: سجلات الأعطال، ونوع الجهاز، ونظام التشغيل لتحسين أداء التطبيق.
2. كيفية استخدام البيانات
نستخدم البيانات للغايات التالية حصراً:
 تمكين مُقدم الرعاية من متابعة موقع كبير السن وسجل نشاطاته في الوقت الفعلي.
 إرسال التنبيهات والإشعارات الخاصة بالأدوية والمواعيد وبلاغات الطوارئ.
 تحسين استقرار التطبيق وتجربة المستخدم.
3. مشاركة البيانات مع أطراف ثالثة
 لا نبيع البيانات: لن يتم بيع أو تأجير أو مشاركة بياناتك الشخصية أو الصحية مع أي جهات تجارية أو تسويقية.
 مزودو الخدمات: قد نتمشاركة بعض البيانات المفرغة من الهوية مع مزودي الخدمات السحابية وخدمات الإشعارات (مثل خرائط Google وFirebase) لغرض تشغيل التطبيق تقنياً فقط.
 الامتثال القانوني: قد نكشف عن البيانات في حال طلبها بموجب أنظمة وقوانين رسمية من الجهات الحكومية المختصة.
4. حماية البيانات وأمانها
نطبق أعلى معايير الأمان والتشفير (مثل تشفير البيانات أثناء النقل التخزين) لحماية بياناتك من الوصول غير المصرح به أو التعديل أو الإفصاح.
5. حقوق المستخدم
يحق للمستخدم في أي وقت:
 الطلب والاطلاع على البيانات المخزنة عنه.
 تعديل أو تصحيح البيانات غير الدقيقة.
 طلب حذف الحساب وكافة البيانات المرتبطة به نهائياً من سيرفراتنا.
ثالثاً: التواصل والاستفسارات
إذا كان لديك أي استفسار حول سياسة الخصوصية أو الشروط والأحكام، يمكنك التواصل مع فريق الدعم الفني عبر البريد الإلكتروني:
support@yusr-app.com ''';

  void _showTermsAndConditions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.backgroundColor,
          title: Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: AppColors.mainColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'الشروط والأحكام',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              _termsAndConditionsText,
              textAlign: TextAlign.right,
              style: GoogleFonts.cairo(
                fontSize: 13,
                height: 1.8,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إغلاق',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _agreeToTerms = true);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'أوافق على الشروط',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

