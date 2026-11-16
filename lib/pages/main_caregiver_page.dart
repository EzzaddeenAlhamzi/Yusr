import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/custom_bottom_nav_bar.dart';
import '../core/widgets/senior_selector_widget.dart';
import '../core/services/senior_manager.dart';
import 'medicines_page.dart';
import 'appointments_page.dart';
import 'location_page.dart';
import 'health_status_page.dart';
import 'notifications_page.dart';
import 'emergency_page.dart';
import 'activity_log_page.dart';
import 'profile_page.dart';
import 'profile_page_caregiver.dart';
import '../core/services/auth_service.dart';
import 'senior_data_page.dart';
import '../core/widgets/custom_app_drawer.dart';

class MainCaregiverPage extends StatefulWidget {
  const MainCaregiverPage({super.key});

  @override
  State<MainCaregiverPage> createState() => _MainCaregiverPageState();
}

class _MainCaregiverPageState extends State<MainCaregiverPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PageController _pageController;
  int _currentTabIndex = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = CaregiverNavNotifier.currentTab.value;
    _pageController = PageController(initialPage: _currentTabIndex);
    SeniorManager().fetchSeniorsFromDatabase();
    CaregiverNavNotifier.currentTab.addListener(_onGlobalTabChanged);
  }

  void _onGlobalTabChanged() {
    final targetIndex = CaregiverNavNotifier.currentTab.value;
    if (targetIndex != _currentTabIndex && mounted) {
      setState(() {
        _currentTabIndex = targetIndex;
      });
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    CaregiverNavNotifier.currentTab.removeListener(_onGlobalTabChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshRealData() async {
    setState(() => _isRefreshing = true);
    await SeniorManager().fetchSeniorsFromDatabase();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _animateToTab(int index) {
    if (_currentTabIndex == index) return;
    setState(() {
      _currentTabIndex = index;
    });
    CaregiverNavNotifier.currentTab.value = index;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _currentTabIndex = index;
            });
            CaregiverNavNotifier.currentTab.value = index;
          },
          children: [
            // التبويب 0: لوحة التحكم الرئيسية لمقدم الرعاية
            _buildHomeDashboard(context),

            // التبويب 1: صفحة طوارئ SOS مدمجة بسلاسة
            const EmergencyPage(showBottomNav: false, isEmbedded: true),

            // التبويب 2: صفحة الملف الشخصي لمقدم الرعاية مدمجة بسلاسة
            const ProfilePageCaregiver(showBottomNav: false, isEmbedded: true),
          ],
        ),
        bottomNavigationBar: customBottomNavigationBar(
          context: context,
          currentIndex: _currentTabIndex,
          onTap: (index) {
            _animateToTab(index);
          },
        ),
      ),
    );
  }

  /// واجهة الصفحة الرئيسية لمقدم الرعاية
  Widget _buildHomeDashboard(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: const CustomAppDrawer(),
      backgroundColor: AppColors.mainColor,
      appBar: customAppBar(
        title: (AuthService().userName != null && AuthService().userName!.isNotEmpty)
            ? 'مرحباً، ${AuthService().userName}'
            : 'مرحباً بك',
        backgroundColor: AppColors.mainColor,
        titleColor: Colors.white,
        height: 96,
        radius: 0,
        showProfile: true,
        onMenuTap: () {
          _scaffoldKey.currentState?.openEndDrawer();
        },
        onNotificationTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationsPage()),
          );
        },
        onProfileTap: () {
          _animateToTab(2);
        },
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
              // 1. المحتوى القابل للتمرير
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshRealData,
                  color: AppColors.mainColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // محدد / مبدل كبار السن مع زر إضافة كبير سن
                        const SeniorSelectorWidget(),

                        const SizedBox(height: 14),

                        // كارت ملخص حالة كبير السن النشط
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildStatusSummaryCard(context),
                        ),

                        const SizedBox(height: 14),

                        // شبكة الكروت للخدمات
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildActionGrid(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. زر تحديث البيانات الثابت بالأسفل
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: _buildBottomActionButtons(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. كارت ملخص الحالة المتغير حسب كبير السن المختار
  Widget _buildStatusSummaryCard(BuildContext context) {
    return ListenableBuilder(
      listenable: SeniorManager(),
      builder: (context, _) {
        if (!SeniorManager().hasSeniors) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorderColor, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.mainColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_outlined,
                    size: 38,
                    color: AppColors.mainColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'لم يتم ربط حساب كبير السن بعد',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اربط حساب كبير السن لمتابعة صحته وموقعه ومواعيده من قاعدة البيانات مباشرة.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/link-senior');
                  },
                  icon: const Icon(Icons.link, color: Colors.white, size: 18),
                  label: Text(
                    'ربط كبير سن جديد',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mainColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ],
            ),
          );
        }

        final senior = SeniorManager().currentSenior;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorderColor, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الشريط العلوي
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'ملخص حالة',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mainColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${senior.relationship})',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 8,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          senior.healthStatus,
                          style: GoogleFonts.cairo(
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // التفاصيل الوسطى
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // عمود كبير السن
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'كبير السن',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          senior.name.split(' ').first,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          senior.age > 0 ? '${senior.age} سنة' : 'العمر غير محدد',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // عمود المهمة القادمة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'المهمة القادمة',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              senior.nextTask,
                              style: GoogleFonts.cairo(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.mainColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('💊', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          senior.nextTaskTime,
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

              if (senior.watchConnected || senior.steps.isNotEmpty || senior.sleepHours.isNotEmpty) ...[
                const SizedBox(height: 14),

                // خط فاصل
                const Divider(color: AppColors.cardBorderColor, height: 1),

                const SizedBox(height: 12),

                // المؤشرات السفلية الحقيقية (حاوية الساعة تختفي تماماً عند عدم الربط بساعة)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (senior.steps.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            senior.steps,
                            style: GoogleFonts.cairo(
                              color: AppColors.mainColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('🚶‍♂️', style: TextStyle(fontSize: 13)),
                        ],
                      )
                    else
                      const SizedBox.shrink(),

                    if (senior.sleepHours.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            senior.sleepHours,
                            style: GoogleFonts.cairo(
                              color: AppColors.mainColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('💤', style: TextStyle(fontSize: 13)),
                        ],
                      )
                    else
                      const SizedBox.shrink(),

                    // حاوية الساعة الذكية: تختفي نهائياً إذا لم تكن هناك ساعة مرتبطة
                    if (senior.watchConnected && senior.watchModel.isNotEmpty && senior.watchModel != 'غير مقترنة')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${senior.watchBattery}% شحن',
                            style: GoogleFonts.cairo(
                              color: AppColors.mainColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('⌚', style: TextStyle(fontSize: 13)),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // 2. شبكة الخيارات
  Widget _buildActionGrid(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'الموقع',
        'icon': Icons.location_on_rounded,
        'iconColor': const Color(0xFF3B62AC),
      },
      {
        'title': 'الحالة الصحية',
        'icon': Icons.favorite_rounded,
        'iconColor': const Color(0xFFE53935),
      },
      {
        'title': 'المواعيد',
        'icon': Icons.calendar_month_rounded,
        'iconColor': const Color(0xFF3B62AC),
      },
      {
        'title': 'الأدوية',
        'icon': Icons.medication_rounded,
        'iconColor': const Color(0xFFAB47BC),
      },
      {
        'title': 'بيانات كبير السن',
        'icon': Icons.person_rounded,
        'iconColor': const Color(0xFF5C93D4),
      },
      {
        'title': 'متابعة الحالة الصحية',
        'icon': Icons.monitor_heart_outlined,
        'iconColor': const Color(0xFF26A69A),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () {
            if (item['title'] == 'الأدوية') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MedicinesPage()),
              );
            } else if (item['title'] == 'المواعيد') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppointmentsPage()),
              );
            } else if (item['title'] == 'الموقع') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LocationPage()),
              );
            } else if (item['title'] == 'الحالة الصحية') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HealthStatusPage()),
              );
            } else if (item['title'] == 'بيانات كبير السن') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SeniorDataPage()),
              );
            } else if (item['title'] == 'متابعة الحالة الصحية') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ActivityLogPage()),
              );
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorderColor, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 32,
                  color: item['iconColor'] as Color,
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'] as String,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. زر تحديث البيانات الحقيقي (بدون أي أشرطة سفلية منبثقة)
  Widget _buildBottomActionButtons(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.mainColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.mainColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _isRefreshing ? null : _refreshRealData,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isRefreshing ? 'جاري التحديث الفعلي...' : 'تحديث البيانات',
                style: GoogleFonts.cairo(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              _isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.sync_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
