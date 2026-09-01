import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum OfflineCredentialResult { success, unavailable, mismatch, expired }

class OfflineCredentialStorage {
  OfflineCredentialStorage({
    FlutterSecureStorage? storage,
    DateTime Function()? now,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _now = now ?? DateTime.now;

  static const _credentialKey = 'offline_login_credential_v1';
  static const _iterations = 50000;
  static const _validity = Duration(days: 30);

  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  Future<void> save(String username, String password) async {
    final salt = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final createdAt = _now().toUtc();
    final payload = <String, dynamic>{
      'version': 1,
      'username': _normalize(username),
      'salt': base64Encode(salt),
      'digest': base64Encode(_derive(password, salt)),
      'created_at': createdAt.toIso8601String(),
      'expires_at': createdAt.add(_validity).toIso8601String(),
    };
    await _storage.write(key: _credentialKey, value: jsonEncode(payload));
  }

  Future<OfflineCredentialResult> verify(
    String username,
    String password,
  ) async {
    final encoded = await _storage.read(key: _credentialKey);
    if (encoded == null || encoded.isEmpty) {
      return OfflineCredentialResult.unavailable;
    }
    try {
      final payload = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      final expiresAt = DateTime.parse('${payload['expires_at']}').toUtc();
      if (!_now().toUtc().isBefore(expiresAt)) {
        return OfflineCredentialResult.expired;
      }
      if (_normalize(username) != '${payload['username']}') {
        return OfflineCredentialResult.mismatch;
      }
      final salt = base64Decode('${payload['salt']}');
      final expected = base64Decode('${payload['digest']}');
      final actual = _derive(password, salt);
      return _constantTimeEquals(expected, actual)
          ? OfflineCredentialResult.success
          : OfflineCredentialResult.mismatch;
    } catch (_) {
      return OfflineCredentialResult.unavailable;
    }
  }

  Future<void> clear() => _storage.delete(key: _credentialKey);

  List<int> _derive(String password, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var value = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(value);
    for (var iteration = 1; iteration < _iterations; iteration++) {
      value = hmac.convert(value).bytes;
      for (var index = 0; index < result.length; index++) {
        result[index] ^= value[index];
      }
    }
    return result;
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  String _normalize(String username) => username.trim().toLowerCase();
}
