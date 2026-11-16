import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

/// الشريط العلوي الموحد (CustomTopBar) للصفحات الفرعية
class CustomTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final bool? showBack;
  final bool showBackButton;
  final Widget? trailing;
  final Widget? leading;
  final List<Widget>? actions;
  final Color backgroundColor;
  final Color titleColor;
  final double height;

  const CustomTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.showBack,
    this.showBackButton = true,
    this.trailing,
    this.leading,
    this.actions,
    this.backgroundColor = AppColors.mainColor,
    this.titleColor = Colors.white,
    this.height = 65.0,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final effectiveShowBack = (showBack ?? showBackButton);

    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && actions != null && actions!.isNotEmpty) {
      effectiveLeading = Row(
        mainAxisSize: MainAxisSize.min,
        children: actions!,
      );
    }

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // الجانب الأيمن / الإجراءات
          if (effectiveLeading != null)
            effectiveLeading
          else if (trailing != null)
            trailing!
          else
            const SizedBox(width: 44),

          // العنوان بالمنتصف
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                color: titleColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // زر الرجوع في اليسار
          if (effectiveShowBack)
            IconButton(
              icon: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 26,
              ),
              onPressed: onBack ?? () => Navigator.maybePop(context),
              tooltip: 'رجوع',
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// ويدجت الحاوية المنحنية لجسم الصفحة
class CurvedBodyContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color color;
  final EdgeInsetsGeometry padding;

  const CurvedBodyContainer({
    super.key,
    required this.child,
    this.radius = 28.0,
    this.color = AppColors.backgroundColor,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
