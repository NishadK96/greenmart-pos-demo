enum SyncStatus { pending, synced, failed, conflict }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    this.nameEn = '',
    this.nameAr = '',
    this.active = true,
    this.subCategories = const [],
  });
  final String id, name;
  final String nameEn, nameAr;
  final String icon;
  final bool active;
  final List<Category> subCategories;
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
    required this.variationId,
    this.taxPercent = 5,
    this.unit = 'pc',
    this.active = true,
    this.imageUrl = '',
    this.unitId = '',
    this.taxId = '',
  });
  final String id,
      name,
      sku,
      barcode,
      categoryId,
      unit,
      variationId,
      unitId,
      taxId;
  final String imageUrl;
  final int purchasePrice, sellingPrice, stock, minimumStock;
  final double taxPercent;
  final bool active;
  Product copyWith({
    String? name,
    String? sku,
    String? categoryId,
    String? unit,
    String? unitId,
    String? taxId,
    int? purchasePrice,
    int? sellingPrice,
    int? stock,
    int? minimumStock,
    String? imageUrl,
    bool? active,
  }) => Product(
    id: id,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    barcode: sku ?? barcode,
    categoryId: categoryId ?? this.categoryId,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    sellingPrice: sellingPrice ?? this.sellingPrice,
    stock: stock ?? this.stock,
    minimumStock: minimumStock ?? this.minimumStock,
    variationId: variationId,
    taxPercent: taxPercent,
    unit: unit ?? this.unit,
    unitId: unitId ?? this.unitId,
    taxId: taxId ?? this.taxId,
    active: active ?? this.active,
    imageUrl: imageUrl ?? this.imageUrl,
  );
}

class LookupOption {
  const LookupOption({required this.id, required this.name, this.value});
  final String id, name;
  final double? value;
}

class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.unitId,
    required this.purchasePrice,
    required this.sellingPrice,
    this.sku = '',
    this.categoryId = '',
    this.taxId = '',
    this.minimumStock = 0,
    this.manageStock = true,
    this.locationIds = const [],
    this.openingStock = 0,
    this.imageBytes,
    this.imageName,
    this.brandId = '',
    this.subCategoryId = '',
    this.barcodeType = 'C128',
    this.taxType = 'exclusive',
    this.purchasePriceIncTax,
    this.sellingPriceIncTax,
    this.profitPercent = 25,
    this.description = '',
    this.weight = '',
    this.preparationMinutes,
    this.enableSerialNumber = false,
    this.notForSelling = false,
    this.brochureBytes,
    this.brochureName,
  });
  final String name, unitId, sku, categoryId, taxId;
  final String brandId,
      subCategoryId,
      barcodeType,
      taxType,
      description,
      weight;
  final int purchasePrice, sellingPrice, minimumStock, openingStock;
  final bool manageStock;
  final List<String> locationIds;
  final List<int>? imageBytes;
  final String? imageName;
  final int? purchasePriceIncTax, sellingPriceIncTax, preparationMinutes;
  final double profitPercent;
  final bool enableSerialNumber, notForSelling;
  final List<int>? brochureBytes;
  final String? brochureName;
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

class BusinessLocation {
  const BusinessLocation({required this.id, required this.name});
  final String id, name;
}

class PaymentOption {
  const PaymentOption({required this.code, required this.label});
  final String code, label;
}

class BusinessProfile {
  const BusinessProfile({
    required this.name,
    required this.currencyCode,
    required this.currencySymbol,
    required this.timeZone,
    required this.taxLabel,
  });
  final String name, currencyCode, currencySymbol, timeZone, taxLabel;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.username,
    required this.isAdmin,
  });
  final String name, username;
  final bool isAdmin;
}

class ProfitLoss {
  const ProfitLoss({
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.grossProfit,
    required this.netProfit,
  });
  final int totalSales, totalPurchases, totalExpenses, grossProfit, netProfit;
}

class StockItem {
  const StockItem({
    required this.productId,
    required this.variationId,
    required this.name,
    required this.sku,
    required this.unit,
    required this.stock,
    required this.minimumStock,
    required this.unitPrice,
    required this.locationName,
  });
  final String productId, variationId, name, sku, unit, locationName;
  final int stock, minimumStock, unitPrice;
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
  final String paymentMethod;
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
