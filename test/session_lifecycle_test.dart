import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yusr1/core/services/api_service.dart';
import 'package:yusr1/core/services/auth_service.dart';
import 'package:yusr1/core/services/token_storage.dart';
import 'package:yusr1/pages/choose_mode_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TokenStorage.instance.resetCacheForTest();
    AuthService().resetForTest();
  });

  group('role normalization', () {
    test('maps backend elderly to client senior', () {
      expect(AuthService.normalizeClientRole('elderly'), 'senior');
      expect(AuthService.normalizeClientRole('Elderly'), 'senior');
      expect(AuthService.normalizeClientRole('senior'), 'senior');
      expect(AuthService.normalizeClientRole('caregiver'), 'caregiver');
      expect(AuthService.normalizeClientRole(''), isNull);
      expect(AuthService.normalizeClientRole(null), isNull);
    });

    test('canAccess accepts elderly alias for senior session', () {
      AuthService().setSeniorSession(
        id: 7,
        name: 'سعد',
        phone: '770',
      );
      expect(AuthService().canAccess('senior'), isTrue);
      expect(AuthService().canAccess('elderly'), isTrue);
      expect(AuthService().canAccess('caregiver'), isFalse);
    });
  });

  group('restoreSession', () {
    test('unauthenticated when no token', () async {
      AuthService.meFetcher = () async => {'status': 'success'};
      final outcome = await AuthService().restoreSession();
      expect(outcome, SessionRestoreOutcome.unauthenticated);
      expect(AuthService().isLoggedIn, isFalse);
    });

    test('authenticated caregiver from /me payload', () async {
      TokenStorage.debugForceToken = 'valid-token';
      AuthService.meFetcher = () async => {
            'status': 'success',
            'role': 'caregiver',
            'caregiver': {
              'Caregivers_ID': 12,
              'C_Name': 'أحمد',
              'C_PhonNumber': '771',
              'C_Email': 'a@example.invalid',
              'Eldery_ID': 3,
            },
          };

      final outcome = await AuthService().restoreSession();
      expect(outcome, SessionRestoreOutcome.authenticated);
      expect(AuthService().isLoggedIn, isTrue);
      expect(AuthService().isCaregiver, isTrue);
      expect(AuthService().userId, 12);
      expect(AuthService().linkedElderlyId, 3);
    });

    test('maps elderly role and never treats as caregiver', () async {
      TokenStorage.debugForceToken = 'valid-token';
      AuthService.meFetcher = () async => {
            'status': 'success',
            'role': 'elderly',
            'elderly': {
              'Eldery_ID': 44,
              'E_Name': 'فاطمة',
              'E_PhonNumber': '772',
              'E_Email': 'f@example.invalid',
            },
          };

      final outcome = await AuthService().restoreSession();
      expect(outcome, SessionRestoreOutcome.authenticated);
      expect(AuthService().isSenior, isTrue);
      expect(AuthService().isCaregiver, isFalse);
      expect(AuthService().userId, 44);
    });

    test('401 clears session and denies homes', () async {
      TokenStorage.debugForceToken = 'revoked';
      AuthService.meFetcher = () async => {
            'status': 'error',
            'error_type': 'unauthenticated',
            'http_status': 401,
          };

      final outcome = await AuthService().restoreSession();
      expect(outcome, SessionRestoreOutcome.unauthenticated);
      expect(AuthService().isLoggedIn, isFalse);
      // debugForceToken cleared by TokenStorage.clear()
      expect(TokenStorage.debugForceToken, isNull);
    });

    test('network failure does not clear token and does not authenticate',
        () async {
      TokenStorage.debugForceToken = 'keep-me';
      AuthService.meFetcher = () async => {
            'status': 'error',
            'error_type': 'connection_error',
            'is_connection_error': true,
            'message': 'تعذّر الاتصال بالخادم',
          };

      final outcome = await AuthService().restoreSession();
      expect(outcome, SessionRestoreOutcome.networkUnavailable);
      expect(AuthService().isLoggedIn, isFalse);
      expect(TokenStorage.debugForceToken, 'keep-me');
    });

    test('corrupt /me profile denies session', () async {
      TokenStorage.debugForceToken = 'tok';
      AuthService.meFetcher = () async => {
            'status': 'success',
            'role': 'caregiver',
            'caregiver': {'Caregivers_ID': 'bad'},
          };
      final outcome = await AuthService().restoreSession();
      expect(outcome, SessionRestoreOutcome.unauthenticated);
      expect(AuthService().isLoggedIn, isFalse);
    });
  });

  group('logout', () {
    test('local clear always; serverRevoked false on hook failure', () async {
      AuthService().setCaregiverSession(
        id: 1,
        name: 'x',
        phone: '1',
      );
      AuthService.remoteLogoutHook = () async => false;

      SharedPreferences.setMockInitialValues({
        'senior_mode': 'simple',
        'med_confirmed_1_2_2026-01-01': true,
        'custom_api_url': 'http://127.0.0.1:8088/api/legacy',
        'last_working_url': 'http://127.0.0.1:8088/api/legacy',
      });

      final result = await AuthService().logout();
      expect(result.localCleared, isTrue);
      expect(result.serverRevoked, isFalse);
      expect(AuthService().isLoggedIn, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('senior_mode'), isNull);
      expect(prefs.getBool('med_confirmed_1_2_2026-01-01'), isNull);
      expect(
        prefs.getString('custom_api_url'),
        'http://127.0.0.1:8088/api/legacy',
      );
    });

    test('serverRevoked true when hook succeeds', () async {
      AuthService().setSeniorSession(id: 2, name: 'y', phone: '2');
      AuthService.remoteLogoutHook = () async => true;
      final result = await AuthService().logout();
      expect(result.serverRevoked, isTrue);
      expect(result.localCleared, isTrue);
    });
  });

  group('homeRouteForSession', () {
    test('caregiver → main-caregiver', () async {
      AuthService().setCaregiverSession(id: 1, name: 'c', phone: '1');
      expect(await AuthService().homeRouteForSession(), '/main-caregiver');
    });

    test('senior uses per-user mode key only', () async {
      SharedPreferences.setMockInitialValues({
        'senior_mode': 'advanced', // global must NOT win (A4)
        'senior_mode_9': 'simple',
      });
      AuthService().setSeniorSession(id: 9, name: 's', phone: '9');
      expect(await AuthService().homeRouteForSession(), '/simple-home');
    });

    test('senior without per-user mode → choose-mode', () async {
      SharedPreferences.setMockInitialValues({
        'senior_mode': 'simple',
      });
      AuthService().setSeniorSession(id: 5, name: 's', phone: '5');
      expect(await AuthService().homeRouteForSession(), '/choose-mode');
    });
  });

  group('A5 network vs password distinction (message contract)', () {
    test('connection_error message is not wrong_password', () {
      const conn = {
        'status': 'error',
        'error_type': 'connection_error',
        'is_connection_error': true,
        'message':
            'تعذّر الاتصال بالخادم، يُرجى التأكد من اتصال الهاتف بالشبكة والمحاولة مرة أخرى',
      };
      const badPass = {
        'status': 'error',
        'error_type': 'wrong_password',
        'message': 'كلمة المرور غير صحيحة، يرجى التأكد والمحاولة مرة أخرى',
      };
      expect(conn['error_type'], isNot(badPass['error_type']));
      expect(conn['is_connection_error'], isTrue);
      expect(badPass.containsKey('is_connection_error'), isFalse);
    });
  });

  group('EMA cold-start after logout', () {
    test('401 without Bearer must not imply an authenticated session', () {
      // Contract: wouldAttachBearer=false → do NOT clear token / do NOT navigate.
      // (Gating lives in ApiService._sendRequest + main._handleUnauthorized.)
      expect(AuthService().isLoggedIn, isFalse);
      expect(AuthService.normalizeClientRole(null), isNull);
      expect(
        ApiService.wouldAttachBearer(
          attachBearer: true,
          token: 'present-but-not-sent-to-8000',
          url: 'http://127.0.0.1:8000/api/legacy',
        ),
        isFalse,
      );
    });

    test('unauthenticated restore outcome is Welcome path (not caregiver login)',
        () async {
      AuthService.meFetcher = () async => {
            'status': 'error',
            'error_type': 'unauthenticated',
            'http_status': 401,
          };
      final outcome = await AuthService().restoreSession();
      expect(outcome, SessionRestoreOutcome.unauthenticated);
      expect(await AuthService().homeRouteForSession(), '/welcome');
    });

    test(
      'POSITIVE: trusted authenticated 401 may invalidate session (attach gate)',
      () {
        expect(
          ApiService.wouldAttachBearer(
            attachBearer: true,
            token: 'live-session',
            url: 'http://127.0.0.1:8088/api/legacy',
          ),
          isTrue,
        );
      },
    );

    test(
      'NEGATIVE: untrusted 401 with stored token must not invalidate session',
      () {
        expect(
          ApiService.wouldAttachBearer(
            attachBearer: true,
            token: 'live-session',
            url: 'http://127.0.0.1:8000/api/legacy',
          ),
          isFalse,
        );
      },
    );
  });

  group('ChooseModePage cross-user preferences', () {
    test('POSITIVE: logged-in user writes only per-user keys', () async {
      SharedPreferences.setMockInitialValues({});
      await ChooseModePage.persistModeForAuthenticatedUser(
        modeStr: 'simple',
        userId: 44,
        isLoggedIn: true,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('senior_mode_44'), 'simple');
      expect(prefs.getBool('senior_setup_done_44'), isTrue);
      expect(prefs.getBool('senior_location_allowed_44'), isTrue);
      expect(prefs.getBool('senior_notifications_allowed_44'), isTrue);
      // Globals must never be written.
      expect(prefs.getString('senior_mode'), isNull);
      expect(prefs.getBool('senior_location_allowed'), isNull);
      expect(prefs.getBool('senior_notifications_allowed'), isNull);
      expect(prefs.getBool('senior_setup_done'), isNull);
    });

    test('NEGATIVE: pre-login / no uid writes nothing (no global leak)',
        () async {
      SharedPreferences.setMockInitialValues({
        'senior_mode_99': 'advanced', // other user must stay untouched
      });
      await ChooseModePage.persistModeForAuthenticatedUser(
        modeStr: 'simple',
        userId: null,
        isLoggedIn: false,
      );
      await ChooseModePage.persistModeForAuthenticatedUser(
        modeStr: 'simple',
        userId: 12,
        isLoggedIn: false,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('senior_mode'), isNull);
      expect(prefs.getString('senior_mode_12'), isNull);
      expect(prefs.getString('senior_mode_99'), 'advanced');
      expect(prefs.getBool('senior_location_allowed'), isNull);
      expect(prefs.getBool('senior_notifications_allowed'), isNull);
    });

    test('switch scrub clears per-user mode keys of prior user', () async {
      SharedPreferences.setMockInitialValues({
        'senior_mode_44': 'simple',
        'senior_setup_done_44': true,
        'senior_location_allowed_44': true,
        'senior_notifications_allowed_44': true,
        'senior_mode': 'advanced', // legacy global still scrubbed
        'custom_api_url': 'http://127.0.0.1:8088/api/legacy',
      });
      await AuthService().clearUserScopedCaches(includePerUserModeKeys: true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('senior_mode_44'), isNull);
      expect(prefs.getBool('senior_setup_done_44'), isNull);
      expect(prefs.getBool('senior_location_allowed_44'), isNull);
      expect(prefs.getBool('senior_notifications_allowed_44'), isNull);
      expect(prefs.getString('senior_mode'), isNull);
      expect(
        prefs.getString('custom_api_url'),
        'http://127.0.0.1:8088/api/legacy',
      );
    });
  });
}
