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
    expect(
      ApiService.isTrustedBearerUrl('http://192.168.0.252:8088/api/legacy'),
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
    expect(
      ApiService.isTrustedBearerUrl('http://127.0.0.1/yusr_api/index.php'),
      isTrue,
    );
  });

  test('Bearer rejected for misleading hostnames with /api/legacy path', () {
    expect(
      ApiService.isTrustedBearerUrl('http://evil.com/api/legacy'),
      isFalse,
    );
    expect(
      ApiService.isTrustedBearerUrl('http://127.0.0.1.evil.com:8088/api/legacy'),
      isFalse,
    );
    expect(
      ApiService.isTrustedBearerUrl(
        'http://evil.com/redirect?to=http://127.0.0.1:8088/api/legacy',
      ),
      isFalse,
    );
  });

  test('Bearer rejected for wrong port even with legacy path', () {
    expect(
      ApiService.isTrustedBearerUrl('http://127.0.0.1:9999/api/legacy'),
      isFalse,
    );
    expect(
      ApiService.isTrustedBearerUrl('http://127.0.0.1:8089/api/legacy'),
      isFalse,
    );
  });

  test('Bearer rejected for trusted host but non-Yusr path', () {
    expect(
      ApiService.isTrustedBearerUrl('http://127.0.0.1:8088/not-api'),
      isFalse,
    );
    expect(
      ApiService.isTrustedBearerUrl('http://127.0.0.1:8088/'),
      isFalse,
    );
  });

  test('Bearer rejected for userinfo spoof on trusted host', () {
    expect(
      ApiService.isTrustedBearerUrl(
        'http://attacker@127.0.0.1:8088/api/legacy',
      ),
      isFalse,
    );
  });

  test('Bearer rejected for https scheme mismatch on lab http origins', () {
    expect(
      ApiService.isTrustedBearerUrl('https://127.0.0.1:8088/api/legacy'),
      isFalse,
    );
  });
}
