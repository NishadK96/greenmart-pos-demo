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
    this.heldCarts = const [],
    this.grossDiscount = 0,
    this.grossDiscountType = 'fixed',
    this.grossDiscountRate = 0,
    this.orderTaxId = '',
    this.allowOverselling = false,
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
  List<PaymentOption> get checkoutPaymentOptions => paymentOptions
      .where((option) => !option.isCustom)
      .toList(growable: false);
  List<PaymentOption> get posPaymentOptions {
    final standard = checkoutPaymentOptions
        .where((option) => option.code.toLowerCase() != 'due')
        .toList(growable: true);
    if (!standard.any((option) => option.code.toLowerCase() == 'credit')) {
      standard.add(const PaymentOption(code: 'credit', label: 'Credit sale'));
    }
    return List.unmodifiable(standard);
  }

  final List<StockItem> stockItems;
  final List<LookupOption> units, taxes;
  final List<LookupOption> brands;
  final BusinessProfile? business;
  final UserProfile? user;
  final ProfitLoss? profitLoss;
  final List<CartLine> cart;
  final Customer? customer;
  final Sale? lastSale;
  final List<HeldCart> heldCarts;
  final int grossDiscount;
  final String grossDiscountType;
  final double grossDiscountRate;
  final String orderTaxId;
  double get orderTaxPercent =>
      taxes.where((tax) => tax.id == orderTaxId).firstOrNull?.value ?? 0;
  int get cartOrderTax =>
      ((maximumGrossDiscount - cartGrossDiscount) * orderTaxPercent / 100)
          .round();
  final bool allowOverselling;
  int get cartSubtotal => cart.fold<int>(0, (v, e) => v + e.subtotal);
  int get cartLineDiscount => cart.fold<int>(0, (v, e) => v + e.discount);
  int get cartTax => cart.fold<int>(0, (v, e) => v + e.tax) + cartOrderTax;
  int get maximumGrossDiscount =>
      cart.fold<int>(0, (value, line) => value + line.total);
  int get cartGrossDiscount {
    if (grossDiscountType == 'percentage') {
      if (grossDiscountRate <= 0) return 0;
      return (maximumGrossDiscount * grossDiscountRate / 100).round().clamp(
        0,
        maximumGrossDiscount,
      );
    }
    if (grossDiscount <= 0) return 0;
    if (grossDiscount >= maximumGrossDiscount) return maximumGrossDiscount;
    return grossDiscount;
  }

  int get cartDiscount => cartLineDiscount + cartGrossDiscount;
  int get cartTotal =>
      cart.fold<int>(0, (value, line) => value + line.total) -
      cartGrossDiscount +
      cartOrderTax;
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
    List<HeldCart>? heldCarts,
    int? grossDiscount,
    String? grossDiscountType,
    double? grossDiscountRate,
    String? orderTaxId,
    bool? allowOverselling,
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
    heldCarts: heldCarts ?? this.heldCarts,
    grossDiscount: grossDiscount ?? this.grossDiscount,
    grossDiscountType: grossDiscountType ?? this.grossDiscountType,
    grossDiscountRate: grossDiscountRate ?? this.grossDiscountRate,
    orderTaxId: orderTaxId ?? this.orderTaxId,
    allowOverselling: allowOverselling ?? this.allowOverselling,
  );
}

class AppStore extends Notifier<AppState> {
  @override
  AppState build() => _seed();
  void addToCart(
    Product product, {
    List<SelectedModifier> modifiers = const [],
  }) {
    final candidate = CartLine(product: product, modifiers: modifiers);
    final i = state.cart.indexWhere((e) => e.lineId == candidate.lineId);
    final lines = [...state.cart];
    if (i < 0 && (state.allowOverselling || product.stock > 0)) {
      lines.add(candidate);
    } else if (i >= 0 &&
        (state.allowOverselling || lines[i].quantity < product.stock)) {
      final updated = lines[i].copyWith(quantity: lines[i].quantity + 1);
      lines
        ..removeAt(i)
        ..add(updated);
    }
    state = state.copyWith(cart: lines);
  }

