enum PurchaseDocumentType { order, invoice, purchaseReturn }

class PurchaseExpense {
  const PurchaseExpense({this.name = '', this.amount = 0});
  final String name;
  final double amount;
}

class PurchasePaymentDraft {
  const PurchasePaymentDraft({
    required this.amount,
    required this.method,
    required this.paidOn,
    this.accountId,
    this.note = '',
  });
  final double amount;
  final String method;
  final DateTime paidOn;
  final String? accountId;
  final String note;

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'method': method,
    'paid_on': paidOn.toIso8601String(),
    if (accountId != null && accountId!.isNotEmpty) 'account_id': accountId,
    if (note.trim().isNotEmpty) 'note': note.trim(),
  };
}

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
    this.exchangeRate = 1,
    this.discountType = 'fixed',
    this.discountAmount = 0,
    this.taxId,
    this.shippingDetails = '',
    this.shippingCharges = 0,
    this.deliveryDate,
    this.payTermNumber,
    this.payTermType = 'days',
    this.expenses = const [],
    this.payments = const [],
  });

  final String id,
      reference,
      supplierId,
      supplierName,
      locationId,
      locationName;
  final String status, shippingStatus, notes;
  final String? purchaseOrderId;
  final String? taxId, payTermType;
  final DateTime date;
  final DateTime? deliveryDate;
  final int total;
  final double exchangeRate, discountAmount, shippingCharges;
  final String discountType, shippingDetails;
  final int? payTermNumber;
  final PurchaseDocumentType type;
  final List<PurchaseLineRecord> lines;
  final List<PurchaseExpense> expenses;
  final List<PurchasePaymentDraft> payments;
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
    this.exchangeRate = 1,
    this.discountType = 'fixed',
    this.discountAmount = 0,
    this.taxId,
    this.shippingDetails = '',
    this.shippingCharges = 0,
    this.deliveryDate,
    this.payTermNumber,
    this.payTermType = 'days',
    this.expenses = const [],
    this.payments = const [],
  });

  final PurchaseDocumentType type;
  final String supplierId, locationId, reference, status, shippingStatus, notes;
  final String? purchaseOrderId;
  final String? taxId, payTermType;
  final DateTime date;
  final DateTime? deliveryDate;
  final List<PurchaseLineRecord> lines;
  final double exchangeRate, discountAmount, shippingCharges;
  final String discountType, shippingDetails;
  final int? payTermNumber;
  final List<PurchaseExpense> expenses;
  final List<PurchasePaymentDraft> payments;

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
    'exchange_rate': exchangeRate,
    'discount_type': discountType,
    'discount_amount': discountAmount,
    if (taxId != null && taxId!.isNotEmpty) 'tax_id': taxId,
    'shipping_charges': shippingCharges,
    if (shippingDetails.trim().isNotEmpty)
      'shipping_details': shippingDetails.trim(),
    if (deliveryDate != null) 'delivery_date': deliveryDate!.toIso8601String(),
    if (payTermNumber != null) 'pay_term_number': payTermNumber,
    if (payTermNumber != null) 'pay_term_type': payTermType,
    for (var i = 0; i < expenses.length && i < 4; i++) ...{
      'additional_expense_key_${i + 1}': expenses[i].name.trim(),
      'additional_expense_value_${i + 1}': expenses[i].amount,
    },
    if (payments.isNotEmpty)
      'payments': payments.map((payment) => payment.toJson()).toList(),
    'lines': lines.map((line) => line.toJson()).toList(growable: false),
  };
}
