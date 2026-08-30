import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../shared/models/entities.dart';
import '../../auth/auth_controller.dart';
import '../../store/app_store.dart';
import '../data/offline_pos_storage.dart';
import '../domain/offline_pos_entities.dart';

final offlinePosControllerProvider =
    AsyncNotifierProvider<OfflinePosController, OfflinePosState>(
      OfflinePosController.new,
    );

class OfflinePosController extends AsyncNotifier<OfflinePosState> {
  final _storage = OfflinePosStorage();

  @override
  Future<OfflinePosState> build() async {
    final cached = await _storage.load();
    _hydrate(cached.catalog);
    return cached;
  }

  Future<void> prepare({
    required String locationId,
    required String cashRegisterId,
  }) async {
    final token = await _token();
    var response = await ref
        .read(apiProvider)
        .offlineBootstrap(
          accessToken: token,
          locationId: locationId,
          cashRegisterId: cashRegisterId,
        );
    final firstBootstrap = _map(response['bootstrap']);
    final contextJson = _map(response['context'] ?? firstBootstrap['context']);
    final context = OfflinePosContext.fromJson(contextJson);
    var page = firstBootstrap.isNotEmpty ? firstBootstrap : response;
    final productJson = <Map<String, dynamic>>[];
    final customerJson = <Map<String, dynamic>>[];
    void collect(Map<String, dynamic> source) {
      productJson.addAll(_items(_map(source['products'])['items']));
      customerJson.addAll(_items(_map(source['customers'])['items']));
    }

    collect(page);
    var productCursor =
        (_map(page['products'])['next_cursor'] as num?)?.toInt() ?? 0;
    var customerCursor =
        (_map(page['customers'])['next_cursor'] as num?)?.toInt() ?? 0;
    while (_map(page['products'])['has_more'] == true ||
        _map(page['customers'])['has_more'] == true) {
      response = await ref
          .read(apiProvider)
          .offlineBootstrap(
            accessToken: token,
            locationId: locationId,
            cashRegisterId: cashRegisterId,
            contextId: context.id,
            productCursor: productCursor,
            customerCursor: customerCursor,
          );
      page = response;
      collect(page);
      productCursor =
          (_map(page['products'])['next_cursor'] as num?)?.toInt() ??
          productCursor;
      customerCursor =
          (_map(page['customers'])['next_cursor'] as num?)?.toInt() ??
          customerCursor;
    }
    final metadata = firstBootstrap.isNotEmpty ? firstBootstrap : page;
    final catalog = _catalog(
      products: productJson,
      customers: customerJson,
      metadata: metadata,
      changesCursor:
          (page['changes_cursor'] as num?)?.toInt() ??
          (metadata['changes_cursor'] as num?)?.toInt() ??
          0,
    );
    final current = state.value ?? const OfflinePosState();
    final updated = current.copyWith(context: context, catalog: catalog);
    state = AsyncData(updated);
    await _storage.save(updated);
    _hydrate(catalog);
  }

  Future<void> refreshCatalogChanges() async {
    final current = state.value ?? await future;
    final context = current.context;
    if (context == null || !context.active || !current.catalog.isNotEmpty)
      return;
    var catalog = current.catalog;
    var cursor = catalog.changesCursor;
    var hasMore = true;
    final token = await _token();
    while (hasMore) {
      final page = await ref
          .read(apiProvider)
          .offlineChanges(
            accessToken: token,
            contextId: context.id,
            cursor: cursor,
          );
      catalog = _applyChanges(catalog, _items(page['items']));
      cursor = (page['next_cursor'] as num?)?.toInt() ?? cursor;
      catalog = catalog.copyWith(
        changesCursor: cursor,
        cachedAt: DateTime.now(),
      );
      final updated = current.copyWith(catalog: catalog);
      state = AsyncData(updated);
      await _storage.save(updated);
      hasMore = page['has_more'] == true;
    }
    _hydrate(catalog);
  }

  void restoreCachedCatalog() {
    final cached = state.value;
    if (cached != null) _hydrate(cached.catalog);
  }

  Future<Sale> queueCurrentSale() async {
    final current = state.value ?? await future;
    final context = current.context;
    if (context == null || !context.active) {
      throw const ApiException(
        'Offline POS is not prepared. Connect once and prepare offline mode from Sync.',
      );
    }
    final appState = ref.read(appStoreProvider);
    if (appState.cart.isEmpty) throw const ApiException('The cart is empty.');
    final customer =
        appState.customer ??
        (appState.customers.isEmpty ? null : appState.customers.first);
    if (customer == null ||
        int.tryParse(customer.id) == null ||
        appState.cart.any(
          (line) =>
              int.tryParse(line.product.id) == null ||
              int.tryParse(line.product.variationId) == null,
        )) {
      throw const ApiException(
        'This cart contains local-only data and cannot be synchronized offline.',
      );
    }
    final sale = ref.read(appStoreProvider.notifier).checkout('cash');
    final clientId = _uuid();
    final provisional =
        'OFF-${sale.createdAt.millisecondsSinceEpoch.toString().substring(5)}';
    ref
        .read(appStoreProvider.notifier)
        .applyOfflineSyncOutcome(
          localSaleId: sale.localId,
          status: SyncStatus.pending,
          invoiceNo: provisional,
        );
    final queuedSale = ref.read(appStoreProvider).lastSale!;
    final record = OfflineSaleRecord(
      localSaleId: queuedSale.localId,
      clientTransactionId: clientId,
      provisionalInvoiceRef: provisional,
      createdAt: queuedSale.createdAt,
      payload: _salePayload(queuedSale, context, clientId, provisional),
    );
    final updated = current.copyWith(queue: [...current.queue, record]);
    state = AsyncData(updated);
    await _storage.save(updated);
    return queuedSale;
  }

