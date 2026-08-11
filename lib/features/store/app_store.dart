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
  void addProduct(Product product) =>
      state = state.copyWith(products: [...state.products, product]);
  void replaceProducts(List<Product> products) =>
      state = state.copyWith(products: products);

  void adjustStock(String productId, int delta, String reason) {
    final products = state.products
        .map(
          (p) => p.id == productId
              ? p.copyWith(stock: (p.stock + delta).clamp(0, 999999))
              : p,
        )
        .toList();
    final tx = InventoryTransaction(
      localId: 'it-${DateTime.now().microsecondsSinceEpoch}',
      productId: productId,
      quantityDelta: delta,
      reason: reason,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
    state = state.copyWith(
      products: products,
      inventoryTransactions: [tx, ...state.inventoryTransactions],
      syncQueue: [_queue('inventory', tx.localId), ...state.syncQueue],
    );
  }

  void savePurchase(String productId, int quantity, int rate) {
    adjustStock(productId, quantity, 'Purchase');
    final now = DateTime.now();
    final purchase = Purchase(
      localId: 'p-${now.microsecondsSinceEpoch}',
      invoiceNo: 'PUR-${1000 + state.purchases.length}',
      supplier: const Supplier(id: 's1', name: 'Metro Wholesale'),
      createdAt: now,
      items: [
        PurchaseItem(productId: productId, quantity: quantity, rate: rate),
      ],
      total: quantity * rate,
      syncStatus: SyncStatus.pending,
    );
    state = state.copyWith(
      purchases: [purchase, ...state.purchases],
      syncQueue: [_queue('purchase', purchase.localId), ...state.syncQueue],
    );
  }

  Sale checkout(PaymentMethod method) {
    final now = DateTime.now();
    final customer = state.customer ?? state.customers.first;
    final sale = Sale(
      localId: 'sale-${now.microsecondsSinceEpoch}',
      invoiceNo: 'RF-${(10001 + state.sales.length)}',
      createdAt: now,
      updatedAt: now,
      customer: customer,
      items: [...state.cart],
      paymentMethod: method,
      total: state.cartTotal,
      tax: state.cartTax,
      discount: state.cartDiscount,
      syncStatus: SyncStatus.pending,
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
      syncQueue: [_queue('sale', sale.localId), ...state.syncQueue],
      cart: [],
      clearCustomer: true,
      lastSale: sale,
    );
    return sale;
  }

  SyncQueueItem _queue(String type, String id) => SyncQueueItem(
    localId: 'q-${DateTime.now().microsecondsSinceEpoch}',
    entityType: type,
    entityId: id,
    createdAt: DateTime.now(),
  );
}

AppState _seed() {
  const cats = [
    Category(id: 'all', name: 'All', icon: '◉'),
    Category(id: 'grocery', name: 'Grocery', icon: '🥫'),
    Category(id: 'beverages', name: 'Beverages', icon: '🥤'),
    Category(id: 'snacks', name: 'Snacks', icon: '🍿'),
    Category(id: 'household', name: 'Household', icon: '🧹'),
    Category(id: 'personal', name: 'Personal Care', icon: '🧴'),
  ];
  return AppState(
    products: const [],
    categories: cats,
    customers: const [Customer(id: 'walkin', name: 'Walk-in Customer')],
    sales: const [],
    purchases: const [],
    inventoryTransactions: const [],
    syncQueue: const [],
  );
}
