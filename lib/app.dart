import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/app_shell.dart';
import 'features/home/module_screens.dart';
import 'features/pos/pos_screen.dart';
import 'features/sales/receipt_screen.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
        GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
        GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
        GoRoute(
          path: '/categories',
          builder: (_, __) => const CategoriesScreen(),
        ),
        GoRoute(
          path: '/purchases',
          builder: (_, __) => const PurchasesScreen(),
        ),
        GoRoute(
          path: '/inventory',
          builder: (_, __) => const InventoryScreen(),
        ),
        GoRoute(
          path: '/customers',
          builder: (_, __) => const CustomersScreen(),
        ),
        GoRoute(path: '/sales', builder: (_, __) => const SalesScreen()),
        GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
        GoRoute(path: '/sync', builder: (_, __) => const SyncScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
    GoRoute(path: '/receipt', builder: (_, __) => const ReceiptScreen()),
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
