import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RememberedLogin {
  const RememberedLogin(this.username, this.password);

  final String username;
  final String password;
}

/// Stores login-form autofill only when the user opts in to Remember Me.
/// Keep this separate from the hashed offline-login credential: logout must
/// revoke offline authentication without erasing the user's autofill choice.
class RememberedLoginStorage {
  RememberedLoginStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'remembered_login_v1';
  final FlutterSecureStorage _storage;

  Future<RememberedLogin?> read() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final username = value['username'] as String?;
      final password = value['password'] as String?;
      if (username == null ||
          username.isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }
      return RememberedLogin(username, password);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String username, String password) => _storage.write(
    key: _key,
    value: jsonEncode({'username': username.trim(), 'password': password}),
  );

  Future<void> clear() => _storage.delete(key: _key);
}
