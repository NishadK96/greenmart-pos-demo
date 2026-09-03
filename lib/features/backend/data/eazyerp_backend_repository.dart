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
  Future<List<Category>> categories(String accessToken) =>
      _api.categories(accessToken);

  @override
  Future<void> createCategory({
    required String accessToken,
    required String name,
    String nameAr = '',
    String? parentId,
  }) => _api.createCategory(
    accessToken: accessToken,
    name: name,
    nameAr: nameAr,
    parentId: parentId,
  );

  @override
  Future<void> updateCategory({
    required String accessToken,
    required String id,
    required String name,
    String nameAr = '',
  }) => _api.updateCategory(
    accessToken: accessToken,
    id: id,
    name: name,
    nameAr: nameAr,
  );

  @override
  Future<void> deleteCategory({
    required String accessToken,
    required String id,
    String? replacementId,
  }) => _api.deleteCategory(
    accessToken: accessToken,
    id: id,
    replacementId: replacementId,
  );

  @override
  Future<bool> checkSku({
    required String accessToken,
    required String sku,
    String? excludeProductId,
  }) => _api.checkSku(
    accessToken: accessToken,
    sku: sku,
    excludeProductId: excludeProductId,
  );

  @override
  Future<void> deleteProduct(String accessToken, String id) =>
      _api.deleteProduct(accessToken, id);

  @override
  Future<Product> updateProductStatus({
    required String accessToken,
    required Product product,
    required bool active,
  }) => _api.updateProductStatus(
    accessToken: accessToken,
    product: product,
    active: active,
  );

  @override
  Future<Product> removeProductImage({
    required String accessToken,
    required Product product,
  }) => _api.removeProductImage(accessToken: accessToken, product: product);

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
    String payTermType = '',
    String shippingAddress = '',
    String position = '',
  }) => _api.createCustomer(
    accessToken: accessToken,
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

  @override
  Future<Customer> updateCustomer({
    required String accessToken,
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
    String payTermType = '',
    String shippingAddress = '',
    String position = '',
  }) => _api.updateCustomer(
    accessToken: accessToken,
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

  @override
  Future<CreatedSale> createSale({
    required String accessToken,
    required String locationId,
    required String cashRegisterId,
    required Customer customer,
    required List<CartLine> lines,
    required String paymentMethod,
    required int total,
    required int grossDiscount,
    required String clientTransactionId,
    bool isCreditSale = false,
    String grossDiscountType = 'fixed',
    double grossDiscountRate = 0,
  }) async {
    final json = await _api.createSale(
      accessToken: accessToken,
      locationId: locationId,
      cashRegisterId: cashRegisterId,
      customer: customer,
      lines: lines,
      paymentMethod: paymentMethod,
      total: total,
      grossDiscount: grossDiscount,
      clientTransactionId: clientTransactionId,
      isCreditSale: isCreditSale,
      grossDiscountType: grossDiscountType,
      grossDiscountRate: grossDiscountRate,
    );
    return CreatedSale(
      id: json['id']?.toString() ?? '',
      invoiceNo:
          json['official_invoice_no']?.toString() ??
          json['invoice_no']?.toString() ??
          '',
      invoicePdfUrl: json['invoice_pdf_url']?.toString() ?? '',
      idempotentReplay:
          json['idempotent_replay'] == true ||
          json['idempotent_replay']?.toString() == '1',
    );
  }

  @override
  Future<String> createSaleReturn({
    required String accessToken,
    required Sale sale,
    required Map<String, int> quantities,
  }) async {
    final result = await _api.createSaleReturn(
      accessToken: accessToken,
      sale: sale,
      quantities: quantities,
    );
    return result['invoice_no']?.toString() ??
        result['ref_no']?.toString() ??
        result['id']?.toString() ??
        '';
  }

  @override
  Future<List<SaleReturnRecord>> saleReturns({required String accessToken}) =>
      _api.saleReturns(accessToken);
}
