import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../models/senior_model.dart';
import '../services/senior_manager.dart';

class SeniorSelectorWidget extends StatelessWidget {
  final VoidCallback? onAddSenior;
  final bool showAddButton;

  const SeniorSelectorWidget({
    super.key,
    this.onAddSenior,
    this.showAddButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SeniorManager(),
      builder: (context, _) {
        final manager = SeniorManager();
        final seniors = manager.seniors;
        final selectedIndex = manager.selectedIndex;

        return SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: seniors.length + (showAddButton ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index < seniors.length) {
                final senior = seniors[index];
                final isSelected = index == selectedIndex;

                return InkWell(
                  onTap: () => manager.selectSenior(index),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.mainColor : AppColors.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? AppColors.mainColor : AppColors.cardBorderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          senior.gender == 'أنثى' ? Icons.face_3 : Icons.face,
                          size: 18,
                          color: isSelected ? Colors.white : AppColors.mainColor,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              senior.relationship.isNotEmpty
                                  ? '${senior.relationship} (${senior.name.split(' ').first})'
                                  : senior.name.split(' ').first,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.textColor,
                              ),
                            ),
                          ],
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle, size: 14, color: Colors.white),
                        ],
                      ],
                    ),
                  ),
                );
              } else {
                // زر إضافة كبير سن جديد
                return InkWell(
                  onTap: () {
                    if (onAddSenior != null) {
                      onAddSenior!();
                    } else {
                      showAddNewSeniorModal(context);
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_circle,
                          color: AppColors.secondaryTeal,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'إضافة كبير سن',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  static void showAddNewSeniorModal(BuildContext context) {
    final nameController = TextEditingController();
    final relationController = TextEditingController();
    final ageController = TextEditingController();
    String selectedBlood = 'O+';
    String selectedGender = 'ذكر';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'إضافة كبير سن جديد للمتابعة',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainColor,
                      ),
                    ),
                    Text(
                      'أدخل البيانات الأساسية لربط الساعة الذكية ومتابعة الحالة',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // الاسم
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل لكبير السن',
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.mainColor),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // صلة القرابة والعمر
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: relationController,
                            decoration: const InputDecoration(
                              labelText: 'صلة القرابة (الوالد، الجدة...)',
                              prefixIcon: Icon(Icons.family_restroom, color: AppColors.mainColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'العمر',
                              prefixIcon: Icon(Icons.cake_outlined, color: AppColors.mainColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // الجنس وفصيلة الدم
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedGender,
                                isExpanded: true,
                                items: ['ذكر', 'أنثى']
                                    .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e, style: GoogleFonts.cairo(fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedGender = val);
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cardBorderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedBlood,
                                isExpanded: true,
                                items: ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-']
                                    .map((e) => DropdownMenuItem(
                                          value: e,
                                          child: Text('فصيلة $e', style: GoogleFonts.cairo(fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedBlood = val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // زر الحفظ والإضافة
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final name = nameController.text.trim();
                          final relation = relationController.text.trim();
                          final age = int.tryParse(ageController.text.trim()) ?? 70;

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('يرجى إدخال اسم كبير السن', style: GoogleFonts.cairo()),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final newSenior = SeniorModel(
                            id: 'senior_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            relationship: relation.isNotEmpty ? relation : 'قريب',
                            age: age,
                            bloodType: selectedBlood,
                            gender: selectedGender,
                            healthStatus: 'مستقر',
                            chronicDiseases: [],
                            allergies: 'لا توجد حساسية مسجلة',
                            criticalMedications: [],
                            doctorName: 'طبيب الرعاية الأولية',
                            hospital: 'المركز الصحي',
                            location: 'الموقع غير محدد',
                            nextTask: 'لا توجد مهام مسجلة',
                            nextTaskTime: '--:--',
                            pairingCode: 'YS-${(1000 + (DateTime.now().millisecondsSinceEpoch % 9000))}',
                            watchModel: '',
                            watchBattery: 0,
                            watchConnected: false,
                          );

                          SeniorManager().addSenior(newSenior);
                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تمت إضافة $name بنجاح إلى قائمة الرعاية 🌟',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: AppColors.secondaryTeal,
                            ),
                          );
                        },
                        child: Text(
                          'حفظ وإضافة كبير السن',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
