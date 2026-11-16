import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import 'ai_page.dart';

class LocationPageElderly extends StatefulWidget {
  const LocationPageElderly({super.key});

  @override
  State<LocationPageElderly> createState() => _LocationPageElderlyState();
}

class _LocationPageElderlyState extends State<LocationPageElderly> {
  bool _isLoading = true;
  double? _latitude;
  double? _longitude;
  String _locationName = 'جاري تحديد موقعك الجغرافي...';

  @override
  void initState() {
    super.initState();
    _fetchAutoLocation();
  }

  /// أخذ الموقع الجغرافي تلقائياً من الهاتف وتحديثه في قاعدة البيانات
  Future<void> _fetchAutoLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // فحص قاعدة البيانات لآخر موقع محفوظ
        await _fetchFallbackDbLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );

        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationName = 'الموقع المباشر: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}';

        // تحديث الموقع في قاعدة البيانات location_tracking
        final elderlyId = AuthService().userId;
        if (elderlyId != null) {
          try {
            await ApiService.instance.updateLocation(
              elderlyId: elderlyId,
              latitude: pos.latitude,
              longitude: pos.longitude,
              location: _locationName,
            );
          } catch (_) {}
        }
      } else {
        await _fetchFallbackDbLocation();
      }
    } catch (_) {
      await _fetchFallbackDbLocation();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFallbackDbLocation() async {
    final elderlyId = AuthService().userId;
    if (elderlyId != null) {
      try {
        final loc = await ApiService.instance.getLocation(elderlyId: elderlyId);
        if (loc != null && loc is Map) {
          final lat = loc['latitude'] != null ? double.tryParse(loc['latitude'].toString()) : null;
          final lng = loc['Longitude'] != null ? double.tryParse(loc['Longitude'].toString()) : null;
          final text = loc['E_Location']?.toString() ?? '';
          if (lat != null && lng != null) {
            _latitude = lat;
            _longitude = lng;
          }
          if (text.isNotEmpty) {
            _locationName = text;
            return;
          }
        }
      } catch (_) {}
    }
    if (_latitude != null && _longitude != null) {
      _locationName = '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}';
    } else {
      _locationName = 'تم تفعيل الموقع وتحديث الإحداثيات';
    }
  }

  Future<void> _shareLocation() async {
    final lat = _latitude ?? 15.3694;
    final lng = _longitude ?? 44.1910;
    final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appbarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // الشريط العلوي الموحد (CustomTopBar) مع زر الرجوع في جهة اليسار
            CustomTopBar(
              title: 'الموقع',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // الجسم المنحني الرئيسي للصفحة
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    // المحتوى القابل للتمرير
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),

                            // صورة الخريطة
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
                                  'assets/img/img5.jpg',
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
                                          Icons.location_on_rounded,
                                          size: 70,
                                          color: appbarColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // بطاقة "موقعي الحالي"
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 22),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: cardBorderColor, width: 1.4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'موقعي الحالي:',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_isLoading)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8.0),
                                      child: CircularProgressIndicator(color: appbarColor),
                                    )
                                  else
                                    Text(
                                      _locationName,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: appbarColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // بطاقة "مشاركة الموقع"
                            InkWell(
                              onTap: _shareLocation,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: cardBorderColor, width: 1.4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.share_rounded,
                                      color: iconColor,
                                      size: 34,
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'مشاركة الموقع',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
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
