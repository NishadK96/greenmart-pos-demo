import '../../../shared/models/entities.dart';

class OfflineCatalog {
  const OfflineCatalog({
    this.products = const [],
    this.categories = const [],
    this.customers = const [],
    this.locations = const [],
    this.paymentOptions = const [],
    this.taxes = const [],
    this.changesCursor = 0,
    this.allowOverselling = false,
    this.cachedAt,
  });

  final List<Product> products;
  final List<Category> categories;
  final List<Customer> customers;
  final List<BusinessLocation> locations;
  final List<PaymentOption> paymentOptions;
  final List<LookupOption> taxes;
  final int changesCursor;
  final bool allowOverselling;
  final DateTime? cachedAt;
  bool get isNotEmpty => products.isNotEmpty && customers.isNotEmpty;

  OfflineCatalog copyWith({
    List<Product>? products,
    List<Category>? categories,
    List<Customer>? customers,
    List<BusinessLocation>? locations,
    List<PaymentOption>? paymentOptions,
    List<LookupOption>? taxes,
    int? changesCursor,
    bool? allowOverselling,
    DateTime? cachedAt,
  }) => OfflineCatalog(
    products: products ?? this.products,
    categories: categories ?? this.categories,
    customers: customers ?? this.customers,
    locations: locations ?? this.locations,
    paymentOptions: paymentOptions ?? this.paymentOptions,
    taxes: taxes ?? this.taxes,
    changesCursor: changesCursor ?? this.changesCursor,
    allowOverselling: allowOverselling ?? this.allowOverselling,
    cachedAt: cachedAt ?? this.cachedAt,
  );
}

class OfflinePosContext {
  const OfflinePosContext({
    required this.id,
    required this.locationId,
    required this.cashRegisterId,
    required this.authorizedUntil,
    required this.businessId,
    required this.userId,
  });

  factory OfflinePosContext.fromJson(Map<String, dynamic> json) =>
      OfflinePosContext(
        id: '${json['id'] ?? ''}',
        locationId: '${json['location_id'] ?? ''}',
        cashRegisterId: '${json['cash_register_id'] ?? ''}',
        authorizedUntil:
            DateTime.tryParse('${json['authorized_until'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        businessId: '${json['business_id'] ?? ''}',
        userId: '${json['user_id'] ?? ''}',
      );

  final String id, locationId, cashRegisterId, businessId, userId;
  final DateTime authorizedUntil;

  bool get active => id.isNotEmpty && authorizedUntil.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
    'id': id,
    'location_id': locationId,
    'cash_register_id': cashRegisterId,
    'authorized_until': authorizedUntil.toIso8601String(),
    'business_id': businessId,
    'user_id': userId,
  };
}

class OfflineSaleRecord {
  const OfflineSaleRecord({
    required this.localSaleId,
    required this.clientTransactionId,
    required this.provisionalInvoiceRef,
    required this.createdAt,
    required this.payload,
    this.revision = 1,
    this.status = 'pending',
    this.message,
  });

  factory OfflineSaleRecord.fromJson(Map<String, dynamic> json) =>
      OfflineSaleRecord(
        localSaleId: '${json['local_sale_id'] ?? ''}',
        clientTransactionId: '${json['client_transaction_id'] ?? ''}',
        provisionalInvoiceRef: '${json['provisional_invoice_ref'] ?? ''}',
        createdAt:
            DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? const {}),
        revision: (json['revision'] as num?)?.toInt() ?? 1,
        status: '${json['status'] ?? 'pending'}',
        message: json['message']?.toString(),
      );

  final String localSaleId, clientTransactionId, provisionalInvoiceRef, status;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final int revision;
  final String? message;

  bool get pending => status == 'pending' || status == 'temp_retry';

  OfflineSaleRecord copyWith({String? status, String? message}) =>
      OfflineSaleRecord(
        localSaleId: localSaleId,
        clientTransactionId: clientTransactionId,
        provisionalInvoiceRef: provisionalInvoiceRef,
        createdAt: createdAt,
        payload: payload,
        revision: revision,
        status: status ?? this.status,
        message: message ?? this.message,
      );

  Map<String, dynamic> toJson() => {
    'local_sale_id': localSaleId,
    'client_transaction_id': clientTransactionId,
    'provisional_invoice_ref': provisionalInvoiceRef,
    'created_at': createdAt.toIso8601String(),
    'payload': payload,
    'revision': revision,
    'status': status,
    if (message != null) 'message': message,
  };
}

class OfflinePosState {
  const OfflinePosState({
    this.context,
    this.catalog = const OfflineCatalog(),
    this.queue = const [],
    this.syncing = false,
  });
  final OfflinePosContext? context;
  final OfflineCatalog catalog;
  final List<OfflineSaleRecord> queue;
  final bool syncing;
  bool get ready => context?.active == true;
  int get pendingCount => queue.where((item) => item.pending).length;

  OfflinePosState copyWith({
    OfflinePosContext? context,
    OfflineCatalog? catalog,
    List<OfflineSaleRecord>? queue,
    bool? syncing,
  }) => OfflinePosState(
    context: context ?? this.context,
    catalog: catalog ?? this.catalog,
    queue: queue ?? this.queue,
    syncing: syncing ?? this.syncing,
  );
}