  void quantity(String id, int delta) {
    final lines = [...state.cart];
    final i = lines.indexWhere((e) => e.lineId == id);
    if (i < 0) return;
    final q = lines[i].quantity + delta;
    if (q <= 0)
      lines.removeAt(i);
    else if (state.allowOverselling || q <= lines[i].product.stock)
      lines[i] = lines[i].copyWith(quantity: q);
    state = state.copyWith(cart: lines);
  }

  void discount(String id, int amount) {
    final lines = [...state.cart];
    final i = lines.indexWhere((e) => e.lineId == id);
    if (i < 0) return;
    final maximum = lines[i].subtotal;
    lines[i] = lines[i].copyWith(discount: amount.clamp(0, maximum));
    state = state.copyWith(cart: lines);
  }

  void unitPrice(String id, int? amount) {
    final lines = [...state.cart];
    final i = lines.indexWhere((e) => e.lineId == id);
    if (i < 0) return;
    final updated = amount == null
        ? lines[i].copyWith(clearUnitPriceOverride: true)
        : lines[i].copyWith(unitPriceOverride: amount < 0 ? 0 : amount);
    lines[i] = updated.copyWith(
      discount: updated.discount.clamp(0, updated.subtotal),
    );
    state = state.copyWith(cart: lines);
  }

  void setGrossDiscount(int amount) => state = state.copyWith(
    grossDiscount: amount.clamp(0, state.maximumGrossDiscount),
    grossDiscountType: 'fixed',
    grossDiscountRate: 0,
  );

  void setGrossDiscountPercentage(double rate) => state = state.copyWith(
    grossDiscount: 0,
    grossDiscountType: 'percentage',
    grossDiscountRate: rate.clamp(0, 100),
  );

  void remove(String id) => state = state.copyWith(
    cart: state.cart.where((e) => e.lineId != id).toList(),
  );
  void clearCart() => state = state.copyWith(
    orderTaxId: '',
    cart: [],
    clearCustomer: true,
    grossDiscount: 0,
    grossDiscountType: 'fixed',
    grossDiscountRate: 0,
  );
  void setOrderTax(String id) => state = state.copyWith(orderTaxId: id);
  void replaceTaxes(List<LookupOption> taxes) {
    final selectedExists = taxes.any((tax) => tax.id == state.orderTaxId);
    state = state.copyWith(
      taxes: List.unmodifiable(taxes),
      orderTaxId: selectedExists ? state.orderTaxId : '',
    );
  }

  void clearCashierContext() => state = state.copyWith(
    orderTaxId: '',
    cart: [],
    heldCarts: [],
    clearCustomer: true,
    grossDiscount: 0,
    grossDiscountType: 'fixed',
    grossDiscountRate: 0,
  );
  void holdCart() {
    if (state.cart.isEmpty) return;
    state = state.copyWith(
      heldCarts: [
        HeldCart(
          orderTaxId: state.orderTaxId,
          lines: [...state.cart],
          grossDiscount: state.cartGrossDiscount,
          grossDiscountType: state.grossDiscountType,
          grossDiscountRate: state.grossDiscountRate,
        ),
        ...state.heldCarts,
      ],
      cart: [],
      orderTaxId: '',
      grossDiscount: 0,
      grossDiscountType: 'fixed',
      grossDiscountRate: 0,
      clearCustomer: true,
    );
  }

  void resumeLastHeldCart() {
    if (state.heldCarts.isEmpty || state.cart.isNotEmpty) return;
    state = state.copyWith(
      orderTaxId: state.heldCarts.first.orderTaxId,
      cart: [...state.heldCarts.first.lines],
      grossDiscount: state.heldCarts.first.grossDiscount,
      grossDiscountType: state.heldCarts.first.grossDiscountType,
      grossDiscountRate: state.heldCarts.first.grossDiscountRate,
      heldCarts: state.heldCarts.skip(1).toList(growable: false),
    );
  }

