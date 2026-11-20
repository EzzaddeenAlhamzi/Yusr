import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../shard/medicine_item.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/medication_adherence_helper.dart';
import 'ai_page.dart';
import 'add_medicine.dart';

class MedicinesPageElderly extends StatefulWidget {
  const MedicinesPageElderly({super.key});

  @override
  State<MedicinesPageElderly> createState() => _MedicinesPageElderlyState();
}

class _MedicinesPageElderlyState extends State<MedicinesPageElderly> {
  // قوائم الأدوية مقسمة حسب الفترات — مُجلَبة من قاعدة البيانات
  List<MedicineItem> _morningMedicines = [];
  List<MedicineItem> _afternoonMedicines = [];
  List<MedicineItem> _eveningMedicines = [];
  // الأرقام الحقيقية من DB لتتمكن من الحذف
  List<int?> _morningIds = [];
  List<int?> _afternoonIds = [];
  List<int?> _eveningIds = [];
  /// Medicayion_ID → today's server dose row
  final Map<int, Map<String, dynamic>> _todayDosesByMed = {};
  bool _isLoading = false;
  bool _confirmInFlight = false;
  bool _dosesOffline = false;

  @override
  void initState() {
    super.initState();
    _loadMedicinesFromDb();
  }

  Future<void> _loadMedicinesFromDb() async {
    setState(() => _isLoading = true);
    try {
      final int? elderlyId = AuthService().isSenior ? AuthService().userId : null;
      final list = await ApiService.instance.getMedications(elderlyId: elderlyId);
      final medsConnectionError = ApiService.lastListConnectionError;

      final civil = MedicationAdherenceHelper.civilDateToday();
      final doseRes = await ApiService.instance.getTodayMedicationDoses(
        elderlyId: elderlyId,
        civilDate: civil,
      );
      final Map<int, Map<String, dynamic>> doseMap = {};
      var dosesOffline = true;
      if (doseRes['status'] == 'success' && doseRes['data'] is List) {
        dosesOffline = false;
        for (final raw in (doseRes['data'] as List)) {
          if (raw is Map) {
            final row = Map<String, dynamic>.from(raw);
            final id = row['Medicayion_ID'] is int
                ? row['Medicayion_ID'] as int
                : int.tryParse(row['Medicayion_ID']?.toString() ?? '');
            if (id != null) doseMap[id] = row;
          }
        }
      } else {
        dosesOffline = MedicationAdherenceHelper.isConnectionFailure(doseRes) ||
            medsConnectionError;
      }

      final List<MedicineItem> morning = [];
      final List<int?> morningIds = [];
      final List<MedicineItem> afternoon = [];
      final List<int?> afternoonIds = [];
      final List<MedicineItem> evening = [];
      final List<int?> eveningIds = [];

      for (final m in list) {
        final name = (m['M_Name'] ?? 'دواء').toString();
        final dose = (m['M_much'] ?? '').toString();
        final repeat = (m['M_RepatTime'] ?? '').toString().toLowerCase();
        final id = m['Medicayion_ID'] is int ? m['Medicayion_ID'] as int? : int.tryParse(m['Medicayion_ID']?.toString() ?? '');

        const Widget iconWidget = Icon(
          Icons.medication_liquid_outlined,
          size: 46,
          color: Color(0xFF8E24AA),
        );

        final item = MedicineItem(
          name: name,
          boxDescription: dose.isNotEmpty ? dose : 'الجرعة غير محددة',
          pillDescription: repeat.isNotEmpty ? repeat : 'يومياً',
          iconWidget: iconWidget,
        );

        if (repeat.contains('صباح') || repeat.contains('morning') || repeat.contains('فطور')) {
          morning.add(item);
          morningIds.add(id);
        } else if (repeat.contains('غداء') || repeat.contains('ظهر') || repeat.contains('noon') || repeat.contains('afternoon')) {
          afternoon.add(item);
          afternoonIds.add(id);
        } else if (repeat.contains('مساء') || repeat.contains('ليل') || repeat.contains('evening') || repeat.contains('night') || repeat.contains('عشاء')) {
          evening.add(item);
          eveningIds.add(id);
        } else {
          // إذا لم تُحدَّد الفترة نضعها في الصباح
          morning.add(item);
          morningIds.add(id);
        }
      }

      if (mounted) {
        setState(() {
          // Preserve last good catalog/doses when offline so confirm CTA stays
          // tappable and can show Arabic blocked feedback (no fake Taken).
          if (!medsConnectionError) {
            _morningMedicines = morning;
            _morningIds = morningIds;
            _afternoonMedicines = afternoon;
            _afternoonIds = afternoonIds;
            _eveningMedicines = evening;
            _eveningIds = eveningIds;
          }
          if (!dosesOffline) {
            _todayDosesByMed
              ..clear()
              ..addAll(doseMap);
          }
          _dosesOffline = dosesOffline || medsConnectionError;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _dosesOffline = true);
        _showConfirmFailureSnack(
          MedicationAdherenceHelper.offlineConfirmBlockedMessage(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showConfirmFailureSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _confirmDose(int? medId) async {
    if (medId == null || _confirmInFlight) return;
    // Known offline: never hit the network, never show Taken / success.
    if (_dosesOffline) {
      _showConfirmFailureSnack(
        MedicationAdherenceHelper.offlineConfirmBlockedMessage(),
      );
      return;
    }
    setState(() => _confirmInFlight = true);
    try {
      final dose = _todayDosesByMed[medId];
      final civil = MedicationAdherenceHelper.civilDateToday();
      final clientId =
          'el-$medId-$civil-${DateTime.now().millisecondsSinceEpoch}';
      final res = await ApiService.instance.confirmMedicationDose(
        medicationId: medId,
        civilDate: civil,
        occurrenceKey: dose?['occurrence_key']?.toString(),
        clientConfirmId: clientId,
      );
      if (!mounted) return;
      if (!MedicationAdherenceHelper.isConfirmSuccess(res)) {
        if (MedicationAdherenceHelper.isConnectionFailure(res)) {
          setState(() => _dosesOffline = true);
        }
        _showConfirmFailureSnack(
          MedicationAdherenceHelper.confirmFailureMessage(res),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? 'تم تأكيد تناول الدواء بنجاح',
            style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
      await _loadMedicinesFromDb();
    } catch (_) {
      if (mounted) {
        setState(() => _dosesOffline = true);
        _showConfirmFailureSnack(
          MedicationAdherenceHelper.offlineConfirmBlockedMessage(),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmInFlight = false);
    }
  }

  // دالة الانتقال لصفحة إضافة دواء جديد
  void _navigateToAddMedicine() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddMedicineScreen(),
      ),
    );

    if (result is Map<String, dynamic> && result.isNotEmpty) {
      // أعد تحميل البيانات من قاعدة البيانات
      await _loadMedicinesFromDb();
    }
  }

  // دالة حذف دواء مع نافذة تأكيد وحذف حقيقي من قاعدة البيانات
  void _deleteMedicine(List<MedicineItem> list, List<int?> ids, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: cardBorderColor, width: 1.2),
        ),
        title: Text(
          'حذف الدواء',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: const Color(0xFFE53935),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذا الدواء؟',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'تراجع',
              style: GoogleFonts.tajawal(
                color: Colors.grey[700],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final medId = index < ids.length ? ids[index] : null;
              if (medId != null) {
                await ApiService.instance.deleteMedication(medId);
              }
              // أعد تحميل البيانات من قاعدة البيانات
              await _loadMedicinesFromDb();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حذف الدواء بنجاح',
                      style: GoogleFonts.tajawal(fontSize: 16),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              'حذف',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة تعديل دواء بحقول مستقلة للاسم، لون العلبة، ولون الحبة
  void _editMedicine(List<MedicineItem> list, int index) {
    final currentItem = list[index];
    final nameController = TextEditingController(text: currentItem.name);
    final boxController = TextEditingController(text: currentItem.boxDescription);
    final pillController = TextEditingController(text: currentItem.pillDescription);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: cardBorderColor, width: 1.4),
        ),
        title: Text(
          'تعديل الدواء',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: appbarColor,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(ctx).size.width * 0.92,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'اسم الدواء',
                    labelStyle: GoogleFonts.tajawal(
                      color: appbarColor,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: 'مثال: علاج المعدة',
                    hintStyle: GoogleFonts.tajawal(fontSize: 18),
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
                const SizedBox(height: 16),
                TextField(
                  controller: boxController,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'لون أو وصف العلبة',
                    labelStyle: GoogleFonts.tajawal(
                      color: iconColor,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: 'مثال: داخل العلبة الحمراء',
                    hintStyle: GoogleFonts.tajawal(fontSize: 18),
                    filled: true,
                    fillColor: backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                const SizedBox(height: 16),
                TextField(
                  controller: pillController,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.tajawal(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'لون أو وصف الحبة',
                    labelStyle: GoogleFonts.tajawal(
                      color: const Color(0xFF526E7A),
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                    hintText: 'مثال: الحبة الحمراء',
                    hintStyle: GoogleFonts.tajawal(fontSize: 18),
                    filled: true,
                    fillColor: backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: cardBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF526E7A), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(
                color: Colors.grey[700],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: appbarColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              final newName = nameController.text.trim();
              final newBox = boxController.text.trim();
              final newPill = pillController.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  list[index] = MedicineItem(
                    name: newName,
                    boxDescription: newBox.isNotEmpty ? newBox : currentItem.boxDescription,
                    pillDescription: newPill.isNotEmpty ? newPill : currentItem.pillDescription,
                    iconWidget: currentItem.iconWidget,
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم تعديل الدواء بنجاح',
                      style: GoogleFonts.tajawal(fontSize: 18),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              'حفظ التعديل',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
            // الشريط العلوي (CustomTopBar)
            CustomTopBar(
              title: 'الادوية',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),

            // جسم الصفحة المنحني: جميع الكروت تتمرر معاً تحت الـ AppBar
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Column(
                  children: [
                    // قائمة الكروت القابلة للتمرير معاً
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: appbarColor,
                              ),
                            )
                          : ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(top: 18.0, bottom: 12.0),
                        children: [
                          if (_dosesOffline) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF9A825)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    MedicationAdherenceHelper.outdatedCacheBanner(),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFF57F17),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    MedicationAdherenceHelper
                                        .offlineConfirmBlockedMessage(),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFBF360C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // 1. كروت أدوية الصباح
                          ..._buildSectionOrEmpty(
                            label: 'أدوية الصباح',
                            items: _morningMedicines,
                            ids: _morningIds,
                            emptyIcon: const Icon(Icons.sanitizer_rounded, size: 46, color: Color(0xFFC62828)),
                          ),

                          // 2. كروت أدوية بعد الغداء
                          ..._buildSectionOrEmpty(
                            label: 'أدوية بعد الغداء',
                            items: _afternoonMedicines,
                            ids: _afternoonIds,
                            emptyIcon: const Icon(Icons.medication_sharp, size: 46, color: Color(0xFFC0CA33)),
                          ),

                          // 3. كروت أدوية المساء
                          ..._buildSectionOrEmpty(
                            label: 'أدوية المساء',
                            items: _eveningMedicines,
                            ids: _eveningIds,
                            emptyIcon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.apps_rounded, color: Colors.white, size: 28),
                            ),
                          ),

                          const SizedBox(height: 10),
                        ],
                      ),
                    ),

                    // المنطقة السفلية الثابتة: زر إضافة دواء جديد بالبداية ثم زر اضغط للتحدث تحته
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
                      child: Column(
                        children: [
                          // 1. زر "إضافة دواء جديد" بالبداية
                          InkWell(
                            onTap: _navigateToAddMedicine,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: cardBorderColor, width: 1.2),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'اضافة دواء جديد',
                                    style: GoogleFonts.tajawal(
                                      color: appbarColor,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.add_rounded,
                                    color: appbarColor,
                                    size: 30,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 2. زر "اضغط للتحدث" تحته
                          Container(
                            width: double.infinity,
                            height: 56,
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
    );
  }

  // دالة مساعدة: تبني قسم أدوية فترة (list مع IDs) أو حالة فارغة
  List<Widget> _buildSectionOrEmpty({
    required String label,
    required List<MedicineItem> items,
    required List<int?> ids,
    required Widget emptyIcon,
  }) {
    if (items.isNotEmpty) {
      return [
        for (int i = 0; i < items.length; i++) ...[
          _buildMedicineCard(
            timeTitle: i == 0 ? label : '$label (إضافي)',
            item: items[i],
            medId: i < ids.length ? ids[i] : null,
            iconWidget: items[i].iconWidget,
            onEdit: () => _editMedicine(items, i),
            onDelete: () => _deleteMedicine(items, ids, i),
          ),
          const SizedBox(height: 14),
        ],
      ];
    } else {
      return [
        _buildMedicineCard(
          timeTitle: label,
          placeholderText: 'لا يوجد دواء مضاف لهذه الفترة',
          iconWidget: emptyIcon,
        ),
        const SizedBox(height: 14),
      ];
    }
  }

  // ودجت موحدة لبناء كروت الأدوية بتنسيق 3 أسطر ملونة وأزرار التعديل والحذف
  Widget _buildMedicineCard({
    required String timeTitle,
    MedicineItem? item,
    int? medId,
    String? placeholderText,
    Widget? iconWidget,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final dose = medId != null ? _todayDosesByMed[medId] : null;
    final displayState = dose?['display_state']?.toString();
    final labelAr = dose?['display_label_ar']?.toString() ??
        (_dosesOffline
            ? 'يلزم الاتصال لعرض الحالة'
            : MedicationAdherenceHelper.displayLabelAr(displayState));
    final confirmed =
        MedicationAdherenceHelper.isConfirmedState(displayState);
    final canConfirm = dose != null &&
        (dose['can_confirm'] == true) &&
        !confirmed &&
        !_confirmInFlight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط علوي صغير يوضح الفترة (صباح / بعد الغداء / مساء)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: appbarColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              timeTitle,
              style: GoogleFonts.tajawal(
                color: appbarColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // النصوص على اليمين (اسم الدواء، لون العلبة، لون الحبة)
              Expanded(
                child: item != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // السطر الأول: اسم العلاج
                          Text(
                            item.name,
                            style: GoogleFonts.tajawal(
                              color: Colors.black87,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // السطر الثاني: لون العلبة بلون ثاني (iconColor)
                          Row(
                            children: [
                              const Icon(
                                Icons.archive_outlined,
                                size: 19,
                                color: iconColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.boxDescription,
                                  style: GoogleFonts.tajawal(
                                    color: iconColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // السطر الثالث: لون الحبة بسطر مستقل بلون متناسق
                          Row(
                            children: [
                              const Icon(
                                Icons.medication_rounded,
                                size: 19,
                                color: Color(0xFF526E7A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.pillDescription,
                                  style: GoogleFonts.tajawal(
                                    color: const Color(0xFF526E7A),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'الحالة: $labelAr',
                            style: GoogleFonts.tajawal(
                              color: confirmed
                                  ? const Color(0xFF2E7D32)
                                  : (MedicationAdherenceHelper
                                          .isOverdueNotConfirmed(displayState)
                                      ? const Color(0xFFE53935)
                                      : appbarColor),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (dose?['confirmed_at'] != null)
                            Text(
                              'وقت التأكيد: ${dose!['confirmed_at']}',
                              style: GoogleFonts.tajawal(
                                color: Colors.black54,
                                fontSize: 15,
                              ),
                            ),
                        ],
                      )
                    : Text(
                        placeholderText ?? 'لا يوجد دواء مضاف',
                        style: GoogleFonts.tajawal(
                          color: Colors.black38,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              // أيقونة العلاج متمركزة في وسط الكارد على جهة اليسار
              SizedBox(
                width: 56,
                height: 56,
                child: Center(
                  child: iconWidget ??
                      const Icon(
                        Icons.medication_rounded,
                        size: 46,
                        color: appbarColor,
                      ),
                ),
              ),
            ],
          ),
          if (item != null && medId != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmed
                      ? const Color(0xFF2E7D32)
                      : appbarColor,
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _confirmInFlight
                    ? null
                    : (canConfirm
                        ? () => _confirmDose(medId)
                        : (_dosesOffline && !confirmed
                            ? () => _confirmDose(medId)
                            : null)),
                child: _confirmInFlight && !confirmed
                    ? const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        confirmed ? 'تم التأكيد على الخادم' : 'تم تناول الدواء',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: cardBorderColor),
            const SizedBox(height: 6),
            Row(
              children: [
                // زر التعديل في اليمين
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, color: appbarColor, size: 22),
                    label: Text(
                      'تعديل',
                      style: GoogleFonts.tajawal(
                        color: appbarColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                // زر الحذف في اليسار
                if (onDelete != null)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935), size: 22),
                    label: Text(
                      'حذف',
                      style: GoogleFonts.tajawal(
                        color: const Color(0xFFE53935),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
