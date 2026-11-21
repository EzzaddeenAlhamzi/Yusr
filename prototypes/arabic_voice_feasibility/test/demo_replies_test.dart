import 'package:arabic_voice_feasibility/synthetic/demo_replies.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('greeting keywords map to SYN-GREETING', () {
    expect(matchSyntheticReply('مرحبا يسر').id, 'SYN-GREETING');
  });

  test('emergency words are blocked (no external action)', () {
    final reply = matchSyntheticReply('أحتاج إسعاف الآن');
    expect(reply.id, 'SYN-NO-EMERGENCY');
  });

  test('medication words are blocked', () {
    final reply = matchSyntheticReply('ما هي أدويتي');
    expect(reply.id, 'SYN-NO-MEDS');
  });

  test('unknown phrase uses fallback synthetic reply', () {
    expect(matchSyntheticReply('طقس اليوم').id, 'SYN-FALLBACK');
  });

  test('empty transcript uses empty synthetic reply', () {
    expect(matchSyntheticReply('   ').id, 'SYN-EMPTY');
  });
}
