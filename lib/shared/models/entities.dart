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
    this.taxPercent = 0,
    this.sellingPriceIncludesTax = false,
    this.unit = 'pc',
    this.active = true,
    this.imageUrl = '',
    this.unitId = '',
    this.taxId = '',
    this.nameEn = '',
    this.nameAr = '',
    this.modifierGroups = const [],
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
  final bool sellingPriceIncludesTax;
  final bool active;
  final List<ModifierGroup> modifierGroups;
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
    List<ModifierGroup>? modifierGroups,
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
    sellingPriceIncludesTax: sellingPriceIncludesTax,
    unit: unit ?? this.unit,
    unitId: unitId ?? this.unitId,
    taxId: taxId ?? this.taxId,
    active: active ?? this.active,
    imageUrl: imageUrl ?? this.imageUrl,
    nameEn: nameEn ?? this.nameEn,
    nameAr: nameAr ?? this.nameAr,
    modifierGroups: modifierGroups ?? this.modifierGroups,
  );

  String displayName(bool arabic) {
    if (arabic && nameAr.trim().isNotEmpty) return nameAr.trim();
    if (!arabic && nameEn.trim().isNotEmpty) return nameEn.trim();
    return name;
  }
}

class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.name,
    this.isActive = true,
    this.isRequired = false,
    this.minSelections = 0,
    this.maxSelections,
    this.options = const [],
  });

  final String id, name;
  final bool isActive, isRequired;
  final int minSelections;
  final int? maxSelections;
  final List<ModifierOption> options;
}

class ModifierOption {
  const ModifierOption({
    required this.variationId,
    required this.name,
    this.subSku = '',
    this.isActive = true,
    this.isAvailable = true,
    this.priceAdjustment = 0,
    this.priceIncludesTax = true,
  });

  final String variationId, name, subSku;
  final bool isActive, isAvailable, priceIncludesTax;
  final int priceAdjustment;
}

class SelectedModifier {
  const SelectedModifier({
    required this.modifierGroupId,
    required this.modifierGroupName,
    required this.variationId,
    required this.name,
    this.quantity = 1,
    this.unitPrice = 0,
    this.priceIncludesTax = true,
    this.sellLineId,
  });

  final String modifierGroupId, modifierGroupName, variationId, name;
  final int quantity, unitPrice;
  final bool priceIncludesTax;
  final String? sellLineId;

  String get signature => '$modifierGroupId:$variationId:$quantity';
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
    this.nameEn = '',
    this.nameAr = '',
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
    this.profitPercent = 0,
    this.description = '',
    this.weight = '',
    this.preparationMinutes,
    this.enableSerialNumber = false,
    this.notForSelling = false,
    this.brochureBytes,
    this.brochureName,
  });
  final String name, nameEn, nameAr, unitId, sku, categoryId, taxId;
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
    this.landmark = '',
    this.streetName = '',
    this.buildingNumber = '',
    this.additionalNumber = '',
    this.customField1 = '',
    this.customField2 = '',
    this.customField3 = '',
    this.customField4 = '',
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
      landmark,
      streetName,
      buildingNumber,
      additionalNumber,
      customField1,
      customField2,
      customField3,
      customField4,
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
    this.taxNumber = '',
  });
  final String name, currencyCode, currencySymbol, timeZone, taxLabel;
  final String nameEn, nameAr, taxNumber;
  final bool allowOverselling;

  String displayName(bool arabic) {
    if (arabic && nameAr.trim().isNotEmpty) return nameAr.trim();
    if (!arabic && nameEn.trim().isNotEmpty) return nameEn.trim();
    return name;
  }
}

class BusinessSettings {
  const BusinessSettings({required this.name, required this.taxNumber});

  final String name, taxNumber;
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
  const Supplier({
    required this.id,
    required this.name,
    this.contactName = '',
    this.mobile = '',
    this.email = '',
    this.taxNumber = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.zipCode = '',
    this.landmark = '',
    this.streetName = '',
    this.buildingNumber = '',
    this.additionalNumber = '',
  });
  final String id,
      name,
      contactName,
      mobile,
      email,
      taxNumber,
      addressLine1,
      addressLine2,
      city,
      state,
      country,
      zipCode,
      landmark,
      streetName,
      buildingNumber,
      additionalNumber;
}

class CartLine {
  const CartLine({
    required this.product,
    this.quantity = 1,
    this.discount = 0,
    this.unitPriceOverride,
    this.sellLineId,
    this.quantityReturned = 0,
    this.saleUnitPriceIncTax,
    this.modifiers = const [],
    this.itemNote = '',
  });
  final Product product;
  final int quantity, discount;
  final int? unitPriceOverride;
  final String? sellLineId;
  final int quantityReturned;
  final int? saleUnitPriceIncTax;
  final List<SelectedModifier> modifiers;
  final String itemNote;
  String get lineId {
    if (modifiers.isEmpty) return product.id;
    final signature = modifiers.map((item) => item.signature).toList()..sort();
    return '${product.id}|${signature.join('|')}';
  }

