import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class DateFilterItem {
  final String title;
  final IconData icon;

  const DateFilterItem({
    required this.title,
    required this.icon,
  });
}

/// كارد وقائمة تصفية التاريخ الموحدة بألوان وتصميم التطبيق
class DateFilterDropdown extends StatelessWidget {
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final List<DateFilterItem> items;

  const DateFilterDropdown({
    super.key,
    required this.selectedValue,
    required this.onSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<String>(
        color: AppColors.cardColor,
        surfaceTintColor: AppColors.cardColor,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorderColor, width: 1),
        ),
        constraints: const BoxConstraints(minWidth: 135, maxWidth: 165),
        offset: const Offset(0, 32),
        onSelected: onSelected,
        itemBuilder: (context) => items.map((item) {
          final isSelected = selectedValue == item.title;
          return PopupMenuItem<String>(
            value: item.title,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 15,
                  color: isSelected ? AppColors.mainColor : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppColors.mainColor : AppColors.textColor,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: AppColors.mainColor,
                  ),
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded, color: AppColors.mainColor, size: 15),
              const SizedBox(width: 5),
              Text(
                selectedValue,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainColor,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
