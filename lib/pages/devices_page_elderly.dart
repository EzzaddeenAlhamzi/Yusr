import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../core/widgets/elderly_bottom_nav_bar.dart';
import '../core/services/auth_service.dart';
import 'ai_page.dart';

import '../core/services/api_service.dart';

class DevicesPageElderly extends StatefulWidget {
  const DevicesPageElderly({super.key});

  @override
  State<DevicesPageElderly> createState() => _DevicesPageElderlyState();
}

class _DevicesPageElderlyState extends State<DevicesPageElderly> {
  bool _showDetails = false;
  bool _isChecking = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _devices = [];
  Map<String, dynamic>? _activeDevice;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    final elderlyId = AuthService().userId;
    if (elderlyId != null) {
      final list = await ApiService.instance.getDevices(elderlyId: elderlyId);
      if (mounted) {
        setState(() {
          _devices = list;
          _activeDevice = list.isNotEmpty ? list.first : null;
          _isLoading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _devices = [];
        _activeDevice = null;
        _isLoading = false;
      });
    }
  }

  // دالة البحث عن الساعة بإصدار صوت رنين
  void _findMyWatch() {
    if (_activeDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: Text(
            'لا توجد ساعة ذكية متصلة حالياً لإصدار رنين',
            style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorderColor, width: 1.4),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.volume_up_rounded, color: appbarColor, size: 32),
            const SizedBox(width: 8),
            Text(
              'البحث عن الساعة',
              style: GoogleFonts.tajawal(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: appbarColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: appbarColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.watch_rounded,
                color: appbarColor,
                size: 46,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري إصدار صوت رنين عالي من ساعتك الذكية لتتمكن من العثور عليها بسهولة 🔔',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                fontSize: 19,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: appbarColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'إيقاف الرنين',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة فحص وتحديث اتصال الساعة
  void _checkConnection() async {
    if (_activeDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: Text(
            'لا توجد ساعة ذكية متصلة حالياً',
            style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }

    setState(() {
      _isChecking = true;
    });

    await _loadDevices();

    if (mounted) {
      setState(() {
        _isChecking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ساعتك الذكية متصلة ومحدثة مع النظام 👍',
                  style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // دالة فك اقتران الساعة
  Future<void> _unpairDevice(int deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'فك اقتران الساعة',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.red.shade800),
          textAlign: TextAlign.right,
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في إلغاء اقتران هذه الساعة الذكية؟',
          style: GoogleFonts.tajawal(fontSize: 16),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text('فك الاقتران', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.instance.deleteDevice(deviceId: deviceId);
      if (res['success'] == true) {
        setState(() {
          _showDetails = false;
        });
        await _loadDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF2E7D32),
              content: Text(
                'تم إلغاء اقتران الساعة الذكية بنجاح',
                style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      }
    }
  }

  // دالة إضافة وإقران ساعة جديدة مع زر التخطي والربط بقاعدة البيانات
  void _showAddDeviceDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline_rounded, color: appbarColor, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'إضافة جهاز ذكي آخر',
                    style: GoogleFonts.tajawal(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bluetooth_searching_rounded, color: appbarColor, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'تأكد من تشغيل البلوتوث وتقريب الجهاز للاتصال والمزامنة المباشرة',
                        style: GoogleFonts.tajawal(
                          fontSize: 14.5,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // قائمة الأجهزة الذكية الأخرى المتاحة للربط
              _buildAddOtherDeviceTile(
                ctx: ctx,
                title: 'جهاز قياس ضغط الدم الذكي',
                subtitle: 'مراقبة ضغط الدم ومزامنة القراءات تلقائياً',
                deviceType: 'جهاز ضغط',
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFE53935),
              ),
              const SizedBox(height: 10),
              _buildAddOtherDeviceTile(
                ctx: ctx,
                title: 'جهاز قياس سكر الدم الذكي',
                subtitle: 'متابعة قراءات السكر وتنبيهات الجرعات',
                deviceType: 'جهاز سكر',
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFF1E88E5),
              ),
              const SizedBox(height: 10),
              _buildAddOtherDeviceTile(
                ctx: ctx,
                title: 'مقياس نسبة الأكسجين والنبض (Oximeter)',
                subtitle: 'قياس نسبة الأكسجين ومعدل نبضات القلب',
                deviceType: 'مقياس أكسجين',
                icon: Icons.air_rounded,
                iconColor: const Color(0xFF00897B),
              ),
              const SizedBox(height: 10),
              _buildAddOtherDeviceTile(
                ctx: ctx,
                title: 'سوار الطوارئ والاستشعار الصحي',
                subtitle: 'مستشعر للحركة وتنبيهات السقوط السريعة',
                deviceType: 'سوار طوارئ',
                icon: Icons.notification_important_rounded,
                iconColor: const Color(0xFFF57C00),
              ),
              const SizedBox(height: 12),
              // زر الربط لاحقاً (تخطي)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.grey.shade800,
                        content: Text(
                          'تم إلغاء إضافة الجهاز.',
                          style: GoogleFonts.tajawal(fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'الرجوع (إلغاء)',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddOtherDeviceTile({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required String deviceType,
    required IconData icon,
    required Color iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 26),
      ),
      title: Text(
        title,
        style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.tajawal(fontSize: 13, color: Colors.grey.shade700),
      ),
      trailing: const Icon(Icons.add_circle, color: appbarColor, size: 24),
      onTap: () async {
        Navigator.pop(ctx);
        final elderlyId = AuthService().userId;
        if (elderlyId != null) {
          final res = await ApiService.instance.addDevice(
            elderlyId: elderlyId,
            deviceName: title,
            deviceType: deviceType,
            status: 'Active',
          );
          if (res['success'] == true) {
            await _loadDevices();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF2E7D32),
                  content: Text(
                    'تمت إضافة $title وحفظه بنجاح 🎉',
                    style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red.shade700,
                  content: Text(
                    res['message'] ?? 'فشلت إضافة الجهاز',
                    style: GoogleFonts.tajawal(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
          }
        }
      },
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
            // الشريط العلوي
            CustomTopBar(
              title: _showDetails ? 'تفاصيل الساعة' : 'أجهزتي الذكية',
              onBack: _showDetails
                  ? () {
                      setState(() {
                        _showDetails = false;
                      });
                    }
                  : () => Navigator.maybePop(context),
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
                        padding: const EdgeInsets.only(top: 20, bottom: 20),
                        child: _showDetails ? _buildDetailsView() : _buildMainListView(),
                      ),
                    ),

                    // زر "اضغط للتحدث" السفلي
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
                      child: Container(
                        width: double.infinity,
                        height: 56,
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
                                  size: 30,
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
      bottomNavigationBar: const ElderlyBottomNavBar(currentIndex: 1),
    );
  }

  // 1. الشاشة الرئيسية للأجهزة (كارد اسم الساعة + زر إضافة جهاز)
  Widget _buildMainListView() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: appbarColor),
        ),
      );
    }

    if (_devices.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.watch_off_outlined,
                    size: 46,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'لا توجد ساعة ذكية متصلة',
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'لم يتم ربط ساعتك الذكية بحسابك حتى الآن.\nيمكنك إقران ساعتك لتفعيل ميزات الأمان ونبض القلب وتنبيهات السقوط.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.orange.shade800),
                      const SizedBox(width: 6),
                      Text(
                        'حالة الساعة: غير مقترنة',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _showAddDeviceDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 26),
              label: Text(
                'إضافة جهاز ذكي',
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: appbarColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final device = _activeDevice ?? _devices.first;
    final isConnected = (device['Status'] ?? 'Active') == 'Active';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // كارد اسم الساعة القابل للضغط
        InkWell(
          onTap: () {
            setState(() {
              _showDetails = true;
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cardBorderColor, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: appbarColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.watch_rounded,
                        color: appbarColor,
                        size: 42,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device['Device_Name'] ?? 'الجهاز الذكي',
                            style: GoogleFonts.tajawal(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.circle,
                                  color: isConnected ? const Color(0xFF43A047) : Colors.orange,
                                  size: 12),
                              const SizedBox(width: 6),
                              Text(
                                isConnected ? 'متصلة ونشطة 🟢' : 'غير متصلة ⚪',
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isConnected ? const Color(0xFF2E7D32) : Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: appbarColor,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.devices_other_rounded, color: appbarColor, size: 24),
                        const SizedBox(width: 6),
                        Text(
                          'النوع: ${device['Device_Type'] ?? 'ساعة ذكية'}',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'اضغط لعرض التفاصيل',
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: appbarColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // زر إضافة جهاز جديد
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _showAddDeviceDialog,
            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 26),
            label: Text(
              'إضافة جهاز آخر',
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: appbarColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // زر البحث عن الساعة
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _findMyWatch,
            icon: const Icon(Icons.volume_up_rounded, color: appbarColor, size: 26),
            label: Text(
              'البحث عن ساعتي (إصدار رنين) 🔔',
              style: GoogleFonts.tajawal(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: appbarColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: appbarColor, width: 1.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 2. شاشة تفاصيل الساعة البسيطة لكبير السن
  Widget _buildDetailsView() {
    final device = _activeDevice ?? (_devices.isNotEmpty ? _devices.first : <String, dynamic>{});
    final deviceId = device['Devices_ID'] != null ? int.tryParse(device['Devices_ID'].toString()) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // كارت معلومات الساعة البسيطة
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorderColor, width: 1.4),
          ),
          child: Column(
            children: [
              _buildSimpleDetailRow(
                icon: Icons.watch_rounded,
                iconColor: appbarColor,
                title: 'اسم الجهاز',
                value: device['Device_Name'] ?? 'الجهاز الذكي',
              ),
              const Divider(height: 24),
              _buildSimpleDetailRow(
                icon: Icons.category_rounded,
                iconColor: const Color(0xFF0288D1),
                title: 'نوع الجهاز',
                value: device['Device_Type'] ?? 'ساعة ذكية',
              ),
              const Divider(height: 24),
              _buildSimpleDetailRow(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF2E7D32),
                title: 'حالة الاتصال',
                value: (device['Status'] ?? 'Active') == 'Active'
                    ? 'متصلة ونشطة بنجاح 🟢'
                    : 'غير متصلة ⚪',
              ),
              const Divider(height: 24),
              _buildSimpleDetailRow(
                icon: Icons.tag_rounded,
                iconColor: const Color(0xFF7B1FA2),
                title: 'رقم المعرف في النظام',
                value: '#${device['Devices_ID'] ?? '-'}',
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // أزرار التحكم البسيطة
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _findMyWatch,
                  icon: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                  label: Text(
                    'رنين الساعة 🔔',
                    style: GoogleFonts.tajawal(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appbarColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _checkConnection,
                  icon: const Icon(Icons.sync_rounded, color: appbarColor, size: 22),
                  label: Text(
                    _isChecking ? 'جاري الفحص...' : 'فحص الاتصال 🔄',
                    style: GoogleFonts.tajawal(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: appbarColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: appbarColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),

        if (deviceId != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _unpairDevice(deviceId),
              icon: const Icon(Icons.link_off_rounded, color: Colors.red),
              label: Text(
                'فك اقتران هذه الساعة',
                style: GoogleFonts.tajawal(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // زر الرجوع لقائمة الأجهزة
        SizedBox(
          width: double.infinity,
          height: 50,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _showDetails = false;
              });
            },
            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.black87),
            label: Text(
              'العودة للأجهزة',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // سطر تفصيل بسيط لكبير السن
  Widget _buildSimpleDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
