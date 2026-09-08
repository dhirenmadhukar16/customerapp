import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _tokenKey = 'whitefox_access_token';

  static Future<void> saveToken(String token) {
    return _storage.write(
      key: _tokenKey,
      value: token,
    );
  }

  static Future<String?> readToken() {
    return _storage.read(
      key: _tokenKey,
    );
  }

  static Future<void> deleteToken() {
    return _storage.delete(
      key: _tokenKey,
    );
  }
}
