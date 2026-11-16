import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// مدير التنقل لشريط مقدم الرعاية لضمان انتقال سلس وموحد
class CaregiverNavNotifier {
  static final ValueNotifier<int> currentTab = ValueNotifier<int>(0);

  static void switchTo(BuildContext context, int index) {
    currentTab.value = index;
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }
}

/// شريط التنقل السفلي الموحد لتطبيق يُسر بتصميم مقوس وأنيق
class CustomBottomNavigationBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final BuildContext? context;

  const CustomBottomNavigationBar({
    super.key,
    this.currentIndex = 0,
    this.onTap,
    this.context,
  });

  @override
  State<CustomBottomNavigationBar> createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant CustomBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _selectedIndex = widget.currentIndex;
    }
  }

  void _handleTap(int index) {
    if (_selectedIndex == index && widget.currentIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
    if (widget.onTap != null) {
      widget.onTap!(index);
    } else {
      final ctx = widget.context ?? context;
      CaregiverNavNotifier.switchTo(ctx, index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.home_rounded, 'size': 27.0},
      {'icon': Icons.sos_rounded, 'size': 29.0},
      {'icon': Icons.person_rounded, 'size': 27.0},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.mainColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(items.length, (index) {
                  final isSelected = _selectedIndex == index;
                  final item = items[index];

                  return Expanded(
                    child: Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(25),
                          splashColor: const Color(0x33FFFFFF),
                          highlightColor: const Color(0x1AFFFFFF),
                          onTap: () => _handleTap(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0x2EFFFFFF)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: Colors.white.withValues(alpha: 0.35),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Icon(
                                item['icon'] as IconData,
                                color: isSelected ? Colors.white : Colors.white70,
                                size: isSelected
                                    ? (item['size'] as double) + 2
                                    : (item['size'] as double),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// دالة مساعدة لإنشاء الشريط السفلي
Widget customBottomNavigationBar({
  BuildContext? context,
  int currentIndex = 0,
  ValueChanged<int>? onTap,
}) {
  return CustomBottomNavigationBar(
    context: context,
    currentIndex: currentIndex,
    onTap: onTap,
  );
}

/// للتوافقية مع أي استدعاء قديم
typedef CustomBottomNavBar = CustomBottomNavigationBar;
