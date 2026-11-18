import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-backed Sanctum token storage (NOT SharedPreferences).
///
/// Tokens are never logged. P1.2 minimum Bearer client support — not a full P1.3 session redesign.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _tokenKey = 'yusr_sanctum_token';
  static const _roleKey = 'yusr_auth_role';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// In-memory cache so HTTP path does not hit secure storage every request.
  String? _cachedToken;

  @visibleForTesting
  static String? debugForceToken;

  Future<void> saveToken(String token, {String? role}) async {
    final clean = token.trim();
    if (clean.isEmpty) return;
    _cachedToken = clean;
    await _storage.write(key: _tokenKey, value: clean);
    if (role != null && role.isNotEmpty) {
      await _storage.write(key: _roleKey, value: role);
    }
  }

  Future<String?> readToken() async {
    if (debugForceToken != null) return debugForceToken;
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }
    try {
      _cachedToken = await _storage.read(key: _tokenKey);
    } catch (_) {
      _cachedToken = null;
    }
    return _cachedToken;
  }

  Future<String?> readRole() async {
    try {
      return await _storage.read(key: _roleKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    _cachedToken = null;
    debugForceToken = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _roleKey);
    } catch (_) {}
  }

  @visibleForTesting
  void resetCacheForTest() {
    _cachedToken = null;
    debugForceToken = null;
  }
}