  int get modifierUnitTotalIncludingTax => modifiers.fold(
    0,
    (total, item) =>
        total +
        (item.priceIncludesTax
                ? item.unitPrice
                : item.unitPrice +
                      (item.unitPrice * product.taxPercent / 100).round()) *
            item.quantity,
  );
  int get modifierUnitTotalExcludingTax => modifiers.fold(
    0,
    (total, item) =>
        total +
        (item.priceIncludesTax
                ? (item.unitPrice / (1 + product.taxPercent / 100)).round()
                : item.unitPrice) *
            item.quantity,
  );
  int get returnableQuantity =>
      (quantity - quantityReturned).clamp(0, quantity);
  int get returnUnitPrice => saleUnitPriceIncTax ?? unitPrice;
  int get unitPrice => unitPriceOverride ?? product.sellingPrice;
  int get subtotal =>
      (unitPrice +
          (product.sellingPriceIncludesTax
              ? modifierUnitTotalIncludingTax
              : modifierUnitTotalExcludingTax)) *
      quantity;
  int get taxableAmount => (subtotal - discount).clamp(0, subtotal);
  int get tax => product.sellingPriceIncludesTax
      ? (taxableAmount - taxableAmount / (1 + product.taxPercent / 100)).round()
      : (taxableAmount * product.taxPercent / 100).round();
  int get total =>
      product.sellingPriceIncludesTax ? taxableAmount : taxableAmount + tax;
  int get unitPriceExcludingTax => product.sellingPriceIncludesTax
      ? (unitPrice / (1 + product.taxPercent / 100)).round()
      : unitPrice;
  int get unitTax => product.sellingPriceIncludesTax
      ? unitPrice - unitPriceExcludingTax
      : (unitPrice * product.taxPercent / 100).round();
  int get unitPriceIncludingTax =>
      product.sellingPriceIncludesTax ? unitPrice : unitPrice + unitTax;
  CartLine copyWith({
    int? quantity,
    int? discount,
    int? unitPriceOverride,
    bool clearUnitPriceOverride = false,
    int? quantityReturned,
    List<SelectedModifier>? modifiers,
    String? itemNote,
  }) => CartLine(
    product: product,
    quantity: quantity ?? this.quantity,
    discount: discount ?? this.discount,
    unitPriceOverride: clearUnitPriceOverride
        ? null
        : unitPriceOverride ?? this.unitPriceOverride,
    sellLineId: sellLineId,
    quantityReturned: quantityReturned ?? this.quantityReturned,
    saleUnitPriceIncTax: saleUnitPriceIncTax,
    modifiers: modifiers ?? this.modifiers,
    itemNote: itemNote ?? this.itemNote,
  );
}

class HeldCart {
  const HeldCart({
    required this.lines,
    this.grossDiscount = 0,
    this.grossDiscountType = 'fixed',
    this.grossDiscountRate = 0,
    this.orderTaxId = '',
  });

  final List<CartLine> lines;
  final int grossDiscount;
  final String grossDiscountType;
  final double grossDiscountRate;
  final String orderTaxId;
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
    this.status = 'final',
    this.paymentStatus = '',
    this.locationId = '',
    this.tableId = '',
    this.waiterId = '',
    this.serviceTypeId = '',
    this.saleNote = '',
    this.isKitchenOrder = false,
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
  final String status, paymentStatus, locationId, tableId, waiterId;
  final String serviceTypeId, saleNote;
  final bool isKitchenOrder;

  Sale copyWith({
    String? serverId,
    String? invoiceNo,
    List<CartLine>? items,
    SyncStatus? syncStatus,
    String? zatcaStatus,
    String? status,
    String? paymentStatus,
    String? locationId,
    String? tableId,
    String? waiterId,
    String? serviceTypeId,
    String? saleNote,
    bool? isKitchenOrder,
  }) => Sale(
    localId: localId,
    serverId: serverId ?? this.serverId,
    invoiceNo: invoiceNo ?? this.invoiceNo,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    customer: customer,
    items: items ?? this.items,
    paymentMethod: paymentMethod,
    total: total,
    tax: tax,
    discount: discount,
    grossDiscountType: grossDiscountType,
    grossDiscountRate: grossDiscountRate,
    syncStatus: syncStatus ?? this.syncStatus,
    zatcaStatus: zatcaStatus ?? this.zatcaStatus,
    status: status ?? this.status,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    locationId: locationId ?? this.locationId,
    tableId: tableId ?? this.tableId,
    waiterId: waiterId ?? this.waiterId,
    serviceTypeId: serviceTypeId ?? this.serviceTypeId,
    saleNote: saleNote ?? this.saleNote,
    isKitchenOrder: isKitchenOrder ?? this.isKitchenOrder,
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

class RestaurantTable {
  const RestaurantTable({
    required this.id,
    required this.name,
    required this.description,
  });
  final String id, name, description;
}

class ConnectorAccess {
  const ConnectorAccess({required this.isAdmin, required this.permissions});
  final bool isAdmin;
  final Set<String> permissions;
  bool allows(String permission) => isAdmin || permissions.contains(permission);
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
