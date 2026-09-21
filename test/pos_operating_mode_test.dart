import 'package:eazy_pos/features/settings/application/pos_operating_mode_controller.dart';
import 'package:eazy_pos/core/localization/app_localizations.dart';
import 'package:eazy_pos/core/theme/app_theme.dart';
import 'package:eazy_pos/features/home/module_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('POS operating mode persists per device', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);

    expect(first.read(posOperatingModeProvider), PosOperatingMode.retail);
    await first
        .read(posOperatingModeProvider.notifier)
        .setMode(PosOperatingMode.kitchen);
    expect(first.read(posOperatingModeProvider), PosOperatingMode.kitchen);
    expect(PosOperatingMode.kitchen.route, '/kitchen-pos');

    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(posOperatingModeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(second.read(posOperatingModeProvider), PosOperatingMode.kitchen);
  });

  testWidgets('settings exposes a responsive device mode selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(compact: true),
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('POS operating mode'), findsOneWidget);
    expect(find.text('Retail POS'), findsOneWidget);
    expect(find.text('Kitchen POS'), findsOneWidget);
    await tester.tap(find.text('Kitchen POS'));
    await tester.pumpAndSettle();
    expect(container.read(posOperatingModeProvider), PosOperatingMode.kitchen);
    expect(tester.takeException(), isNull);
  });
}