  Future<void> syncNow() async {
    final current = state.value ?? await future;
    final context = current.context;
    final pending = current.queue.where((item) => item.pending).toList();
    if (context == null || pending.isEmpty) return;
    state = AsyncData(current.copyWith(syncing: true));
    var queue = [...current.queue];
    try {
      for (var offset = 0; offset < pending.length; offset += 25) {
        final batch = pending.skip(offset).take(25).toList();
        final response = await ref
            .read(apiProvider)
            .syncOfflineSales(
              accessToken: await _token(),
              contextId: context.id,
              batch: batch.map((item) => item.payload).toList(),
            );
        final outcomes = response['data'] as List? ?? const [];
        for (final raw in outcomes.whereType<Map>()) {
          final outcome = Map<String, dynamic>.from(raw);
          final clientId = '${outcome['client_transaction_id'] ?? ''}';
          final index = queue.indexWhere(
            (item) => item.clientTransactionId == clientId,
          );
          if (index < 0) continue;
          final status = '${outcome['status'] ?? 'temp_retry'}';
          queue[index] = queue[index].copyWith(
            status: status,
            message: outcome['message']?.toString(),
          );
          final success =
              status == 'synchronized' || status == 'already_synchronized';
          ref
              .read(appStoreProvider.notifier)
              .applyOfflineSyncOutcome(
                localSaleId: queue[index].localSaleId,
                status: success
                    ? SyncStatus.synced
                    : status == 'conflicted'
                    ? SyncStatus.conflict
                    : status == 'rejected'
                    ? SyncStatus.failed
                    : SyncStatus.pending,
                serverId: outcome['server_transaction_id']?.toString(),
                invoiceNo: outcome['official_invoice_no']?.toString(),
                zatcaStatus: outcome['zatca_status']?.toString(),
              );
        }
      }
      final updated = current.copyWith(queue: queue, syncing: false);
      state = AsyncData(updated);
      await _storage.save(updated);
    } catch (_) {
      state = AsyncData(current.copyWith(queue: queue, syncing: false));
      rethrow;
    }
  }

  Map<String, dynamic> _salePayload(
    Sale sale,
    OfflinePosContext context,
    String clientId,
    String provisional,
  ) {
    final lineDiscounts = sale.items.fold<int>(
      0,
      (total, line) => total + line.discount,
    );
    final grossDiscount = (sale.discount - lineDiscounts).clamp(
      0,
      sale.discount,
    );
    return {
      'client_transaction_id': clientId,
      'revision': 1,
      'provisional_invoice_ref': provisional,
      'document_type': 'sale',
      'location_id': int.parse(context.locationId),
      'contact_id': int.parse(sale.customer.id),
      'transaction_date': sale.createdAt.toIso8601String(),
      'discount_type': sale.grossDiscountType,
      'discount_amount': sale.grossDiscountType == 'percentage'
          ? sale.grossDiscountRate
          : grossDiscount / 100,
      'products': [
        for (final line in sale.items)
          {
            'product_id': int.parse(line.product.id),
            'variation_id': int.parse(line.product.variationId),
            'quantity': line.quantity,
            'unit_price':
                line.unitPrice / (1 + (line.product.taxPercent / 100)) / 100,
            'unit_price_inc_tax': line.unitPrice / 100,
            'item_tax':
                (line.unitPrice -
                    (line.unitPrice / (1 + (line.product.taxPercent / 100)))) /
                100,
            'line_discount_type': 'fixed',
            'line_discount_amount': line.discount / line.quantity / 100,
            if (line.product.taxId.isNotEmpty)
              'tax_id': int.tryParse(line.product.taxId),
            'cached_price': {'unit_price_inc_tax': line.unitPrice / 100},
          },
      ],
      'payments': [
        {'method': 'cash', 'amount': sale.total / 100},
      ],
    };
  }

