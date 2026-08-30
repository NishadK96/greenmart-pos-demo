import '../../../shared/models/entities.dart';

class BackendSnapshot {
  const BackendSnapshot({
    required this.products,
    required this.categories,
    required this.customers,
    required this.sales,
    required this.locations,
    required this.paymentOptions,
    required this.stockItems,
    required this.business,
    required this.user,
    required this.profitLoss,
    required this.units,
    required this.taxes,
    required this.brands,
  });

  final List<Product> products;
  final List<Category> categories;
  final List<Customer> customers;
  final List<Sale> sales;
  final List<BusinessLocation> locations;
  final List<PaymentOption> paymentOptions;
  final List<StockItem> stockItems;
  final BusinessProfile business;
  final UserProfile user;
  final ProfitLoss profitLoss;
  final List<LookupOption> units, taxes;
  final List<LookupOption> brands;
}

class CreatedSale {
  const CreatedSale({required this.id, required this.invoiceNo});
  final String id, invoiceNo;
}

abstract interface class BackendRepository {
  Future<BackendSnapshot> load(String accessToken);

  Future<LookupOption> createUnit({
    required String accessToken,
    required String name,
    required String shortName,
    required bool allowDecimal,
  });
  Future<List<Category>> categories(String accessToken);
  Future<void> createCategory({
    required String accessToken,
    required String name,
    String nameAr,
    String? parentId,
  });
  Future<void> updateCategory({
    required String accessToken,
    required String id,
    required String name,
    String nameAr,
  });
  Future<void> deleteCategory({
    required String accessToken,
    required String id,
    String? replacementId,
  });
  Future<bool> checkSku({
    required String accessToken,
    required String sku,
    String? excludeProductId,
  });
  Future<void> deleteProduct(String accessToken, String id);
  Future<Product> updateProductStatus({
    required String accessToken,
    required Product product,
    required bool active,
  });
  Future<Product> removeProductImage({
    required String accessToken,
    required Product product,
  });

  Future<Customer> createCustomer({
    required String accessToken,
    required String name,
    required String mobile,
    String email,
    String taxNumber,
    String businessName,
    String commercialRegistrationNumber,
    String addressLine1,
    String addressLine2,
    String city,
    String state,
    String country,
    String zipCode,
    String contactId,
    String prefix,
    String middleName,
    String lastName,
    String alternateNumber,
    String landline,
    String dateOfBirth,
    String customerGroupId,
    String payTermNumber,
    String payTermType,
    String shippingAddress,
    String position,
  });

  Future<Customer> updateCustomer({
    required String accessToken,
    required Customer customer,
    required String name,
    required String mobile,
    String email,
    String taxNumber,
    String businessName,
    String commercialRegistrationNumber,
    String addressLine1,
    String addressLine2,
    String city,
    String state,
    String country,
    String zipCode,
    String contactId,
    String prefix,
    String middleName,
    String lastName,
    String alternateNumber,
    String landline,
    String dateOfBirth,
    String customerGroupId,
    String payTermNumber,
    String payTermType,
    String shippingAddress,
    String position,
  });

  Future<CreatedSale> createSale({
    required String accessToken,
    required String locationId,
    required String cashRegisterId,
    required Customer customer,
    required List<CartLine> lines,
    required String paymentMethod,
    required int total,
    required int grossDiscount,
    bool isCreditSale = false,
    String grossDiscountType = 'fixed',
    double grossDiscountRate = 0,
  });

  Future<String> createSaleReturn({
    required String accessToken,
    required Sale sale,
    required Map<String, int> quantities,
  });

  Future<List<SaleReturnRecord>> saleReturns({required String accessToken});

  Future<Product> createProduct({
    required String accessToken,
    required ProductDraft draft,
    bool quick,
  });
  Future<Product> updateProduct({
    required String accessToken,
    required Product product,
    required ProductDraft draft,
  });
  Future<List<Product>> bulkUpdateProducts({
    required String accessToken,
    required List<Product> products,
    String? categoryId,
    String? locationId,
    int? sellingPrice,
  });
  Future<List<Product>> importProducts({
    required String accessToken,
    required List<int> bytes,
    required String fileName,
  });
}
