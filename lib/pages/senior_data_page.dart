import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/widgets/custom_app_bar.dart';
import '../core/widgets/senior_selector_widget.dart';
import '../core/services/senior_manager.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/models/senior_model.dart';
import 'location_page.dart';
import 'medicines_page.dart';

class SeniorDataPage extends StatefulWidget {
  const SeniorDataPage({super.key});

  @override
  State<SeniorDataPage> createState() => _SeniorDataPageState();
}

class _SeniorDataPageState extends State<SeniorDataPage> {
  bool _fallDetectionEnabled = true;
  bool _autoVitalsEnabled = true;
  bool _gpsTrackingEnabled = true;
  bool _isSyncing = false;
  String _careType = 'رعاية صحية ومتابعة دورية';
  bool _isLoadingCareType = false;

  @override
  void initState() {
    super.initState();
    _loadCareType();
    SeniorManager().addListener(_onSeniorChanged);
  }

  @override
  void dispose() {
    SeniorManager().removeListener(_onSeniorChanged);
    super.dispose();
  }

  void _onSeniorChanged() {
    _loadCareType();
  }

  Future<void> _loadCareType() async {
    if (!SeniorManager().hasSeniors) return;
    final senior = SeniorManager().currentSenior;
    final int? seniorId = int.tryParse(senior.id);
    if (seniorId == null) return;

    if (mounted) setState(() => _isLoadingCareType = true);
    try {
      final list = await ApiService.instance.getTypeOfCare(elderlyId: seniorId);
      if (mounted && list.isNotEmpty) {
        setState(() {
          _careType = list.first['Care_Type']?.toString() ?? 'رعاية صحية ومتابعة دورية';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر جلب نوع الرعاية. يرجى التحقق من اتصال الشبكة.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCareType = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.mainColor,
        appBar: CustomSubAppBar(
          title: 'ملفات كبار السن',
          height: 95,
          trailing: IconButton(
            onPressed: () => _showOptionsMenu(context),
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
            tooltip: 'خيارات',
          ),
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
                final senior = SeniorManager().currentSenior;

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
                              Icons.person_off_outlined,
                              size: 70,
                              color: AppColors.mainColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'لا يوجد ملف لكبير سن مسجل',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'لم تقم بربط أي كبير سن بحسابك بعد. يمكنك ربط كبير السن للبدء في إدارة ومتابعة ملفه الصحي والشخصي والأدوية.',
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

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // محدد كبير السن للتبديل بين الملفات
                      const SeniorSelectorWidget(showAddButton: false),

                      const SizedBox(height: 16),

                      // 1. صورة الأفاتار والاسم وصلة القرابة
                      _buildHeaderProfileSection(senior),

                      const SizedBox(height: 16),

                      // 2. كارت المعلومات الشخصية
                      _buildPersonalInfoCard(senior),

                      const SizedBox(height: 14),

                      // 3. كارت نوع وخطة الرعاية المخصص (type_of_care)
                      _buildCareTypeCard(context, senior),

                      const SizedBox(height: 14),

                      // 4. كارت الحالة الصحية والأمراض المزمنة
                      _buildHealthConditionCard(senior),

                      const SizedBox(height: 14),

                      // 4. كارت الأدوية الحالية
                      _buildCurrentMedicationsCard(senior),

                      // 5. قسم الساعة والأجهزة الذكية المتصلة (لا تظهر الحاوية نهائياً عند عدم وجود ساعة ذكية مرتبطة)
                      if (senior.watchConnected &&
                          senior.watchModel.isNotEmpty &&
                          senior.watchModel != 'غير مقترنة') ...[
                        _buildConnectedWatchAndDevicesSection(context, senior),
                        const SizedBox(height: 14),
                      ],

                      const SizedBox(height: 20),

                      // 6. زر تعديل البيانات
                      _buildEditDataButton(context, senior),

                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // 1. قسم الصورة والاسم
  Widget _buildHeaderProfileSection(SeniorModel senior) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mainColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  senior.gender == 'أنثى' ? Icons.face_3 : Icons.face,
                  size: 60,
                  color: AppColors.mainColor,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondaryTeal,
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            senior.name,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.mainColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'صلة القرابة: ${senior.relationship} (${senior.age} سنة)',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppColors.mainColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. كارت المعلومات الشخصية
  Widget _buildPersonalInfoCard(SeniorModel senior) {
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
              const Icon(Icons.person_outline, color: AppColors.mainColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'البيانات الشخصية',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.cardBorderColor),
          const SizedBox(height: 10),
          _buildInfoRow('الاسم الكامل', senior.name),
          _buildInfoRow('صلة القرابة', senior.relationship),
          _buildInfoRow('العمر والجنس', '${senior.age} سنة (${senior.gender})'),
          _buildInfoRow('فصيلة الدم', senior.bloodType),
          _buildInfoRow('العنوان السكني', senior.location),
        ],
      ),
    );
  }

  // كارت نوع وخطة الرعاية المخصص (type_of_care)
  Widget _buildCareTypeCard(BuildContext context, SeniorModel senior) {
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
              Row(
                children: [
                  const Icon(Icons.volunteer_activism_outlined,
                      color: AppColors.secondaryTeal, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'خطة ونوع الرعاية',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showEditCareTypeSheet(context, senior),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note,
                          size: 18, color: AppColors.mainColor),
                      const SizedBox(width: 4),
                      Text(
                        'تعديل',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mainColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.cardBorderColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.mainColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.mainColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingCareType)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.mainColor,
                        ),
                      )
                    else
                      const Icon(Icons.verified_outlined,
                          size: 16, color: AppColors.mainColor),
                    const SizedBox(width: 6),
                    Text(
                      _careType,
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'نوع الرعاية محدد في النظام لمتابعة احتياجات كبير السن الطبية واليومية وتوجيه الخدمات المخصصة.',
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCareTypeSheet(BuildContext context, SeniorModel senior) {
    final int? seniorId = int.tryParse(senior.id);
    final int? caregiverId = AuthService().userId;
    final options = [
      'رعاية صحية وتمريضية شاملة',
      'متابعة أدوية وعلامات حيوية',
      'مرافقة وإشراف يومي واجتماعي',
      'علاج طبيعي وتأهيل حركي',
      'رعاية خفيفة ومتابعة دورية',
    ];
    String selected = _careType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                      'تحديد نوع وخطة الرعاية',
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اختر خطة الرعاية المناسبة لكبير السن (${senior.name}):',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...options.map((opt) {
                      final isSelected = selected == opt;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected
                              ? AppColors.mainColor
                              : Colors.grey,
                        ),
                        title: Text(
                          opt,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.mainColor
                                : AppColors.textColor,
                          ),
                        ),
                        onTap: () {
                          setSheetState(() => selected = opt);
                        },
                      );
                    }),
                    const SizedBox(height: 16),
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
                          Navigator.pop(ctx);
                          setState(() {
                            _careType = selected;
                          });
                          await ApiService.instance.addTypeOfCare(
                            careType: selected,
                            caregiverId: caregiverId,
                            elderlyId: seniorId,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تم تحديث نوع الرعاية بنجاح في قاعدة البيانات',
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
                          }
                        },
                        child: Text(
                          'حفظ نوع الرعاية',
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

  // 4. كارت الحالة الصحية
  Widget _buildHealthConditionCard(SeniorModel senior) {
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
              const Icon(Icons.health_and_safety_outlined, color: Color(0xFFE53935), size: 20),
              const SizedBox(width: 8),
              Text(
                'الحالة الصحية والأمراض المزمنة',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.cardBorderColor),
          const SizedBox(height: 10),
          _buildInfoRow('حالة الاستقرار', senior.healthStatus),
          _buildInfoRow('الأمراض المزمنة', senior.chronicDiseases.join('، ')),
          _buildInfoRow('الحساسية الدوائية', senior.allergies),
          _buildInfoRow('الطبيب المتابع', '${senior.doctorName} (${senior.hospital})'),
        ],
      ),
    );
  }

  // 4. كارت الأدوية
  Widget _buildCurrentMedicationsCard(SeniorModel senior) {
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
              Row(
                children: [
                  const Icon(Icons.medication_outlined, color: AppColors.mainColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'الأدوية اليومية والجرعات',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainColor,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MedicinesPage()),
                  );
                },
                child: Text('جدول الأدوية', style: GoogleFonts.cairo(fontSize: 12, color: AppColors.mainColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.cardBorderColor),
          const SizedBox(height: 10),
          if (senior.criticalMedications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'لا توجد أدوية مسجلة',
                style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            ...senior.criticalMedications.map(
              (med) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: AppColors.secondaryTeal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        med,
                        style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 5. قسم الساعة والأجهزة الذكية المتصلة
  Widget _buildConnectedWatchAndDevicesSection(BuildContext context, SeniorModel senior) {
    final bool hasWatch = senior.watchConnected && senior.watchModel.isNotEmpty && senior.watchModel != 'غير مقترنة';
    final batteryColor = senior.watchBattery > 20 ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الكارت: أيقونة الساعة + العنوان + حالة الاتصال
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.watch_outlined, color: AppColors.mainColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'الساعة والأجهزة الذكية',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainColor,
                    ),
                  ),
                ],
              ),
              // شارة الاتصال
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasWatch ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: hasWatch ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasWatch ? 'متصلة الآن' : 'غير متصلة',
                      style: GoogleFonts.cairo(
                        color: hasWatch ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.cardBorderColor),
          const SizedBox(height: 14),

          if (!hasWatch) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorderColor.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.watch_off_outlined,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لا توجد ساعة ذكية مقترنة حالياً',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'يمكنك إقران ساعة ذكية لمتابعة المؤشرات الحيوية ومستشعر السقوط وتحديد الموقع.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showManageWatchDialog(context, senior),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_link, size: 18, color: Colors.white),
                    label: Text(
                      'إقران ساعة ذكية الآن',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[

          // تفاصيل الساعة: الاسم ومؤشر البطارية
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorderColor.withValues(alpha: 0.6)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bluetooth_connected, size: 18, color: AppColors.secondaryTeal),
                        const SizedBox(width: 6),
                        Text(
                          senior.watchModel,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          senior.watchBattery > 20 ? Icons.battery_charging_full : Icons.battery_alert,
                          size: 18,
                          color: batteryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${senior.watchBattery}% شحن',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: batteryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // شريط البطارية
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: senior.watchBattery / 100.0,
                    minHeight: 6,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // كبسولة رمز الاقتران (Pairing Code) مع زر النسخ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'رمز الاقتران بالساعة:',
                      style: GoogleFonts.cairo(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      (senior.pairingCode.isEmpty ||
                              senior.pairingCode == '——' ||
                              senior.pairingCode == '------')
                          ? 'غير متوفر'
                          : senior.pairingCode,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.copy, size: 17, color: AppColors.mainColor),
                  tooltip: 'نسخ الرمز',
                  onPressed: () {
                    final code = senior.pairingCode;
                    if (code.isEmpty || code == '——' || code == '------') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'لا يوجد رمز اقتران متاح للنسخ (غير متوفر من الخادم).',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: Colors.orange.shade800,
                        ),
                      );
                      return;
                    }
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم نسخ رمز الاقتران: $code',
                          style: GoogleFonts.cairo(),
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.mainColor,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // أزرار التحكم السريعة بالساعة (رنين + مزامنة)
          Row(
            children: [
              // زر رنين الساعة
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.mainColor, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: Colors.white),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'جاري إرسال إشارة الرنين إلى ${senior.watchModel}... 🔔',
                                style: GoogleFonts.cairo(),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFFE65100),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  icon: const Icon(Icons.ring_volume_outlined, size: 18, color: AppColors.mainColor),
                  label: Text(
                    'رنين الساعة',
                    style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.mainColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // زر إعادة المزامنة
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: AppColors.secondaryTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSyncing
                      ? null
                      : () async {
                          setState(() => _isSyncing = true);
                          await Future.delayed(const Duration(seconds: 1));
                          if (context.mounted) {
                            setState(() => _isSyncing = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'تمت مزامنة بيانات الساعة بنجاح! ⏱️',
                                  style: GoogleFonts.cairo(),
                                ),
                                backgroundColor: const Color(0xFF2E7D32),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync, size: 18, color: Colors.white),
                  label: Text(
                    _isSyncing ? 'جاري...' : 'مزامنة الآن',
                    style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // خيارات الحماية والتنبيهات المتقدمة للساعة
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorderColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات الأمان التلقائية للساعة:',
                  style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.mainColor),
                ),
                const SizedBox(height: 6),
                _buildWatchSettingSwitch(
                  title: 'اكتشاف السقوط التلقائي (Fall Alert)',
                  subtitle: 'إطلاق نداء طوارئ فوري عند رصد سقوط مفاجئ',
                  value: _fallDetectionEnabled,
                  onChanged: (val) => setState(() => _fallDetectionEnabled = val),
                ),
                const Divider(height: 1, color: AppColors.cardBorderColor),
                _buildWatchSettingSwitch(
                  title: 'القياس الدوري للمؤشرات الحيوية',
                  subtitle: 'قياس النبض ونسبة الأكسجين كل 15 دقيقة',
                  value: _autoVitalsEnabled,
                  onChanged: (val) => setState(() => _autoVitalsEnabled = val),
                ),
                const Divider(height: 1, color: AppColors.cardBorderColor),
                _buildWatchSettingSwitch(
                  title: 'التتبع اللحظي عبر GPS',
                  subtitle: 'تحديث موقع كبير السن على الخريطة باستمرار',
                  value: _gpsTrackingEnabled,
                  onChanged: (val) => setState(() => _gpsTrackingEnabled = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // زر إدارة أو فك ارتباط الساعة
          Center(
            child: TextButton.icon(
              onPressed: () => _showManageWatchDialog(context, senior),
              icon: const Icon(Icons.settings_outlined, size: 16, color: AppColors.textSecondary),
              label: Text(
                'إدارة اتصال الساعة أو ربط ساعة بديلة',
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildWatchSettingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textColor)),
                Text(subtitle, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.mainColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showManageWatchDialog(BuildContext context, SeniorModel senior) {
    final modelController = TextEditingController(text: senior.watchModel);
    final codeController = TextEditingController(text: senior.pairingCode);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'إدارة الساعة الذكية',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.mainColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: modelController,
              decoration: const InputDecoration(labelText: 'اسم/موديل الساعة'),
              style: GoogleFonts.cairo(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'رمز الاقتران (Pairing Code)'),
              style: GoogleFonts.cairo(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mainColor),
            onPressed: () {
              // Watch pairing fields are not persisted by update_elderly API.
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'بيانات الساعة غير قابلة للمزامنة مع الخادم حالياً (مؤجّل). استخدم شاشة الأجهزة لتسجيل جهاز.',
                    style: GoogleFonts.cairo(),
                  ),
                  backgroundColor: Colors.orange.shade800,
                ),
              );
            },
            child: Text('حفظ التعديلات', style: GoogleFonts.cairo(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$title: ',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. زر تعديل البيانات
  Widget _buildEditDataButton(BuildContext context, SeniorModel senior) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mainColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _showEditDialog(context, senior),
        icon: const Icon(Icons.edit_note, color: Colors.white, size: 22),
        label: Text(
          'تعديل بيانات ${senior.relationship}',
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, SeniorModel senior) {
    final nameController = TextEditingController(text: senior.name);
    final phoneController = TextEditingController(text: senior.phoneNumber);
    String selectedGender = senior.gender;
    final relationController = TextEditingController(text: senior.relationship);
    final ageController = TextEditingController(text: senior.age.toString());
    final locationController = TextEditingController(text: senior.location);
    final doctorController = TextEditingController(text: senior.doctorName);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(
              'تعديل بيانات كبير السن',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.mainColor),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'الاسم الكامل (E_Name)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف (E_PhonNumber)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGender,
                    decoration: const InputDecoration(labelText: 'الجنس (E_sex)'),
                    items: const [
                      DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                      DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedGender = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: relationController,
                    decoration: const InputDecoration(labelText: 'صلة القرابة'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'العمر'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: doctorController,
                    decoration: const InputDecoration(labelText: 'الطبيب المتابع'),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final updated = senior.copyWith(
                    name: nameController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    gender: selectedGender,
                    relationship: relationController.text.trim(),
                    age: int.tryParse(ageController.text.trim()) ?? senior.age,
                    location: locationController.text.trim(),
                    doctorName: doctorController.text.trim(),
                  );
                  final ok = await SeniorManager().updateSenior(senior.id, updated);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'تم تحديث البيانات بنجاح'
                            : 'تعذّر حفظ التعديلات على الخادم',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: ok ? AppColors.mainColor : Colors.red.shade700,
                    ),
                  );
                },
              child: Text(
                'حفظ التعديلات',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: AppColors.mainColor),
                title: Text('عرض الموقع المباشر لكبير السن', style: GoogleFonts.cairo()),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.medication_outlined, color: AppColors.mainColor),
                title: Text('عرض جدول الأدوية', style: GoogleFonts.cairo()),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicinesPage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
