import 'package:eazy_pos/core/utils/money.dart';
import 'package:eazy_pos/core/localization/app_localizations.dart';
import 'package:eazy_pos/features/kitchen/presentation/kitchen_pos_screen.dart';
import 'package:eazy_pos/features/store/app_store.dart';
import 'package:eazy_pos/shared/models/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _tea = Product(
  id: '1',
  name: 'Tea',
  sku: 'TEA',
  barcode: '123',
  categoryId: 'drinks',
  purchasePrice: 500,
  sellingPrice: 1000,
  stock: 10,
  minimumStock: 0,
  variationId: '2',
);

const _teaWithSize = Product(
  id: 'tea-with-size',
  name: 'Tea with size',
  sku: 'TEA-SIZE',
  barcode: '124',
  categoryId: 'drinks',
  purchasePrice: 500,
  sellingPrice: 1000,
  stock: 10,
  minimumStock: 0,
  variationId: 'tea-variation',
  modifierGroups: [
    ModifierGroup(
      id: 'size',
      name: 'Size',
      maxSelections: 1,
      options: [
        ModifierOption(
          variationId: 'large',
          name: 'Large',
          priceAdjustment: 200,
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('kitchen POS exposes searchable customer selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1168, 660);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          supportedLocales: [Locale('en'), Locale('ar')],
          localizationsDelegates: [AppLocalizations.delegate],
          home: Scaffold(body: KitchenPosScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('kitchen-customer-selector')));
    await tester.pumpAndSettle();

    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Walk-in Customer'), findsWidgets);
    expect(find.text('Add customer'), findsOneWidget);
    expect(find.text('Search name, business, phone or email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'adding the same configured product from the catalog creates separate lines',
    (tester) async {
      tester.view.physicalSize = const Size(1168, 660);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(appStoreProvider.notifier)
          .replaceCatalog(
            const [_teaWithSize],
            [const Category(id: 'drinks', name: 'Beverages', icon: 'drink')],
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            supportedLocales: [Locale('en'), Locale('ar')],
            localizationsDelegates: [AppLocalizations.delegate],
            home: Scaffold(body: KitchenPosScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> addLargeTea() async {
        await tester.tap(
          find.byKey(const ValueKey('kitchen-product-tea-with-size')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Large'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add to order'));
        await tester.pumpAndSettle();
      }

      await addLargeTea();
      await addLargeTea();

      expect(find.text('2 items'), findsOneWidget);
      expect(
        tester
            .widget<RiyalAmount>(
              find.byKey(const ValueKey('kitchen-order-total')),
            )
            .minorUnits,
        2400,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 700),
    const Size(390, 760),
    const Size(960, 760),
    const Size(1168, 660),
    const Size(1280, 850),
  ]) {
    testWidgets('kitchen order draft stays usable at ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(appStoreProvider.notifier)
          .replaceCatalog(
            const [_tea],
            [const Category(id: 'drinks', name: 'Beverages', icon: 'drink')],
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: KitchenPosScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kitchen POS'), findsOneWidget);
      expect(find.text('Tea'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('kitchen-table-card')), findsNothing);
      await tester.tap(find.text('Dine in'));
      await tester.pumpAndSettle();
      if (size.width >= 960) {
        final serviceRect = tester.getRect(
          find.widgetWithText(OutlinedButton, 'Dine in'),
        );
        final tableRect = tester.getRect(
          find.byKey(const ValueKey('kitchen-table-card')),
        );
        expect((serviceRect.top - tableRect.top).abs(), lessThanOrEqualTo(2));
        expect(
          (serviceRect.height - tableRect.height).abs(),
          lessThanOrEqualTo(2),
        );
        if (size.height < 720) {
          final keypadSeven = tester.getRect(
            find.byKey(const ValueKey('kitchen-keypad-7')),
          );
          expect(keypadSeven.height, greaterThanOrEqualTo(34));
          expect(keypadSeven.bottom, lessThanOrEqualTo(size.height));
        }
      } else {
        final tableRect = tester.getRect(
          find.byKey(const ValueKey('kitchen-table-card')),
        );
        expect(tableRect.left, greaterThanOrEqualTo(0));
        expect(tableRect.right, lessThanOrEqualTo(size.width));
        expect(tableRect.bottom, lessThanOrEqualTo(size.height));
        expect(
          find.byKey(const ValueKey('kitchen-category-panel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('kitchen-add-quantity')),
          findsOneWidget,
        );
      }

      await tester.tap(find.byKey(const ValueKey('kitchen-product-1')));
      await tester.pumpAndSettle();
      if (size.width < 960) {
        expect(find.text('View order (1)'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('kitchen-mobile-order-toggle')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Current Order'), findsOneWidget);
      }
      expect(
        tester
            .widget<RiyalAmount>(
              find.byKey(const ValueKey('kitchen-order-total')),
            )
            .minorUnits,
        1000,
      );
      expect(find.text('Tap an item to start an order.'), findsNothing);
      expect(container.read(appStoreProvider).cart, isEmpty);

      await tester.ensureVisible(find.byKey(const ValueKey('send-to-kitchen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('send-to-kitchen')));
      await tester.pump();
      expect(
        find.textContaining('Set up a kitchen printer route'),
        findsOneWidget,
      );
      expect(container.read(appStoreProvider).sales, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile quantity can be set without crowding search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: KitchenPosScreen())),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('kitchen-add-quantity')));
    await tester.pumpAndSettle();
    expect(find.text('Quantity per item tap'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '3');
    await tester.tap(find.text('Set quantity'));
    await tester.pumpAndSettle();
    expect(find.text('x3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop keypad applies a decimal order discount', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1168, 660);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(appStoreProvider.notifier)
        .replaceCatalog(
          const [_tea],
          [const Category(id: 'drinks', name: 'Beverages', icon: 'drink')],
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: KitchenPosScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kitchen-product-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Disc'));
    await tester.tap(find.widgetWithText(OutlinedButton, '2'));
    await tester.tap(find.widgetWithText(OutlinedButton, '.'));
    await tester.tap(find.widgetWithText(OutlinedButton, '5'));
    await tester.tap(find.widgetWithText(FilledButton, 'Enter'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RiyalAmount>(
            find.byKey(const ValueKey('kitchen-order-total')),
          )
          .minorUnits,
      750,
    );
    expect(tester.takeException(), isNull);
  });
}
