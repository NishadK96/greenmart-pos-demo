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
    this.nameEn = '',
    this.nameAr = '',
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
  final String nameEn, nameAr;
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
    String? nameEn,
    String? nameAr,
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
    nameEn: nameEn ?? this.nameEn,
    nameAr: nameAr ?? this.nameAr,
  );

  String displayName(bool arabic) {
    if (arabic && nameAr.trim().isNotEmpty) return nameAr.trim();
    if (!arabic && nameEn.trim().isNotEmpty) return nameEn.trim();
    return name;
  }
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
  final int? purchasePrice, sellingPrice;
  final int minimumStock, openingStock;
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
    this.businessName = '',
    this.commercialRegistrationNumber = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.zipCode = '',
    this.contactId = '',
    this.prefix = '',
    this.middleName = '',
    this.lastName = '',
    this.alternateNumber = '',
    this.landline = '',
    this.dateOfBirth = '',
    this.customerGroupId = '',
    this.payTermNumber = '',
    this.payTermType = 'days',
    this.shippingAddress = '',
    this.position = '',
  });
  final String id, name, phone, email, address;
  final String? taxNumber;
  final String businessName,
      commercialRegistrationNumber,
      addressLine1,
      addressLine2,
      city,
      state,
      country,
      zipCode,
      contactId,
      prefix,
      middleName,
      lastName,
      alternateNumber,
      landline,
      dateOfBirth,
      customerGroupId,
      payTermNumber,
      payTermType,
      shippingAddress,
      position;

  bool get isBusiness =>
      businessName.trim().isNotEmpty || (taxNumber?.trim().isNotEmpty ?? false);

  bool get isWalkIn {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized == 'walk in' || normalized == 'walk in customer';
  }
}

class BusinessLocation {
  const BusinessLocation({required this.id, required this.name});
  final String id, name;
}

class PaymentOption {
  const PaymentOption({required this.code, required this.label});
  final String code, label;

  bool get isCustom => code.toLowerCase().startsWith('custom_pay_');
}

class BusinessProfile {
  const BusinessProfile({
    required this.name,
    required this.currencyCode,
    required this.currencySymbol,
    required this.timeZone,
    required this.taxLabel,
    this.allowOverselling = false,
    this.nameEn = '',
    this.nameAr = '',
  });
  final String name, currencyCode, currencySymbol, timeZone, taxLabel;
  final String nameEn, nameAr;
  final bool allowOverselling;

  String displayName(bool arabic) {
    if (arabic && nameAr.trim().isNotEmpty) return nameAr.trim();
    if (!arabic && nameEn.trim().isNotEmpty) return nameEn.trim();
    return name;
  }
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

enum SubscriptionTier { lite, basic, standard, advance, unknown }

class SubscriptionSummary {
  const SubscriptionSummary({
    required this.name,
    required this.tier,
    required this.includedUsers,
    required this.userLimit,
    required this.activeUsers,
    this.endDate,
  });

  final String name;
  final SubscriptionTier tier;
  final int includedUsers, userLimit, activeUsers;
  final DateTime? endDate;

  int get additionalUsers => (userLimit - includedUsers).clamp(0, userLimit);
  int get remainingUsers => (userLimit - activeUsers).clamp(0, userLimit);
  bool get isUnlimited => userLimit == 0;
  bool get canBuyAdditionalUsers => tier != SubscriptionTier.lite;
  bool get canAddUser => isUnlimited || activeUsers < userLimit;
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
  const CartLine({
    required this.product,
    this.quantity = 1,
    this.discount = 0,
    this.unitPriceOverride,
    this.sellLineId,
    this.quantityReturned = 0,
  });
  final Product product;
  final int quantity, discount;
  final int? unitPriceOverride;
  final String? sellLineId;
  final int quantityReturned;
  int get returnableQuantity =>
      (quantity - quantityReturned).clamp(0, quantity);
  int get unitPrice => unitPriceOverride ?? product.sellingPrice;
  int get subtotal => unitPrice * quantity;
  int get tax => ((subtotal - discount) * product.taxPercent / 100).round();
  int get total => subtotal - discount + tax;
  CartLine copyWith({
    int? quantity,
    int? discount,
    int? unitPriceOverride,
    bool clearUnitPriceOverride = false,
  }) => CartLine(
    product: product,
    quantity: quantity ?? this.quantity,
    discount: discount ?? this.discount,
    unitPriceOverride: clearUnitPriceOverride
        ? null
        : unitPriceOverride ?? this.unitPriceOverride,
    sellLineId: sellLineId,
    quantityReturned: quantityReturned,
  );
}

class HeldCart {
  const HeldCart({
    required this.lines,
    this.grossDiscount = 0,
    this.grossDiscountType = 'fixed',
    this.grossDiscountRate = 0,
  });

  final List<CartLine> lines;
  final int grossDiscount;
  final String grossDiscountType;
  final double grossDiscountRate;
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
    this.grossDiscountType = 'fixed',
    this.grossDiscountRate = 0,
    required this.syncStatus,
    this.zatcaStatus,
  });
  final String localId, invoiceNo;
  final String? serverId;
  final DateTime createdAt, updatedAt;
  final Customer customer;
  final List<CartLine> items;
  final String paymentMethod;
  final int total, tax, discount;
  final String grossDiscountType;
  final double grossDiscountRate;
  final SyncStatus syncStatus;
  final String? zatcaStatus;

  Sale copyWith({
    String? serverId,
    String? invoiceNo,
    SyncStatus? syncStatus,
    String? zatcaStatus,
  }) => Sale(
    localId: localId,
    serverId: serverId ?? this.serverId,
    invoiceNo: invoiceNo ?? this.invoiceNo,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    customer: customer,
    items: items,
    paymentMethod: paymentMethod,
    total: total,
    tax: tax,
    discount: discount,
    grossDiscountType: grossDiscountType,
    grossDiscountRate: grossDiscountRate,
    syncStatus: syncStatus ?? this.syncStatus,
    zatcaStatus: zatcaStatus ?? this.zatcaStatus,
  );
}

class SaleReturnRecord {
  const SaleReturnRecord({
    required this.id,
    required this.invoiceNo,
    required this.parentSaleId,
    required this.parentInvoiceNo,
    required this.createdAt,
    required this.customerName,
    required this.total,
    required this.paymentStatus,
    required this.paymentMethod,
  });

  final String id;
  final String invoiceNo;
  final String parentSaleId;
  final String parentInvoiceNo;
  final DateTime createdAt;
  final String customerName;
  final int total;
  final String paymentStatus;
  final String paymentMethod;
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
