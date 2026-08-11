import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import 'app_store.dart';

final catalogSyncProvider = FutureProvider<void>((ref) async {
  final token = await ref.watch(authControllerProvider.future);
  if (token == null || token.isEmpty) return;
  final products = await ref.read(apiProvider).products(token);
  ref.read(appStoreProvider.notifier).replaceProducts(products);
});
