import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retailflow_pos/app.dart';
import 'package:retailflow_pos/core/localization/app_localizations.dart';
import 'package:retailflow_pos/features/home/module_screens.dart';
import 'package:retailflow_pos/features/pos/pos_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('login opens the application', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RetailFlowApp()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('language switch changes the app to Arabic and RTL', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RetailFlowApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('مرحباً بعودتك'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('F2 focuses the POS product search', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _PosTestApp()));
    await tester.pumpAndSettle();

    final search = tester.widget<TextField>(find.byType(TextField).first);
    expect(search.focusNode?.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();

    expect(search.focusNode?.hasFocus, isTrue);
  });

  testWidgets('F3 opens Recent Sales without leaving the POS', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _PosTestApp()));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pumpAndSettle();

    expect(find.text('Recent Sales'), findsWidgets);
    expect(find.text('No completed sales are available yet'), findsOneWidget);
    expect(find.byType(PosScreen), findsOneWidget);
  });

  testWidgets('F4 opens customer selector without leaving the POS', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: _PosTestApp()));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await tester.pumpAndSettle();

    expect(find.text('Select customer'), findsOneWidget);
    expect(find.text('Walk-in Customer'), findsWidgets);
    expect(find.byType(PosScreen), findsOneWidget);
  });

  testWidgets('mobile POS hides desktop shortcut labels', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: _PosTestApp()));
    await tester.pumpAndSettle();

    expect(find.text('F2 / ⌃2'), findsNothing);
    expect(find.text('F4 / ⌃4'), findsNothing);
    expect(find.byType(PosScreen), findsOneWidget);
  });

  testWidgets('Products page renders its responsive management layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: _ProductsTestApp()));
    await tester.pumpAndSettle();

    expect(find.text('Total Products'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
    expect(find.text('Out of Stock'), findsOneWidget);
    expect(find.text('Total Stock Value'), findsOneWidget);
    expect(find.text('No products match these filters'), findsOneWidget);
  });
}

class _PosTestApp extends StatelessWidget {
  const _PosTestApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    localizationsDelegates: [AppLocalizations.delegate],
    supportedLocales: [Locale('en'), Locale('ar')],
    home: Scaffold(body: PosScreen()),
  );
}

class _ProductsTestApp extends StatelessWidget {
  const _ProductsTestApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    localizationsDelegates: [AppLocalizations.delegate],
    supportedLocales: [Locale('en'), Locale('ar')],
    home: Scaffold(body: ProductsScreen()),
  );
}
