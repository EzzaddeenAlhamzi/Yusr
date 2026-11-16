import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// الشاشة الأولى في وضع كبير السن: "التطبيق سيساعدك في:"
class SeniorHelpPage extends StatelessWidget {
  const SeniorHelpPage({super.key});

  static const Color backgroundColor = Color(0xFFF7F5EE);
  static const Color primaryTeal = Color(0xFF125D73);
  static const Color iconGreen = Color(0xFF267364);
  static const Color textDark = Color(0xFF1E232A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 70),

                // العنوان الرئيسي
                Text(
                  'التطبيق سيساعدك في:',
                  style: GoogleFonts.cairo(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),

                const SizedBox(height: 55),

                // الصف الأول: التذكير بالأدوية (أيقونة الكبسولة المطابقة للصورة تماماً)
                _buildFeatureItem(
                  title: 'التذكير بالأدوية',
                  icon: const PillIcon(color: iconGreen, size: 30),
                ),

                const SizedBox(height: 38),

                // الصف الثاني: عرض موقعك لعائلتك
                _buildFeatureItem(
                  title: 'عرض موقعك لعائلتك',
                  icon: const Icon(
                    Icons.location_on_rounded,
                    color: iconGreen,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 38),

                // الصف الثالث: البقاء على اتصال مع عائلتك
                _buildFeatureItem(
                  title: 'البقاء على اتصال مع عائلتك',
                  icon: const Icon(
                    Icons.people_alt_rounded,
                    color: iconGreen,
                    size: 30,
                  ),
                ),

                const Spacer(),

                // زر التالي
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final args = ModalRoute.of(context)?.settings.arguments;
                      Navigator.pushNamed(
                        context,
                        '/senior-link-code',
                        arguments: args ?? {'mode': 'advanced', 'role': 'senior'},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'التالي',
                      style: GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required String title,
    required Widget icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Center(child: icon),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// أيقونة كبسولة دواء مقسومة لنصفين ومائلة بزاوية دقيقة مطابقة لتصميم الصورة
class PillIcon extends StatelessWidget {
  final Color color;
  final double size;

  const PillIcon({
    super.key,
    required this.color,
    this.size = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PillPainter(color: color),
      ),
    );
  }
}

class _PillPainter extends CustomPainter {
  final Color color;

  _PillPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double center = size.width / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    // تحريك نقطة الأصل للمنتصف والتدوير بزاوية 45 درجة (الميلان من أعلى اليسار إلى أسفل اليمين)
    canvas.translate(center, center);
    canvas.rotate(math.pi / 4);

    // أبعاد الكبسولة المتطابقة تماماً مع التصميم
    final double radius = size.width * 0.22; // نصف قطر قبة الكبسولة (~6.6 بكسل)
    final double halfLength = size.width * 0.38; // طول كل نصف (~11.4 بكسل)
    final double gap = size.width * 0.10; // الفراغ القاطع الصريح بين النصفين (~3.0 بكسل)
    final double innerRadius = 1.6; // نعومة زوايا القطع

    // النصف الأول (الممتد نحو أعلى اليسار)
    final leftRect = Rect.fromLTRB(
      -halfLength - (gap / 2),
      -radius,
      -(gap / 2),
      radius,
    );
    final leftRRect = RRect.fromRectAndCorners(
      leftRect,
      topLeft: Radius.circular(radius),
      bottomLeft: Radius.circular(radius),
      topRight: Radius.circular(innerRadius),
      bottomRight: Radius.circular(innerRadius),
    );
    canvas.drawRRect(leftRRect, paint);

    // النصف الثاني (الممتد نحو أسفل اليمين)
    final rightRect = Rect.fromLTRB(
      gap / 2,
      -radius,
      halfLength + (gap / 2),
      radius,
    );
    final rightRRect = RRect.fromRectAndCorners(
      rightRect,
      topRight: Radius.circular(radius),
      bottomRight: Radius.circular(radius),
      topLeft: Radius.circular(innerRadius),
      bottomLeft: Radius.circular(innerRadius),
    );
    canvas.drawRRect(rightRRect, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PillPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
