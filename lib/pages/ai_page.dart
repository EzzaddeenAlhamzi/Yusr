import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/senior_manager.dart';
import '../shard/color.dart';
import '../shard/custom_header.dart';

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> with SingleTickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  String? _lastQuery;
  String? _aiResponse;
  bool _isEmergency = false;
  int? _emergencyId;
  String? _errorMessage;

  late AnimationController _animController;

  final List<String> _quickSuggestions = [
    'ما هي مواعيدي الطبية القادمة؟',
    'ما هي أدويتي المقررة وجرعاتها؟',
    'ما هي آخر قراءاتي وقياساتي الصحية؟',
    'أشعر بالتعب وألم في الصدر وأحتاج مساعدة',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  int? _resolveElderlyId() {
    if (AuthService().isSenior && AuthService().userId != null) {
      return AuthService().userId;
    }
    if (SeniorManager().hasSeniors) {
      final parsed = int.tryParse(SeniorManager().currentSenior.id);
      if (parsed != null && parsed > 0) return parsed;
    }
    return AuthService().linkedSeniorId;
  }

  Future<void> _sendPrompt(String promptText) async {
    final cleanPrompt = promptText.trim();
    if (cleanPrompt.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _lastQuery = cleanPrompt;
      _aiResponse = null;
      _errorMessage = null;
      _isEmergency = false;
      _emergencyId = null;
    });
    _promptController.clear();
    FocusScope.of(context).unfocus();

    try {
      final elderlyId = _resolveElderlyId();
      final response = await ApiService.instance.askAiVoiceAssistant(
        prompt: cleanPrompt,
        elderlyId: elderlyId,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        setState(() {
          _aiResponse = response['reply']?.toString() ?? 'تمت المعالجة بنجاح.';
          _isEmergency = response['is_emergency'] == true;
          if (response['emergency_id'] != null) {
            _emergencyId = int.tryParse(response['emergency_id'].toString());
          }
        });
      } else {
        setState(() {
          _errorMessage = response['message']?.toString() ??
              'حدث خطأ أثناء التواصل مع المساعد الذكي';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر الاتصال بالخادم، يرجى التأكد من تشغيل الشبكة و Laravel API';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  void _resetConversation() {
    setState(() {
      _isLoading = false;
      _lastQuery = null;
      _aiResponse = null;
      _isEmergency = false;
      _emergencyId = null;
      _errorMessage = null;
      _promptController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appbarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // الشريط العلوي (CustomTopBar)
            CustomTopBar(
              title: 'المساعد الصوتي الذكي',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // الجسم المنحني الرئيسي
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // المحتوى القابل للتمرير
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 15),

                            // دائرة أيقونة المساعد الصوتي مع نبض عند التفكير
                            AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                final scale = _isLoading
                                    ? 1.0 + (_animController.value * 0.08)
                                    : 1.0;
                                return Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.transparent,
                                      border: Border.all(
                                        color: _isLoading
                                            ? appbarColor
                                            : Colors.grey.withValues(alpha: 0.25),
                                        width: _isLoading ? 2.5 : 1.5,
                                      ),
                                    ),
                                    child: const Center(
                                      child: SmilingRobotIcon(
                                        size: 85,
                                        color: Color(0xFF2E8B75),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // النصوص الرئيسية
                            Text(
                              _isLoading ? 'جاري التفكير...' : 'أنا هنا لمساعدتك',
                              style: GoogleFonts.tajawal(
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'اسألني عن أدويتك ومواعيدك أو اطلب المساعدة في أي وقت',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.tajawal(
                                color: Colors.grey[600],
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // تنبيه الطوارئ في حال تم رصدها
                            if (_isEmergency) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.shade400,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'نداء استغاثة عاجل!',
                                            style: GoogleFonts.tajawal(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _emergencyId != null
                                                ? 'تم إرسال بلاغ طوارئ فوري برقم ($_emergencyId) وتسجيله لمقدم الرعاية. يرجى التزام الهدوء.'
                                                : 'تم رصد حالة طارئة وتنبيه مقدم الرعاية فوراً. يرجى التزام الهدوء.',
                                            style: GoogleFonts.tajawal(
                                              fontSize: 14,
                                              color: Colors.red.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // عرض السؤال الأخير إن وجد
                            if (_lastQuery != null) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appbarColor.withValues(alpha: 0.12),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(18),
                                      topLeft: Radius.circular(18),
                                      bottomLeft: Radius.circular(18),
                                    ),
                                  ),
                                  child: Text(
                                    _lastQuery!,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: appbarColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // عرض الإجابة أو مؤشر التحميل
                            if (_isLoading) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFF2E8B75),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'المساعد يبحث في بياناتك الصحية...',
                                      style: GoogleFonts.tajawal(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_aiResponse != null) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(18),
                                      topLeft: Radius.circular(18),
                                      bottomRight: Radius.circular(18),
                                    ),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: SelectableText(
                                    _aiResponse!,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      height: 1.6,
                                      color: Colors.grey[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ] else if (_errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 14,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // الأسئلة المقترحة السريعة
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'أسئلة سريعة مقترحة:',
                                style: GoogleFonts.tajawal(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _quickSuggestions.map((suggestion) {
                                final isCrit = suggestion.contains('مساعدة');
                                return InkWell(
                                  onTap: _isLoading
                                      ? null
                                      : () => _sendPrompt(suggestion),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCrit
                                          ? Colors.red.shade50
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isCrit
                                            ? Colors.red.shade200
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isCrit
                                              ? Icons.emergency_rounded
                                              : Icons.chat_bubble_outline_rounded,
                                          size: 16,
                                          color: isCrit
                                              ? Colors.red.shade700
                                              : appbarColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          suggestion,
                                          style: GoogleFonts.tajawal(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isCrit
                                              ? Colors.red.shade900
                                              : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // حقل الإدخال الكتابي / الصوتي
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promptController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: _sendPrompt,
                              style: GoogleFonts.tajawal(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'اكتب استفسارك للمساعد...',
                                hintStyle: GoogleFonts.tajawal(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _isLoading
                                ? null
                                : () => _sendPrompt(_promptController.text),
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Color(0xFF2E8B75),
                            ),
                            tooltip: 'إرسال',
                          ),
                        ],
                      ),
                    ),

                    // زر "إيقاف / محادثة جديدة" السفلي الثابت
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          color: appbarColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: InkWell(
                          onTap: _resetConversation,
                          borderRadius: BorderRadius.circular(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _aiResponse != null || _lastQuery != null
                                    ? 'بدء محادثة جديدة'
                                    : 'إيقاف',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                _aiResponse != null || _lastQuery != null
                                    ? Icons.refresh_rounded
                                    : Icons.stop_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ودجت أيقونة الروبوت المبتسم والودود
class SmilingRobotIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SmilingRobotIcon({
    super.key,
    this.size = 100,
    this.color = const Color(0xFF2E8B75),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SmilingRobotPainter(color: color),
    );
  }
}

class _SmilingRobotPainter extends CustomPainter {
  final Color color;

  _SmilingRobotPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final paintStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // 1. هوائي الروبوت (Antenna)
    canvas.drawLine(
      Offset(w * 0.5, h * 0.22),
      Offset(w * 0.5, h * 0.12),
      paintStroke,
    );
    canvas.drawCircle(Offset(w * 0.5, h * 0.10), w * 0.055, paintFill);

    // 2. الأذنين الجانبيتين (Ears)
    final leftEar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.43, w * 0.08, h * 0.22),
      Radius.circular(w * 0.04),
    );
    final rightEar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.84, h * 0.43, w * 0.08, h * 0.22),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(leftEar, paintFill);
    canvas.drawRRect(rightEar, paintFill);

    // 3. رأس الروبوت المستدير الزوايا (Head)
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.22, w * 0.68, h * 0.64),
      Radius.circular(w * 0.18),
    );
    canvas.drawRRect(headRect, paintFill);

    // 4. عيون الروبوت الودودة والمبتسمة (Eyes)
    // العين اليمنى واليسرى
    canvas.drawCircle(Offset(w * 0.36, h * 0.48), w * 0.075, whitePaint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.48), w * 0.075, whitePaint);

    // بريق العين (Catchlights)
    final pupilPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.36, h * 0.48), w * 0.038, pupilPaint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.48), w * 0.038, pupilPaint);

    // 5. ابتسامة الروبوت اللطيفة (Smile)
    final smilePath = Path();
    smilePath.moveTo(w * 0.38, h * 0.66);
    smilePath.quadraticBezierTo(
      w * 0.50,
      h * 0.77,
      w * 0.62,
      h * 0.66,
    );
    canvas.drawPath(smilePath, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
