import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';

/// Blocks protected routes when session is missing/invalid (A3).
/// Redirects once to login — no infinite loop (login is public).
class AuthRouteGuard extends StatefulWidget {
  const AuthRouteGuard({
    super.key,
    required this.child,
    this.requiredRole,
  });

  final Widget child;

  /// Optional: `'caregiver'` or `'senior'` (also accepts `'elderly'`).
  final String? requiredRole;

  @override
  State<AuthRouteGuard> createState() => _AuthRouteGuardState();
}

class _AuthRouteGuardState extends State<AuthRouteGuard> {
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforce());
  }

  void _enforce() {
    if (!mounted || _redirectScheduled) return;
    final auth = AuthService();
    if (auth.isRestoring) return;

    final ok = auth.isLoggedIn &&
        (widget.requiredRole == null ||
            auth.canAccess(widget.requiredRole!));
    if (ok) return;

    _redirectScheduled = true;
    final roleArg = AuthService.normalizeClientRole(widget.requiredRole) ??
        auth.role ??
        'caregiver';
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
      arguments: {'role': roleArg},
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final ok = auth.isLoggedIn &&
        (widget.requiredRole == null ||
            auth.canAccess(widget.requiredRole!));
    if (ok) return widget.child;

    // Placeholder while redirect runs — never the protected UI.
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Text(
          'جاري التحقق من الجلسة...',
          style: GoogleFonts.cairo(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
