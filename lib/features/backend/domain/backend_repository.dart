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

  Future<Customer> createCustomer({
    required String accessToken,
    required String name,
    required String mobile,
    String email,
    String taxNumber,
  });

  Future<Customer> updateCustomer({
    required String accessToken,
    required Customer customer,
    required String name,
    required String mobile,
    String email,
    String taxNumber,
  });

  Future<CreatedSale> createSale({
    required String accessToken,
    required String locationId,
    required Customer customer,
    required List<CartLine> lines,
    required String paymentMethod,
    required int total,
  });

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
