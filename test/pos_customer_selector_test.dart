import 'package:eazy_pos/core/localization/app_localizations.dart';
import 'package:eazy_pos/features/pos/pos_screen.dart';
import 'package:eazy_pos/features/store/app_store.dart';
import 'package:eazy_pos/shared/models/entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('POS selector shows Arabic customer names', (tester) async {
    const customer = Customer(id: '42', name: 'أحمد علي', phone: '0501234567');
    const state = AppState(
      products: [],
      categories: [],
      customers: [customer],
      sales: [],
      purchases: [],
      inventoryTransactions: [],
      syncQueue: [],
      locations: [],
      paymentOptions: [],
      stockItems: [],
      units: [],
      taxes: [],
      brands: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showPosCustomerSelector(context, ref, state),
                child: const Text('Open customers'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.text('أحمد علي'), findsOneWidget);
    expect(tester.getSize(find.text('أحمد علي')).width, greaterThan(0));
    expect(find.text('0501234567'), findsOneWidget);
  });
}
