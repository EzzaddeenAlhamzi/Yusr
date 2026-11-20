import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/api_service.dart';
import '../../core/services/local_notification_service.dart';
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

  void _showConfirmFailureSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 16),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _loadDoses() async {
    setState(() {
      _isLoading = true;
      _error = null;
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
        final doses = (res['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() {
          _offline = false;
          _error = null;
          _doses = doses;
        });
        if (seniorId != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await LocalNotificationService.instance.syncMedicationDoses(
              elderlyId: seniorId,
              doses: doses,
              remindersEnabledForMed: (medId) {
                return prefs.getBool('med_reminder_active_${seniorId}_$medId') ??
                    true;
              },
            );
          } catch (_) {}
        }
      } else {
        final offline = MedicationAdherenceHelper.isConnectionFailure(res);
        setState(() {
          _offline = offline;
          _error = offline
              ? MedicationAdherenceHelper.offlineConfirmBlockedMessage()
              : (res['message']?.toString() ??
                  'تعذّر تحميل جرعات اليوم من الخادم');
          // Keep last good doses when offline so confirm CTA can show
          // Arabic blocked feedback instead of empty spinner-only UI.
          if (!offline) {
            _doses = [];
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _offline = true;
          _error = MedicationAdherenceHelper.offlineConfirmBlockedMessage();
        });
        _showConfirmFailureSnack(
          MedicationAdherenceHelper.offlineConfirmBlockedMessage(),
        );
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

    // Known offline: never hit the network, never show Taken / success.
    if (_offline) {
      _showConfirmFailureSnack(
        MedicationAdherenceHelper.offlineConfirmBlockedMessage(),
      );
      return;
    }

    setState(() => _confirmInFlight = true);
    try {
      final civil = MedicationAdherenceHelper.civilDateToday();
      final clientId =
          'simple-$medId-$civil-${DateTime.now().millisecondsSinceEpoch}';
      final res = await ApiService.instance.confirmMedicationDose(
        medicationId: medId,
        civilDate: civil,
        occurrenceKey: dose['occurrence_key']?.toString(),
        clientConfirmId: clientId,
      );
      if (!mounted) return;
      if (!MedicationAdherenceHelper.isConfirmSuccess(res)) {
        if (MedicationAdherenceHelper.isConnectionFailure(res)) {
          setState(() => _offline = true);
        }
        _showConfirmFailureSnack(
          MedicationAdherenceHelper.confirmFailureMessage(res),
        );
        return;
      }
      final occKey = dose['occurrence_key']?.toString();
      final eid = int.tryParse(SeniorManager().currentSenior?.id ?? '');
      if (occKey != null && eid != null) {
        try {
          await LocalNotificationService.instance.cancelMedicationOccurrence(
            elderlyId: eid,
            occurrenceKey: occKey,
          );
        } catch (_) {}
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
    } catch (_) {
      if (mounted) {
        setState(() => _offline = true);
        _showConfirmFailureSnack(
          MedicationAdherenceHelper.offlineConfirmBlockedMessage(),
        );
      }
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
                                    _offline
                                        ? MedicationAdherenceHelper
                                            .offlineConfirmBlockedMessage()
                                        : 'لا توجد جرعات مجدولة لليوم',
                                    style: GoogleFonts.cairo(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
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
              onPressed: _confirmInFlight
                  ? null
                  : (canConfirm
                      ? () => _confirm(dose)
                      : (_offline && !confirmed
                          ? () => _confirm(dose)
                          : null)),
              child: _confirmInFlight && !confirmed
                  ? const SizedBox(
                      height: 26,
                      width: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : Text(
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
