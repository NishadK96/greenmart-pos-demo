import 'package:eazy_pos/core/utils/money.dart';
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

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(390, 760),
    const Size(960, 760),
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
}