  Future<String> _token() async {
    var token = await ref.read(authControllerProvider.future);
    if (token == 'offline-local-session') {
      ref.invalidate(authControllerProvider);
      token = await ref.read(authControllerProvider.future);
    }
    if (token == null || token.isEmpty || token == 'offline-local-session') {
      throw const ApiException('Your session has expired.');
    }
    return token;
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  List<Map<String, dynamic>> _items(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);

  OfflineCatalog _catalog({
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> customers,
    required Map<String, dynamic> metadata,
    required int changesCursor,
  }) {
    final taxes = _items(metadata['taxes'])
        .map(
          (item) => LookupOption(
            id: '${item['id'] ?? ''}',
            name: '${item['name'] ?? ''}',
            value: _number(item['amount']),
          ),
        )
        .toList(growable: false);
    final taxAmounts = {for (final tax in taxes) tax.id: tax.value ?? 0};
    final onlineProducts = {
      for (final product in ref.read(appStoreProvider).products)
        product.id: product,
    };
    return OfflineCatalog(
      products: products
          .map(
            (item) => _product(
              item,
              taxAmounts,
              existing: onlineProducts['${item['id'] ?? ''}'],
            ),
          )
          .whereType<Product>()
          .toList(growable: false),
      categories: ref.read(appStoreProvider).categories,
      customers: customers.map(_customer).toList(growable: false),
      locations: _items(metadata['locations'])
          .map(
            (item) => BusinessLocation(
              id: '${item['id'] ?? ''}',
              name: '${item['name'] ?? ''}',
            ),
          )
          .toList(growable: false),
      paymentOptions: _map(metadata['payment_methods']).entries
          .map(
            (entry) => PaymentOption(code: entry.key, label: '${entry.value}'),
          )
          .toList(growable: false),
      taxes: taxes,
      changesCursor: changesCursor,
      cachedAt: DateTime.now(),
      allowOverselling:
          ref.read(appStoreProvider).business?.allowOverselling ??
          ref.read(appStoreProvider).allowOverselling,
    );
  }

  Product? _product(
    Map<String, dynamic> item,
    Map<String, double> taxAmounts, {
    Product? existing,
  }) {
    final variations = _items(item['variations']);
    if (variations.isEmpty) return null;
    final variation = variations.first;
    final taxId = '${item['tax_id'] ?? ''}';
    return Product(
      id: '${item['id'] ?? ''}',
      name: '${item['name'] ?? ''}',
      sku: '${item['sku'] ?? variation['sub_sku'] ?? ''}',
      barcode:
          existing?.barcode ?? '${item['sku'] ?? variation['sub_sku'] ?? ''}',
      categoryId: existing?.categoryId ?? '',
      purchasePrice: existing?.purchasePrice ?? 0,
      sellingPrice: (_number(variation['sell_price_inc_tax']) * 100).round(),
      stock: _number(variation['stock']).floor(),
      minimumStock: existing?.minimumStock ?? 0,
      variationId: '${variation['id'] ?? ''}',
      taxPercent: taxAmounts[taxId] ?? 0,
      unit: existing?.unit ?? 'pc',
      unitId: '${item['unit_id'] ?? existing?.unitId ?? ''}',
      taxId: taxId,
      active: true,
      imageUrl: existing?.imageUrl ?? '',
    );
  }

  Customer _customer(Map<String, dynamic> item) => Customer(
    id: '${item['id'] ?? ''}',
    name: '${item['name'] ?? item['supplier_business_name'] ?? 'Customer'}',
    phone: '${item['mobile'] ?? ''}',
    taxNumber: item['tax_number']?.toString(),
    businessName: '${item['supplier_business_name'] ?? ''}',
    contactId: '${item['contact_id'] ?? ''}',
    payTermNumber: '${item['pay_term_number'] ?? ''}',
    payTermType: '${item['pay_term_type'] ?? 'days'}',
  );

  OfflineCatalog _applyChanges(
    OfflineCatalog catalog,
    List<Map<String, dynamic>> changes,
  ) {
    final products = {for (final item in catalog.products) item.id: item};
    final customers = {for (final item in catalog.customers) item.id: item};
    final taxAmounts = {
      for (final tax in catalog.taxes) tax.id: tax.value ?? 0,
    };
    for (final change in changes) {
      final id = '${change['entity_id'] ?? ''}';
      final deleted = change['operation'] == 'delete' || change['data'] is! Map;
      if (change['entity_type'] == 'product') {
        if (deleted) {
          products.remove(id);
        } else {
          final product = _product(
            _map(change['data']),
            taxAmounts,
            existing: products[id],
          );
          if (product != null) products[id] = product;
        }
      } else if (change['entity_type'] == 'customer') {
        if (deleted) {
          customers.remove(id);
        } else {
          customers[id] = _customer(_map(change['data']));
        }
      }
    }
    return catalog.copyWith(
      products: products.values.toList(growable: false),
      customers: customers.values.toList(growable: false),
    );
  }

  void _hydrate(OfflineCatalog catalog) {
    if (!catalog.isNotEmpty) return;
    if (ref.read(appStoreProvider).products.isNotEmpty) return;
    ref
        .read(appStoreProvider.notifier)
        .restoreOfflineCatalog(
          products: catalog.products,
          categories: catalog.categories,
          customers: catalog.customers,
          locations: catalog.locations,
          paymentOptions: catalog.paymentOptions,
          taxes: catalog.taxes,
          allowOverselling: catalog.allowOverselling,
        );
  }

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
