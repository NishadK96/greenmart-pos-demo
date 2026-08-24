import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceSessionStorage {
  DeviceSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _deviceIdKey = 'connector_device_id';
  static const _deviceSecretKey = 'connector_device_secret';
  static const _activeSessionKey = 'connector_active_session';

  bool get isSupported => !kIsWeb;

  Future<Map<String, String>> deviceHeaders() async {
    if (!isSupported) return const {};
    final id = await _readOrCreate(_deviceIdKey, _uuidV4);
    final secret = await _readOrCreate(_deviceSecretKey, () => _hex(32));
    return {
      'X-Connector-Device-Id': id,
      'X-Connector-Device-Secret': secret,
      'X-Connector-Platform': defaultTargetPlatform.name,
      'X-Connector-Device-Name': 'GreenMart POS',
    };
  }

  Future<void> saveSession(String id, String refreshToken) async {
    if (!isSupported) return;
    await _storage.write(key: 'connector_refresh_$id', value: refreshToken);
    await _storage.write(key: _activeSessionKey, value: id);
  }

  Future<String?> refreshToken(String id) => isSupported
      ? _storage.read(key: 'connector_refresh_$id')
      : Future.value();

  Future<String?> activeSessionId() =>
      isSupported ? _storage.read(key: _activeSessionKey) : Future.value();

  Future<void> clearActiveSession() async {
    if (!isSupported) return;
    await _storage.delete(key: _activeSessionKey);
  }

  Future<void> removeSession(String id) async {
    if (!isSupported) return;
    await _storage.delete(key: 'connector_refresh_$id');
    if (await activeSessionId() == id) {
      await _storage.delete(key: _activeSessionKey);
    }
  }

  Future<String> _readOrCreate(String key, String Function() create) async {
    final current = await _storage.read(key: key);
    if (current != null && current.isNotEmpty) return current;
    final value = create();
    await _storage.write(key: key, value: value);
    return value;
  }

  String _hex(int bytes) {
    final random = Random.secure();
    return List.generate(
      bytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
