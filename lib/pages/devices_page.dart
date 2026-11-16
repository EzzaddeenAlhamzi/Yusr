import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/senior_selector_widget.dart';
import '../core/services/senior_manager.dart';
import '../core/services/api_service.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  Map<String, dynamic>? _selectedDevice;
  bool _isConnected = true;
  bool _isReconnecting = false;
  final int _batteryLevel = 85;

  List<Map<String, dynamic>> _dbDevices = [];
  bool _isLoadingDevices = false;

  @override
  void initState() {
    super.initState();
    _loadAllDevices();
  }

  Future<void> _loadAllDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final list = await ApiService.instance.getDevices();
      if (mounted) {
        setState(() {
          _dbDevices = list;
          _isLoadingDevices = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingDevices = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل قائمة الأجهزة المتصلة. تأكد من اتصال الخادم والشبكة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  IconData _getDeviceIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('ساعة') || t.contains('watch')) return Icons.watch;
    if (t.contains('سوار') || t.contains('band') || t.contains('نبض')) return Icons.monitor_heart;
    if (t.contains('ضغط') || t.contains('pressure')) return Icons.favorite;
    if (t.contains('سكر') || t.contains('glucose')) return Icons.bloodtype;
    if (t.contains('طوارئ') || t.contains('sos') || t.contains('قلادة')) return Icons.emergency;
    if (t.contains('سقوط') || t.contains('حركة') || t.contains('fall')) return Icons.directions_walk;
    if (t.contains('أكسجين') || t.contains('spo2') || t.contains('oximeter')) return Icons.air;
    return Icons.devices_other;
  }

  Color _getDeviceColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('ساعة') || t.contains('watch')) return AppColors.mainColor;
    if (t.contains('سوار') || t.contains('band') || t.contains('نبض')) return const Color(0xFF00897B);
    if (t.contains('ضغط') || t.contains('pressure')) return const Color(0xFFE53935);
    if (t.contains('سكر') || t.contains('glucose')) return const Color(0xFFFB8C00);
    if (t.contains('طوارئ') || t.contains('sos') || t.contains('قلادة')) return const Color(0xFFC2185B);
    if (t.contains('سقوط') || t.contains('حركة') || t.contains('fall')) return const Color(0xFF3949AB);
    if (t.contains('أكسجين') || t.contains('spo2') || t.contains('oximeter')) return const Color(0xFF039BE5);
    return const Color(0xFF5E35B1);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.mainColor,
        appBar: CustomSubAppBar(
          title: _selectedDevice == null ? 'الأجهزة والساعات الذكية' : (_selectedDevice!['name'] as String),
          height: 95,
          trailing: IconButton(
            icon: const Icon(Icons.dns_rounded, color: Colors.white, size: 24),
            tooltip: 'فحص وإعدادات قاعدة البيانات',
            onPressed: () => ApiService.showServerConfigDialog(context),
          ),
          onBack: _selectedDevice != null
              ? () {
                  setState(() {
                    _selectedDevice = null;
                  });
                }
              : () => Navigator.maybePop(context),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            child: ListenableBuilder(
              listenable: SeniorManager(),
              builder: (context, _) {
                final hasSenior = SeniorManager().hasSeniors;

                if (!hasSenior) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.mainColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.devices_other_outlined,
                              size: 70,
                              color: AppColors.mainColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'لا توجد ساعات أو أجهزة ذكية',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'يرجى ربط كبير السن أولاً لتتمكن من إقران ومتابعة ساعته وأجهزته الذكية.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/link-senior');
                            },
                            icon: const Icon(Icons.link, color: Colors.white),
                            label: Text(
                              'ربط كبير سن جديد',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mainColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await _loadAllDevices();
                          await SeniorManager().reload();
                        },
                        color: AppColors.mainColor,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.all(16.0),
                          child: _selectedDevice == null
                              ? _buildDevicesListScreen()
                              : _buildDeviceDetailsScreen(),
                        ),
                      ),
                    ),
                    if (_selectedDevice == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                        child: _buildAddDeviceBottomButton(context),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // 1. شاشة قائمة الأجهزة والساعات الذكية
  Widget _buildDevicesListScreen() {
    final seniors = SeniorManager().seniors;

    // تجميع الأجهزة المرتبطة من قاعدة البيانات
    final List<Map<String, dynamic>> combinedDevices = [];

    for (final dev in _dbDevices) {
      final elderlyId = dev['Elderly_ID']?.toString();
      final devType = (dev['D_Type'] ?? 'ساعة ذكية').toString();
      final devNum = (dev['T_Number'] ?? 'YS-DEV-1').toString();
      final devId = dev['Devices_ID'];

      // إيجاد كبير السن المعني
      String seniorName = 'كبير السن';
      String rel = 'المشمول بالرعاية';
      for (final s in seniors) {
        if (s.id == elderlyId) {
          seniorName = s.name;
          rel = s.relationship;
          break;
        }
      }

      combinedDevices.add({
        'id': 'db_dev_$devId',
        'dbDeviceId': devId,
        'name': devNum.isNotEmpty && !devNum.startsWith('YS-') ? devNum : '$devType ($seniorName)',
        'type': devType,
        'serial': devNum,
        'seniorName': seniorName,
        'relationship': rel,
        'seniorId': elderlyId,
        'battery': 85,
        'status': 'متصل ونشط',
        'lastSync': 'الآن',
        'wearStatus': devType.contains('ساعة') || devType.contains('سوار') ? 'ملبوس على المعصم' : 'جاهز للقياس',
        'hasWatch': true,
      });
    }

    // إذا لم تكن هناك أجهزة مسجلة في قاعدة البيانات وكان لدى كبير السن الحالي ساعة افتراضية
    if (combinedDevices.isEmpty) {
      for (final s in seniors) {
        if (s.watchConnected && s.watchModel.isNotEmpty && s.watchModel != 'غير مقترنة') {
          combinedDevices.add({
            'id': 'senior_watch_${s.id}',
            'dbDeviceId': null,
            'name': 'ساعة ${s.relationship} (${s.name.split(' ').first})',
            'type': s.watchModel,
            'serial': s.pairingCode,
            'seniorName': s.name,
            'relationship': s.relationship,
            'seniorId': s.id,
            'battery': s.watchBattery > 0 ? s.watchBattery : 85,
            'status': 'متصلة ونشطة',
            'lastSync': 'الآن',
            'wearStatus': 'ملبوسة على المعصم',
            'hasWatch': true,
          });
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // محدد كبير السن للتبديل
        const SeniorSelectorWidget(showAddButton: false),
        const SizedBox(height: 14),

        // كارت ملخص شبكة الأجهزة
        _buildDevicesOverviewCard(combinedDevices.length),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الأجهزة والساعات المقترنة (${combinedDevices.length})',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.mainColor,
              ),
            ),
            if (_isLoadingDevices)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mainColor),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (combinedDevices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorderColor, width: 1),
            ),
            child: Column(
              children: [
                const Icon(Icons.devices_other_outlined, size: 48, color: AppColors.mainColor),
                const SizedBox(height: 12),
                Text(
                  'لا توجد أجهزة أو ساعات مرتبطة حالياً',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اضغط على زر "إضافة جهاز أو ساعة جديدة" بالأسفل لإقران أي جهاز ذكي أو طبي لكبير السن وحفظه في قاعدة البيانات.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: combinedDevices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final dev = combinedDevices[index];
              return _buildDeviceCard(dev);
            },
          ),

        const SizedBox(height: 16),

        // إرشادات الحفاظ على ربط الأجهزة الذكية
        _buildQuickTipsCard(),
      ],
    );
  }

  // كارت ملخص شبكة الأجهزة الذكية والطبية
  Widget _buildDevicesOverviewCard(int activeCount) {
    final bool hasActive = activeCount > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            hasActive ? Icons.hub_outlined : Icons.devices_other_outlined,
            color: hasActive ? const Color(0xFF2E7D32) : AppColors.textSecondary,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasActive ? 'منظومة الأجهزة الذكية نشطة ($activeCount متصلة)' : 'لا توجد أجهزة مرتبطة',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
                  ),
                ),
                Text(
                  hasActive
                      ? 'تدعم منظومة يُسر الساعات الذكية، أجهزة قياس الضغط والسكر، وقلادات الطوارئ'
                      : 'يمكنك إقران أي جهاز ذكي أو طبي لكبير السن لحفظ بياناته ومتابعتها لحظياً',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // كارت الجهاز
  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final String type = device['type'] ?? 'ساعة ذكية';
    final IconData icon = _getDeviceIcon(type);
    final Color color = _getDeviceColor(type);
    final int battery = (device['battery'] as int?) ?? 85;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDevice = device;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device['name'] as String,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'كبير السن: ${device['seniorName']}',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // نسبة البطارية
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: battery > 20
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        battery > 20 ? Icons.battery_charging_full : Icons.battery_alert,
                        size: 14,
                        color: battery > 20 ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$battery%',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: battery > 20 ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.cardBorderColor),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      device['status'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                Text(
                  'الكود: ${device['serial'] ?? 'YS-DEV'}',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'التفاصيل والخيارات',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainColor,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.mainColor),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. شاشة تفاصيل الجهاز الذكي أو الطبي
  Widget _buildDeviceDetailsScreen() {
    final dev = _selectedDevice!;
    final String type = dev['type'] ?? 'جهاز ذكي';
    final IconData icon = _getDeviceIcon(type);
    final Color color = _getDeviceColor(type);

    return Column(
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(icon, size: 64, color: color),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          dev['name'] ?? type,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'النوع: $type | المعرف: ${dev['serial'] ?? 'YS-DEV'}',
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),

        const SizedBox(height: 20),

        // كارت الاتصال والمزامنة
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorderColor, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: _isConnected ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnected ? 'متصل ونشط' : 'غير متصل',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                    ),
                  ),
                ],
              ),
              _isReconnecting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.mainColor,
                      ),
                    )
                  : TextButton(
                      onPressed: _reconnectWatch,
                      child: Text(
                        _isConnected ? 'فصل الاتصال' : 'إعادة الاتصال',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _isConnected
                              ? const Color(0xFFD32F2F)
                              : AppColors.mainColor,
                        ),
                      ),
                    ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // بطاقة المواصفات والمستشعرات
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'البيانات والمواصفات التشغيلية',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainColor,
                ),
              ),
              const SizedBox(height: 10),
              _buildDetailRow(Icons.person_pin_circle_outlined, 'كبير السن المستخدم', dev['seniorName'] ?? 'محمد عبدالله'),
              const Divider(height: 16, color: AppColors.cardBorderColor),
              _buildDetailRow(Icons.category_outlined, 'نوع الجهاز', type),
              const Divider(height: 16, color: AppColors.cardBorderColor),
              _buildDetailRow(Icons.fingerprint, 'الرقم التسلسلي / الكود', dev['serial'] ?? 'YS-DEV-1'),
              const Divider(height: 16, color: AppColors.cardBorderColor),
              _buildDetailRow(Icons.battery_std, 'مستوى شحن البطارية', '${dev['battery'] ?? _batteryLevel}%'),
              const Divider(height: 16, color: AppColors.cardBorderColor),
              _buildDetailRow(Icons.wifi, 'نوع الاتصال والشبكة', 'Bluetooth BLE + Wi-Fi'),
              const Divider(height: 16, color: AppColors.cardBorderColor),
              _buildDetailRow(Icons.sync, 'حالة المزامنة مع قاعدة البيانات', 'متزامن بنجاح عبر MySQL'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // زر فحص الرنين والتنبيه
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم إرسال إشارة تنبيه ورنين إلى ${dev['name']} بنجاح 🔔',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                  backgroundColor: AppColors.mainColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mainColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.volume_up_rounded),
            label: Text(
              'إصدار رنين وتنبيه تجريبي للجهاز',
              style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // زر فك الاقتران وحذف الجهاز
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final devId = dev['dbDeviceId'];
              final seniorId = int.tryParse(dev['seniorId']?.toString() ?? '');

              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    'فك اقتران وحذف الجهاز',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                    textAlign: TextAlign.right,
                  ),
                  content: Text(
                    'هل أنت متأكد من رغبتك في إلغاء اقتران هذا الجهاز وحذفه نهائياً من قاعدة البيانات؟',
                    style: GoogleFonts.cairo(fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                      child: Text('فك الاقتران والحذف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final res = await ApiService.instance.deleteDevice(
                  deviceId: devId is int ? devId : null,
                  elderlyId: devId == null ? seniorId : null,
                );

                if (res['success'] == true) {
                  await _loadAllDevices();
                  await SeniorManager().reload();
                  if (mounted) {
                    setState(() {
                      _selectedDevice = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم إلغاء اقتران الجهاز وحذفه من قاعدة البيانات بنجاح',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  }
                }
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.red.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.link_off_rounded, color: Colors.red),
            label: Text(
              'فك اقتران وحذف الجهاز من قاعدة البيانات',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // زر المساعدة والإرشادات
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showHelpDialog(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: AppColors.mainColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.menu_book_outlined, color: AppColors.mainColor),
            label: Text(
              'دليل إرشادات استخدام الأجهزة الذكية',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.mainColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.mainColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, color: Color(0xFFF57C00), size: 20),
              const SizedBox(width: 8),
              Text(
                'نصائح الحفاظ على دقة الأجهزة الذكية',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• تأكد من تشغيل البلوتوث والواي فاي لمزامنة القراءات فوراً إلى حساب مقدم الرعاية.\n'
            '• شحن الساعات والأجهزة الطبية بانتظام يضمن استمرار إرسال إشارات الاستغاثة في حالات الطوارئ.\n'
            '• يمكنك إضافة ساعات ذكية، أجهزة قياس ضغط، وسكر، وقلادات استغاثة لأي كبير سن.',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _reconnectWatch() {
    setState(() {
      _isReconnecting = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnected = !_isConnected;
          _isReconnecting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isConnected ? 'تمت إعادة مزامنة الجهاز بنجاح' : 'تم قطع اتصال الجهاز مؤقتاً',
              textAlign: TextAlign.right,
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _isConnected ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  /// نافذة إضافة أي جهاز ذكي أو طبي لكبير السن وحفظه في MySQL
  void _showAddDeviceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final seniors = SeniorManager().seniors;
        String selectedSeniorId = seniors.isNotEmpty ? seniors.first.id : '1';

        final List<Map<String, dynamic>> deviceTypes = [
          {'type': 'ساعة ذكية', 'icon': Icons.watch, 'defaultName': 'ساعة Yusr Smart Watch v3'},
          {'type': 'سوار طبي / نبض', 'icon': Icons.monitor_heart, 'defaultName': 'سوار VitalBand الصحي'},
          {'type': 'جهاز قياس ضغط الدم', 'icon': Icons.favorite, 'defaultName': 'جهاز قياس الضغط Omron Smart'},
          {'type': 'جهاز قياس السكر', 'icon': Icons.bloodtype, 'defaultName': 'جهاز قياس السكر Accu-Chek'},
          {'type': 'قلادة استغاثة طوارئ SOS', 'icon': Icons.emergency, 'defaultName': 'قلادة طوارئ SOS 4G'},
          {'type': 'مستشعر كشف السقوط', 'icon': Icons.directions_walk, 'defaultName': 'مستشعر السقوط المنزلي'},
          {'type': 'مقياس أكسجين الدم', 'icon': Icons.air, 'defaultName': 'مقياس أكسجين SpO2 الذكي'},
          {'type': 'جهاز مخصص آخر', 'icon': Icons.devices_other, 'defaultName': 'جهاز رعاية ذكي'},
        ];

        String selectedType = 'ساعة ذكية';
        final nameController = TextEditingController(text: 'ساعة Yusr Smart Watch v3');
        final serialController = TextEditingController(
          text: 'YS-${DateTime.now().millisecondsSinceEpoch % 10000}',
        );
        bool isSaving = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: AppColors.backgroundColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.mainColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_to_queue_rounded, color: AppColors.mainColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'إضافة وإقران جهاز جديد',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mainColor,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // اختيار كبير السن
                      Text(
                        'كبير السن المراد إقران الجهاز به:',
                        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSeniorId,
                            isExpanded: true,
                            items: seniors
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                        '${s.relationship} - ${s.name}',
                                        style: GoogleFonts.cairo(fontSize: 13),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedSeniorId = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // اختيار نوع الجهاز
                      Text(
                        'نوع الجهاز أو المستشعر:',
                        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cardBorderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedType,
                            isExpanded: true,
                            items: deviceTypes
                                .map((dt) => DropdownMenuItem<String>(
                                      value: dt['type'] as String,
                                      child: Row(
                                        children: [
                                          Icon(dt['icon'] as IconData, size: 18, color: AppColors.mainColor),
                                          const SizedBox(width: 8),
                                          Text(dt['type'] as String, style: GoogleFonts.cairo(fontSize: 13)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedType = val;
                                  final match = deviceTypes.firstWhere((e) => e['type'] == val);
                                  nameController.text = match['defaultName'] as String;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // اسم أو موديل الجهاز
                      Text(
                        'اسم أو موديل الجهاز:',
                        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'مثال: Apple Watch أو Omron M3',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          fillColor: AppColors.cardColor,
                          filled: true,
                        ),
                        style: GoogleFonts.cairo(fontSize: 13),
                      ),
                      const SizedBox(height: 14),

                      // الرقم التسلسلي أو المعرف
                      Text(
                        'الرقم التعريفي / التسلسلي للجهاز:',
                        style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: serialController,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: 'YS-WATCH-102',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          fillColor: AppColors.cardColor,
                          filled: true,
                        ),
                        style: GoogleFonts.sourceCodePro(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
                  ),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final elderlyId = int.tryParse(selectedSeniorId);
                            if (elderlyId == null) return;

                            final devName = nameController.text.trim().isEmpty ? selectedType : nameController.text.trim();
                            final serialNum = serialController.text.trim().isEmpty
                                ? 'YS-${DateTime.now().millisecondsSinceEpoch % 10000}'
                                : serialController.text.trim();

                            setDialogState(() => isSaving = true);

                            final res = await ApiService.instance.addDevice(
                              elderlyId: elderlyId,
                              deviceType: selectedType,
                              deviceName: devName,
                              number: serialNum,
                              status: 'Active',
                            );

                            setDialogState(() => isSaving = false);

                            if (res['success'] == true) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _loadAllDevices();
                              await SeniorManager().reload();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تم إقران "$devName" وحفظه في قاعدة البيانات بنجاح! 🎉',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: const Color(0xFF2E7D32),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      res['message'] ?? 'فشل حفظ الجهاز في قاعدة البيانات',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('حفظ وإقران الجهاز', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.help_outline, color: AppColors.mainColor),
                const SizedBox(width: 8),
                Text(
                  'تعليمات استخدام الأجهزة الذكية',
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
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
                    '1. تأكد من تفعيل البلوتوث والواي فاي بالجهاز أو الساعة الذكية.',
                    style: GoogleFonts.cairo(fontSize: 13.5, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '2. شحن الأجهزة ليلاً يضمن استمرار إرسال إشارات الاستغاثة وقياس العلامات الحيوية طوال اليوم.',
                    style: GoogleFonts.cairo(fontSize: 13.5, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '3. يمكنك إقران أكثر من جهاز (ساعة، مقياس ضغط، جهاز سكر) لكل كبير سن مسجل بحسابك.',
                    style: GoogleFonts.cairo(fontSize: 13.5, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'فهمت ذلك',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // زر إضافة جهاز ذكي أو ساعة في نهاية الصفحة
  Widget _buildAddDeviceBottomButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.mainColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40125D73),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAddDeviceDialog(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 24,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'إضافة جهاز أو ساعة جديدة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
