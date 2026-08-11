import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../shared/models/entities.dart';
import '../../../core/utils/money.dart';
import '../../auth/auth_controller.dart';
import '../../store/app_store.dart';
import '../data/eazyerp_backend_repository.dart';

final backendControllerProvider =
    AsyncNotifierProvider<BackendController, void>(BackendController.new);

class BackendController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {
    final token = await ref.watch(authControllerProvider.future);
    final store = ref.read(appStoreProvider.notifier);
    store.replaceCatalog(const [], const []);
    if (token == null || token.isEmpty) return;
    try {
      final snapshot = await ref.read(backendRepositoryProvider).load(token);
      configureCurrency(snapshot.business.currencySymbol);
      store.replaceRemoteData(
        products: snapshot.products,
        categories: snapshot.categories,
        customers: snapshot.customers,
        sales: snapshot.sales,
        locations: snapshot.locations,
        paymentOptions: snapshot.paymentOptions,
        stockItems: snapshot.stockItems,
        business: snapshot.business,
        user: snapshot.user,
        profitLoss: snapshot.profitLoss,
        units: snapshot.units,
        taxes: snapshot.taxes,
        brands: snapshot.brands,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await ref.read(authControllerProvider.notifier).logout();
      }
      rethrow;
    }
  }

  Future<Customer> createCustomer({
    required String name,
    required String mobile,
    String email = '',
    String taxNumber = '',
  }) async {
    final token = await _token();
    final customer = await ref
        .read(backendRepositoryProvider)
        .createCustomer(
          accessToken: token,
          name: name,
          mobile: mobile,
          email: email,
          taxNumber: taxNumber,
        );
    ref.read(appStoreProvider.notifier).addCustomer(customer);
    return customer;
  }

  Future<Customer> updateCustomer({
    required Customer customer,
    required String name,
    required String mobile,
    String email = '',
    String taxNumber = '',
  }) async {
    final updated = await ref
        .read(backendRepositoryProvider)
        .updateCustomer(
          accessToken: await _token(),
          customer: customer,
          name: name,
          mobile: mobile,
          email: email,
          taxNumber: taxNumber,
        );
    ref.read(appStoreProvider.notifier).updateCustomer(updated);
    return updated;
  }

  Future<Sale> checkout(String paymentMethod) async {
    final token = await _token();
    final state = ref.read(appStoreProvider);
    if (state.cart.isEmpty ||
        state.customers.isEmpty ||
        state.locations.isEmpty) {
      throw const ApiException('Sale data is incomplete. Refresh and retry.');
    }
    final created = await ref
        .read(backendRepositoryProvider)
        .createSale(
          accessToken: token,
          locationId: state.locations.first.id,
          customer: state.customer ?? state.customers.first,
          lines: state.cart,
          paymentMethod: paymentMethod,
          total: state.cartTotal,
        );
    final sale = ref
        .read(appStoreProvider.notifier)
        .checkout(
          paymentMethod,
          serverId: created.id,
          invoiceNo: created.invoiceNo,
        );
    ref.invalidateSelf();
    return sale;
  }

  Future<Product> createProduct(
    ProductDraft draft, {
    bool quick = false,
  }) async {
    final product = await ref
        .read(backendRepositoryProvider)
        .createProduct(accessToken: await _token(), draft: draft, quick: quick);
    ref.read(appStoreProvider.notifier).upsertProduct(product);
    ref.invalidateSelf();
    return product;
  }

  Future<Product> updateProduct(Product product, ProductDraft draft) async {
    final updated = await ref
        .read(backendRepositoryProvider)
        .updateProduct(
          accessToken: await _token(),
          product: product,
          draft: draft,
        );
    ref.read(appStoreProvider.notifier).upsertProduct(updated);
    ref.invalidateSelf();
    return updated;
  }

  Future<List<Product>> bulkUpdateProducts({
    required List<Product> products,
    String? categoryId,
    String? locationId,
    int? sellingPrice,
  }) async {
    final updated = await ref
        .read(backendRepositoryProvider)
        .bulkUpdateProducts(
          accessToken: await _token(),
          products: products,
          categoryId: categoryId,
          locationId: locationId,
          sellingPrice: sellingPrice,
        );
    ref.read(appStoreProvider.notifier).upsertProducts(updated);
    ref.invalidateSelf();
    return updated;
  }

  Future<List<Product>> importProducts(List<int> bytes, String fileName) async {
    final imported = await ref
        .read(backendRepositoryProvider)
        .importProducts(
          accessToken: await _token(),
          bytes: bytes,
          fileName: fileName,
        );
    ref.read(appStoreProvider.notifier).upsertProducts(imported);
    ref.invalidateSelf();
    return imported;
  }

  Future<String> _token() async {
    final token = await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty) {
      throw const ApiException('Your session has expired. Please sign in.');
    }
    return token;
  }
}
