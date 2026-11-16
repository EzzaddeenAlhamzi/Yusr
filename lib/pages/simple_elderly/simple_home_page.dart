import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// الشاشة الرئيسية للوضع البسيط (Senior Home Screen - Simple Mode)
/// مطابقة 100% وبدقة تامة لصورة شاشة اللابتوب المرسلة:
/// - شريط علوي:
///   * على اليسار: مستطيل البطارية وتحته "2026 أغسطس"
///   * على اليمين: "م 6:30"
/// - شبكة 2×3 بمربعات بيضاء وخطوط سوداء 4px:
///   * الصف 1: فقاعة المحادثة الصفراء مع 3 دوائر (يسار) | أيقونة الهاتف الخضراء مع الإطار الأسود (يمين)
///   * الصف 2: علبة الدواء البرتقالية مع علامة + (يسار) | المنزل الأزرق الكحلي (يمين)
///   * الصف 3: المايكروفون البنفسجي (يسار) | زر SOS الأحمر الدائري (يمين)
class SimpleHomePage extends StatelessWidget {
  const SimpleHomePage({super.key});

  static const Color headerBackground = Color(0xFFFFFFFF);
  static const Color gridBackground = Color(0xFFFFFFFF);
  static const Color greenPhone = Color(0xFF18AB53);
  static const Color yellowMessage = Color(0xFFE8C24A);
  static const Color blueHome = Color(0xFF2B386D);
  static const Color orangeJar = Color(0xFFE79A54);
  static const Color redSos = Color(0xFFE03837);
  static const Color purpleMic = Color(0xFF9953C7);
  static const Color batteryGreen = Color(0xFF00873D);

