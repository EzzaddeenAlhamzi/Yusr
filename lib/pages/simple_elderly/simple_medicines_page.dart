import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/api_service.dart';
import '../../core/services/medication_adherence_helper.dart';
import '../../core/services/senior_manager.dart';

/// شاشة الأدوية للوضع البسيط — P2.2: جدول اليوم + تأكيد خادم كبير السن.
class SimpleMedicinesPage extends StatefulWidget {
  const SimpleMedicinesPage({super.key});

  @override
  State<SimpleMedicinesPage> createState() => _SimpleMedicinesPageState();
}

class _SimpleMedicinesPageState extends State<SimpleMedicinesPage> {
  List<Map<String, dynamic>> _doses = [];
  bool _isLoading = false;
  bool _confirmInFlight = false;
  bool _offline = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDoses();
  }

  Future<void> _loadDoses() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _offline = false;
    });
    try {
      final senior = SeniorManager().currentSenior;
      final int? seniorId = int.tryParse(senior.id);
      final civil = MedicationAdherenceHelper.civilDateToday();
      final res = await ApiService.instance.getTodayMedicationDoses(
        elderlyId: seniorId,
        civilDate: civil,
      );
      if (!mounted) return;
      if (res['status'] == 'success' && res['data'] is List) {
        setState(() {
          _doses = (res['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      } else {
        final offline = res['is_connection_error'] == true ||
            res['error_type'] == 'connection_error';
        setState(() {
          _offline = offline;
          _error = res['message']?.toString() ??
              'تعذّر تحميل جرعات اليوم من الخادم';
          _doses = [];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _offline = true;
          _error = MedicationAdherenceHelper.outdatedCacheBanner();
          _doses = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirm(Map<String, dynamic> dose) async {
    if (_confirmInFlight) return;
    final medId = dose['Medicayion_ID'] is int
        ? dose['Medicayion_ID'] as int
        : int.tryParse(dose['Medicayion_ID']?.toString() ?? '');
    if (medId == null) return;

    setState(() => _confirmInFlight = true);
    try {
      final civil = MedicationAdherenceHelper.civilDateToday();
      final clientId =
          'simple-${medId}-${civil}-${DateTime.now().millisecondsSinceEpoch}';
      final res = await ApiService.instance.confirmMedicationDose(
        medicationId: medId,
        civilDate: civil,
        occurrenceKey: dose['occurrence_key']?.toString(),
        clientConfirmId: clientId,
      );
      if (!mounted) return;
      if (res['status'] != 'success') {
        final offline = res['is_connection_error'] == true ||
            res['error_type'] == 'connection_error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              offline
                  ? MedicationAdherenceHelper.offlineConfirmBlockedMessage()
                  : (res['message']?.toString() ?? 'تعذّر تأكيد الجرعة'),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? 'تم تأكيد تناول الدواء بنجاح',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      await _loadDoses();
    } finally {
      if (mounted) setState(() => _confirmInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopAppBar(context),
              const SizedBox(height: 8),
              if (_offline || _error != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF9A825)),
                    ),
                    child: Text(
                      _error ??
                          MedicationAdherenceHelper.outdatedCacheBanner(),
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF57F17),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF5E35B1),
                        ),
                      )
                    : _doses.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.medication_outlined,
                                      size: 64, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  Text(
                                    'لا توجد جرعات مجدولة لليوم',
                                    style: GoogleFonts.cairo(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDoses,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              itemCount: _doses.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 18),
                              itemBuilder: (context, index) {
                                return _buildDoseCard(_doses[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E35B1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.medication, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  'الأدوية',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard(Map<String, dynamic> dose) {
    final med = dose['medication'] is Map
        ? Map<String, dynamic>.from(dose['medication'] as Map)
        : <String, dynamic>{};
    final title = (med['M_Name'] ?? 'دواء').toString();
    final instruction = (med['M_much'] ?? '').toString();
    final repeat = (med['M_RepatTime'] ?? '').toString();
    final time = (dose['scheduled_time'] ?? '').toString();
    final displayState = dose['display_state']?.toString();
    final labelAr = dose['display_label_ar']?.toString() ??
        MedicationAdherenceHelper.displayLabelAr(displayState);
    final confirmed =
        MedicationAdherenceHelper.isConfirmedState(displayState);
    final canConfirm =
        dose['can_confirm'] == true && !confirmed && !_confirmInFlight;
    final isNight = (dose['slot']?.toString() ?? '') == 'evening';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD1C4E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            instruction.isNotEmpty ? instruction : 'الجرعة غير محددة',
            style: GoogleFonts.cairo(
              fontSize: 17,
              color: const Color(0xFF37474F),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (repeat.isNotEmpty)
            Text(
              repeat,
              style: GoogleFonts.cairo(
                fontSize: 16,
                color: const Color(0xFF546E7A),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  color: isNight
                      ? const Color(0xFF1565C0)
                      : const Color(0xFFF9A825),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    time.isNotEmpty ? time : 'موعد اليوم',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  labelAr,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: confirmed
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF6A1B9A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmed
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF5E35B1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: canConfirm
                  ? () => _confirm(dose)
                  : (_offline && !confirmed
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                MedicationAdherenceHelper
                                    .offlineConfirmBlockedMessage(),
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                ),
                              ),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      : null),
              child: Text(
                confirmed ? 'تم التأكيد على الخادم' : 'تم تناول الدواء',
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
