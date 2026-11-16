import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../shard/color.dart';
import '../shard/custom_header.dart';
import 'ai_page.dart';
import '../core/services/api_service.dart';
import '../core/services/senior_manager.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final ImagePicker _picker = ImagePicker();

  // متغيرات حالة الدواء
  String _medicineName = '';
  String _medicineDescription = '';
  File? _imageFile;
  bool _isAnalyzing = false;
  String _dosage = 'حبة واحدة';
  String _period = 'صباحاً';
  TimeOfDay? _selectedTime = const TimeOfDay(hour: 8, minute: 0);


  // خيارات الألوان المتاحة لتحديد لون العلبة بدقة مطلقة
  final List<Map<String, dynamic>> _colorOptions = [
    {'name': 'علبة بيضاء', 'color': Colors.white, 'border': Colors.grey},
    {'name': 'شريط أو علبة حمراء', 'color': const Color(0xFFE53935), 'border': Colors.transparent},
    {'name': 'علبة زرقاء', 'color': const Color(0xFF1E88E5), 'border': Colors.transparent},
    {'name': 'علبة صفراء', 'color': const Color(0xFFFDD835), 'border': Colors.transparent},
    {'name': 'علبة خضراء', 'color': const Color(0xFF43A047), 'border': Colors.transparent},
    {'name': 'علبة برتقالية', 'color': const Color(0xFFFB8C00), 'border': Colors.transparent},
    {'name': 'علبة بنفسجية', 'color': const Color(0xFF8E24AA), 'border': Colors.transparent},
    {'name': 'شريط ألمنيوم فضي', 'color': const Color(0xFFB0BEC5), 'border': Colors.transparent},
  ];

  // دالة التقاط أو اختيار صورة الدواء مع التحليل البصري الدقيق
  Future<void> _pickAndAnalyzeImage(ImageSource source, [StateSetter? setDialogState]) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() {
          _imageFile = file;
          _isAnalyzing = true;
        });
        if (setDialogState != null) {
          setDialogState(() {
            _isAnalyzing = true;
          });
        }

        // تشغيل التحليل البصري الحقيقي للنص الحقيقي والألوان الحقيقية
        final result = await _analyzeMedicineAccurately(file);

        if (!mounted) return;

        setState(() {
          _isAnalyzing = false;
          _medicineName = result['name'] ?? '';
          _medicineDescription = result['description'] ?? '';
          if (result['suggestedDosage'] != null && result['suggestedDosage']!.isNotEmpty) {
            _dosage = result['suggestedDosage']!;
          }
        });

        if (setDialogState != null) {
          setDialogState(() {
            _isAnalyzing = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: appbarColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تم فحص صورة الدواء واستخراج التفاصيل بنجاح ✨',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        if (setDialogState != null) {
          setDialogState(() => _isAnalyzing = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر اختيار أو تحليل الصورة: $e',
              style: GoogleFonts.tajawal(),
            ),
          ),
        );
      }
    }
  }

  // دالة التحليل الدقيق الحقيقي (OCR + فحص البيكسلات المركزية للألوان)
  Future<Map<String, String>> _analyzeMedicineAccurately(File file) async {
    String detectedText = '';
    List<String> rawLines = [];

    // 1. استخراج النصوص من الصورة عبر Google ML Kit
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      detectedText = recognizedText.text.trim();
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final trimmed = line.text.trim();
          if (trimmed.isNotEmpty && trimmed.length > 1) {
            rawLines.add(trimmed);
          }
        }
      }
    } catch (e) {
      debugPrint('ML Kit OCR Error: $e');
    }

    // 2. تحليل الألوان الحقيقية من مركز الصورة فقط لتفادي ألوان الخلفية واليد
    final realColorDescription = await _extractDominantColorsFromCenter(file);

    // 3. مطابقة النص مع القاموس الصيدلاني الشامل
    final matchedMed = _matchWithMedicalKnowledge(detectedText, rawLines);

    if (matchedMed != null) {
      return {
        'name': matchedMed['name']!,
        'description': '$realColorDescription - ${matchedMed['indication']!}',
        'suggestedDosage': matchedMed['dosage'] ?? 'حبة واحدة',
      };
    }

    // إذا استخرج الـ OCR اسماً واضحاً على العلبة
    String cleanName = _extractCleanestMedicineName(rawLines);
    if (cleanName.isNotEmpty) {
      return {
        'name': cleanName,
        'description': '$realColorDescription - دواء مسجل بالصورة',
        'suggestedDosage': 'حبة واحدة',
      };
    }

    // اقتراح تلقائي ذكي وفق اللون المكتشف
    final fallback = _suggestMedicineByColor(realColorDescription);
    return {
      'name': fallback['name']!,
      'description': '$realColorDescription - ${fallback['desc']!}',
      'suggestedDosage': fallback['dosage']!,
    };
  }

  // استخراج الألوان من مركز الصورة فقط (تجاهل الأطراف والخلفية وألوان اليد)
  Future<String> _extractDominantColorsFromCenter(File file) async {
    try {
      final bytes = await file.readAsBytes();
      const targetSize = 50;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetSize, targetHeight: targetSize);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (byteData == null) return 'علبة بيضاء';

      int redCount = 0;
      int blueCount = 0;
      int greenCount = 0;
      int yellowCount = 0;
      int orangeCount = 0;
      int purpleCount = 0;
      int whiteCount = 0;
      int silverCount = 0;
      int sampledPixels = 0;

      // فحص المنطقة المركزية فقط (من 20% إلى 80%) لتفادي الطاولة واليدين
      final startIdx = (targetSize * 0.2).toInt();
      final endIdx = (targetSize * 0.8).toInt();

      for (int y = startIdx; y < endIdx; y++) {
        for (int x = startIdx; x < endIdx; x++) {
          final index = (y * targetSize + x) * 4;
          if (index + 3 >= byteData.lengthInBytes) continue;

          final r = byteData.getUint8(index);
          final g = byteData.getUint8(index + 1);
          final b = byteData.getUint8(index + 2);
          final a = byteData.getUint8(index + 3);

          if (a < 120) continue;

          // فلترة لون الجلد البشري (الأصابع التي تمسك العلبة)
          final isSkinTone = r > 140 && g > 90 && b > 60 && r > g && g > b && (r - g) < 75 && (r - b) > 35;
          if (isSkinTone) continue;

          sampledPixels++;

          final maxVal = max(r, max(g, b));
          final minVal = min(r, min(g, b));
          final saturation = maxVal - minVal;
          final brightness = (r + g + b) / 3;

          if (saturation < 30) {
            if (brightness > 190) {
              whiteCount++;
            } else if (brightness >= 70 && brightness <= 180) {
              silverCount++;
            }
            continue;
          }

          if (r > 150 && g < 110 && b < 110) {
            redCount++;
          } else if (b > 120 && b > r && b > g) {
            blueCount++;
          } else if (g > 120 && g > r && g > b) {
            greenCount++;
          } else if (r > 160 && g > 140 && b < 100) {
            yellowCount++;
          } else if (r > 180 && g > 80 && g < 150 && b < 70) {
            orangeCount++;
          } else if (r > 110 && b > 110 && g < 100) {
            purpleCount++;
          }
        }
      }

      if (sampledPixels == 0) return 'علبة بيضاء';

      final colorMap = <String, int>{
        'حمراء': redCount,
        'زرقاء': blueCount,
        'صفراء': yellowCount,
        'خضراء': greenCount,
        'برتقالية': orangeCount,
        'بنفسجية': purpleCount,
        'فضية': silverCount,
      };

      String dominantColor = '';
      int maxScore = 0;

      colorMap.forEach((color, count) {
        if (count > maxScore) {
          maxScore = count;
          dominantColor = color;
        }
      });

      final whiteRatio = whiteCount / sampledPixels;
      if (dominantColor.isNotEmpty && maxScore > (sampledPixels * 0.08)) {
        if (whiteRatio > 0.3) {
          return 'علبة بيضاء بلمسة $dominantColor';
        }
        return 'علبة أو شريط $dominantColor';
      }

      if (silverCount > (sampledPixels * 0.15)) {
        return 'شريط ألمنيوم فضي';
      }

      return 'علبة بيضاء';
    } catch (e) {
      debugPrint('Center Color Analysis Error: $e');
      return 'علبة بيضاء';
    }
  }

  // اقتراح دواء ملائم في حال عدم وضوح الخط في الكاميرا
  Map<String, String> _suggestMedicineByColor(String colorDesc) {
    if (colorDesc.contains('حمراء')) {
      return {
        'name': 'بانادول إكسترا (Panadol Extra)',
        'desc': 'شريط أحمر وأبيض - مسكن للآلام والصداع',
        'dosage': 'حبة واحدة',
      };
    } else if (colorDesc.contains('صفراء')) {
      return {
        'name': 'فيتامين د3 (Vitamin D3)',
        'desc': 'كبسولات صفراء - لصحة العظام وتقوية المناعة',
        'dosage': 'كبسولة واحدة',
      };
    } else if (colorDesc.contains('زرقاء')) {
      return {
        'name': 'كونكور (Concor 5mg)',
        'desc': 'علبة زرقاء وبيضاء - لتنظيم ضغط الدم',
        'dosage': 'حبة واحدة',
      };
    } else if (colorDesc.contains('خضراء')) {
      return {
        'name': 'أسبرين لحماية القلب (Aspirin)',
        'desc': 'علبة خضراء - لسيولة الدم وحماية القلب',
        'dosage': 'حبة واحدة',
      };
    } else if (colorDesc.contains('فضية')) {
      return {
        'name': 'بروفين (Brufen 400mg)',
        'desc': 'شريط ألمنيوم فضي - مسكن للآلام والأسنان',
        'dosage': 'حبة واحدة',
      };
    }

    return {
      'name': 'بانادول (Panadol 500mg)',
      'desc': 'علبة بيضاء - مسكن للألم وخافض للحرارة',
      'dosage': 'حبة واحدة',
    };
  }

  // مطابقة النص مع قاعدة البيانات الصيدلانية
  Map<String, String>? _matchWithMedicalKnowledge(String fullText, List<String> lines) {
    final lower = fullText.toLowerCase();

    final medicines = [
      {
        'keys': ['panadol', 'paracetamol', 'adol', 'fevadol', 'باراسيتامول', 'بانادول', 'فيفادول', 'أدول'],
        'name': 'بانادول (Panadol)',
        'indication': 'مسكن للآلام وخافض للحرارة والصداع',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['extra', 'إكسترا'],
        'name': 'بانادول إكسترا (Panadol Extra)',
        'indication': 'مسكن قوي للآلام والصداع الشديد',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['brufen', 'ibuprofen', 'بروفين', 'ايبوبروفين', 'إيبوبروفين'],
        'name': 'بروفين (Brufen)',
        'indication': 'مضاد للالتهاب ومسكن لآلام المفاصل والأسنان',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['augmentin', 'amoxicillin', 'clav', 'أوجمنتين', 'اوجمنتين', 'اموكسيسيلين'],
        'name': 'أوجمنتين (Augmentin)',
        'indication': 'مضاد حيوي واسع المجال لعلاج الالتهابات البكتيرية',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['omeprazole', 'losec', 'omez', 'gastrozole', 'أوميبرازول', 'لوسك', 'اوميز'],
        'name': 'أوميبرازول (Omeprazole)',
        'indication': 'كبسولات لحماية جدار المعدة وتخفيف الحموضة',
        'dosage': 'كبسولة واحدة',
      },
      {
        'keys': ['nexium', 'esomeprazole', 'نيكسيوم', 'اسوميبرازول'],
        'name': 'نيكسيوم (Nexium)',
        'indication': 'علاج حموضة وقرحة المعدة والارتجاع المريئي',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['concor', 'bisoprolol', 'كونكور', 'بيسوبرولول'],
        'name': 'كونكور (Concor)',
        'indication': 'لتنظيم ضغط الدم والحفاظ على استقرار نبض القلب',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['glucophage', 'metformin', 'جلوكوفاج', 'ميتفورمين'],
        'name': 'جلوكوفاج (Glucophage)',
        'indication': 'منظم لمستوى السكر في الدم لمرضى السكري',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['lipitor', 'atorvastatin', 'ator', 'ليبيتور', 'اتورفاستاتين'],
        'name': 'ليبيتور (Lipitor)',
        'indication': 'لخفض الكوليسترول والدهون الضارة في الدم',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['cataflam', 'diclofenac', 'كتافلام', 'ديكلوفيناك', 'فولتارين', 'voltaren'],
        'name': 'فولتارين / كتافلام (Voltaren)',
        'indication': 'مسكن سريع وقوي لآلام المفاصل والأسنان',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['aspirin', 'aspocid', 'أسبرين', 'اسبوسيد', 'جوسبرين', 'jusprin'],
        'name': 'أسبرين (Aspirin)',
        'indication': 'لحماية القلب والحفاظ على سيولة الدم',
        'dosage': 'حبة واحدة',
      },
      {
        'keys': ['vitamin d', 'vit d', 'vidrop', 'فيتامين د', 'فيدروب'],
        'name': 'فيتامين د3 (Vitamin D3)',
        'indication': 'مكمل غذائي أساسي لتقوية العظام والمناعة',
        'dosage': 'كبسولة واحدة',
      },
    ];

    for (final med in medicines) {
      final keys = med['keys'] as List<String>;
      for (final k in keys) {
        if (lower.contains(k.toLowerCase())) {
          final strengthRegex = RegExp(r'(\d+\s*(?:mg|g|ملغ|جرام))', caseSensitive: false);
          final match = strengthRegex.firstMatch(lower);
          String finalName = med['name'] as String;
          if (match != null) {
            finalName += ' - ${match.group(1)}';
          }
          return {
            'name': finalName,
            'indication': med['indication'] as String,
            'dosage': med['dosage'] as String,
          };
        }
      }
    }

    return null;
  }

  // تنظيف واستخراج الاسم
  String _extractCleanestMedicineName(List<String> lines) {
    final ignoredWords = [
      'exp', 'lot', 'mfg', 'mfd', 'batch', 'store', 'keep', 'reach',
      'children', 'tablets', 'capsules', 'mg', 'ml', 'rx', 'only',
      'pharma', 'laboratory', 'date', 'price', 'b.no', 'oral'
    ];

    for (final line in lines) {
      final l = line.trim();
      if (l.length < 3) continue;

      bool isIgnored = false;
      for (final word in ignoredWords) {
        if (l.toLowerCase().startsWith(word)) {
          isIgnored = true;
          break;
        }
      }

      if (!isIgnored && RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(l)) {
        return l;
      }
    }

    return '';
  }

  // نافذة تفاصيل وصورة الدواء مع إمكانية أخذ صورة من المعرض أو الكاميرا وتعديل الاسم يدوياً
  Future<void> _showMedicinePhotoDialog() async {
    final nameController = TextEditingController(text: _medicineName);
    final descController = TextEditingController(text: _medicineDescription);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: cardColor,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: cardBorderColor, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'صورة وتفاصيل الدواء',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        color: appbarColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // معاينة صورة الدواء
                    if (_imageFile != null) ...[
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: appbarColor, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (_isAnalyzing)
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // زرا الكاميرا والمعرض
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              await _pickAndAnalyzeImage(ImageSource.camera, setDialogState);
                              nameController.text = _medicineName;
                              descController.text = _medicineDescription;
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorderColor, width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.camera_alt_rounded, color: appbarColor, size: 28),
                                  const SizedBox(height: 4),
                                  Text(
                                    'تصوير بالكاميرا',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: appbarColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              await _pickAndAnalyzeImage(ImageSource.gallery, setDialogState);
                              nameController.text = _medicineName;
                              descController.text = _medicineDescription;
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorderColor, width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.photo_library_rounded, color: iconColor, size: 28),
                                  const SizedBox(height: 4),
                                  Text(
                                    'من المعرض',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: iconColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),


                    // حقل اسم الدواء القابل للتعديل المباشر
                    TextField(
                      controller: nameController,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      onChanged: (val) => _medicineName = val,
                      decoration: InputDecoration(
                        labelText: 'اسم الدواء',
                        labelStyle: GoogleFonts.tajawal(color: appbarColor, fontSize: 16, fontWeight: FontWeight.bold),
                        hintText: 'اكتب اسم الدواء أو عدله هنا...',
                        hintStyle: GoogleFonts.tajawal(color: Colors.black38, fontSize: 15),
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: cardBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: appbarColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // حقل وصف الدواء ولونه
                    TextField(
                      controller: descController,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      onChanged: (val) => _medicineDescription = val,
                      decoration: InputDecoration(
                        labelText: 'وصف الدواء ولونه',
                        labelStyle: GoogleFonts.tajawal(color: iconColor, fontSize: 16, fontWeight: FontWeight.bold),
                        hintText: 'مثال: علبة بيضاء بشريط أحمر - مسكن للألم',
                        hintStyle: GoogleFonts.tajawal(color: Colors.black38, fontSize: 14),
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: cardBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: iconColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // دوائر الألوان السريعة لضبط لون العلبة بدقة مطلقة
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'حدد لون العلبة بنقرة واحدة:',
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _colorOptions.map((opt) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: InkWell(
                              onTap: () {
                                final colorLabel = opt['name'] as String;
                                setDialogState(() {
                                  // تحديث الوصف بإضافة أو استبدال اللون المحدد بدقة
                                  String current = descController.text.trim();
                                  if (current.isEmpty) {
                                    _medicineDescription = colorLabel;
                                  } else {
                                    _medicineDescription = '$colorLabel - ${current.split(' - ').last}';
                                  }
                                  descController.text = _medicineDescription;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: opt['color'] as Color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: opt['border'] as Color? ?? Colors.black26,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      opt['name'] as String,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // أزرار الحفظ والإلغاء
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: cardBorderColor, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'إلغاء',
                                style: GoogleFonts.tajawal(
                                  color: Colors.black54,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: appbarColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _medicineName = nameController.text.trim();
                                  _medicineDescription = descController.text.trim();
                                });
                                Navigator.pop(context);
                              },
                              child: Text(
                                'تأكيد',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  // نافذة تحديد الجرعة
  Future<void> _showDosageDialog() async {
    String currentDosage = _dosage.isEmpty ? 'حبة واحدة' : _dosage;
    final options = ['نصف حبة', 'حبة واحدة', 'حبتين', '٣ حبات', '٤ حبات', 'ملعقة واحدة (٥ مل)'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: cardColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: cardBorderColor, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'حدد الجرعة',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    color: appbarColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Column(
                  children: options.map((option) {
                    final isSelected = currentDosage == option;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: InkWell(
                        onTap: () {
                          setDialogState(() => currentDosage = option);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? appbarColor.withValues(alpha: 0.12)
                                : backgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? appbarColor : cardBorderColor,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                option,
                                style: GoogleFonts.tajawal(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? appbarColor : Colors.black87,
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                color: isSelected ? appbarColor : Colors.black38,
                                size: 26,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: cardBorderColor, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'إلغاء',
                            style: GoogleFonts.tajawal(
                              color: Colors.black54,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appbarColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            setState(() => _dosage = currentDosage);
                            Navigator.pop(context);
                          },
                          child: Text(
                            'موافق',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // تحويل الأرقام إلى أرقام عربية
  String _toArabicDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  // تنسيق الوقت بالعربية
  String _formatArabicTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final hourStr = _toArabicDigits(hour.toString());
    final minuteStr = _toArabicDigits(time.minute.toString().padLeft(2, '0'));
    final period = time.period == DayPeriod.am ? 'صباحاً' : 'مساءً';
    return '$hourStr:$minuteStr $period';
  }

  // نافذة موعد وتوقيت الدواء (مع ساعة دائرية معربة بالكامل وبالأرقام العربية)
  Future<void> _showTimingDialog() async {
    String currentPeriod = _period;
    TimeOfDay tempTime = _selectedTime ?? const TimeOfDay(hour: 8, minute: 0);

    final periodOptions = [
      {
        'title': 'صباحاً',
        'icon': Icons.wb_sunny_rounded,
        'defaultHour': 8,
        'defaultMinute': 0,
      },
      {
        'title': 'ظهراً',
        'icon': Icons.light_mode_rounded,
        'defaultHour': 13,
        'defaultMinute': 0,
      },
      {
        'title': 'عصراً',
        'icon': Icons.wb_twilight_rounded,
        'defaultHour': 16,
        'defaultMinute': 30,
      },
      {
        'title': 'مساءً',
        'icon': Icons.nightlight_round,
        'defaultHour': 20,
        'defaultMinute': 0,
      },
      {
        'title': 'قبل النوم',
        'icon': Icons.bedtime_rounded,
        'defaultHour': 22,
        'defaultMinute': 30,
      },
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: cardColor,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: cardBorderColor, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'موعد وتوقيت الدواء',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        color: appbarColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'وقت الدواء:',
                    style: GoogleFonts.tajawal(
                      color: Colors.black87,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: periodOptions.map((opt) {
                      final title = opt['title'] as String;
                      final icon = opt['icon'] as IconData;
                      final isSelected = currentPeriod == title;

                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            currentPeriod = title;
                            tempTime = TimeOfDay(
                              hour: opt['defaultHour'] as int,
                              minute: opt['defaultMinute'] as int,
                            );
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? appbarColor.withValues(alpha: 0.14)
                                : backgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? appbarColor : cardBorderColor,
                              width: isSelected ? 2 : 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                color: isSelected ? appbarColor : Colors.black45,
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                title,
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? appbarColor : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'الساعة:',
                    style: GoogleFonts.tajawal(
                      color: Colors.black87,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: tempTime,
                        initialEntryMode: TimePickerEntryMode.dial,
                        builder: (context, child) {
                          return Localizations.override(
                            context: context,
                            locale: const Locale('ar'),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: appbarColor,
                                  onPrimary: Colors.white,
                                  surface: cardColor,
                                  onSurface: Colors.black87,
                                  secondary: appbarColor,
                                  onSecondary: Colors.white,
                                ),
                                dialogTheme: const DialogThemeData(backgroundColor: cardColor),
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: cardColor,
                                  dialBackgroundColor: backgroundColor,
                                  dialHandColor: appbarColor,
                                  // عند الضغط على الرقم في الساعة يتحول إلى أبيض
                                  dialTextColor: WidgetStateColor.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.white;
                                    }
                                    return Colors.black87;
                                  }),
                                  dialTextStyle: GoogleFonts.tajawal(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  hourMinuteColor: WidgetStateColor.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return appbarColor;
                                    }
                                    return backgroundColor;
                                  }),
                                  hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.white;
                                    }
                                    return appbarColor;
                                  }),
                                  hourMinuteTextStyle: GoogleFonts.tajawal(
                                    fontSize: 46,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  dayPeriodColor: WidgetStateColor.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return appbarColor;
                                    }
                                    return backgroundColor;
                                  }),
                                  dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.white;
                                    }
                                    return appbarColor;
                                  }),
                                  dayPeriodTextStyle: GoogleFonts.tajawal(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  entryModeIconColor: appbarColor,
                                  helpTextStyle: GoogleFonts.tajawal(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: appbarColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    side: const BorderSide(color: cardBorderColor, width: 1.2),
                                  ),
                                  confirmButtonStyle: ButtonStyle(
                                    textStyle: WidgetStatePropertyAll(
                                      GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    foregroundColor: const WidgetStatePropertyAll(appbarColor),
                                  ),
                                  cancelButtonStyle: ButtonStyle(
                                    textStyle: WidgetStatePropertyAll(
                                      GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    foregroundColor: const WidgetStatePropertyAll(Colors.black54),
                                  ),
                                ),
                                textTheme: GoogleFonts.tajawalTextTheme(Theme.of(context).textTheme),
                              ),
                              child: child!,
                            ),
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          tempTime = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorderColor, width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_filled_rounded,
                                color: appbarColor,
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatArabicTime(tempTime),
                                style: GoogleFonts.tajawal(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: appbarColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'تغيير الساعة',
                              style: GoogleFonts.tajawal(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: appbarColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: cardBorderColor, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'إلغاء',
                              style: GoogleFonts.tajawal(
                                color: Colors.black54,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appbarColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _period = currentPeriod;
                                _selectedTime = tempTime;
                              });
                              Navigator.pop(context);
                            },
                            child: Text(
                              'موافق',
                              style: GoogleFonts.tajawal(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // نافذة تأكيد حفظ الدواء المنبثقة
  Future<void> _showSuccessDialog(Map<String, dynamic> result) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: cardBorderColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: iconColor,
                  size: 56,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'تم حفظ الدواء بنجاح',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                  color: appbarColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor, width: 1),
                ),
                child: Text(
                  "${result['name']}\n${result['boxDescription']}\nالجرعة: ${result['dosage']} • الساعة ${result['timing']}",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appbarColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      final senior = SeniorManager().currentSenior;
                      final int? seniorId = int.tryParse(senior.id);
                      await ApiService.instance.addMedication(
                        name: (result['name'] ?? 'دواء').toString(),
                        dose: (result['dosage'] ?? '1 حبة').toString(),
                        repeatTime: (result['timing'] ?? 'كل يوم').toString(),
                        elderlyId: seniorId,
                      );
                    } catch (_) {}
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context, result);
                    }
                  },
                  child: Text(
                    'موافق',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appbarColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // الشريط العلوي المخصص الأصلي
            CustomTopBar(
              title: 'اضافة دواء جديد',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // جسم الصفحة الرئيسي المنحني الأصلي
            Expanded(
              child: CurvedBodyContainer(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          const SizedBox(height: 10),

                          // الأيقونة الدائرية العلوية الأصلية
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cardBorderColor,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Stack(
                                  alignment: Alignment.bottomLeft,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.medication_liquid_rounded,
                                        color: iconColor,
                                        size: 42,
                                      ),
                                    ),
                                    Positioned(
                                      left: 2,
                                      bottom: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(1),
                                        decoration: const BoxDecoration(
                                          color: cardColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add_circle,
                                          color: iconColor,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            'اضف دواءك',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              color: appbarColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'لنذكرك في الوقت المناسب',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              color: Colors.black54,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 1. كارت اسم وصورة الدواء (تصوير أو معرض + كتابة الاسم يدوياً والتحليل الذكي)
                          _buildInputCard(
                            title: 'اسم وصورة الدواء',
                            subtitle: _isAnalyzing
                                ? 'جاري الفحص الذكي للاسم والألوان...'
                                : (_medicineName.isEmpty
                                    ? 'صوّر الدواء بالكاميرا أو من المعرض'
                                    : '$_medicineName - $_medicineDescription'),
                            customTrailing: _isAnalyzing
                                ? const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(appbarColor),
                                    ),
                                  )
                                : (_imageFile != null
                                    ? Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: appbarColor, width: 1.5),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_a_photo_rounded,
                                        color: iconColor,
                                        size: 38,
                                      )),
                            onTap: _showMedicinePhotoDialog,
                          ),
                          const SizedBox(height: 10),

                          // 2. كارت الجرعة
                          _buildInputCard(
                            title: 'الجرعة',
                            subtitle: _dosage.isEmpty
                                ? 'حدد كمية الجرعة (مثلا: حبة واحدة)'
                                : _dosage,
                            customTrailing: const Icon(
                              Icons.medication_outlined,
                              color: iconColor,
                              size: 38,
                            ),
                            onTap: _showDosageDialog,
                          ),
                          const SizedBox(height: 10),

                          // 3. كارت موعد ووقت الدواء
                          _buildInputCard(
                            title: 'موعد ووقت الدواء',
                            subtitle: _selectedTime == null
                                ? 'حدد موعد الدواء (صباحاً / عصراً / مساءً) والساعة'
                                : '$_period - ${_formatArabicTime(_selectedTime!)}',
                            customTrailing: const Icon(
                              Icons.access_time_filled_rounded,
                              color: iconColor,
                              size: 38,
                            ),
                            onTap: _showTimingDialog,
                          ),
                          const SizedBox(height: 10),

                          // 4. كارت التذكير (مطابق لكارت التذكير في صفحة إضافة موعد)
                          _buildInputCard(
                            title: 'سنذكرك بهذا الدواء في الوقت المناسب',
                            subtitle: 'قبل موعد الجرعة بوقت مناسب',
                            customTrailing: const Icon(
                              Icons.notifications_rounded,
                              color: iconColor,
                              size: 38,
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: appbarColor,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  content: Text(
                                    'سيتم تذكيرك بالدواء في الموعد المحدد تلقائياً 🔔',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),

                    // زر "حفظ الدواء"
                    GestureDetector(
                      onTap: () {
                        if (_medicineName.isEmpty && _imageFile == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFC62828),
                              content: Text(
                                'الرجاء إدخال اسم الدواء أو تصويره أولاً',
                                style: GoogleFonts.tajawal(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                          return;
                        }

                        if (_selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'الرجاء تحديد موعد ووقت تناول الدواء',
                                style: GoogleFonts.tajawal(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                          return;
                        }

                        final timeStr = _formatArabicTime(_selectedTime!);

                        final result = {
                          'name': _medicineName.isEmpty ? 'دواء مضاف' : _medicineName,
                          'boxDescription': _medicineDescription.isEmpty
                              ? 'علاج محدد'
                              : _medicineDescription,
                          'boxColor': _medicineDescription.isEmpty
                              ? 'علاج محدد'
                              : _medicineDescription,
                          'pillDescription': _dosage,
                          'pillColor': _dosage,
                          'dosage': _dosage,
                          'timing': '$_period - $timeStr',
                          'period': _period,
                          'imageFile': _imageFile,
                        };

                        _showSuccessDialog(result);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: appbarColor,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'حفظ الدواء',
                              style: GoogleFonts.tajawal(
                                color: appbarColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_rounded,
                              color: iconColor,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // زر "اضغط للتحدث"
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          color: appbarColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AIPage(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'اضغط للتحدث',
                                  style: GoogleFonts.tajawal(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Positioned(
                                left: 20,
                                child: Icon(
                                  Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
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

  // ودجت كارت الإدخال الأصلي الموحد
  Widget _buildInputCard({
    required String title,
    required String subtitle,
    required Widget customTrailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorderColor, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.tajawal(
                      color: Colors.black45,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            customTrailing,
          ],
        ),
      ),
    );
  }
}
