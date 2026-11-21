import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shard/color.dart';
import '../shard/custom_header.dart';
import '../shard/appointment_item.dart';
import '../core/services/api_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/local_notification_ids.dart';
import '../core/services/local_notification_service.dart';
import '../core/services/senior_manager.dart';
import '../core/widgets/appointment_advance_reminder_line.dart';
import 'ai_page.dart';
import 'past_dates.dart';
import 'add_date.dart';

class DatesScreen extends StatefulWidget {
  const DatesScreen({super.key});

  @override
  State<DatesScreen> createState() => _DatesScreenState();
}

// الاسم البديل للتوافق
typedef AppointmentsScreen = DatesScreen;

class _DatesScreenState extends State<DatesScreen> {
  static const List<String> _advanceOptions = [
    'بدون تذكير مسبق',
    'قبل الموعد بـ 15 دقيقة',
    'قبل الموعد بـ 30 دقيقة',
    'قبل الموعد بساعة',
    'قبل الموعد بيوم واحد',
  ];

  List<AppointmentItem> _appointments = [];
  bool _isLoading = true;
  bool _permissionHintShown = false;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  /// Elderly-only scheduling uses the signed-in senior id (authorized own appts).
  int? get _ownElderlyId {
    if (AuthService().isSenior) return AuthService().userId;
    return int.tryParse(SeniorManager().currentSenior.id);
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final int? seniorId = _ownElderlyId;

      final list = await ApiService.instance.getAppointments(elderlyId: seniorId);
      if (list.isEmpty && ApiService.lastListError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.lastListError!,
              style: GoogleFonts.tajawal(),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final items = <AppointmentItem>[];
      final syncRows = <Map<String, dynamic>>[];
      for (final a in list) {
        final idRaw = a['Appointment_ID'];
        final id = idRaw is int
            ? idRaw
            : int.tryParse(idRaw?.toString() ?? '');
        final dateStr = (a['A_Date'] ?? '').toString();
        final timeRaw = (a['A_Time'] ?? 'غير محدد').toString();
        final timeFormatted =
            timeRaw.length >= 5 ? timeRaw.substring(0, 5) : timeRaw;
        final remKey = seniorId != null && id != null
            ? 'appt_advance_rem_${seniorId}_$id'
            : null;
        final advanceReminder = remKey == null
            ? AppointmentReminderOffset.defaultLabel
            : (prefs.getString(remKey) ??
                AppointmentReminderOffset.defaultLabel);

        DateTime? apptDateTime;
        final cleanDate = dateStr.split('T').first.trim();
        final cleanTime = timeRaw.trim();
        apptDateTime = DateTime.tryParse('$cleanDate $cleanTime');
        if (apptDateTime == null && cleanDate.isNotEmpty) {
          apptDateTime = DateTime.tryParse(cleanDate);
        }
        final isPast =
            apptDateTime != null ? now.isAfter(apptDateTime) : false;

        items.add(AppointmentItem(
          id: id?.toString() ?? idRaw?.toString(),
          title: a['A_DateType'] ?? 'موعد',
          day: a['A_Date'] ?? 'قريباً',
          time: timeFormatted,
          date: a['A_Date']?.toString(),
          notes: a['A_Note']?.toString(),
          location: a['A_Location']?.toString(),
          advanceReminder: advanceReminder,
          dateTime: apptDateTime,
          isPast: isPast,
        ));
        if (id != null && apptDateTime != null) {
          syncRows.add({
            'id': id,
            'title': a['A_DateType'] ?? 'موعد',
            'dateTime': apptDateTime,
            'advanceReminder': advanceReminder,
            'isCancelled': false,
            'isPast': isPast,
          });
        }
      }
      if (mounted) {
        setState(() {
          _appointments = items;
        });
      }
      // Channel A on the elderly handset — device-local; not CG device sync.
      if (AuthService().isSenior && seniorId != null) {
        await _syncElderlyAppointmentReminders(seniorId, syncRows);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'تعذّر تحميل المواعيد. يرجى التأكد من اتصال الخادم والإنترنت.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Schedule/cancel Lock K reminders on this elderly Android device only.
  Future<void> _syncElderlyAppointmentReminders(
    int elderlyId,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      await LocalNotificationService.instance.initialize();
      final quiet =
          await LocalNotificationService.instance.loadQuietHours(elderlyId);
      final needsSchedule = items.any((item) {
        final offset = AppointmentReminderOffset.minutesFromLabel(
          item['advanceReminder']?.toString(),
        );
        return item['isPast'] != true &&
            item['isCancelled'] != true &&
            offset > 0;
      });
      if (needsSchedule) {
        final granted =
            await LocalNotificationService.instance.isPermissionGranted();
        if (!granted && mounted && !_permissionHintShown) {
          _permissionHintShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'لم يُمنح إذن الإشعارات. لن تُجدول تذكيرات المواعيد على هذا الجهاز حتى تفعّلها من الإعدادات.',
                style: GoogleFonts.tajawal(fontSize: 15),
              ),
              backgroundColor: const Color(0xFFE65100),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      await LocalNotificationService.instance.syncAppointmentReminders(
        elderlyId: elderlyId,
        items: items,
        quiet: quiet,
        navRoute: '/dates',
      );
    } catch (_) {}
  }

  // الانتقال لصفحة إضافة موعد جديد
  void _navigateToAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddDateScreen()),
    );
    if (result != null) {
      await _loadAppointments();
    }
  }

