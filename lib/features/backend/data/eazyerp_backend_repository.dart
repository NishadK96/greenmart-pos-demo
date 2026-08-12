import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../shared/models/entities.dart';
import '../../../core/network/api_provider.dart';
import '../domain/backend_repository.dart';

final backendRepositoryProvider = Provider<BackendRepository>(
  (ref) => EazyErpBackendRepository(ref.watch(apiProvider)),
);

class EazyErpBackendRepository implements BackendRepository {
  const EazyErpBackendRepository(this._api);
  final Api _api;

  @override
  Future<LookupOption> createUnit({
    required String accessToken,
    required String name,
    required String shortName,
    required bool allowDecimal,
  }) => _api.createUnit(
    accessToken: accessToken,
    name: name,
    shortName: shortName,
    allowDecimal: allowDecimal,
  );

  @override
  Future<BackendSnapshot> load(String accessToken) async {
    final products = await _api.products(accessToken);
    final results = await Future.wait<Object>([
      _api.categories(accessToken),
      _api.customers(accessToken),
      _api.locations(accessToken),
      _api.paymentOptions(accessToken),
      _api.businessDetails(accessToken),
      _api.loggedInUser(accessToken),
      _api.profitLoss(accessToken),
      _api.stockReport(accessToken),
      _api.units(accessToken),
      _api.taxes(accessToken),
      _api.brands(accessToken),
    ]);
    final customers = results[1] as List<Customer>;
    return BackendSnapshot(
      products: products,
      categories: results[0] as List<Category>,
      customers: customers,
      sales: await _api.sales(accessToken, products, customers),
      locations: results[2] as List<BusinessLocation>,
      paymentOptions: results[3] as List<PaymentOption>,
      business: results[4] as BusinessProfile,
      user: results[5] as UserProfile,
      profitLoss: results[6] as ProfitLoss,
      stockItems: results[7] as List<StockItem>,
      units: results[8] as List<LookupOption>,
      taxes: results[9] as List<LookupOption>,
      brands: results[10] as List<LookupOption>,
    );
  }

  @override
  Future<Product> createProduct({
    required String accessToken,
    required ProductDraft draft,
    bool quick = false,
  }) =>
      _api.createProduct(accessToken: accessToken, draft: draft, quick: quick);

  @override
  Future<Product> updateProduct({
    required String accessToken,
    required Product product,
    required ProductDraft draft,
  }) => _api.updateProduct(
    accessToken: accessToken,
    product: product,
    draft: draft,
  );

  @override
  Future<List<Product>> bulkUpdateProducts({
    required String accessToken,
    required List<Product> products,
    String? categoryId,
    String? locationId,
    int? sellingPrice,
  }) => _api.bulkUpdateProducts(
    accessToken: accessToken,
    products: products,
    categoryId: categoryId,
    locationId: locationId,
    sellingPrice: sellingPrice,
  );

  @override
  Future<List<Product>> importProducts({
    required String accessToken,
    required List<int> bytes,
    required String fileName,
  }) => _api.importProducts(
    accessToken: accessToken,
    bytes: bytes,
    fileName: fileName,
  );

  @override
  Future<Customer> createCustomer({
    required String accessToken,
    required String name,
    required String mobile,
    String email = '',
    String taxNumber = '',
  }) => _api.createCustomer(
    accessToken: accessToken,
    name: name,
    mobile: mobile,
    email: email,
    taxNumber: taxNumber,
  );

  @override
  Future<Customer> updateCustomer({
    required String accessToken,
    required Customer customer,
    required String name,
    required String mobile,
    String email = '',
    String taxNumber = '',
  }) => _api.updateCustomer(
    accessToken: accessToken,
    customer: customer,
    name: name,
    mobile: mobile,
    email: email,
    taxNumber: taxNumber,
  );

  @override
  Future<CreatedSale> createSale({
    required String accessToken,
    required String locationId,
    required Customer customer,
    required List<CartLine> lines,
    required String paymentMethod,
    required int total,
  }) async {
    final json = await _api.createSale(
      accessToken: accessToken,
      locationId: locationId,
      customer: customer,
      lines: lines,
      paymentMethod: paymentMethod,
      total: total,
    );
    return CreatedSale(
      id: json['id']?.toString() ?? '',
      invoiceNo: json['invoice_no']?.toString() ?? '',
    );
  }
}
