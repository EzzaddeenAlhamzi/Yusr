import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/custom_bottom_nav_bar.dart';
import '../core/services/senior_manager.dart';
import '../core/services/auth_service.dart';
import '../core/services/api_service.dart';

class ProfilePageCaregiver extends StatefulWidget {
  final bool showBottomNav;
  final bool isEmbedded;

  const ProfilePageCaregiver({
    super.key,
    this.showBottomNav = true,
    this.isEmbedded = false,
  });

  @override
  State<ProfilePageCaregiver> createState() => _ProfilePageCaregiverState();
}

class _ProfilePageCaregiverState extends State<ProfilePageCaregiver> {
  int _selectedTabIndex = 0; // 0: Main, 1: Account, 2: Settings

  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;
  String _selectedLanguage = 'العربية';

  String _caregiverName = 'مقدم الرعاية';
  String _caregiverPhone = 'غير مسجل';
  String _caregiverEmail = 'غير مسجل';
  String _relationship = 'مشرف';

  @override
  void initState() {
    super.initState();
    _caregiverName = AuthService().userName ?? 'مقدم الرعاية';
    _caregiverPhone = AuthService().userPhone ?? 'غير مسجل';
    _caregiverEmail = AuthService().userEmail ?? 'غير مسجل';
    _loadCaregiverData();
  }

  Future<void> _loadCaregiverData() async {
    try {
      final id = AuthService().userId;
      if (id != null) {
        final data = await ApiService.instance.getCaregiver(id);
        if (data != null && mounted) {
          setState(() {
            _caregiverName = data['C_Name']?.toString() ?? _caregiverName;
            _caregiverPhone = data['C_PhonNumber']?.toString() ?? _caregiverPhone;
            _caregiverEmail = data['C_Email']?.toString() ?? _caregiverEmail;
            _relationship = data['C_Relationship']?.toString() ?? _relationship;
          });
          AuthService().setCaregiverSession(
            id: id,
            name: _caregiverName,
            phone: _caregiverPhone,
            email: _caregiverEmail,
            linkedElderlyId: data['Eldery_ID'] != null ? int.tryParse(data['Eldery_ID'].toString()) : AuthService().linkedElderlyId,
          );
        }
      }
    } catch (_) {}
  }

