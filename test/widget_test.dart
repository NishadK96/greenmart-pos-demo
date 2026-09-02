import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:retailflow_pos/app.dart';
import 'package:retailflow_pos/core/localization/app_localizations.dart';
import 'package:retailflow_pos/features/auth/auth_controller.dart';
import 'package:retailflow_pos/features/home/module_screens.dart';
import 'package:retailflow_pos/features/pos/pos_screen.dart';
import 'package:retailflow_pos/features/store/app_store.dart';
import 'package:retailflow_pos/shared/models/entities.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('login opens the application', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
        ],
        child: const RetailFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start your shift'), findsOneWidget);
    expect(find.text('Continue to Eazy POS'), findsOneWidget);
  });

  testWidgets('language switch changes the app to Arabic and RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutAuthController.new),
        ],
        child: const RetailFlowApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();

    expect(find.text('ابدأ ورديتك'), findsOneWidget);
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
    expect(find.text('New customer'), findsOneWidget);
    expect(find.byType(PosScreen), findsOneWidget);
  });

  testWidgets('F6 opens price editor for the latest cart item', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const product = Product(
      id: 'price-shortcut-product',
      name: 'Shortcut product',
      sku: 'SHORTCUT-1',
      barcode: 'SHORTCUT-1',
      categoryId: 'test',
      purchasePrice: 500,
      sellingPrice: 1000,
      stock: 5,
      minimumStock: 0,
      variationId: 'price-shortcut-variation',
    );
    container.read(appStoreProvider.notifier).addToCart(product);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _PosTestApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f6);
    await tester.pumpAndSettle();

    expect(find.text('Edit unit price'), findsOneWidget);
    expect(find.text('Unit price'), findsOneWidget);
  });

  testWidgets('F8 opens gross discount editor for the current cart', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const product = Product(
      id: 'discount-shortcut-product',
      name: 'Discount shortcut product',
      sku: 'DISCOUNT-1',
      barcode: 'DISCOUNT-1',
      categoryId: 'test',
      purchasePrice: 500,
      sellingPrice: 1000,
      stock: 5,
      minimumStock: 0,
      variationId: 'discount-shortcut-variation',
    );
    container.read(appStoreProvider.notifier).addToCart(product);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _PosTestApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    await tester.pumpAndSettle();

    expect(find.text('Gross discount'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Rate'), findsOneWidget);
  });

  testWidgets('cart keyboard entry changes the selected item quantity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = _keyboardCartContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _PosTestApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    expect(find.text('3_'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      container
          .read(appStoreProvider)
          .cart
          .firstWhere((line) => line.product.id == 'keyboard-second')
          .quantity,
      3,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pumpAndSettle();
    expect(
      container
          .read(appStoreProvider)
          .cart
          .firstWhere((line) => line.product.id == 'keyboard-first')
          .quantity,
      2,
    );
  });

  testWidgets('Enter opens keyboard actions for the selected cart item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = _keyboardCartContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _PosTestApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Keyboard second product'), findsWidgets);
    expect(find.text('Edit unit price'), findsOneWidget);
    expect(find.text('Line discount'), findsOneWidget);
    expect(find.text('Remove item'), findsOneWidget);
  });

  testWidgets('Down after the last cart item selects Pay and Enter opens it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = _keyboardCartContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _PosTestApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();
    final search = tester.widget<TextField>(find.byType(TextField).first);
    expect(search.focusNode?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.text('ENTER'), findsOneWidget);
    final payTarget = tester.widget<Semantics>(
      find.byKey(const ValueKey('pos-pay-keyboard-target')).first,
    );
    expect(payTarget.properties.selected, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Select payment method'), findsOneWidget);
  });

  testWidgets('payment keyboard requires two deliberate Enter presses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = _keyboardCartContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _PosTestApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();

    expect(find.text('Select payment method'), findsOneWidget);
    expect(find.textContaining('use arrow keys'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Press Enter again to confirm'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Press Enter again to confirm'), findsNothing);
  });

  testWidgets('POS customer selector opens quick customer creation', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: _PosTestApp()));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await tester.pumpAndSettle();
    await tester.tap(find.text('New customer'));
    await tester.pumpAndSettle();

    expect(find.text('Customer name'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Email (optional)'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });

  testWidgets('credit sale requires a selected non-walk-in customer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2048, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = _creditSaleContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _PosTestApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f12);
    await tester.pumpAndSettle();

    expect(find.text('Select a customer first'), findsOneWidget);
    expect(find.text('Select customer'), findsOneWidget);
    expect(
      find.textContaining('Credit cannot be assigned to the Walk-in Customer'),
      findsOneWidget,
    );
  });

  testWidgets('credit sale confirmation explains due amount and terms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2048, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = _creditSaleContainer(selectCreditCustomer: true);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _PosTestApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f12);
    await tester.pumpAndSettle();

    expect(find.text('Confirm credit sale'), findsOneWidget);
    expect(find.text('Riyadh Retail'), findsWidgets);
    expect(find.text('30 days'), findsOneWidget);
    expect(find.text('Create credit sale'), findsOneWidget);
    expect(find.textContaining('full invoice amount'), findsOneWidget);
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

  testWidgets('Dashboard renders its responsive business overview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: _DashboardTestApp()));
    await tester.pumpAndSettle();

    expect(find.text('Recent sales'), findsOneWidget);
    expect(find.text('Low stock'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Sales overview'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sales overview'), findsOneWidget);
    expect(find.text('Top selling products'), findsOneWidget);
    expect(find.text('Payment methods'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sales history renders its responsive transaction workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: _SalesTestApp()));
    await tester.pumpAndSettle();

    expect(find.text('Sales history'), findsOneWidget);
    expect(find.text('Total sales'), findsOneWidget);
    expect(find.text('Total invoices'), findsOneWidget);
    expect(find.text('Total customers'), findsOneWidget);
    expect(find.text('Average order value'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recent sales'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recent sales'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Low stock'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Low stock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sales history explains credit payment and outstanding amount', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = _creditSaleContainer(selectCreditCustomer: true);
    addTearDown(container.dispose);
    container
        .read(appStoreProvider.notifier)
        .checkout('due', serverId: '16', invoiceNo: '0016');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _SalesTestApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment due'), findsOneWidget);
    expect(find.text('Payment / sync'), findsOneWidget);
    await tester.tap(find.text('0016'));
    await tester.pumpAndSettle();

    expect(find.text('Credit sale'), findsOneWidget);
    expect(find.textContaining('Outstanding:'), findsOneWidget);
    expect(find.text('Riyadh Retail'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sales mobile filters open as a responsive bottom sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: _SalesTestApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Date range'), findsOneWidget);
    expect(find.text('All customers'), findsOneWidget);
    expect(find.text('Payment method'), findsOneWidget);
    expect(find.text('Apply filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _SignedOutAuthController extends AuthController {
  @override
  Future<String?> build() async => null;
}

ProviderContainer _creditSaleContainer({bool selectCreditCustomer = false}) {
  final container = ProviderContainer();
  const product = Product(
    id: 'credit-product',
    name: 'Credit product',
    sku: 'CREDIT-1',
    barcode: 'CREDIT-1',
    categoryId: 'test',
    purchasePrice: 500,
    sellingPrice: 1000,
    stock: 5,
    minimumStock: 0,
    variationId: 'credit-variation',
  );
  const walkIn = Customer(id: '1', name: 'Walk-in Customer');
  const creditCustomer = Customer(
    id: '15',
    name: 'Riyadh Retail',
    payTermNumber: '30',
    payTermType: 'days',
  );
  final store = container.read(appStoreProvider.notifier);
  store.restoreOfflineCatalog(
    products: const [product],
    categories: const [],
    customers: const [walkIn, creditCustomer],
    locations: const [BusinessLocation(id: '1', name: 'Main Store')],
    paymentOptions: const [PaymentOption(code: 'cash', label: 'Cash')],
    taxes: const [],
  );
  store.addToCart(product);
  if (selectCreditCustomer) store.selectCustomer(creditCustomer);
  return container;
}

ProviderContainer _keyboardCartContainer() {
  final container = ProviderContainer();
  const first = Product(
    id: 'keyboard-first',
    name: 'Keyboard first product',
    sku: 'KEY-1',
    barcode: 'KEY-1',
    categoryId: 'test',
    purchasePrice: 500,
    sellingPrice: 1000,
    stock: 10,
    minimumStock: 0,
    variationId: 'keyboard-first-variation',
  );
  const second = Product(
    id: 'keyboard-second',
    name: 'Keyboard second product',
    sku: 'KEY-2',
    barcode: 'KEY-2',
    categoryId: 'test',
    purchasePrice: 700,
    sellingPrice: 1500,
    stock: 10,
    minimumStock: 0,
    variationId: 'keyboard-second-variation',
  );
  final store = container.read(appStoreProvider.notifier);
  store.restoreOfflineCatalog(
    products: const [first, second],
    categories: const [],
    customers: const [Customer(id: '1', name: 'Walk-in Customer')],
    locations: const [BusinessLocation(id: '1', name: 'Main Store')],
    paymentOptions: const [
      PaymentOption(code: 'cash', label: 'Cash'),
      PaymentOption(code: 'card', label: 'Card'),
    ],
    taxes: const [],
  );
  store.addToCart(first);
  store.addToCart(second);
  return container;
}

class _PosTestApp extends StatefulWidget {
  const _PosTestApp();

  @override
  State<_PosTestApp> createState() => _PosTestAppState();
}

class _PosTestAppState extends State<_PosTestApp> {
  late final GoRouter router = GoRouter(
    initialLocation: '/pos',
    routes: [
      GoRoute(
        path: '/pos',
        builder: (_, __) => const Scaffold(body: PosScreen()),
      ),
    ],
  );

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    localizationsDelegates: const [AppLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    routerConfig: router,
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

class _DashboardTestApp extends StatelessWidget {
  const _DashboardTestApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    localizationsDelegates: [AppLocalizations.delegate],
    supportedLocales: [Locale('en'), Locale('ar')],
    home: Scaffold(body: DashboardScreen()),
  );
}

class _SalesTestApp extends StatelessWidget {
  const _SalesTestApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    localizationsDelegates: [AppLocalizations.delegate],
    supportedLocales: [Locale('en'), Locale('ar')],
    home: Scaffold(body: SalesScreen()),
  );
}
