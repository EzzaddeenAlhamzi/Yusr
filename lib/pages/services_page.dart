import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/custom_bottom_nav_bar.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/senior_manager.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingServices = false;
  bool _isLoadingRequests = false;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _myRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadServices(),
      _loadRequests(),
    ]);
  }

  Future<void> _loadServices() async {
    if (mounted) setState(() => _isLoadingServices = true);
    try {
      final list = await ApiService.instance.getServices();
      if (mounted) {
        setState(() {
          _services = list;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل الخدمات المتاحة. تأكد من اتصال الخادم والشبكة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _loadRequests() async {
    if (mounted) setState(() => _isLoadingRequests = true);
    try {
      final caregiverId = AuthService().userId;
      final seniorId = SeniorManager().hasSeniors
          ? int.tryParse(SeniorManager().currentSenior.id)
          : null;

      final list = await ApiService.instance.getServiceRequests(
        caregiverId: caregiverId,
        elderlyId: seniorId,
      );
      if (mounted) {
        setState(() {
          _myRequests = list;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل طلبات الخدمات. تأكد من اتصال الخادم والشبكة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.mainColor,
        appBar: const CustomSubAppBar(
          title: 'خدمات الرعاية والدعم',
          height: 95,
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
            child: Column(
              children: [
                // شريط التبويب
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: AppColors.mainColor,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                    unselectedLabelStyle: GoogleFonts.cairo(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.medical_services_outlined, size: 20),
                        text: 'الخدمات المتاحة',
                      ),
                      Tab(
                        icon: Icon(Icons.assignment_turned_in_outlined, size: 20),
                        text: 'طلباتي السابقة',
                      ),
                    ],
                  ),
                ),

                // محتوى التبويبات
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildServicesTab(),
                      _buildRequestsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: customBottomNavigationBar(
          context: context,
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) {
              Navigator.popUntil(context, (route) => route.isFirst);
            } else if (index == 1) {
              Navigator.pushNamed(context, '/emergency');
            } else if (index == 2) {
              Navigator.pushNamed(context, '/profile');
            }
          },
        ),
      ),
    );
  }

  // تبويب الخدمات المتاحة
  Widget _buildServicesTab() {
    if (_isLoadingServices && _services.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.mainColor),
      );
    }

    if (_services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 60,
                color: AppColors.mainColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد خدمات متاحة حالياً',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم إضافة باقات وخدمات رعاية جديدة قريباً',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadServices,
      color: AppColors.mainColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _services.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final s = _services[index];
          final name = s['S_Name']?.toString() ?? 'خدمة رعاية';
          final type = s['S_Type']?.toString() ?? 'عام';
          final desc = s['S_Description']?.toString() ?? '';
          final status = s['S_Status']?.toString() ?? 'نشط';

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mainColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.textColor.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.cardBorderColor),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: status == 'نشط'
                              ? const Color(0xFF2E7D32)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'الحالة: $status',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: status == 'نشط'
                                ? const Color(0xFF2E7D32)
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mainColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showRequestModal(context, s),
                      icon: const Icon(Icons.send_rounded,
                          size: 15, color: Colors.white),
                      label: Text(
                        'طلب الخدمة',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // تبويب طلباتي السابقة
  Widget _buildRequestsTab() {
    if (_isLoadingRequests && _myRequests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.mainColor),
      );
    }

    if (_myRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 60,
                color: AppColors.mainColor.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'لم تقم بتقديم أي طلبات خدمة حتى الآن',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'يمكنك استعراض الخدمات وتقديم طلب جديد في أي وقت',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: Text(
                  'استعراض الخدمات',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: AppColors.mainColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _myRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final r = _myRequests[index];
          final reqId = r['Service_Requst_ID']?.toString() ?? '';
          final sName = r['S_Name']?.toString() ?? 'خدمة رعاية';
          final date = r['Requst_Date']?.toString() ?? '';
          final status = r['Requst_Status']?.toString() ?? 'قيد المراجعة';
          final note = r['Requst_Note']?.toString() ?? '';

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sName,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$reqId',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (note.isNotEmpty) ...[
                  Text(
                    'الملاحظات: $note',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: AppColors.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                const Divider(height: 1, color: AppColors.cardBorderColor),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          date,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // نافذة تأكيد وتقديم طلب الخدمة
  void _showRequestModal(BuildContext context, Map<String, dynamic> service) {
    final noteCtrl = TextEditingController();
    int? selectedElderlyId = SeniorManager().hasSeniors
        ? int.tryParse(SeniorManager().currentSenior.id)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final seniors = SeniorManager().seniors;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'طلب خدمة: ${service['S_Name']}',
                      style: GoogleFonts.cairo(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      service['S_Description']?.toString() ?? '',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (seniors.isNotEmpty) ...[
                      Text(
                        'كبير السن المستفيد:',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: selectedElderlyId ?? int.tryParse(seniors.first.id),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: AppColors.cardBorderColor),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: seniors.map((s) {
                          final id = int.tryParse(s.id) ?? 0;
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              '${s.name} (${s.relationship})',
                              style: GoogleFonts.cairo(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() => selectedElderlyId = val);
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'ملاحظات إضافية أو تفاصيل الموعد:',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'اكتب أي متطلبات خاصة أو توقيت الزيارة المفضل...',
                        hintStyle: GoogleFonts.cairo(
                            fontSize: 12, color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorderColor),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: GoogleFonts.cairo(fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final serviceId = service['Service_ID'];
                          final caregiverId = AuthService().userId;
                          final note = noteCtrl.text.trim().isNotEmpty
                              ? noteCtrl.text.trim()
                              : 'طلب خدمة ${service['S_Name']} عبر التطبيق';

                          Navigator.pop(ctx);

                          final res = await ApiService.instance.requestService(
                            serviceId: serviceId is int
                                ? serviceId
                                : int.tryParse(serviceId.toString()) ?? 1,
                            caregiverId: caregiverId,
                            elderlyId: selectedElderlyId,
                            note: note,
                          );

                          if (context.mounted) {
                            if (res['status'] == 'success') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res['message']?.toString() ??
                                        'تم إرسال طلب الخدمة بنجاح',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFF2E7D32),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                              _loadRequests();
                              _tabController.animateTo(1);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res['message']?.toString() ??
                                        'تعذر إرسال الطلب',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          'تأكيد إرسال الطلب',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
