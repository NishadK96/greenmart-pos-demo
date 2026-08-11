import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/entities.dart';

final appStoreProvider = NotifierProvider<AppStore, AppState>(AppStore.new);

class AppState {
  const AppState({
    required this.products,
    required this.categories,
    required this.customers,
    required this.sales,
    required this.purchases,
    required this.inventoryTransactions,
    required this.syncQueue,
    required this.locations,
    required this.paymentOptions,
    required this.stockItems,
    required this.units,
    required this.taxes,
    required this.brands,
    this.business,
    this.user,
    this.profitLoss,
    this.cart = const [],
    this.customer,
    this.lastSale,
  });
  final List<Product> products;
  final List<Category> categories;
  final List<Customer> customers;
  final List<Sale> sales;
  final List<Purchase> purchases;
  final List<InventoryTransaction> inventoryTransactions;
  final List<SyncQueueItem> syncQueue;
  final List<BusinessLocation> locations;
  final List<PaymentOption> paymentOptions;
  final List<StockItem> stockItems;
  final List<LookupOption> units, taxes;
  final List<LookupOption> brands;
  final BusinessProfile? business;
  final UserProfile? user;
  final ProfitLoss? profitLoss;
  final List<CartLine> cart;
  final Customer? customer;
  final Sale? lastSale;
  int get cartSubtotal => cart.fold(0, (v, e) => v + e.subtotal);
  int get cartTax => cart.fold(0, (v, e) => v + e.tax);
  int get cartDiscount => cart.fold(0, (v, e) => v + e.discount);
  int get cartTotal => cart.fold(0, (v, e) => v + e.total);
  int get itemCount => cart.fold(0, (v, e) => v + e.quantity);
  AppState copyWith({
    List<Product>? products,
    List<Category>? categories,
    List<Customer>? customers,
    List<Sale>? sales,
    List<Purchase>? purchases,
    List<InventoryTransaction>? inventoryTransactions,
    List<SyncQueueItem>? syncQueue,
    List<BusinessLocation>? locations,
    List<PaymentOption>? paymentOptions,
    List<StockItem>? stockItems,
    List<LookupOption>? units,
    List<LookupOption>? taxes,
    List<LookupOption>? brands,
    BusinessProfile? business,
    UserProfile? user,
    ProfitLoss? profitLoss,
    List<CartLine>? cart,
    Customer? customer,
    bool clearCustomer = false,
    Sale? lastSale,
  }) => AppState(
    products: products ?? this.products,
    categories: categories ?? this.categories,
    customers: customers ?? this.customers,
    sales: sales ?? this.sales,
    purchases: purchases ?? this.purchases,
    inventoryTransactions: inventoryTransactions ?? this.inventoryTransactions,
    syncQueue: syncQueue ?? this.syncQueue,
    locations: locations ?? this.locations,
    paymentOptions: paymentOptions ?? this.paymentOptions,
    stockItems: stockItems ?? this.stockItems,
    units: units ?? this.units,
    taxes: taxes ?? this.taxes,
    brands: brands ?? this.brands,
    business: business ?? this.business,
    user: user ?? this.user,
    profitLoss: profitLoss ?? this.profitLoss,
    cart: cart ?? this.cart,
    customer: clearCustomer ? null : customer ?? this.customer,
    lastSale: lastSale ?? this.lastSale,
  );
}

class AppStore extends Notifier<AppState> {
  @override
  AppState build() => _seed();
  void addToCart(Product product) {
    final i = state.cart.indexWhere((e) => e.product.id == product.id);
    final lines = [...state.cart];
    if (i < 0) {
      lines.add(CartLine(product: product));
    } else if (lines[i].quantity < product.stock) {
      lines[i] = lines[i].copyWith(quantity: lines[i].quantity + 1);
    }
    state = state.copyWith(cart: lines);
  }

