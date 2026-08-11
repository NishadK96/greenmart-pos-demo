import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../home/app_shell.dart';
import 'auth_controller.dart';
import '../store/catalog_sync.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    ref.watch(catalogSyncProvider);
    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => _returnToLogin(context),
      data: (token) => token == null || token.isEmpty
          ? _returnToLogin(context)
          : AppShell(child: child),
    );
  }

  Widget _returnToLogin(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/login');
    });
    return const Scaffold(body: SizedBox.shrink());
  }
}
