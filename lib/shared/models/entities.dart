enum SyncStatus { pending, synced, failed, conflict }

enum PaymentMethod { cash, card, digital }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    this.active = true,
  });
  final String id, name;
  final String icon;
  final bool active;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.categoryId,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    required this.minimumStock,
    this.taxPercent = 5,
    this.unit = 'pc',
    this.active = true,
    this.imageAsset = 'assets/products/grocery.jpg',
  });
  final String id, name, sku, barcode, categoryId, unit;
  final String imageAsset;
  final int purchasePrice, sellingPrice, stock, minimumStock;
  final double taxPercent;
  final bool active;
  Product copyWith({int? stock}) => Product(
    id: id,
    name: name,
    sku: sku,
    barcode: barcode,
    categoryId: categoryId,
    purchasePrice: purchasePrice,
    sellingPrice: sellingPrice,
    stock: stock ?? this.stock,
    minimumStock: minimumStock,
    taxPercent: taxPercent,
    unit: unit,
    active: active,
    imageAsset: imageAsset,
  );
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.taxNumber,
  });
  final String id, name, phone, email, address;
  final String? taxNumber;
}

class Supplier {
  const Supplier({required this.id, required this.name});
  final String id, name;
}

class CartLine {
  const CartLine({required this.product, this.quantity = 1, this.discount = 0});
  final Product product;
  final int quantity, discount;
  int get subtotal => product.sellingPrice * quantity;
  int get tax => ((subtotal - discount) * product.taxPercent / 100).round();
  int get total => subtotal - discount + tax;
  CartLine copyWith({int? quantity, int? discount}) => CartLine(
    product: product,
    quantity: quantity ?? this.quantity,
    discount: discount ?? this.discount,
  );
}

class Sale {
  const Sale({
    required this.localId,
    this.serverId,
    required this.invoiceNo,
    required this.createdAt,
    required this.updatedAt,
    required this.customer,
    required this.items,
    required this.paymentMethod,
    required this.total,
    required this.tax,
    required this.discount,
    required this.syncStatus,
  });
  final String localId, invoiceNo;
  final String? serverId;
  final DateTime createdAt, updatedAt;
  final Customer customer;
  final List<CartLine> items;
  final PaymentMethod paymentMethod;
  final int total, tax, discount;
  final SyncStatus syncStatus;
}

class Purchase {
  const Purchase({
    required this.localId,
    required this.invoiceNo,
    required this.supplier,
    required this.createdAt,
    required this.items,
    required this.total,
    required this.syncStatus,
  });
  final String localId, invoiceNo;
  final Supplier supplier;
  final DateTime createdAt;
  final List<PurchaseItem> items;
  final int total;
  final SyncStatus syncStatus;
}

class PurchaseItem {
  const PurchaseItem({
    required this.productId,
    required this.quantity,
    required this.rate,
  });
  final String productId;
  final int quantity, rate;
}

class InventoryTransaction {
  const InventoryTransaction({
    required this.localId,
    required this.productId,
    required this.quantityDelta,
    required this.reason,
    required this.createdAt,
    required this.syncStatus,
  });
  final String localId, productId, reason;
  final int quantityDelta;
  final DateTime createdAt;
  final SyncStatus syncStatus;
}

class SyncQueueItem {
  const SyncQueueItem({
    required this.localId,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    this.status = SyncStatus.pending,
  });
  final String localId, entityType, entityId;
  final DateTime createdAt;
  final SyncStatus status;
}

class TaxConfiguration {
  const TaxConfiguration({this.mode = 'standard', this.enabled = true});
  final String mode;
  final bool enabled;
}

class PrinterConfiguration {
  const PrinterConfiguration({
    this.type = 'Mock printer',
    this.paperSize = '80mm',
  });
  final String type, paperSize;
}

abstract interface class ConnectivityService {
  Stream<bool> get changes;
  Future<bool> get isOnline;
}

abstract interface class SyncService {
  Future<void> syncNow();
}

abstract interface class PrinterService {
  Future<void> printReceipt(Sale sale);
}

abstract interface class PaymentTerminalService {
  Future<bool> requestPayment(int amount);
}

abstract interface class ZatcaService {
  Future<String> createInvoicePayload(Sale sale);
}
