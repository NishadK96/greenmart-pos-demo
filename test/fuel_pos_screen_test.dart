import 'package:eazy_pos/core/localization/app_localizations.dart';
import 'package:eazy_pos/core/theme/app_theme.dart';
import 'package:eazy_pos/features/fuel/presentation/fuel_pos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [390.0, 1180.0]) {
    testWidgets('fuel POS remains usable at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(compact: width < 760),
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: const [Locale('en'), Locale('ar')],
            home: const Scaffold(body: FuelPosScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (width < 560) {
        expect(find.text('New Fuel Sale'), findsOneWidget);
        expect(find.textContaining('Complete sale'), findsNothing);
        expect(find.text('Configure fuel products'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Search or add customer'));
        await tester.pumpAndSettle();
        expect(find.text('Add customer'), findsWidgets);
        expect(find.text('Search name, business, phone or email'), findsOneWidget);
      } else {
        expect(find.text('New fuel sale'), findsOneWidget);
        expect(find.textContaining('Complete sale'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
