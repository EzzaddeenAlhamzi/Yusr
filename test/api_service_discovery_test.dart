import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusr1/core/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiService.resetDiscoveryStateForTest();
  });

  test('prefers reachable custom_api_url before racing candidates', () async {
    SharedPreferences.setMockInitialValues({
      'custom_api_url': 'http://127.0.0.1:8088/api/legacy',
      'last_working_url': 'http://127.0.0.1:8000/api/legacy',
    });

    final pinged = <String>[];
    final winner = await ApiService.instance.discoverWorkingServer(
      ping: (url) async {
        pinged.add(url);
        // Custom lab is reachable; pretend :8000 would also respond (race trap).
        return url.contains(':8088') || url.contains(':8000');
      },
    );

    expect(winner, 'http://127.0.0.1:8088/api/legacy');
    expect(pinged.first, 'http://127.0.0.1:8088/api/legacy');
    // Custom win must short-circuit — no candidate race after success.
    expect(pinged.length, 1);
    expect(ApiService.workingUrl, winner);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('last_working_url'),
      'http://127.0.0.1:8088/api/legacy',
    );
  });

  test('falls back to candidates when custom_api_url missing', () async {
    SharedPreferences.setMockInitialValues({});

    final winner = await ApiService.instance.discoverWorkingServer(
      ping: (url) async => url == ApiService.loopbackPort8088,
    );

    expect(winner, ApiService.loopbackPort8088);
    expect(ApiService.workingUrl, ApiService.loopbackPort8088);
  });

  test('falls back to candidates when custom_api_url unreachable', () async {
    SharedPreferences.setMockInitialValues({
      'custom_api_url': 'http://127.0.0.1:9999/api/legacy',
    });

    final pinged = <String>[];
    final winner = await ApiService.instance.discoverWorkingServer(
      ping: (url) async {
        pinged.add(url);
        if (url.contains(':9999')) return false;
        return url == ApiService.loopbackPort8088;
      },
    );

    expect(pinged.first, 'http://127.0.0.1:9999/api/legacy');
    expect(winner, ApiService.loopbackPort8088);
    // Failed custom must not reappear in the race set.
    expect(pinged.where((u) => u.contains(':9999')).length, 1);
  });

  test('registerCaregiver rejects empty password without network', () async {
    final res = await ApiService.instance.registerCaregiver(
      name: 'A',
      phone: '770',
      relationship: 'ابن',
      password: '',
    );
    expect(res['status'], 'error');
    expect(res['error_type'], 'password_required');
  });

  test('loginElderly rejects empty password without network', () async {
    final res = await ApiService.instance.loginElderly(
      phone: '770',
      password: '   ',
    );
    expect(res['status'], 'error');
    expect(res['error_type'], 'wrong_password');
  });
}
