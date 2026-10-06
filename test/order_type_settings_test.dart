import 'package:eazy_pos/features/settings/application/order_type_settings_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('order-type visibility, labels, and order persist', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    final controller = first.read(orderTypeSettingsProvider.notifier);

    await controller.setEnabled('Delivery', false);
    await controller.rename('Dine in', 'Table service');
    await controller.move(defaultPosOrderTypes, 1, 0);

    final second = ProviderContainer();
    addTearDown(second.dispose);
    await second.read(orderTypeSettingsProvider.notifier).restore();
    final visible = second.read(orderTypeSettingsProvider).apply();

    expect(visible.map((item) => item.code), ['Takeaway', 'Dine in']);
    expect(visible.last.label, 'Table service');
  });

  test('at least the defaults remain available without preferences', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(orderTypeSettingsProvider).apply(), hasLength(3));
  });
}
