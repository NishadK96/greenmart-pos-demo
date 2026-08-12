enum PurchaseDocumentType { order, invoice, purchaseReturn }

class PurchaseLineRecord {
  const PurchaseLineRecord({
    required this.productId,
    required this.variationId,
    required this.name,
    required this.quantity,
    required this.unitCost,
    this.id,
    this.sku = '',
    this.taxId,
    this.discountPercent = 0,
  });

  final String? id, taxId;
  final String productId, variationId, name, sku;
  final double quantity, unitCost, discountPercent;
  double get lineTotal => quantity * unitCost * (1 - discountPercent / 100);

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'product_id': productId,
    'variation_id': variationId,
    'quantity': quantity,
    'purchase_price': unitCost / 100,
    'purchase_price_inc_tax': unitCost / 100,
    'unit_cost_before_discount': unitCost / 100,
    'unit_cost': unitCost / 100,
    'unit_price': unitCost / 100,
    'discount_percent': discountPercent,
    if (taxId != null && taxId!.isNotEmpty) 'tax_id': taxId,
  };
}

class PurchaseDocument {
  const PurchaseDocument({
    required this.id,
    required this.type,
    required this.reference,
    required this.supplierId,
    required this.supplierName,
    required this.locationId,
    required this.locationName,
    required this.date,
    required this.status,
    required this.total,
    this.notes = '',
    this.shippingStatus = '',
    this.purchaseOrderId,
    this.lines = const [],
  });

  final String id,
      reference,
      supplierId,
      supplierName,
      locationId,
      locationName;
  final String status, shippingStatus, notes;
  final String? purchaseOrderId;
  final DateTime date;
  final int total;
  final PurchaseDocumentType type;
  final List<PurchaseLineRecord> lines;
}

class PurchaseDraft {
  const PurchaseDraft({
    required this.type,
    required this.supplierId,
    required this.locationId,
    required this.date,
    required this.status,
    required this.lines,
    this.reference = '',
    this.shippingStatus = '',
    this.notes = '',
    this.purchaseOrderId,
  });

  final PurchaseDocumentType type;
  final String supplierId, locationId, reference, status, shippingStatus, notes;
  final String? purchaseOrderId;
  final DateTime date;
  final List<PurchaseLineRecord> lines;

  Map<String, dynamic> toJson() => {
    'contact_id': supplierId,
    'supplier_id': supplierId,
    'location_id': locationId,
    'transaction_date': date.toIso8601String(),
    'status': status,
    if (reference.trim().isNotEmpty) 'ref_no': reference.trim(),
    if (shippingStatus.isNotEmpty) 'shipping_status': shippingStatus,
    if (notes.trim().isNotEmpty) 'additional_notes': notes.trim(),
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
    if (purchaseOrderId != null) 'purchase_order_id': purchaseOrderId,
    'lines': lines.map((line) => line.toJson()).toList(growable: false),
  };
}
