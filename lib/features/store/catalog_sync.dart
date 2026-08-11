import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../../shared/models/entities.dart';
import 'app_store.dart';

final catalogSyncProvider = FutureProvider<void>((ref) async {
  final token = await ref.watch(authControllerProvider.future);
  final store = ref.read(appStoreProvider.notifier);
  store.replaceCatalog(const [], const []);
  if (token == null || token.isEmpty) return;
  final api = ref.read(apiProvider);
  final results = await Future.wait([
    api.products(token),
    api.categories(token),
  ]);
  store.replaceCatalog(
    results[0] as List<Product>,
    results[1] as List<Category>,
  );
});
