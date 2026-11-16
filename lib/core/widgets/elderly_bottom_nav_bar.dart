import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shard/color.dart';
import '../../pages/home_page.dart';
import '../../pages/devices_page_elderly.dart';
import '../../pages/profile_page_elderly.dart';

/// شريط التنقل السفلي المخصص لكبار السن بتصميم كبير وواضح وسهل اللمس وتمرير سلس
class ElderlyBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const ElderlyBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  PageRouteBuilder _buildSmoothRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 140),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        _buildSmoothRoute(const HomePage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        _buildSmoothRoute(const DevicesPageElderly()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        _buildSmoothRoute(const ProfilePageElderly()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.home_rounded, 'label': 'الرئيسية', 'size': 32.0},
      {'icon': Icons.watch_outlined, 'label': 'الأجهزة', 'size': 30.0},
      {'icon': Icons.person_rounded, 'label': 'الملف الشخصي', 'size': 30.0},
    ];

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: appbarColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final isSelected = currentIndex == index;
                final item = items[index];

                return InkWell(
                  onTap: () => _onItemTapped(context, index),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 16 : 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: isSelected ? Colors.white : Colors.white70,
                          size: item['size'] as double,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['label'] as String,
                          style: GoogleFonts.tajawal(
                            fontSize: isSelected ? 15 : 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
