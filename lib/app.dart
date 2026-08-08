import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/app_shell.dart';
import 'features/home/module_screens.dart';
import 'features/pos/pos_screen.dart';
import 'features/sales/receipt_screen.dart';

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
      builder: (_, __, child) => AppShell(child: child),
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
      ],
    ),
    GoRoute(
      path: '/receipt',
      pageBuilder: (_, state) => _instantPage(state, const ReceiptScreen()),
    ),
  ],
);

class RetailFlowApp extends StatelessWidget {
  const RetailFlowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'RetailFlow POS',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    routerConfig: _router,
  );
}
