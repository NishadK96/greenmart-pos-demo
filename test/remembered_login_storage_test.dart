import 'package:eazy_pos/features/auth/remembered_login_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('prefills only credentials explicitly saved for Remember Me', () async {
    final storage = RememberedLoginStorage();
    expect(await storage.read(), isNull);

    await storage.save(' cashier@example.com ', 'test-password');
    final saved = await RememberedLoginStorage().read();
    expect(saved?.username, 'cashier@example.com');
    expect(saved?.password, 'test-password');

    await storage.clear();
    expect(await storage.read(), isNull);
  });

  test('ignores damaged saved credentials', () async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'remembered_login_v1', value: '{invalid');
    expect(await RememberedLoginStorage().read(), isNull);
  });
}
