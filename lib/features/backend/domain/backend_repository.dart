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
}

class CreatedSale {
  const CreatedSale({required this.id, required this.invoiceNo});
  final String id, invoiceNo;
}

abstract interface class BackendRepository {
  Future<BackendSnapshot> load(String accessToken);

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
}
