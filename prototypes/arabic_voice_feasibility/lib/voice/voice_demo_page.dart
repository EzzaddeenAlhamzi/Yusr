import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../synthetic/demo_replies.dart';

/// Explicit-tap Arabic STT → synthetic reply → on-device TTS.
///
/// Safety: no always-on mic, no audio file storage, no backend / Gemini calls,
/// no med reminders / emergency / external actions.
class VoiceDemoPage extends StatefulWidget {
  const VoiceDemoPage({super.key});

  @override
  State<VoiceDemoPage> createState() => _VoiceDemoPageState();
}

enum _Phase { idle, requestingPermission, listening, matching, speaking, error }

class _VoiceDemoPageState extends State<VoiceDemoPage> {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  _Phase _phase = _Phase.idle;
  String _statusAr = 'اضغط الميكروفون وقل جملة عربية قصيرة.';
  String _recognized = '';
  SyntheticReply? _reply;
  String? _error;
  bool _sttReady = false;
  bool _ttsReady = false;
  bool _finishing = false;
  String _ttsLocale = 'ar';
  String? _sttLocaleId;

  static const _preferredSttLocales = [
    'ar_SA',
    'ar-SA',
    'ar_EG',
    'ar-EG',
    'ar_AE',
    'ar-AE',
    'ar',
  ];

