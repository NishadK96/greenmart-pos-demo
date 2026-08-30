import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/auth_gate.dart';
import 'features/home/module_screens.dart';
import 'features/pos/pos_screen.dart';
import 'features/products/presentation/product_management_screens.dart';
import 'features/purchases/presentation/purchase_screens.dart';
import 'features/printers/presentation/printer_settings_screen.dart';
import 'shared/models/entities.dart';
import 'features/sales/receipt_screen.dart';
import 'features/zatca/presentation/zatca_screen.dart';
import 'features/subscription/presentation/subscription_screen.dart';
import 'features/reports/presentation/reports_screen.dart';

Page<void> _instantPage(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (_, state) => _instantPage(state, const LoginScreen()),
    ),
    ShellRoute(
      builder: (_, __, child) => AuthGate(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (_, state) =>
              _instantPage(state, const DashboardScreen()),
        ),
        GoRoute(
          path: '/pos',
          pageBuilder: (_, state) => _instantPage(state, const PosScreen()),
        ),
        GoRoute(
          path: '/products',
          pageBuilder: (_, state) =>
              _instantPage(state, const ProductsScreen()),
        ),
        GoRoute(
          path: '/products/create',
          pageBuilder: (_, state) =>
              _instantPage(state, const ProductFormScreen()),
        ),
        GoRoute(
          path: '/products/quick',
          pageBuilder: (_, state) =>
              _instantPage(state, const ProductFormScreen(quick: true)),
        ),
        GoRoute(
          path: '/products/edit',
          pageBuilder: (_, state) => _instantPage(
            state,
            ProductFormScreen(product: state.extra! as Product),
          ),
        ),
        GoRoute(
          path: '/products/bulk',
          pageBuilder: (_, state) =>
              _instantPage(state, const BulkProductUpdateScreen()),
        ),
        GoRoute(
          path: '/products/import',
          pageBuilder: (_, state) =>
              _instantPage(state, const ProductImportScreen()),
        ),
        GoRoute(
          path: '/categories',
          pageBuilder: (_, state) =>
              _instantPage(state, const CategoriesScreen()),
        ),
        GoRoute(
          path: '/purchases',
          pageBuilder: (_, state) =>
              _instantPage(state, const PurchasesScreen()),
        ),
        GoRoute(
          path: '/inventory',
          pageBuilder: (_, state) =>
              _instantPage(state, const InventoryScreen()),
        ),
        GoRoute(
          path: '/customers',
          pageBuilder: (_, state) =>
              _instantPage(state, const CustomersScreen()),
        ),
        GoRoute(
          path: '/sales',
          pageBuilder: (_, state) => _instantPage(state, const SalesScreen()),
        ),
        GoRoute(
          path: '/reports',
          pageBuilder: (_, state) => _instantPage(state, const ReportsScreen()),
        ),
        GoRoute(
          path: '/sync',
          pageBuilder: (_, state) => _instantPage(state, const SyncScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, state) =>
              _instantPage(state, const SettingsScreen()),
        ),
        GoRoute(
          path: '/settings/printers',
          pageBuilder: (_, state) =>
              _instantPage(state, const PrinterSettingsScreen()),
        ),
        GoRoute(
          path: '/settings/subscription',
          pageBuilder: (_, state) =>
              _instantPage(state, const SubscriptionScreen()),
        ),
        GoRoute(
          path: '/zatca',
          pageBuilder: (_, state) => _instantPage(state, const ZatcaScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/receipt',
      pageBuilder: (_, state) => _instantPage(state, const ReceiptScreen()),
    ),
  ],
);

class RetailFlowApp extends ConsumerWidget {
  const RetailFlowApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Eazy POS',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: ref.watch(localeProvider),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: _router,
  );
}
