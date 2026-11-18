/// Labeled **synthetic** demo replies for Track B feasibility only.
///
/// Rules:
/// - No real patient / medication / appointment data.
/// - No emergency escalation, reminders, or external actions.
/// - Matching is keyword-based on STT text (MSA + common Gulf/Yemeni cues).
library;

class SyntheticReply {
  const SyntheticReply({
    required this.id,
    required this.label,
    required this.replyAr,
  });

  /// Stable catalog id for audit / screenshots.
  final String id;

  /// Human-readable label (English) — never spoken; shown in UI as synthetic.
  final String label;

  /// Arabic text spoken via TTS and shown on screen.
  final String replyAr;
}

/// Fallback when no keyword matches.
const SyntheticReply kFallbackReply = SyntheticReply(
  id: 'SYN-FALLBACK',
  label: 'unmatched_phrase',
  replyAr:
      'هذه تجربة صوتية تجريبية فقط. لم أتعرف على عبارة مدعومة. جرّب: مرحبا، كيف حالك، أو ما اسمك.',
);

/// Explicit non-action when emergency-like words appear.
const SyntheticReply kNoEmergencyReply = SyntheticReply(
  id: 'SYN-NO-EMERGENCY',
  label: 'emergency_words_blocked',
  replyAr:
      'تنبيه: هذا النموذج التجريبي لا يتعامل مع الطوارئ ولا يرسل تنبيهات. في حالة الطوارئ الحقيقية اتصل بخدمات الإسعاف مباشرة.',
);

/// Explicit non-action when medication reminder language appears.
const SyntheticReply kNoMedsReply = SyntheticReply(
  id: 'SYN-NO-MEDS',
  label: 'medication_words_blocked',
  replyAr:
      'هذا النموذج لا يعرض أدوية حقيقية ولا يذكّر بمواعيد الدواء. الردود هنا بيانات تجريبية فقط.',
);

const List<({List<String> keywords, SyntheticReply reply})> kDemoCatalog = [
  (
    keywords: ['مرحبا', 'السلام', 'اهلا', 'أهلا', 'هلا'],
    reply: SyntheticReply(
      id: 'SYN-GREETING',
      label: 'greeting',
      replyAr: 'أهلاً بك. أنا مساعد صوتي تجريبي ليُسر — غير إنتاجي، والردود بيانات وهمية.',
    ),
  ),
  (
    keywords: ['كيف حالك', 'كيفك', 'شلونك', 'عامل ايه'],
    reply: SyntheticReply(
      id: 'SYN-HOWAREYOU',
      label: 'how_are_you',
      replyAr: 'بخير والحمد لله. هذه جملة تجريبية للتأكد من النطق العربي عبر الجهاز.',
    ),
  ),
  (
    keywords: ['ما اسمك', 'اسمك', 'من انت', 'من أنت'],
    reply: SyntheticReply(
      id: 'SYN-NAME',
      label: 'name_intro',
      replyAr: 'اسمي يُسر — نموذج جدوى للصوت فقط، ولست المساعد الإنتاجي بعد.',
    ),
  ),
  (
    keywords: ['شكرا', 'شكراً', 'مشكور', 'تسلم'],
    reply: SyntheticReply(
      id: 'SYN-THANKS',
      label: 'thanks',
      replyAr: 'العفو. انتهى هذا الرد التجريبي.',
    ),
  ),
  (
    keywords: ['اختبار', 'تجربة', 'تجريبي'],
    reply: SyntheticReply(
      id: 'SYN-TEST',
      label: 'self_test',
      replyAr: 'تم استلام عبارة الاختبار. التعرف على الكلام والرد الصوتي يعملان في هذا النموذج.',
    ),
  ),
];

const List<String> _emergencyKeywords = [
  'طوارئ',
  'اسعاف',
  'إسعاف',
  'نجدة',
  'ساعدني',
  'ألم',
  'اختناق',
  'سقوط',
  'نبضة',
];

const List<String> _medKeywords = [
  'دواء',
  'دواي',
  'ادوية',
  'أدوية',
  'ادويتي',
  'أدويتي',
  'جرعة',
  'تذكير',
  'حبوب',
  'علاج',
];

/// Maps recognized Arabic text → labeled synthetic reply.
SyntheticReply matchSyntheticReply(String recognizedText) {
  final text = recognizedText.trim();
  if (text.isEmpty) {
    return const SyntheticReply(
      id: 'SYN-EMPTY',
      label: 'empty_transcript',
      replyAr: 'لم أسمع عبارة واضحة. اضغط الميكروفون وقل جملة قصيرة بالعربية.',
    );
  }

  final normalized = text.replaceAll(RegExp(r'\s+'), ' ');

  for (final word in _emergencyKeywords) {
    if (normalized.contains(word)) {
      return kNoEmergencyReply;
    }
  }
  for (final word in _medKeywords) {
    if (normalized.contains(word)) {
      return kNoMedsReply;
    }
  }

  for (final entry in kDemoCatalog) {
    for (final keyword in entry.keywords) {
      if (normalized.contains(keyword)) {
        return entry.reply;
      }
    }
  }

  return kFallbackReply;
}
