import 'package:eazy_pos/core/localization/app_localizations.dart';
import 'package:eazy_pos/core/theme/app_theme.dart';
import 'package:eazy_pos/features/cash_register/domain/cash_register_entities.dart';
import 'package:eazy_pos/features/cash_register/presentation/cash_register_controller.dart';
import 'package:eazy_pos/features/store/app_store.dart';
import 'package:eazy_pos/features/van/presentation/van_pos_screen.dart';
import 'package:eazy_pos/shared/models/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _VanStore extends AppStore {
  @override
  AppState build() => const AppState(
    products: [
      Product(
        id: '1',
        name: 'Bottled water',
        sku: 'WATER',
        barcode: '12345',
        categoryId: '1',
        purchasePrice: 100,
        sellingPrice: 250,
        stock: 8,
        minimumStock: 0,
        variationId: '1',
      ),
    ],
    categories: [],
    customers: [
      Customer(id: '1', name: 'Walk-in Customer'),
      Customer(id: '2', name: 'Arabic Market', phone: '5551234'),
    ],
    sales: [],
    purchases: [],
    inventoryTransactions: [],
    syncQueue: [],
    locations: [BusinessLocation(id: '7', name: 'Van 7')],
    paymentOptions: [PaymentOption(code: 'cash', label: 'Cash')],
    stockItems: [],
    units: [],
    taxes: [],
    brands: [],
  );
}

class _VanRegister extends CashRegisterController {
  @override
  Future<CashRegister?> build() async => CashRegister(
    id: '10',
    locationId: '7',
    status: 'open',
    createdAt: DateTime(2026),
    transactions: const [],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [390.0, 1180.0]) {
    testWidgets('van POS shows a real cart at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStoreProvider.overrideWith(_VanStore.new),
            cashRegisterControllerProvider.overrideWith(_VanRegister.new),
          ],
          child: MaterialApp(
            theme: buildTheme(compact: width < 760),
            localizationsDelegates: const [AppLocalizations.delegate],
            supportedLocales: const [Locale('en'), Locale('ar')],
            home: const Scaffold(body: VanPosScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New van sale'), findsOneWidget);
      expect(find.text('Products · Van 7'), findsOneWidget);
      await tester.tap(find.byTooltip('Add Bottled water'));
      await tester.pumpAndSettle();
      if (width < 850) {
        expect(find.text('View cart'), findsOneWidget);
        await tester.tap(find.text('View cart'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Current order'), findsOneWidget);
      await tester.ensureVisible(find.text('Price'));
      await tester.tap(find.text('Price'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Edit unit price'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '3.75');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('1 × SAR 3.75'), findsOneWidget);
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pumpAndSettle();
      expect(find.text('2 × SAR 3.75'), findsOneWidget);
      await tester.tap(find.text('Price'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use default price'));
      await tester.pumpAndSettle();
      expect(find.text('2 × SAR 2.50'), findsOneWidget);
      await tester.tap(find.text('Walk-in Customer').first);
      await tester.pumpAndSettle();
      expect(find.text('Add customer'), findsWidgets);
      await tester.enterText(find.byType(TextField).last, '5551234');
      await tester.pumpAndSettle();
      expect(find.text('Arabic Market'), findsOneWidget);
      await tester.tap(find.text('Arabic Market'));
      await tester.pumpAndSettle();
      expect(find.text('Arabic Market'), findsOneWidget);
      expect(find.text('Complete sale'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