  void quantity(String id, int delta) {
    final lines = [...state.cart];
    final i = lines.indexWhere((e) => e.product.id == id);
    if (i < 0) return;
    final q = lines[i].quantity + delta;
    if (q <= 0)
      lines.removeAt(i);
    else if (q <= lines[i].product.stock)
      lines[i] = lines[i].copyWith(quantity: q);
    state = state.copyWith(cart: lines);
  }

  void remove(String id) => state = state.copyWith(
    cart: state.cart.where((e) => e.product.id != id).toList(),
  );
  void clearCart() => state = state.copyWith(cart: [], clearCustomer: true);
  void selectCustomer(Customer value) =>
      state = state.copyWith(customer: value);
  void addCustomer(Customer customer) =>
      state = state.copyWith(customers: [...state.customers, customer]);
  void updateCustomer(Customer customer) => state = state.copyWith(
    customers: state.customers
        .map((item) => item.id == customer.id ? customer : item)
        .toList(growable: false),
  );
  void replaceProducts(List<Product> products) =>
      state = state.copyWith(products: products);
  void upsertProduct(Product product) {
    final exists = state.products.any((item) => item.id == product.id);
    state = state.copyWith(
      products: exists
          ? state.products
                .map((item) => item.id == product.id ? product : item)
                .toList(growable: false)
          : [product, ...state.products],
    );
  }

  void upsertProducts(List<Product> products) {
    final byId = {for (final item in state.products) item.id: item};
    for (final item in products) byId[item.id] = item;
    state = state.copyWith(products: byId.values.toList(growable: false));
  }

  void replaceCatalog(List<Product> products, List<Category> categories) =>
      state = state.copyWith(products: products, categories: categories);

  void replaceRemoteData({
    required List<Product> products,
    required List<Category> categories,
    required List<Customer> customers,
    required List<Sale> sales,
    required List<BusinessLocation> locations,
    required List<PaymentOption> paymentOptions,
    required List<StockItem> stockItems,
    required BusinessProfile business,
    required UserProfile user,
    required ProfitLoss profitLoss,
    required List<LookupOption> units,
    required List<LookupOption> taxes,
    required List<LookupOption> brands,
  }) => state = state.copyWith(
    products: products,
    categories: categories,
    customers: customers,
    sales: sales,
    locations: locations,
    paymentOptions: paymentOptions,
    stockItems: stockItems,
    business: business,
    user: user,
    profitLoss: profitLoss,
    units: units,
    taxes: taxes,
    brands: brands,
  );

  Sale checkout(String method, {String? serverId, String? invoiceNo}) {
    final now = DateTime.now();
    final customer = state.customer ?? state.customers.first;
    final sale = Sale(
      localId: 'sale-${now.microsecondsSinceEpoch}',
      invoiceNo: invoiceNo ?? 'Pending',
      serverId: serverId,
      createdAt: now,
      updatedAt: now,
      customer: customer,
      items: [...state.cart],
      paymentMethod: method,
      total: state.cartTotal,
      tax: state.cartTax,
      discount: state.cartDiscount,
      syncStatus: serverId == null ? SyncStatus.pending : SyncStatus.synced,
    );
    var products = [...state.products];
    for (final line in state.cart) {
      products = products
          .map(
            (p) => p.id == line.product.id
                ? p.copyWith(stock: p.stock - line.quantity)
                : p,
          )
          .toList();
    }
    state = state.copyWith(
      products: products,
      sales: [sale, ...state.sales],
      cart: [],
      clearCustomer: true,
      lastSale: sale,
    );
    return sale;
  }
}

AppState _seed() {
  return AppState(
    products: const [],
    categories: const [],
    customers: const [Customer(id: 'walkin', name: 'Walk-in Customer')],
    sales: const [],
    purchases: const [],
    inventoryTransactions: const [],
    syncQueue: const [],
    locations: const [],
    paymentOptions: const [],
    stockItems: const [],
    units: const [],
    taxes: const [],
    brands: const [],
  );
}
