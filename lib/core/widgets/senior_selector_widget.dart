import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
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

  /// Honest add path: linking requires a server code — never invent local seniors.
  static void showAddNewSeniorModal(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'لربط كبير سن استخدم رمز الربط من حسابه (لا تُضاف سجلات محلية وهمية).',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: AppColors.mainColor,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.of(context).pushNamed('/link-senior');
  }
}