  void _showEditCaregiverDialog() {
    final nameCtrl = TextEditingController(text: _caregiverName);
    final phoneCtrl = TextEditingController(text: _caregiverPhone == 'غير مسجل' ? '' : _caregiverPhone);
    final emailCtrl = TextEditingController(text: _caregiverEmail == 'غير مسجل' ? '' : _caregiverEmail);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تعديل الملف الشخصي',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    labelStyle: GoogleFonts.cairo(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                final newPhone = phoneCtrl.text.trim();
                final newEmail = emailCtrl.text.trim();
                if (newName.isNotEmpty) {
                  final navigator = Navigator.of(ctx);
                  setState(() {
                    _caregiverName = newName;
                    if (newPhone.isNotEmpty) _caregiverPhone = newPhone;
                    if (newEmail.isNotEmpty) _caregiverEmail = newEmail;
                  });
                  final id = AuthService().userId;
                  if (id != null) {
                    await ApiService.instance.updateCaregiver(
                      caregiverId: id,
                      name: newName,
                      phone: newPhone.isNotEmpty ? newPhone : _caregiverPhone,
                      email: newEmail.isNotEmpty ? newEmail : _caregiverEmail,
                      relationship: _relationship,
                    );
                    if (!mounted) return;
                    AuthService().setCaregiverSession(
                      id: id,
                      name: newName,
                      phone: newPhone.isNotEmpty ? newPhone : _caregiverPhone,
                      email: newEmail.isNotEmpty ? newEmail : _caregiverEmail,
                    );
                  }
                  if (!ctx.mounted) return;
                  navigator.pop();
                }
              },
              child: Text('حفظ', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: CustomSubAppBar(
        title: 'الملف الشخصي',
        showBackButton: !widget.isEmbedded,
        onBack: () {
          if (widget.isEmbedded) {
            CaregiverNavNotifier.switchTo(context, 0);
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            CaregiverNavNotifier.switchTo(context, 0);
          }
        },
        height: 95.0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم نسخ رابط الملف الشخصي',
                    style: GoogleFonts.cairo(color: Colors.white),
                  ),
                  backgroundColor: AppColors.mainColor,
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? customBottomNavigationBar(
              context: context,
              currentIndex: 2,
              onTap: (index) {
                CaregiverNavNotifier.switchTo(context, index);
              },
            )
          : null,
      body: CurvedBodyContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildTabSelector(),
              const SizedBox(height: 20),
              if (_selectedTabIndex == 0) _buildMainProfileContent(),
              if (_selectedTabIndex == 1) _buildAccountDetailsContent(),
              if (_selectedTabIndex == 2) _buildAppSettingsContent(),
              const SizedBox(height: 24),
              _buildLogoutButton(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return ListenableBuilder(
      listenable: SeniorManager(),
      builder: (context, _) {
        final seniorsCount = SeniorManager().seniors.length;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorderColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showEditCaregiverDialog,
                child: Stack(
                  children: [
                    Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mainColor.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 45,
                        color: AppColors.mainColor,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondaryTeal,
                        ),
                        child: const Icon(Icons.edit, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: _showEditCaregiverDialog,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _caregiverName,
                              style: GoogleFonts.cairo(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_outlined, size: 16, color: AppColors.mainColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.mainColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          seniorsCount == 0
                              ? 'غير مرتبط بكبير سن حالياً'
                              : 'مقدم رعاية لـ $seniorsCount من كبار السن',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mainColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'حساب مقدم الرعاية المعتمد',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildTabItem(0, 'الرئيسية', Icons.dashboard_outlined),
          _buildTabItem(1, 'الحساب', Icons.person_outline),
          _buildTabItem(2, 'الإعدادات', Icons.settings_outlined),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.mainColor : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.mainColor : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainProfileContent() {
    return ListenableBuilder(
      listenable: SeniorManager(),
      builder: (context, _) {
        final seniors = SeniorManager().seniors;

        return Column(
          children: [
            // كارت كبار السن المشمولين بالرعاية
            _buildSectionCard(
              title: 'كبار السن المشمولون بالرعاية (${seniors.length})',
              children: [
                if (seniors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'لا يوجد كبار سن مضافين حالياً',
                        style: GoogleFonts.cairo(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  ...seniors.map(
                    (senior) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorderColor),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.mainColor.withValues(alpha: 0.1),
                              child: Icon(
                                senior.gender == 'أنثى' ? Icons.face_3 : Icons.face,
                                color: AppColors.mainColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${senior.relationship} (${senior.name})',
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textColor,
                                    ),
                                  ),
                                  Text(
                                    'رمز الربط: ${senior.pairingCode} • ${senior.watchModel}',
                                    style: GoogleFonts.cairo(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                senior.healthStatus,
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/link-senior');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.add_link, color: Colors.white, size: 20),
                    label: Text(
                      'ربط وإضافة كبير سن آخر',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'الوصول السريع للخدمات',
              children: [
                _buildMenuTile(
                  icon: Icons.person_search_outlined,
                  title: 'بيانات كبار السن',
                  subtitle: 'تعديل وعرض الملفات الصحية والطبية',
                  onTap: () => Navigator.pushNamed(context, '/senior-data'),
                ),
                const Divider(height: 1),
                _buildMenuTile(
                  icon: Icons.watch_outlined,
                  title: 'الساعات الذكية المرتبطة',
                  subtitle: 'إدارة وتتبع الساعات الذكية لكبار السن',
                  onTap: () => Navigator.pushNamed(context, '/devices'),
                ),
                const Divider(height: 1),
                _buildMenuTile(
                  icon: Icons.history,
                  title: 'سجل النشاطات',
                  subtitle: 'عرض كافة التحذيرات والأحداث السابقة',
                  onTap: () => Navigator.pushNamed(context, '/activity-log'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountDetailsContent() {
    return _buildSectionCard(
      title: 'بيانات الحساب الشخصي',
      children: [
        _buildInfoRow(
          icon: Icons.person_outline,
          title: 'الاسم الكامل',
          subtitle: _caregiverName,
          trailing: TextButton.icon(
            onPressed: _showEditCaregiverDialog,
            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.mainColor),
            label: Text('تعديل', style: GoogleFonts.cairo(color: AppColors.mainColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const Divider(height: 20),
        _buildInfoRow(
          icon: Icons.phone_outlined,
          title: 'رقم الجوال',
          subtitle: _caregiverPhone,
          trailing: TextButton.icon(
            onPressed: _showEditCaregiverDialog,
            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.mainColor),
            label: Text('تعديل', style: GoogleFonts.cairo(color: AppColors.mainColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const Divider(height: 20),
        _buildInfoRow(
          icon: Icons.email_outlined,
          title: 'البريد الإلكتروني',
          subtitle: _caregiverEmail,
          trailing: TextButton.icon(
            onPressed: _showEditCaregiverDialog,
            icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.mainColor),
            label: Text('تعديل', style: GoogleFonts.cairo(color: AppColors.mainColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const Divider(height: 20),
        _buildInfoRow(
          icon: Icons.verified_user_outlined,
          title: 'نوع الحساب',
          subtitle: 'مقدم رعاية مسجل في قاعدة البيانات',
        ),
      ],
    );
  }

  Widget _buildAppSettingsContent() {
    return Column(
      children: [
        _buildSectionCard(
          title: 'الإشعارات والتنبيهات',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.mainColor,
              title: Text(
                'تنبيهات الطوارئ الفورية',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textColor,
                ),
              ),
              subtitle: Text(
                'استقبال إشعارات عاجلة عند رصد سقوط أو استغاثة',
                style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val),
            ),
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.mainColor,
              title: Text(
                'الدخول بالبصمة / الوجه',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textColor,
                ),
              ),
              subtitle: Text(
                'حماية التطبيق بالقياسات الحيوية',
                style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: _biometricEnabled,
              onChanged: (val) => setState(() => _biometricEnabled = val),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'اللغة والتطبيق',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language, color: AppColors.mainColor),
              title: Text(
                'لغة التطبيق',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
              trailing: DropdownButton<String>(
                value: _selectedLanguage,
                underline: const SizedBox(),
                items: ['العربية', 'English']
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: GoogleFonts.cairo(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                },
              ),
            ),
            const Divider(height: 16),
            _buildMenuTile(
              icon: Icons.help_outline,
              title: 'مركز المساعدة والدعم الفني',
              subtitle: 'الأسئلة الشائعة والتواصل مع الدعم',
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildMenuTile(
              icon: Icons.privacy_tip_outlined,
              title: 'سياسة الخصوصية والشروط',
              subtitle: 'معلومات الأمان وحماية البيانات',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorderColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(icon, color: AppColors.mainColor, size: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(icon, color: AppColors.mainColor, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'تسجيل الخروج',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(),
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final result = await AuthService().logout();
                    if (!mounted) return;
                    if (!result.serverRevoked) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم تسجيل الخروج محلياً. تعذّر تأكيد إلغاء الجلسة على الخادم بسبب الشبكة.',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: Colors.orange.shade800,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                    navigator.pushNamedAndRemoveUntil(
                      '/welcome',
                      (route) => false,
                    );
                  },
                  child: Text(
                    'تسجيل الخروج',
                    style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.red.shade400),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(Icons.logout, color: Colors.red.shade600),
        label: Text(
          'تسجيل الخروج',
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade600,
          ),
        ),
      ),
    );
  }
}
