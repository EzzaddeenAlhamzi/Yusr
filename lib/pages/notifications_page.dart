import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/custom_bottom_nav_bar.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _selectedTab = 'الكل';
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchRealNotifications();
  }

  Future<void> _fetchRealNotifications() async {
    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      final list = await ApiService.instance.getNotifications(
        caregiverId: auth.isCaregiver ? auth.userId : null,
        elderlyId: auth.isCaregiver ? auth.linkedElderlyId : auth.userId,
      );

      final mapped = list.map((item) {
        final String title = (item['N_Title'] ?? 'تنبيه جديد').toString();
        final String message = (item['N_Message'] ?? '').toString();
        final String type = (item['N_Type'] ?? 'alert').toString().toLowerCase();
        final String status = (item['N_Status'] ?? 'unread').toString();
        final String date = (item['N_Date'] ?? '').toString();
        final String time = (item['N_Time'] ?? '').toString();
        final String timeFormatted =
            date.isNotEmpty || time.isNotEmpty ? '$date $time'.trim() : 'الآن';

        IconData icon = Icons.notifications_active_outlined;
        if (type.contains('med') || type.contains('دواء')) {
          icon = Icons.medication;
        } else if (type.contains('service') || type.contains('خدمة')) {
          icon = Icons.medical_services_outlined;
        } else if (type.contains('health') ||
            type.contains('صحة') ||
            type.contains('قلب')) {
          icon = Icons.favorite_border;
        } else if (type.contains('sos') || type.contains('طوارئ')) {
          icon = Icons.sos;
        } else if (type.contains('loc') || type.contains('موقع')) {
          icon = Icons.location_on;
        }

        return {
          'id': item['Notifications_ID'],
          'title': title,
          'detail': message,
          'time': timeFormatted,
          'subText': type,
          'type': type,
          'icon': icon,
          'isUnread': status == 'unread' || status == 'جديد',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _notifications = mapped;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل الإشعارات. يرجى التحقق من اتصال الشبكة والخادم.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _selectedTab == 'غير المقروءة'
        ? _notifications.where((n) => n['isUnread'] == true).toList()
        : _notifications;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.mainColor,
        appBar: const CustomSubAppBar(
          title: 'الإشعارات',
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
            child: RefreshIndicator(
              onRefresh: _fetchRealNotifications,
              color: AppColors.mainColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // 1. Tab Switcher
                    _buildTabSwitcher(),

                    const SizedBox(height: 16),

                    // 2. قائمة التنبيهات
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mainColor,
                          ),
                        ),
                      )
                    else if (filteredList.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 50, horizontal: 20),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.mainColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 48,
                                color: AppColors.mainColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد إشعارات حالياً',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ستظهر هنا الإشعارات والتنبيهات المباشرة الواردة من قاعدة البيانات.',
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
                        itemCount: filteredList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          return _buildNotificationCard(item);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: customBottomNavigationBar(
          context: context,
          currentIndex: 0,
          onTap: (index) {
            if (index == 0) {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = 'غير المقروءة';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _selectedTab == 'غير المقروءة'
                        ? AppColors.mainColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'غير المقروءة',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _selectedTab == 'غير المقروءة'
                          ? Colors.white
                          : AppColors.mainColor,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = 'الكل';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _selectedTab == 'الكل'
                        ? AppColors.mainColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'الكل',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _selectedTab == 'الكل'
                          ? Colors.white
                          : AppColors.mainColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final String title = item['title'] ?? '';
    final String detail = item['detail'] ?? item['location'] ?? '';
    final String time = item['time'] ?? '';
    final String subText = item['subText'] ?? '';
    final IconData icon = item['icon'] ?? Icons.notifications;

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
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: const Color(0xFFD32F2F),
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainColor,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    subText,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD32F2F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.cardBorderColor),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // تبديل حالة القراءة
              InkWell(
                onTap: () {
                  setState(() {
                    item['isUnread'] = !(item['isUnread'] as bool);
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (item['isUnread'] as bool)
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (item['isUnread'] as bool) ? 'تحديد كمقروء' : 'غير مقروء',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // زر حذف الإشعار
              IconButton(
                onPressed: () => _confirmDeleteNotification(context, item),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Color(0xFFD32F2F),
                ),
                tooltip: 'حذف',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNotification(
      BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFD32F2F), size: 24),
              const SizedBox(width: 8),
              Text(
                'حذف الإشعار',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف هذا الإشعار؟',
            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _notifications.remove(item);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حذف الإشعار بنجاح',
                      style: GoogleFonts.cairo(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFFD32F2F),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
              ),
              child: Text(
                'حذف',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
