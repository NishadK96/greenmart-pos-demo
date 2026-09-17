import 'package:eazy_pos/shared/widgets/product_card_style_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('card styles are independent and persist per POS mode', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(productCardImagesProvider), {
      'retail': true,
      'kitchen': false,
    });
    await Future<void>.delayed(Duration.zero);
    await container
        .read(productCardImagesProvider.notifier)
        .select('retail', false);
    await container
        .read(productCardImagesProvider.notifier)
        .select('kitchen', true);
    expect(container.read(productCardImagesProvider), {
      'retail': false,
      'kitchen': true,
    });
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    restored.read(productCardImagesProvider);
    await Future<void>.delayed(Duration.zero);
    expect(restored.read(productCardImagesProvider), {
      'retail': false,
      'kitchen': true,
    });
  });
}
