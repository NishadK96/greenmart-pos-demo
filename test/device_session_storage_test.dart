import 'package:eazy_pos/features/auth/device_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'reset removes the complete saved device identity and every session',
    () async {
      const secureStorage = FlutterSecureStorage();
      final sessions = DeviceSessionStorage(storage: secureStorage);
      final oldHeaders = await sessions.deviceHeaders();
      await sessions.saveSession('first', 'refresh-one');
      await sessions.saveSession('second', 'refresh-two');
      await secureStorage.write(key: 'unrelated_secret', value: 'keep-me');

      await sessions.resetDevice();

      final remaining = await secureStorage.readAll();
      expect(remaining, {'unrelated_secret': 'keep-me'});
      expect(await sessions.activeSessionId(), isNull);

      final newHeaders = await sessions.deviceHeaders();
      expect(
        newHeaders['X-Connector-Device-Id'],
        isNot(oldHeaders['X-Connector-Device-Id']),
      );
      expect(
        newHeaders['X-Connector-Device-Secret'],
        isNot(oldHeaders['X-Connector-Device-Secret']),
      );
    },
  );
}