  Future<void> _triggerEmergency(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.red, width: 3),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 36),
              const SizedBox(width: 10),
              Text(
                'طلب استغاثة (SOS)',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
          content: Text(
            'هل تريد الاتصال الفوري بمقدم الرعاية أو بالطوارئ؟',
            style: GoogleFonts.cairo(fontSize: 18, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(fontSize: 16, color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('tel:999');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.call, color: Colors.white),
              label: Text(
                'اتصال الآن',
                style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // 1. الشريط العلوي: بطارية على اليسار وساعة على اليمين
              _buildTopHeader(context),

              // 2. شبكة الأزرار الستة
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: gridBackground,
                    border: Border(
                      top: BorderSide(color: Colors.black, width: 4),
                    ),
                  ),
                  child: Column(
                    children: [
                      // الصف الأول: المحادثة (يسار) | الهاتف (يمين)
                      Expanded(
                        child: Row(
                          children: [
                            // يسار: فقاعة المحادثة الصفراء مع 3 دوائر
                            Expanded(
                              child: _GridItem(
                                onTap: () => Navigator.pushNamed(context, '/simple-contacts'),
                                child: _buildMessageIcon(size: 115),
                              ),
                            ),
                            Container(width: 4, color: Colors.black),
                            // يمين: سماعة الهاتف الخضراء مع الإطار الأسود
                            Expanded(
                              child: _GridItem(
                                onTap: () => Navigator.pushNamed(context, '/simple-contacts'),
                                child: _buildOutlinedIcon(
                                  icon: Icons.phone,
                                  color: greenPhone,
                                  size: 115,
                                  flipX: false, // نفس اتجاه سماعة الهاتف في الصورة تماماً (غير مقلوب)
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(height: 4, color: Colors.black),

                      // الصف الثاني: علبة الدواء مع + (يسار) | المنزل الأزرق (يمين)
                      Expanded(
                        child: Row(
                          children: [
                            // يسار: علبة الدواء البرتقالية مع علامة +
                            Expanded(
                              child: _GridItem(
                                onTap: () => Navigator.pushNamed(context, '/simple-medicines'),
                                child: const _MedicineJarIcon(),
                              ),
                            ),
                            Container(width: 4, color: Colors.black),
                            // يمين: المنزل الأزرق الكحلي مع الباب
                            Expanded(
                              child: _GridItem(
                                onTap: () => Navigator.pushNamed(context, '/simple-return-home'),
                                child: _buildOutlinedIcon(
                                  icon: Icons.home,
                                  color: blueHome,
                                  size: 125,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(height: 4, color: Colors.black),

                      // الصف الثالث: المايكروفون البنفسجي (يسار) | زر SOS الأحمر (يمين)
                      Expanded(
                        child: Row(
                          children: [
                            // يسار: المايكروفون البنفسجي مع الإطار الأسود
                            Expanded(
                              child: _GridItem(
                                onTap: () => Navigator.pushNamed(context, '/ai'),
                                child: _buildOutlinedIcon(
                                  icon: Icons.mic,
                                  color: purpleMic,
                                  size: 125,
                                ),
                              ),
                            ),
                            Container(width: 4, color: Colors.black),
                            // يمين: زر SOS الأحمر
                            Expanded(
                              child: _GridItem(
                                onTap: () => _triggerEmergency(context),
                                child: _buildSosButton(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// الشريط العلوي:
  /// على اليسار: مستطيل البطارية وتحته "2026 أغسطس"
  /// في الوسط: زر التبديل إلى الوضع المتقدم
  /// على اليمين: "م 6:30"
  Widget _buildTopHeader(BuildContext context) {
    return Container(
      color: headerBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // اليسار: البطارية + "2026 أغسطس"
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBatteryIcon(),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '2026',
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'أغسطس',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // الوسط: زر التبديل إلى الوضع المتقدم
          InkWell(
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home-elderly',
                (route) => false,
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF334155)),
                  const SizedBox(width: 4),
                  Text(
                    'الوضع المتقدم',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // اليمين: "م 6:30" على سطر واحد كما في الصورة
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'م',
                style: GoogleFonts.cairo(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '6:30',
                style: GoogleFonts.cairo(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// رسمة مستطيل البطارية (إطار أسود وجزء أخضر في اليمين)
  Widget _buildBatteryIcon() {
    return Container(
      width: 92,
      height: 38,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 3.5),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 48,
          decoration: BoxDecoration(
            color: batteryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  /// دالة رسم أيقونة محددة بإطار أسود بارز في جميع الاتجاهات (مطابقة لشاشتك)
  Widget _buildOutlinedIcon({
    required IconData icon,
    required Color color,
    required double size,
    bool flipX = false,
  }) {
    const double stroke = 3.5;
    Widget iconStack = Stack(
      alignment: Alignment.center,
      children: [
        // رسم الإطار الأسود الخارجي
        for (double dx = -stroke; dx <= stroke; dx += 1.75)
          for (double dy = -stroke; dy <= stroke; dy += 1.75)
            if (dx != 0 || dy != 0)
              Transform.translate(
                offset: Offset(dx, dy),
                child: Icon(icon, size: size, color: Colors.black),
              ),
        // الأيقونة الملونة الأساسية
        Icon(icon, size: size, color: color),
      ],
    );

    if (flipX) {
      return Transform.scale(scaleX: -1, child: iconStack);
    }
    return iconStack;
  }

  /// أيقونة الرسالة الصفراء مع ثلاث دوائر بيضاء محددة بالأسود داخلها
  Widget _buildMessageIcon({required double size}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // فقاعة المحادثة الصفراء المحددة بالأسود مع ذيل بأسفل اليسار
          _buildOutlinedIcon(
            icon: Icons.chat_bubble,
            color: yellowMessage,
            size: size,
            flipX: false,
          ),
          // الدوائر البيضاء الثلاث المحددة بالأسود داخل الفقاعة
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildWhiteDotWithBlackBorder(),
                const SizedBox(width: 6),
                _buildWhiteDotWithBlackBorder(),
                const SizedBox(width: 6),
                _buildWhiteDotWithBlackBorder(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// دائرة بيضاء محددة بالأسود
  Widget _buildWhiteDotWithBlackBorder() {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2.5),
      ),
    );
  }

  /// زر SOS الدائري الأحمر مع النص الأبيض والإطار الأسود
  Widget _buildSosButton() {
    return Container(
      width: 135,
      height: 135,
      decoration: BoxDecoration(
        color: redSos,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 5.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ظل وتحديد خفيف لكلمة SOS
            for (double dx = -2; dx <= 2; dx += 1)
              for (double dy = -2; dy <= 2; dy += 1)
                if (dx != 0 || dy != 0)
                  Transform.translate(
                    offset: Offset(dx, dy),
                    child: Text(
                      "SOS",
                      style: GoogleFonts.cairo(
                        color: Colors.black,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            Text(
              "SOS",
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _GridItem({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.black12,
      child: Center(
        child: child,
      ),
    );
  }
}

/// علبة الدواء البرتقالية مع علامة الزائد (+) البيضاء (الصف 2 - يسار)
class _MedicineJarIcon extends StatelessWidget {
  const _MedicineJarIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 105,
      child: CustomPaint(
        painter: _MedicineJarPainter(),
      ),
    );
  }
}

class _MedicineJarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final jarPaint = Paint()
      ..color = const Color(0xFFF5A844)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final plusPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = size.width / 2;

    // 1. غطاء العلبة العلوي
    const capW = 62.0;
    const capH = 12.0;
    const capTop = 10.0;
    final capRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - capW / 2, capTop, capW, capH),
      const Radius.circular(3),
    );
    canvas.drawRRect(capRect, jarPaint);
    canvas.drawRRect(capRect, strokePaint);

    // 2. جسم العلبة البرتقالي
    const jarW = 76.0;
    const jarH = 74.0;
    const jarTop = capTop + capH;
    final jarRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - jarW / 2, jarTop, jarW, jarH),
      const Radius.circular(8),
    );
    canvas.drawRRect(jarRRect, jarPaint);
    canvas.drawRRect(jarRRect, strokePaint);

    // 3. علامة الزائد (+) البيضاء المحددة بالأسود في المنتصف
    final plusCenterY = jarTop + jarH / 2;
    const armW = 10.0;
    const armL = 30.0;

    final crossPath = Path();
    crossPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, plusCenterY), width: armW, height: armL),
      const Radius.circular(2),
    ));
    crossPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, plusCenterY), width: armL, height: armW),
      const Radius.circular(2),
    ));

    canvas.drawPath(crossPath, plusPaint);
    canvas.drawPath(crossPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// اسم بديل للتوافقية
typedef HomeScreenS = SimpleHomePage;
