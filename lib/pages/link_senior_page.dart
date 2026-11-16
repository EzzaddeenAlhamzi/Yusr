import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/senior_manager.dart';

class LinkSeniorPage extends StatefulWidget {
  const LinkSeniorPage({super.key});

  @override
  State<LinkSeniorPage> createState() => _LinkSeniorPageState();
}

class _LinkSeniorPageState extends State<LinkSeniorPage> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _showWhereToFindDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorderColor, width: 1),
        ),
        title: Text(
          'أين تجد الرمز؟',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'يظهر رمز الربط المكون من 6 أرقام في شاشة تطبيق كبير السن عند اختيار "أنا كبير السن". يمكنك طلبه منه وإدخاله هنا للربط المباشر.',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainColor,
                foregroundColor: AppColors.textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'حسناً، فهمت',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onLinkAccount() async {
    final code = _controllers.map((c) => c.text).join().trim();
    if (code.isNotEmpty) {
      final parsedId = int.tryParse(code.replaceAll(RegExp(r'[^0-9]'), ''));
      final caregiverId = AuthService().userId;
      if (parsedId != null && parsedId > 0 && caregiverId != null) {
        final res = await ApiService.instance.linkElderly(
          caregiverId: caregiverId,
          elderlyId: parsedId,
        );
        if (res['status'] == 'success') {
          AuthService().linkSenior(parsedId);
          await SeniorManager().fetchSeniorsFromDatabase();
        }
      }
    }
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/main-caregiver',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              'الربط بكبير السن',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'أدخل رمز الربط المرسل من كبير السن المكون من 6 أرقام',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 48),

                            // حقول إدخال الأرقام
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  6,
                                  (index) => SizedBox(
                                    width: 48,
                                    height: 56,
                                    child: TextField(
                                      controller: _controllers[index],
                                      focusNode: _focusNodes[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      style: GoogleFonts.cairo(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        fillColor: AppColors.cardColor,
                                        filled: true,
                                        contentPadding: EdgeInsets.zero,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: AppColors.cardBorderColor,
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: AppColors.mainColor,
                                            width: 1.8,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        if (value.isNotEmpty && index < 5) {
                                          _focusNodes[index + 1].requestFocus();
                                        } else if (value.isEmpty && index > 0) {
                                          _focusNodes[index - 1].requestFocus();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(),
                            const SizedBox(height: 36),

                            // زر ربط الحساب
                            ElevatedButton(
                              onPressed: _onLinkAccount,
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
                                'ربط الحساب والمتابعة',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // زر أين أجد الرمز
                            OutlinedButton(
                              onPressed: _showWhereToFindDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.mainColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(
                                  color: AppColors.mainColor,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'أين أجد الرمز؟',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // زر تخطي إلى الخطوة التالية (السماح بالتنبيهات)
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/senior-notifications',
                                  );
                                },
                                child: Text(
                                  'تخطي هذه الخطوة الآن',
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
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
