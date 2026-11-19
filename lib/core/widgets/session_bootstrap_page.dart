import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../../pages/welcome_page.dart';

/// P1.3 cold-start gate: validate Sanctum session before any protected home.
/// Shows a short Arabic RTL loading state; never opens homes before validation.
class SessionBootstrapPage extends StatefulWidget {
  const SessionBootstrapPage({super.key});

  @override
  State<SessionBootstrapPage> createState() => _SessionBootstrapPageState();
}

class _SessionBootstrapPageState extends State<SessionBootstrapPage> {
  bool _showWelcome = false;
  bool _networkRetry = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    ApiService.instance; // ensure hooks wired via first use
    _runRestore();
  }

  Future<void> _runRestore() async {
    setState(() {
      _busy = true;
      _networkRetry = false;
      _showWelcome = false;
    });

    // Ensure ApiService auth hooks (me + logout) are registered.
    ApiService.instance.ensureAuthHooksForSession();

    final outcome = await AuthService().restoreSession();
    if (!mounted) return;

    if (outcome == SessionRestoreOutcome.authenticated) {
      final route = await AuthService().homeRouteForSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
      return;
    }

    if (outcome == SessionRestoreOutcome.networkUnavailable) {
      setState(() {
        _busy = false;
        _networkRetry = true;
      });
      return;
    }

    setState(() {
      _busy = false;
      _showWelcome = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) {
      return const WelcomePage();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'يُسر',
                  style: GoogleFonts.cairo(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
                  ),
                ),
                const SizedBox(height: 12),
                if (_busy) ...[
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.mainColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'جاري استعادة الجلسة...',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: AppColors.textColor,
                    ),
                  ),
                ] else if (_networkRetry) ...[
                  Text(
                    'تعذّر التحقق من الجلسة بسبب مشكلة في الاتصال. لم يتم فتح الحساب بعد.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      color: AppColors.textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _runRestore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'إعادة المحاولة',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      // Deny local access safely; do not claim server revocation.
                      await AuthService().logout();
                      if (!mounted) return;
                      setState(() {
                        _networkRetry = false;
                        _showWelcome = true;
                      });
                    },
                    child: Text(
                      'المتابعة لتسجيل الدخول',
                      style: GoogleFonts.cairo(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