  // دالة حذف الموعد مع نافذة تأكيد
  void _deleteAppointment(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: cardBorderColor, width: 1.2),
        ),
        title: Text(
          'حذف الموعد',
          textAlign: TextAlign.center,
          style: GoogleFonts.tajawal(
            color: const Color(0xFFE53935),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف هذا الموعد؟',
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
              final item = _appointments[index];
              Navigator.pop(ctx);
              if (item.id.isEmpty || int.tryParse(item.id) == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تعذّر حذف الموعد: معرف غير صالح',
                        style: GoogleFonts.tajawal(fontSize: 16),
                      ),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
                return;
              }
              try {
                final parsedId = int.parse(item.id);
                final res =
                    await ApiService.instance.deleteAppointment(parsedId);
                if (!mounted) return;
                if (res['status'] != 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        res['message']?.toString() ?? 'تعذّر حذف الموعد',
                        style: GoogleFonts.tajawal(fontSize: 16),
                      ),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                  return;
                }
                final elderlyId = _ownElderlyId;
                if (AuthService().isSenior && elderlyId != null) {
                  await LocalNotificationService.instance
                      .cancelAppointmentReminder(
                    elderlyId: elderlyId,
                    appointmentId: parsedId,
                  );
                }
                if (!mounted) return;
                setState(() {
                  _appointments.removeAt(index);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حذف الموعد بنجاح',
                      style: GoogleFonts.tajawal(fontSize: 16),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تعذّر الاتصال بالخادم أثناء الحذف',
                        style: GoogleFonts.tajawal(fontSize: 16),
                      ),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
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

  static bool _isValidAppointmentDate(String raw) {
    final text = raw.trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return false;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return false;
    final dt = DateTime.tryParse(text);
    if (dt == null) return false;
    return dt.year == year && dt.month == month && dt.day == day;
  }

  static String _normalizeAppointmentTime(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '09:00:00';
    if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(t)) return t;
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(t)) return '$t:00';
    return t;
  }

  // دالة تعديل الموعد — تحديث على الخادم بنفس Appointment_ID
  void _editAppointment(int index) {
    final item = _appointments[index];
    final appointmentId = int.tryParse(item.id);
    final titleController = TextEditingController(text: item.title);
    final dayController = TextEditingController(
      text: (item.date ?? item.day).toString(),
    );
    final timeController = TextEditingController(text: item.time);
    final locationController =
        TextEditingController(text: item.location ?? '');
    final notesController = TextEditingController(text: item.notes ?? '');
    final pageMessenger = ScaffoldMessenger.of(context);
    var isSaving = false;
    // Shown inside the dialog so invalid-date feedback stays visible above the
    // modal (page SnackBar alone can sit behind the barrier / IME).
    var dateError = '';
    var selectedAdvance =
        item.advanceReminder ?? AppointmentReminderOffset.defaultLabel;
    if (!_advanceOptions.contains(selectedAdvance)) {
      selectedAdvance = AppointmentReminderOffset.defaultLabel;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: cardColor,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: cardBorderColor, width: 1.4),
            ),
            title: Text(
              'تعديل الموعد',
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
                      controller: titleController,
                      textAlign: TextAlign.right,
                      enabled: !isSaving,
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'اسم الزيارة',
                        labelStyle: GoogleFonts.tajawal(
                          color: appbarColor,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: 'مثال: موعد مشفى',
                        hintStyle: GoogleFonts.tajawal(fontSize: 18),
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: cardBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: appbarColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: dayController,
                      textAlign: TextAlign.right,
                      enabled: !isSaving,
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      onChanged: (_) {
                        if (dateError.isNotEmpty) {
                          setDialogState(() => dateError = '');
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'تاريخ الزيارة (YYYY-MM-DD)',
                        labelStyle: GoogleFonts.tajawal(
                          color: iconColor,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: 'مثال: 2026-12-20',
                        hintStyle: GoogleFonts.tajawal(fontSize: 18),
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        errorText: dateError.isEmpty ? null : dateError,
                        errorMaxLines: 3,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: cardBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: iconColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: timeController,
                      textAlign: TextAlign.right,
                      enabled: !isSaving,
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ساعة الزيارة (HH:MM)',
                        labelStyle: GoogleFonts.tajawal(
                          color: const Color(0xFF526E7A),
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: 'مثال: 09:00',
                        hintStyle: GoogleFonts.tajawal(fontSize: 18),
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: cardBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF526E7A), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: locationController,
                      textAlign: TextAlign.right,
                      enabled: !isSaving,
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'المكان',
                        labelStyle: GoogleFonts.tajawal(
                          color: appbarColor,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: 'مثال: المستشفى',
                        hintStyle: GoogleFonts.tajawal(fontSize: 18),
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: cardBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: appbarColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      textAlign: TextAlign.right,
                      enabled: !isSaving,
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ملاحظات',
                        labelStyle: GoogleFonts.tajawal(
                          color: iconColor,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: 'اختياري',
                        hintStyle: GoogleFonts.tajawal(fontSize: 18),
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: cardBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: iconColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'ضبط تذكير مسبق (على هذا الجهاز فقط):',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appbarColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAdvance,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: backgroundColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: cardBorderColor),
                        ),
                      ),
                      items: _advanceOptions
                          .map(
                            (opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(
                                opt,
                                style: GoogleFonts.tajawal(fontSize: 16),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (v) {
                              if (v != null) {
                                setDialogState(() => selectedAdvance = v);
                              }
                            },
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            actionsPadding:
                const EdgeInsets.only(bottom: 20, left: 16, right: 16),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (appointmentId == null) {
                          pageMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'تعذّر تحديد رقم الموعد للتعديل',
                                style: GoogleFonts.tajawal(fontSize: 16),
                              ),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }
                        final dateText = dayController.text.trim();
                        if (!_isValidAppointmentDate(dateText)) {
                          const msg =
                              'تاريخ الموعد غير صالح. استخدم صيغة YYYY-MM-DD صحيحة.';
                          setDialogState(() => dateError = msg);
                          pageMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                msg,
                                style: GoogleFonts.tajawal(fontSize: 16),
                              ),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }
                        if (dateError.isNotEmpty) {
                          setDialogState(() => dateError = '');
                        }
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          pageMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'اسم الزيارة مطلوب',
                                style: GoogleFonts.tajawal(fontSize: 16),
                              ),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        Map<String, dynamic> res;
                        try {
                          res = await ApiService.instance.updateAppointment(
                            appointmentId: appointmentId,
                            date: dateText,
                            time: _normalizeAppointmentTime(
                                timeController.text),
                            dateType: title,
                            location: locationController.text.trim(),
                            note: notesController.text.trim(),
                          );
                        } catch (_) {
                          setDialogState(() => isSaving = false);
                          pageMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'تعذّر حفظ تعديل الموعد على الخادم',
                                style: GoogleFonts.tajawal(fontSize: 16),
                              ),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }

                        if (res['status'] != 'success') {
                          setDialogState(() => isSaving = false);
                          pageMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                (res['message']?.toString().trim().isNotEmpty ==
                                        true)
                                    ? res['message'].toString()
                                    : 'تعذّر حفظ تعديل الموعد على الخادم',
                                style: GoogleFonts.tajawal(fontSize: 16),
                              ),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                          return;
                        }

                        // Device-local offset prefs (not server-persisted).
                        final elderlyId = _ownElderlyId;
                        if (elderlyId != null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(
                            'appt_advance_rem_${elderlyId}_$appointmentId',
                            selectedAdvance,
                          );
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        pageMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم تحديث الموعد بنجاح',
                              style: GoogleFonts.tajawal(fontSize: 16),
                            ),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                        // Reload reconciles local schedules (edit/offset/disable).
                        if (mounted) await _loadAppointments();
                      },
                child: Text(
                  isSaving ? 'جاري الحفظ...' : 'حفظ التعديل',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
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
            // الشريط العلوي المخصص من مجلد shard
            CustomTopBar(
              title: 'المواعيد',
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 10),
            // جسم الصفحة الرئيسي المنحني من مجلد shard
            Expanded(
              child: CurvedBodyContainer(
                padding: const EdgeInsets.symmetric(horizontal: 22.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // زر التنقل الثنائي (القادمة / الماضية)
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: cardBorderColor, width: 1),
                      ),
                      child: Row(
                        children: [
                          // القادمة
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: appbarColor,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'القادمة',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // الماضية
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, anim1, anim2) =>
                                        const PastDatesScreen(),
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration: Duration.zero,
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'الماضية',
                                  style: GoogleFonts.tajawal(
                                    color: appbarColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    // قائمة المواعيد
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: appbarColor),
                            )
                          : _appointments.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'لا توجد مواعيد مضافة حالياً',
                                        style: GoogleFonts.tajawal(
                                          color: Colors.grey[700],
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'يمكنك إضافة موعدك الجديد من الزر بالأسفل',
                                        style: GoogleFonts.tajawal(
                                          color: Colors.grey[500],
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  itemCount: _appointments.length,
                                  itemBuilder: (context, index) {
                                    return _buildAppointmentCard(_appointments[index], index);
                                  },
                                ),
                    ),
                    const SizedBox(height: 10),
                    // كارت إضافة موعد جديد
                    GestureDetector(
                      onTap: _navigateToAdd,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorderColor, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'اضافة موعد جديد',
                              style: GoogleFonts.tajawal(
                                color: appbarColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.add,
                              color: appbarColor,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // زر "اضغط للتحدث"
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
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

  // ودجت كارت الموعد مع أزرار التعديل والحذف
  Widget _buildAppointmentCard(AppointmentItem item, int index) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // تفاصيل الموعد المقسمة على أسطر مخصصة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // السطر الأول: اسم الزيارة
                Text(
                  item.title,
                  style: GoogleFonts.tajawal(
                    color: Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // السطر الثاني: يوم الزيارة بلون ثاني
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.day,
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
                // السطر الثالث: ساعة الزيارة بسطر مستقل ولون مناسب
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: Color(0xFF526E7A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.time,
                        style: GoogleFonts.tajawal(
                          color: const Color(0xFF526E7A),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (AppointmentAdvanceReminderLine.shouldShow(
                    item.advanceReminder)) ...[
                  const SizedBox(height: 6),
                  AppointmentAdvanceReminderLine(
                    advanceReminder: item.advanceReminder!,
                    fontSize: 15,
                    iconSize: 18,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // أزرار الإجراءات: تعديل وحذف
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: appbarColor,
                  size: 26,
                ),
                onPressed: () => _editAppointment(index),
                tooltip: 'تعديل',
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE53935),
                  size: 26,
                ),
                onPressed: () => _deleteAppointment(index),
                tooltip: 'حذف',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
