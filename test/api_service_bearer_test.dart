import 'package:flutter_test/flutter_test.dart';
import 'package:yusr1/core/services/api_service.dart';

void main() {
  test('Bearer allowed on trusted 8088 lab legacy URL', () {
    expect(
      ApiService.isTrustedBearerUrl('http://127.0.0.1:8088/api/legacy'),
      isTrue,
    );
    expect(
      ApiService.isTrustedBearerUrl('http://10.0.2.2:8088/api/legacy'),
      isTrue,
    );
  });

  test('Bearer never attached to :8000 candidates', () {
    expect(
      ApiService.isTrustedBearerUrl('http://127.0.0.1:8000/api/legacy'),
      isFalse,
    );
    expect(
      ApiService.isTrustedBearerUrl('http://10.0.2.2:8000/api/legacy'),
      isFalse,
    );
    expect(
      ApiService.isTrustedBearerUrl('http://192.168.0.252:8000/api/legacy'),
      isFalse,
    );
  });

  test('Bearer rejected for unrelated non-Yusr URLs', () {
    expect(
      ApiService.isTrustedBearerUrl('http://example.com/api'),
      isFalse,
    );
    expect(
      ApiService.isTrustedBearerUrl('http://127.0.0.1:9999/other'),
      isFalse,
    );
  });

  test('Bearer allowed on Apache yusr_api paths that are not :8000', () {
    expect(
      ApiService.isTrustedBearerUrl('http://192.168.0.252/yusr_api/index.php'),
      isTrue,
    );
  });
}
