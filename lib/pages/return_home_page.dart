import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import 'ai_page.dart';

class ReturnHomePage extends StatefulWidget {
  const ReturnHomePage({super.key});

  @override
  State<ReturnHomePage> createState() => _ReturnHomePageState();
}

class _ReturnHomePageState extends State<ReturnHomePage> {
  String _homeAddress = 'المنزل';
  double? _currentLat;
  double? _currentLng;
  bool _isCaregiverLinked = false;
  String _caregiverPhone = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final seniorId = AuthService().userId;
      if (seniorId != null) {
        final elderly = await ApiService.instance.getElderly(seniorId);
        if (elderly != null) {
          final addr = elderly['E_Location']?.toString() ?? elderly['E_Address']?.toString() ?? '';
          if (addr.isNotEmpty) {
            _homeAddress = addr;
          }
          if (elderly['caregiver'] != null) {
            final cg = elderly['caregiver'];
            final phone = cg['C_PhonNumber']?.toString().trim() ?? '';
            if (phone.isNotEmpty && phone != 'غير مسجل') {
              _isCaregiverLinked = true;
              _caregiverPhone = phone;
            }
          }
        }
      }

      // تحديد الموقع الحالي بالـ GPS
      try {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;

          // تحديث الموقع المباشر في قاعدة البيانات
          if (seniorId != null) {
            try {
              await ApiService.instance.updateLocation(
                elderlyId: seniorId,
                latitude: pos.latitude,
                longitude: pos.longitude,
                location: 'الموقع المباشر: ${_currentLat!.toStringAsFixed(4)}, ${_currentLng!.toStringAsFixed(4)}',
              );
            } catch (_) {}
          }
        }
      } catch (_) {}
    } catch (_) {
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _startHomeNavigation() async {
    final destination = _homeAddress.isNotEmpty ? _homeAddress : 'Home';
    final Uri navUri = Uri.parse('google.navigation:q=${Uri.encodeComponent(destination)}&mode=d');
    final Uri webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}');

    try {
      if (await canLaunchUrl(navUri)) {
        await launchUrl(navUri);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('جاري بدء التوجيه إلى $_homeAddress...', style: GoogleFonts.tajawal()),
              backgroundColor: appbarColor,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _shareLocation() async {
    final lat = _currentLat;
    final lng = _currentLng;
    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر مشاركة الموقع: لا توجد إحداثيات GPS متاحة حالياً.',
              style: GoogleFonts.tajawal(),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }
    final Uri mapUri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    try {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر فتح تطبيق الخرائط.', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر مشاركة الموقع.', style: GoogleFonts.tajawal()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appbarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CustomTopBar(
              title: 'الموقع والعودة للمنزل',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),
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
                            const SizedBox(height: 14),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: cardBorderColor, width: 1.4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  'assets/img/img4.jpg',
                                  width: double.infinity,
                                  height: 250,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 250,
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.home_rounded,
                                          size: 80,
                                          color: appbarColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'سيتم توجيهك إلى منزلك\n($_homeAddress)',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.tajawal(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 62,
                              child: ElevatedButton(
                                onPressed: _startHomeNavigation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: appbarColor,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  'ابدأ التوجيه',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 62,
                              child: OutlinedButton(
                                onPressed: _shareLocation,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: appbarColor, width: 2),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  'مشاركة الموقع',
                                  style: GoogleFonts.tajawal(
                                    color: appbarColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            if (_isCaregiverLinked && _caregiverPhone.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.phone_rounded, color: appbarColor),
                                  onPressed: () async {
                                    final uri = Uri.parse('tel:$_caregiverPhone');
                                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: appbarColor, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  label: Text(
                                    'الاتصال بمقدم الرعاية',
                                    style: GoogleFonts.tajawal(
                                      color: appbarColor,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // زر "اضغط للتحدث" في نهاية الصفحة مع الأيقونة لليسار
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
                      child: Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          color: appbarColor,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
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
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'اضغط للتحدث',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Positioned(
                                left: 24,
                                child: Icon(
                                  Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 36,
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
}
