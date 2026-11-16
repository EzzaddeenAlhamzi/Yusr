import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

const double kAppBarHeight = 96.0;
const double kDefaultAppBarHeight = 95.0;
const double kMainAppBarHeight = 100.0;
const double kAppBarRadius = 24.0;

/// ويدجت الشريط العلوي المخصص (AppBar) مع العنوان وزر الرجوع
class CustomTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final bool showBack;
  final Color backgroundColor;
  final Color titleColor;

  const CustomTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.showBack = true,
    this.backgroundColor = appbarColor,
    this.titleColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: titleColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (showBack)
                Positioned(
                  left: -12,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: titleColor,
                      size: 26,
                    ),
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شريط علوي مخصص ومتجاوب للصفحة الرئيسية لمقدم الرعاية
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Color backgroundColor;
  final Color titleColor;
  final double height;
  final double radius;
  final TextStyle? titleStyle;
  final bool showProfile;
  final Widget? profileWidget;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onProfileTap;

  const CustomAppBar({
    super.key,
    this.title = 'مرحباً بك',
    this.leading,
    this.trailing,
    this.backgroundColor = AppColors.mainColor,
    this.titleColor = Colors.white,
    this.height = kMainAppBarHeight,
    this.radius = 0,
    this.titleStyle,
    this.showProfile = true,
    this.profileWidget,
    this.onNotificationTap,
    this.onMenuTap,
    this.onProfileTap,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final effectiveTitleStyle = titleStyle ??
        GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: titleColor,
        );

    // القسم الأيمن في الاتجاه العربي (صورة الملف الشخصي مع نص مرحباً بك)
    final defaultRightSection = GestureDetector(
      onTap: onProfileTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProfile) ...[
            profileWidget ??
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.mainColor,
                    size: 26,
                  ),
                ),
            const SizedBox(width: 10),
          ],
          Text(title, style: effectiveTitleStyle),
        ],
      ),
    );

    // القسم الأيسر في الاتجاه العربي (أيقونة الإشعارات وأيقونة القائمة في أقصى اليسار)
    final defaultLeftSection = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          splashRadius: 22,
          onPressed: onNotificationTap,
          icon: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 26,
          ),
          tooltip: 'الإشعارات',
        ),
        const SizedBox(width: 6),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          splashRadius: 22,
          onPressed: () {
            if (onMenuTap != null) {
              onMenuTap!();
            } else {
              final scaffold = Scaffold.maybeOf(context);
              if (scaffold?.hasEndDrawer == true) {
                scaffold?.openEndDrawer();
              } else {
                scaffold?.openDrawer();
              }
            }
          },
          icon: const Icon(
            Icons.menu_rounded,
            color: Colors.white,
            size: 28,
          ),
          tooltip: 'القائمة',
        ),
      ],
    );

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: radius > 0
            ? BorderRadius.only(
                bottomLeft: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              trailing ?? defaultRightSection,
              leading ?? defaultLeftSection,
            ],
          ),
        ),
      ),
    );
  }
}

/// دالة مساعدة لإنشاء الشريط العلوي بتوافقية تامة
PreferredSizeWidget customAppBar({
  String title = 'مرحبا بك',
  Color backgroundColor = AppColors.mainColor,
  Color titleColor = Colors.white,
  double height = kMainAppBarHeight,
  double radius = 0,
  bool showProfile = true,
  VoidCallback? onNotificationTap,
  VoidCallback? onMenuTap,
  VoidCallback? onProfileTap,
  Widget? leading,
  Widget? trailing,
}) {
  return CustomAppBar(
    title: title,
    backgroundColor: backgroundColor,
    titleColor: titleColor,
    height: height,
    radius: radius,
    showProfile: showProfile,
    onNotificationTap: onNotificationTap,
    onMenuTap: onMenuTap,
    onProfileTap: onProfileTap,
    leading: leading,
    trailing: trailing,
  );
}

/// شريط علوي موحد وكبير واحترافي للصفحات الفرعية
class CustomSubAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final List<Widget>? actions;
  final Color backgroundColor;
  final Color titleColor;
  final double height;
  final double radius;
  final bool showBack;
  final bool showBackButton;

  const CustomSubAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.actions,
    this.backgroundColor = AppColors.mainColor,
    this.titleColor = Colors.white,
    this.height = kDefaultAppBarHeight,
    this.radius = 0,
    this.showBack = true,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final effectiveShowBack = showBack && showBackButton;
    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && actions != null && actions!.isNotEmpty) {
      effectiveTrailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: actions!,
      );
    }

    return Container(
      height: height,
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // زر أو عنصر اختياري على اليمين في RTL (مثل إضافة أو خيارات)
              effectiveTrailing ?? const SizedBox(width: 44),
              // عنوان الصفحة في المنتصف بخط كايرو عريض
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
              // زر الرجوع في اليسار في RTL
              if (effectiveShowBack)
                IconButton(
                  onPressed: onBack ?? () => Navigator.maybePop(context),
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  tooltip: 'رجوع',
                )
              else
                const SizedBox(width: 44),
            ],
          ),
        ),
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
    this.radius = 25.0,
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
