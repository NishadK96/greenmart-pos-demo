import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../shared/models/entities.dart';
import '../../../core/utils/money.dart';
import '../../auth/auth_controller.dart';
import '../../cash_register/presentation/cash_register_controller.dart';
import '../../store/app_store.dart';
import '../../offline_pos/presentation/offline_pos_controller.dart';
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
        rethrow;
      }
      final cached = await ref.read(offlinePosControllerProvider.future);
      if (!cached.catalog.isNotEmpty) rethrow;
    } catch (_) {
      final cached = await ref.read(offlinePosControllerProvider.future);
      if (!cached.catalog.isNotEmpty) rethrow;
    }
  }

  Future<Customer> createCustomer({
    required String name,
    required String mobile,
    String email = '',
    String taxNumber = '',
    String businessName = '',
    String commercialRegistrationNumber = '',
    String addressLine1 = '',
    String addressLine2 = '',
    String city = '',
    String state = '',
    String country = '',
    String zipCode = '',
    String contactId = '',
    String prefix = '',
    String middleName = '',
    String lastName = '',
    String alternateNumber = '',
    String landline = '',
    String dateOfBirth = '',
    String customerGroupId = '',
    String payTermNumber = '',
    String payTermType = 'days',
    String shippingAddress = '',
    String position = '',
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
          businessName: businessName,
          commercialRegistrationNumber: commercialRegistrationNumber,
          addressLine1: addressLine1,
          addressLine2: addressLine2,
          city: city,
          state: state,
          country: country,
          zipCode: zipCode,
          contactId: contactId,
          prefix: prefix,
          middleName: middleName,
          lastName: lastName,
          alternateNumber: alternateNumber,
          landline: landline,
          dateOfBirth: dateOfBirth,
          customerGroupId: customerGroupId,
          payTermNumber: payTermNumber,
          payTermType: payTermType,
          shippingAddress: shippingAddress,
          position: position,
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
    String businessName = '',
    String commercialRegistrationNumber = '',
    String addressLine1 = '',
    String addressLine2 = '',
    String city = '',
    String state = '',
    String country = '',
    String zipCode = '',
    String contactId = '',
    String prefix = '',
    String middleName = '',
    String lastName = '',
    String alternateNumber = '',
    String landline = '',
    String dateOfBirth = '',
    String customerGroupId = '',
    String payTermNumber = '',
    String payTermType = 'days',
    String shippingAddress = '',
    String position = '',
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
          businessName: businessName,
          commercialRegistrationNumber: commercialRegistrationNumber,
          addressLine1: addressLine1,
          addressLine2: addressLine2,
          city: city,
          state: state,
          country: country,
          zipCode: zipCode,
          contactId: contactId,
          prefix: prefix,
          middleName: middleName,
          lastName: lastName,
          alternateNumber: alternateNumber,
          landline: landline,
          dateOfBirth: dateOfBirth,
          customerGroupId: customerGroupId,
          payTermNumber: payTermNumber,
          payTermType: payTermType,
          shippingAddress: shippingAddress,
          position: position,
        );
    ref.read(appStoreProvider.notifier).updateCustomer(updated);
    return updated;
  }

  Future<Sale> checkout(String paymentMethod) =>
      _checkout(paymentMethod, allowTokenRefresh: true);

  Future<Sale> _checkout(
    String paymentMethod, {
    required bool allowTokenRefresh,
  }) async {
    final state = ref.read(appStoreProvider);
    if (state.cart.isEmpty ||
        state.customers.isEmpty ||
        state.locations.isEmpty) {
      throw const ApiException('Sale data is incomplete. Refresh and retry.');
    }
    try {
      final token = await _token();
      final register = await ref.read(cashRegisterControllerProvider.future);
      if (register == null) {
        throw const ApiException(
          'Open a cash register before completing this sale.',
        );
      }
      if (!state.locations.any((item) => item.id == register.locationId)) {
        throw const ApiException(
          'The open cash register does not match an available business location.',
        );
      }
      final created = await ref
          .read(backendRepositoryProvider)
          .createSale(
            accessToken: token,
            locationId: register.locationId,
            cashRegisterId: register.id,
            customer: state.customer ?? state.customers.first,
            lines: state.cart,
            paymentMethod: paymentMethod,
            total: state.cartTotal,
            grossDiscount: state.cartGrossDiscount,
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
    } on ApiException catch (error) {
      if (error.statusCode == 401 && allowTokenRefresh) {
        try {
          await ref.read(authControllerProvider.notifier).refreshAccessToken();
          return await _checkout(paymentMethod, allowTokenRefresh: false);
        } catch (_) {
          return await _queueOfflineCashSale(paymentMethod);
        }
      }
      rethrow;
    } catch (_) {
      return await _queueOfflineCashSale(paymentMethod);
    }
  }

  Future<Sale> _queueOfflineCashSale(String paymentMethod) {
    if (paymentMethod != 'cash') {
      throw const ApiException(
        'Only cash sales can be completed while offline.',
      );
    }
    return ref.read(offlinePosControllerProvider.notifier).queueCurrentSale();
  }

  Future<String> createSaleReturn({
    required Sale sale,
    required Map<String, int> quantities,
  }) async {
    final reference = await ref
        .read(backendRepositoryProvider)
        .createSaleReturn(
          accessToken: await _token(),
          sale: sale,
          quantities: quantities,
        );
    ref.invalidateSelf();
    return reference;
  }

  Future<List<SaleReturnRecord>> saleReturns() async => ref
      .read(backendRepositoryProvider)
      .saleReturns(accessToken: await _token());

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

  Future<LookupOption> createUnit({
    required String name,
    required String shortName,
    required bool allowDecimal,
  }) async {
    final unit = await ref
        .read(backendRepositoryProvider)
        .createUnit(
          accessToken: await _token(),
          name: name,
          shortName: shortName,
          allowDecimal: allowDecimal,
        );
    ref.read(appStoreProvider.notifier).addUnit(unit);
    return unit;
  }

  Future<void> _reloadCategories() async {
    final categories = await ref
        .read(backendRepositoryProvider)
        .categories(await _token());
    ref.read(appStoreProvider.notifier).replaceCategories(categories);
  }

  Future<void> createCategory({
    required String name,
    String nameAr = '',
    String? parentId,
  }) async {
    await ref
        .read(backendRepositoryProvider)
        .createCategory(
          accessToken: await _token(),
          name: name,
          nameAr: nameAr,
          parentId: parentId,
        );
    await _reloadCategories();
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    String nameAr = '',
  }) async {
    await ref
        .read(backendRepositoryProvider)
        .updateCategory(
          accessToken: await _token(),
          id: id,
          name: name,
          nameAr: nameAr,
        );
    await _reloadCategories();
  }

  Future<void> deleteCategory({
    required String id,
    String? replacementId,
  }) async {
    await ref
        .read(backendRepositoryProvider)
        .deleteCategory(
          accessToken: await _token(),
          id: id,
          replacementId: replacementId,
        );
    await _reloadCategories();
  }

  Future<bool> checkSku(String sku, {String? excludeProductId}) async => ref
      .read(backendRepositoryProvider)
      .checkSku(
        accessToken: await _token(),
        sku: sku,
        excludeProductId: excludeProductId,
      );

  Future<void> deleteProduct(Product product) async {
    await ref
        .read(backendRepositoryProvider)
        .deleteProduct(await _token(), product.id);
    ref.read(appStoreProvider.notifier).removeProduct(product.id);
  }

  Future<void> updateProductStatus(Product product, bool active) async {
    final updated = await ref
        .read(backendRepositoryProvider)
        .updateProductStatus(
          accessToken: await _token(),
          product: product,
          active: active,
        );
    ref.read(appStoreProvider.notifier).upsertProduct(updated);
  }

  Future<Product> removeProductImage(Product product) async {
    final updated = await ref
        .read(backendRepositoryProvider)
        .removeProductImage(accessToken: await _token(), product: product);
    ref.read(appStoreProvider.notifier).upsertProduct(updated);
    return updated;
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
    var token = await ref.read(authControllerProvider.future);
    if (token == 'offline-local-session') {
      ref.invalidate(authControllerProvider);
      token = await ref.read(authControllerProvider.future);
    }
    if (token == 'offline-local-session') {
      throw StateError('The backend is unavailable; continue in offline mode.');
    }
    if (token == null || token.isEmpty) {
      throw const ApiException('Your session has expired. Please sign in.');
    }
    return token;
  }
}
