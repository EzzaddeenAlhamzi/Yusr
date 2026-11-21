import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';

/// شاشة العودة للمنزل البسيطة (Simple Return Home Screen)
/// مطابقة تماماً لشاشة iPhone 13 & 14 - 71 في Figma
class SimpleReturnHomePage extends StatelessWidget {
  const SimpleReturnHomePage({super.key});

  Future<void> _startHomeNavigation(BuildContext context) async {
    String? destination;
    try {
      final uid = AuthService().userId;
      if (uid != null) {
        final elderly = await ApiService.instance.getElderly(uid);
        if (elderly != null) {
          final addr = elderly['E_Location']?.toString() ??
              elderly['E_Address']?.toString() ??
              '';
          if (addr.isNotEmpty) {
            destination = addr;
          }
        }
      }
    } catch (_) {}

    if (destination == null || destination.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر بدء التوجيه: عنوان المنزل غير متوفر في الملف.',
              style: GoogleFonts.cairo(fontSize: 16),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse('google.navigation:q=${Uri.encodeComponent(destination)}&mode=d');
    final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذّر فتح تطبيق الخرائط للتوجيه إلى المنزل.',
            style: GoogleFonts.cairo(fontSize: 16),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // الشريط العلوي: سهم الرجوع + "العودة للمنزل" + أيقونة المنزل
            _buildTopAppBar(context),

            const SizedBox(height: 24),

            // الصورة التوضيحية للمنزل (img4.jpg المطابقة للصورة الأصلية في Figma)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/img/img4.jpg',
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 320,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.home_rounded,
                          size: 100,
                          color: Color(0xFF0D47A1),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),

            // الزر السفلي العريض: مايكروفون + "العوده للمنزل"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: InkWell(
                onTap: () => _startHomeNavigation(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0), // رمادي مطابق لتصميم Figma
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // أيقونة المايكروفون البترولية الزرقاء
                      const Icon(
                        Icons.mic_rounded,
                        size: 42,
                        color: Color(0xFF006064), // كحلي بترولي غامق
                      ),

                      // النص "العوده للمنزل"
                      Text(
                        'العوده للمنزل',
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            // P2.4 — keep location sharing reachable from simple mode.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/location-elderly'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF125D73),
                    side: const BorderSide(
                      color: Color(0xFF125D73),
                      width: 1.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.location_on_rounded, size: 28),
                  label: Text(
                    'مشاركة موقعي',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // سهم الرجوع
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.black87,
              size: 28,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          // العنوان في المنتصف "العودة للمنزل"
          Text(
            'العودة للمنزل',
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          // أيقونة المنزل الكحلية/السوداء
          const Icon(
            Icons.home_rounded,
            size: 38,
            color: Color(0xFF1E232A),
          ),
        ],
      ),
    );
  }
}
