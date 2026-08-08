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
  const names = [
    'Basmati Rice 5kg',
    'Whole Wheat Flour',
    'Toor Dal 1kg',
    'Organic Sugar',
    'Sunflower Oil 1L',
    'Tata Salt',
    'Fresh Milk 1L',
    'Orange Juice',
    'Mineral Water',
    'Cola 750ml',
    'Green Tea',
    'Instant Coffee',
    'Masala Chips',
    'Salted Peanuts',
    'Cream Biscuits',
    'Dark Chocolate',
    'Roasted Makhana',
    'Granola Bar',
    'Dishwash Liquid',
    'Laundry Detergent',
    'Floor Cleaner',
    'Kitchen Towels',
    'Garbage Bags',
    'Aluminium Foil',
    'Herbal Shampoo',
    'Bath Soap',
    'Toothpaste',
    'Hand Wash',
    'Face Cream',
    'Baby Wipes',
  ];
  const categoryIds = [
    'grocery',
    'grocery',
    'grocery',
    'grocery',
    'grocery',
    'grocery',
    'beverages',
    'beverages',
    'beverages',
    'beverages',
    'beverages',
    'beverages',
    'snacks',
    'snacks',
    'snacks',
    'snacks',
    'snacks',
    'snacks',
    'household',
    'household',
    'household',
    'household',
    'household',
    'household',
    'personal',
    'personal',
    'personal',
    'personal',
    'personal',
    'personal',
  ];
  final products = List.generate(names.length, (i) {
    const itemImages = [
      'assets/products/items/basmati_rice.jpg',
      'assets/products/items/wheat_flour.jpg',
      'assets/products/items/toor_dal.jpg',
      'assets/products/items/sugar.jpg',
      'assets/products/items/sunflower_oil.jpg',
      'assets/products/items/salt.jpg',
      'assets/products/items/milk.jpg',
      'assets/products/items/orange_juice.jpg',
      'assets/products/items/mineral_water.jpg',
      'assets/products/items/cola.jpg',
      'assets/products/items/green_tea.jpg',
      'assets/products/items/coffee.jpg',
      'assets/products/items/chips.jpg',
      'assets/products/items/peanuts.jpg',
      'assets/products/items/biscuits.jpg',
      'assets/products/items/chocolate.jpg',
      'assets/products/items/makhana.jpg',
      'assets/products/items/granola_bar.jpg',
      'assets/products/items/dishwash.jpg',
      'assets/products/items/detergent.jpg',
      'assets/products/items/floor_cleaner.jpg',
      'assets/products/items/kitchen_towels.jpg',
      'assets/products/items/garbage_bags.jpg',
      'assets/products/items/aluminium_foil.jpg',
      'assets/products/items/shampoo.jpg',
      'assets/products/items/bath_soap.jpg',
      'assets/products/items/toothpaste.jpg',
      'assets/products/items/hand_wash.jpg',
      'assets/products/items/face_cream.jpg',
      'assets/products/items/baby_wipes.jpg',
    ];
    return Product(
      id: 'p$i',
      name: names[i],
      sku: 'SKU-${1000 + i}',
      barcode: '890100000${i.toString().padLeft(2, '0')}',
      categoryId: categoryIds[i],
      purchasePrice: 3500 + i * 175,
      sellingPrice: 4900 + i * 225,
      stock: i % 9 == 0 ? 2 : 12 + (i * 7) % 45,
      minimumStock: 6,
      imageAsset: itemImages[i],
    );
  });
  const customers = [
    Customer(id: 'walkin', name: 'Walk-in Customer'),
    Customer(id: 'c1', name: 'Aarav Sharma', phone: '9876543210'),
    Customer(id: 'c2', name: 'Diya Patel', phone: '9811112233'),
    Customer(id: 'c3', name: 'Kabir Khan', phone: '9822223344'),
    Customer(id: 'c4', name: 'Meera Nair', phone: '9833334455'),
    Customer(id: 'c5', name: 'Rohan Gupta', phone: '9844445566'),
    Customer(id: 'c6', name: 'Sara Ali', phone: '9855556677'),
    Customer(id: 'c7', name: 'Vikram Singh', phone: '9866667788'),
  ];
  final now = DateTime.now();
  final sales = List.generate(10, (i) {
    final item = CartLine(
      product: products[(i * 2) % products.length],
      quantity: 1 + i % 3,
    );
    return Sale(
      localId: 'seed-sale-$i',
      serverId: 'srv-$i',
      invoiceNo: 'RF-${10000 - i}',
      createdAt: now.subtract(Duration(hours: i * 5 + 1)),
      updatedAt: now,
      customer: customers[i % customers.length],
      items: [item],
      paymentMethod: PaymentMethod.values[i % 3],
      total: item.total,
      tax: item.tax,
      discount: 0,
      syncStatus: SyncStatus.synced,
    );
  });
  final purchases = List.generate(
    5,
    (i) => Purchase(
      localId: 'seed-p-$i',
      invoiceNo: 'PUR-${990 - i}',
      supplier: const Supplier(id: 's1', name: 'Metro Wholesale'),
      createdAt: now.subtract(Duration(days: i + 1)),
      items: [
        PurchaseItem(
          productId: products[i].id,
          quantity: 10,
          rate: products[i].purchasePrice,
        ),
      ],
      total: products[i].purchasePrice * 10,
      syncStatus: SyncStatus.synced,
    ),
  );
  return AppState(
    products: products,
    categories: cats,
    customers: customers,
    sales: sales,
    purchases: purchases,
    inventoryTransactions: const [],
    syncQueue: const [],
  );
}
