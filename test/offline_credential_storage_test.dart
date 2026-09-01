import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailflow_pos/features/auth/offline_credential_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'accepts the cached username and password without storing plaintext',
    () async {
      const secureStorage = FlutterSecureStorage();
      final storage = OfflineCredentialStorage(
        storage: secureStorage,
        now: () => DateTime.utc(2026, 9, 1),
      );

      await storage.save(' Demo ', 'password');

      expect(
        await storage.verify('demo', 'password'),
        OfflineCredentialResult.success,
      );
      final saved = await secureStorage.readAll();
      expect(saved.values.single, isNot(contains('"password":"password"')));
      expect(saved.values.single, isNot(contains('password')));
    },
  );

  test('rejects a different username or password', () async {
    final storage = OfflineCredentialStorage(
      now: () => DateTime.utc(2026, 9, 1),
    );
    await storage.save('demo', 'password');

    expect(
      await storage.verify('other', 'password'),
      OfflineCredentialResult.mismatch,
    );
    expect(
      await storage.verify('demo', 'incorrect'),
      OfflineCredentialResult.mismatch,
    );
  });

  test('expires offline login after thirty days', () async {
    var now = DateTime.utc(2026, 9, 1);
    final storage = OfflineCredentialStorage(now: () => now);
    await storage.save('demo', 'password');
    now = DateTime.utc(2026, 10, 1);

    expect(
      await storage.verify('demo', 'password'),
      OfflineCredentialResult.expired,
    );
  });
}
