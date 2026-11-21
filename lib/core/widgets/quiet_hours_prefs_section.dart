import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/local_notification_ids.dart';
import '../services/local_notification_service.dart';

/// Elderly quiet-hours prefs (Arabic RTL). Lock G: meds never silently dropped.
class QuietHoursPrefsSection extends StatefulWidget {
  const QuietHoursPrefsSection({
    super.key,
    this.compact = false,
    this.primaryColor = const Color(0xFF125D73),
  });

  /// When true, hides the large page title chrome (for home-bell dialog embed).
  final bool compact;
  final Color primaryColor;

  @override
  State<QuietHoursPrefsSection> createState() => _QuietHoursPrefsSectionState();
}

class _QuietHoursPrefsSectionState extends State<QuietHoursPrefsSection> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  String _startHm = '22:00';
  String _endHm = '07:00';
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthService().userId;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = 'سجّل الدخول لحفظ تفضيلات ساعات الهدوء.';
        });
      }
      return;
    }
    try {
      final q = await LocalNotificationService.instance.loadQuietHours(uid);
      if (!mounted) return;
      setState(() {
        _enabled = q.enabled;
        _startHm = q.startHm;
        _endHm = q.endHm;
        _loading = false;
        _status = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'تعذّر تحميل إعدادات ساعات الهدوء.';
      });
    }
  }

  Future<void> _persist() async {
    final uid = AuthService().userId;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await LocalNotificationService.instance.saveQuietHours(
        uid,
        QuietHoursPolicy(
          enabled: _enabled,
          startHm: _startHm,
          endHm: _endHm,
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = _enabled
            ? 'تم حفظ ساعات الهدوء ($_startHm – $_endHm).'
            : 'ساعات الهدوء متوقفة.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = 'تعذّر حفظ الإعدادات.';
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = _parseHm(isStart ? _startHm : _endHm) ??
        const TimeOfDay(hour: 22, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: isStart ? 'بداية ساعات الهدوء' : 'نهاية ساعات الهدوء',
      cancelText: 'إلغاء',
      confirmText: 'تم',
      builder: (ctx, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Localizations.override(
            context: ctx,
            locale: const Locale('ar'),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    final hm =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _startHm = hm;
      } else {
        _endHm = hm;
      }
    });
    await _persist();
  }

  TimeOfDay? _parseHm(String hm) {
    final parts = hm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor;
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: primary),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 14 : 18,
          vertical: widget.compact ? 14 : 18,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime_rounded, color: primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ساعات الهدوء',
                    style: GoogleFonts.cairo(
                      fontSize: widget.compact ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E232A),
                    ),
                  ),
                ),
                Switch(
                  value: _enabled,
                  activeThumbColor: primary,
                  onChanged: _saving
                      ? null
                      : (v) async {
                          setState(() => _enabled = v);
                          await _persist();
                        },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              QuietHoursPolicy.arabicMedExceptionCopy,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF267364),
                height: 1.4,
              ),
            ),
            if (_enabled) ...[
              const SizedBox(height: 14),
              Text(
                'خلال هذه الفترة قد تُؤجَّل تذكيرات المواعيد فقط — تذكيرات الدواء تبقى في موعدها.',
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TimeChip(
                      label: 'من',
                      value: _startHm,
                      primary: primary,
                      onTap: _saving ? null : () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeChip(
                      label: 'إلى',
                      value: _endHm,
                      primary: primary,
                      onTap: _saving ? null : () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
            ],
            if (_status != null) ...[
              const SizedBox(height: 10),
              Text(
                _status!,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.value,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