  static const _preferredTtsLocales = [
    'ar-SA',
    'ar-EG',
    'ar-AE',
    'ar-XA',
    'ar',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    unawaited(_stt.stop());
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      _sttReady = await _stt.initialize(
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _phase = _Phase.error;
            _error = 'خطأ التعرف: ${e.errorMsg}';
            _statusAr = 'توقف التعرف على الكلام.';
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            if (_phase == _Phase.listening) {
              unawaited(_finishListening());
            }
          }
        },
      );

      if (_sttReady) {
        final locales = await _stt.locales();
        _sttLocaleId = _pickSttLocale(locales.map((l) => l.localeId).toList());
      }

      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      final langs = await _tts.getLanguages;
      if (langs is List) {
        _ttsLocale = _pickTtsLocale(langs.map((e) => '$e').toList());
      }
      await _tts.setLanguage(_ttsLocale);
      _ttsReady = true;

      if (mounted) {
        setState(() {
          _statusAr = _sttReady
              ? 'جاهز. الميكروفون يعمل بالضغط فقط — لا تسجيل خلفي.'
              : 'التعرف على الكلام غير متاح على هذا الجهاز.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = '$e';
        _statusAr = 'فشل تهيئة الصوت.';
      });
    }
  }

  String? _pickSttLocale(List<String> available) {
    final lower = {for (final a in available) a.toLowerCase(): a};
    for (final pref in _preferredSttLocales) {
      final hit = lower[pref.toLowerCase()];
      if (hit != null) return hit;
    }
    for (final a in available) {
      if (a.toLowerCase().startsWith('ar')) return a;
    }
    return available.isEmpty ? null : available.first;
  }

  String _pickTtsLocale(List<String> available) {
    final lower = {for (final a in available) a.toLowerCase(): a};
    for (final pref in _preferredTtsLocales) {
      final hit = lower[pref.toLowerCase()];
      if (hit != null) return hit;
    }
    for (final a in available) {
      if (a.toLowerCase().startsWith('ar')) return a;
    }
    return 'ar';
  }

  Future<void> _onMicTap() async {
    if (_phase == _Phase.listening) {
      await _stt.stop();
      await _finishListening();
      return;
    }
    if (_phase == _Phase.speaking) {
      await _tts.stop();
      setState(() {
        _phase = _Phase.idle;
        _statusAr = 'تم إيقاف النطق.';
      });
      return;
    }
    if (_phase == _Phase.requestingPermission || _phase == _Phase.matching) {
      return;
    }

    setState(() {
      _phase = _Phase.requestingPermission;
      _finishing = false;
      _error = null;
      _recognized = '';
      _reply = null;
      _statusAr = 'طلب إذن الميكروفون…';
    });

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() {
        _phase = _Phase.error;
        _error = 'رُفض إذن الميكروفون. يمكن المتابعة نصياً لاحقاً في المنتج؛ هنا يلزم الميكروفون.';
        _statusAr = 'لا يمكن الاستماع بدون إذن.';
      });
      return;
    }

    if (!_sttReady) {
      setState(() {
        _phase = _Phase.error;
        _error = 'محرك التعرف غير جاهز.';
        _statusAr = 'أعد فتح التطبيق أو ثبّت حزمة لغة عربية للتعرف.';
      });
      return;
    }

    setState(() {
      _phase = _Phase.listening;
      _statusAr = 'يستمع… قل جملة قصيرة ثم انتظر، أو اضغط لإيقاف.';
    });

    await _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _recognized = result.recognizedWords;
        });
        if (result.finalResult) {
          unawaited(_finishListening());
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        localeId: _sttLocaleId,
        // Feasibility default: allow platform network STT when offline
        // Arabic packs are missing. Prototype never persists audio.
        // P4 should re-evaluate onDevice:true / Vosk per PO-V03.
        onDevice: false,
      ),
    );
  }

  Future<void> _finishListening() async {
    if (_finishing) return;
    if (_phase != _Phase.listening) return;
    _finishing = true;

    await _stt.stop();
    if (!mounted) return;

    setState(() {
      _phase = _Phase.matching;
      _statusAr = 'مطابقة رد تجريبي…';
    });

    final reply = matchSyntheticReply(_recognized);
    setState(() {
      _reply = reply;
      _phase = _Phase.speaking;
      _statusAr = 'ينطق الرد التجريبي (${reply.id})…';
    });

    if (_ttsReady) {
      await _tts.speak(reply.replyAr);
    }

    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _statusAr = 'انتهى. اضغط الميكروفون مجدداً لعبارة أخرى.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final listening = _phase == _Phase.listening;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F4B3A),
          foregroundColor: Colors.white,
          title: const Text('يُسر — جدوى الصوت (تجريبي)'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1C2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC9A227)),
                ),
                child: const Text(
                  'NON-PRODUCTION / Track B feasibility only.\n'
                  'لا ميكروفون دائم • لا رفع صامت • لا تخزين تسجيل • ردود وهمية فقط.\n'
                  'لا تذكير أدوية / طوارئ / إجراءات خارجية.',
                  style: TextStyle(height: 1.45, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _statusAr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F4B3A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'STT locale: ${_sttLocaleId ?? "—"}  |  TTS locale: $_ttsLocale',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 24),
              Center(
                child: Semantics(
                  button: true,
                  label: listening ? 'إيقاف الاستماع' : 'بدء الاستماع',
                  child: InkWell(
                    onTap: _onMicTap,
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: listening
                            ? const Color(0xFFB42318)
                            : const Color(0xFF1F4B3A),
                        boxShadow: [
                          BoxShadow(
                            color: (listening
                                    ? const Color(0xFFB42318)
                                    : const Color(0xFF1F4B3A))
                                .withValues(alpha: 0.35),
                            blurRadius: listening ? 24 : 12,
                            spreadRadius: listening ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        listening ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _LabeledBlock(
                title: 'النص المتعرف عليه',
                body: _recognized.isEmpty ? '—' : _recognized,
              ),
              const SizedBox(height: 16),
              _LabeledBlock(
                title: _reply == null
                    ? 'الرد التجريبي'
                    : 'الرد التجريبي · ${_reply!.id} · ${_reply!.label}',
                body: _reply?.replyAr ?? '—',
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB42318), height: 1.4),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'عبارات مدعومة للتجربة: مرحبا / كيف حالك / ما اسمك / شكرا / اختبار',
                style: TextStyle(color: Colors.grey.shade800, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5C6B5A),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD9E0D6)),
          ),
          child: Text(
            body,
            style: const TextStyle(fontSize: 20, height: 1.45),
          ),
        ),
      ],
    );
  }
}