  void selectCustomer(Customer value) =>
      state = state.copyWith(customer: value);
  void addCustomer(Customer customer) =>
      state = state.copyWith(customers: [...state.customers, customer]);
  void updateCustomer(Customer customer) => state = state.copyWith(
    customers: state.customers
        .map((item) => item.id == customer.id ? customer : item)
        .toList(growable: false),
  );
  void addUnit(LookupOption unit) =>
      state = state.copyWith(units: [...state.units, unit]);
  void replaceCategories(List<Category> categories) =>
      state = state.copyWith(categories: categories);
  void removeProduct(String id) => state = state.copyWith(
    products: state.products.where((product) => product.id != id).toList(),
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

  void applySaleReturn(Sale sale, Map<String, int> quantities) {
    final returnedByProduct = <String, int>{};
    final updatedItems = sale.items
        .map((line) {
          final returnedNow = quantities[line.sellLineId] ?? 0;
          if (returnedNow <= 0) return line;
          returnedByProduct.update(
            line.product.id,
            (value) => value + returnedNow,
            ifAbsent: () => returnedNow,
          );
          return line.copyWith(
            quantityReturned: (line.quantityReturned + returnedNow).clamp(
              0,
              line.quantity,
            ),
          );
        })
        .toList(growable: false);
    final updatedSale = sale.copyWith(items: updatedItems);
    final sales = state.sales
        .map(
          (item) =>
              item.localId == sale.localId ||
                  (sale.serverId != null && item.serverId == sale.serverId)
              ? updatedSale
              : item,
        )
        .toList(growable: false);
    final products = state.products
        .map(
          (product) => returnedByProduct.containsKey(product.id)
              ? product.copyWith(
                  stock: product.stock + returnedByProduct[product.id]!,
                )
              : product,
        )
        .toList(growable: false);
    state = state.copyWith(
      sales: sales,
      products: products,
      lastSale: state.lastSale?.localId == sale.localId ? updatedSale : null,
    );
  }

  void replaceCatalog(List<Product> products, List<Category> categories) =>
      state = state.copyWith(products: products, categories: categories);

  void setAllowOverselling(bool enabled) =>
      state = state.copyWith(allowOverselling: enabled);

  void updateBusinessSettings(BusinessSettings settings) {
    final current = state.business;
    if (current == null) return;
    state = state.copyWith(
      business: BusinessProfile(
        name: settings.name,
        nameEn: current.nameEn,
        nameAr: current.nameAr,
        currencyCode: current.currencyCode,
        currencySymbol: current.currencySymbol,
        timeZone: current.timeZone,
        taxLabel: current.taxLabel,
        taxNumber: settings.taxNumber,
        allowOverselling: current.allowOverselling,
      ),
    );
  }

  void restoreOfflineCatalog({
    required List<Product> products,
    required List<Category> categories,
    required List<Customer> customers,
    required List<BusinessLocation> locations,
    required List<PaymentOption> paymentOptions,
    required List<LookupOption> taxes,
    bool allowOverselling = false,
  }) => state = state.copyWith(
    products: products,
    categories: categories,
    customers: customers,
    locations: locations,
    paymentOptions: paymentOptions,
    taxes: taxes,
    allowOverselling: allowOverselling,
  );

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
    allowOverselling: business.allowOverselling,
    user: user,
    profitLoss: profitLoss,
    units: units,
    taxes: taxes,
    brands: brands,
  );

  void replaceRemoteInsights({
    required List<Sale> sales,
    required List<StockItem> stockItems,
    required ProfitLoss profitLoss,
  }) => state = state.copyWith(
    sales: sales,
    stockItems: stockItems,
    profitLoss: profitLoss,
  );

  void replaceSales(List<Sale> sales) => state = state.copyWith(sales: sales);

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
      grossDiscountType: state.grossDiscountType,
      grossDiscountRate: state.grossDiscountRate,
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
      orderTaxId: '',
      grossDiscount: 0,
      grossDiscountType: 'fixed',
      grossDiscountRate: 0,
    );
    return sale;
  }

  void applyOfflineSyncOutcome({
    required String localSaleId,
    required SyncStatus status,
    String? serverId,
    String? invoiceNo,
    String? zatcaStatus,
  }) {
    Sale? updated;
    final sales = state.sales
        .map((sale) {
          if (sale.localId != localSaleId) return sale;
          updated = sale.copyWith(
            serverId: serverId,
            invoiceNo: invoiceNo,
            syncStatus: status,
            zatcaStatus: zatcaStatus,
          );
          return updated!;
        })
        .toList(growable: false);
    state = state.copyWith(
      sales: sales,
      lastSale: state.lastSale?.localId == localSaleId
          ? updated
          : state.lastSale,
    );
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
