import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../shared/models/entities.dart';
import '../../auth/auth_controller.dart';
import '../../kitchen/presentation/kitchen_printing_controller.dart';
import '../../pos/domain/client_sale_calculation.dart';
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
    _restoreQueuedKitchenSales(cached);
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

  Future<Sale> queueCurrentSale({
    String? clientTransactionId,
    String paymentMethod = 'cash',
  }) async {
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
    final normalizedMethod = paymentMethod.toLowerCase() == 'credit'
        ? 'due'
        : paymentMethod.toLowerCase();
    final allowedMethods = current.catalog.paymentOptions
        .map((option) => option.code.toLowerCase())
        .toSet();
    if (normalizedMethod != 'due' &&
        !allowedMethods.contains(normalizedMethod)) {
      throw const ApiException(
        'This payment method is not enabled for offline sales at this location.',
      );
    }
    final sale = ref.read(appStoreProvider.notifier).checkout(normalizedMethod);
    final clientId = clientTransactionId ?? _uuid();
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
      payload: {
        ..._salePayload(
          queuedSale,
          context,
          clientId,
          provisional,
          paymentMethod: normalizedMethod,
        ),
        'tax_rate_id': appState.orderTaxId.isEmpty
            ? null
            : int.parse(appState.orderTaxId),
      },
    );
    final updated = current.copyWith(queue: [...current.queue, record]);
    state = AsyncData(updated);
    await _storage.save(updated);
    return queuedSale;
  }

  Future<Sale> queueKitchenOrder({
    required String locationId,
    required Customer customer,
    required List<CartLine> lines,
    required String clientTransactionId,
    required String saleNote,
    required String status,
    String? tableId,
    String? serviceStaffId,
    String? serviceTypeId,
    int grossDiscount = 0,
  }) async {
    final current = state.value ?? await future;
    final context = current.context;
    if (context == null ||
        !context.active ||
        context.locationId != locationId) {
      throw const ApiException(
        'Prepare offline mode for this location from Sync while connected.',
      );
    }
    if (lines.isEmpty ||
        int.tryParse(customer.id) == null ||
        lines.any(
          (line) =>
              int.tryParse(line.product.id) == null ||
              int.tryParse(line.product.variationId) == null,
        )) {
      throw const ApiException(
        'This kitchen order contains local-only data and cannot sync.',
      );
    }
    final existingIndex = current.queue.indexWhere(
      (item) => item.clientTransactionId == clientTransactionId,
    );
    if (existingIndex >= 0 &&
        (current.queue[existingIndex].payload['_kind'] != 'kitchen' ||
            !current.queue[existingIndex].pending ||
            current.queue[existingIndex].status == 'print_pending')) {
      throw const ApiException(
        'This kitchen order is already synchronizing. Wait for sync before editing it.',
      );
    }
    final now = DateTime.now();
    final provisional = existingIndex >= 0
        ? current.queue[existingIndex].provisionalInvoiceRef
        : 'OFF-K-${now.microsecondsSinceEpoch}';
    final total = max(
      0,
      lines.fold<int>(0, (sum, line) => sum + line.total) - grossDiscount,
    );
    final sale = Sale(
      localId: 'kitchen-$clientTransactionId',
      invoiceNo: provisional,
      createdAt: now,
      updatedAt: now,
      customer: customer,
      items: lines,
      paymentMethod: 'due',
      total: total,
      tax: lines.fold<int>(0, (sum, line) => sum + line.tax),
      discount: grossDiscount,
      syncStatus: SyncStatus.pending,
      status: status,
      paymentStatus: 'due',
      locationId: locationId,
      tableId: tableId ?? '',
      waiterId: serviceStaffId ?? '',
      serviceTypeId: serviceTypeId ?? '',
      saleNote: saleNote,
      isKitchenOrder: true,
    );
    final sell = <String, dynamic>{
      'client_transaction_id': clientTransactionId,
      'location_id': int.parse(locationId),
      'contact_id': int.parse(customer.id),
      'transaction_date': now.toIso8601String(),
      'status': status,
      'is_kitchen_order': 1,
      if (status == 'draft') 'is_suspend': 1,
      if (tableId?.isNotEmpty == true) 'table_id': int.parse(tableId!),
      if (serviceStaffId?.isNotEmpty == true)
        'service_staff_id': int.parse(serviceStaffId!),
      if (serviceTypeId?.isNotEmpty == true)
        'types_of_service_id': int.parse(serviceTypeId!),
      if (saleNote.trim().isNotEmpty) 'sale_note': saleNote.trim(),
      'discount_type': 'fixed',
      'discount_amount': (grossDiscount / 100).toStringAsFixed(2),
      'products': [
        for (final line in lines)
          {
            'product_id': int.parse(line.product.id),
            'variation_id': int.parse(line.product.variationId),
            'quantity': line.quantity.toStringAsFixed(4),
            'unit_price_inc_tax': (line.unitPriceIncludingTax / 100)
                .toStringAsFixed(2),
            'tax_rate_id': int.tryParse(line.product.taxId),
            'discount_type': 'fixed',
            'discount_amount': (line.discount / 100).toStringAsFixed(2),
            if (line.itemNote.trim().isNotEmpty) 'note': line.itemNote.trim(),
            if (line.modifiers.isNotEmpty)
              'modifiers': [
                for (final modifier in line.modifiers)
                  {
                    'modifier_group_id': int.parse(modifier.modifierGroupId),
                    'variation_id': int.parse(modifier.variationId),
                    'quantity': modifier.quantity,
                    'unit_price_inc_tax': modifier.unitPrice / 100,
                  },
              ],
          },
      ],
    };
    final record = OfflineSaleRecord(
      localSaleId: sale.localId,
      clientTransactionId: clientTransactionId,
      provisionalInvoiceRef: provisional,
      createdAt: now,
      payload: {
        '_kind': 'kitchen',
        'sell': sell,
        '_snapshot': {
          'total': total,
          'tax': sale.tax,
          'discount': grossDiscount,
          'lines': [
            for (final line in lines)
              {
                'product_id': line.product.id,
                'variation_id': line.product.variationId,
                'quantity': line.quantity,
                'unit_price_override': line.unitPriceOverride,
                'discount': line.discount,
                'note': line.itemNote,
                'instance_id': line.instanceId,
                'modifiers': [
                  for (final modifier in line.modifiers)
                    {
                      'group_id': modifier.modifierGroupId,
                      'group_name': modifier.modifierGroupName,
                      'variation_id': modifier.variationId,
                      'name': modifier.name,
                      'quantity': modifier.quantity,
                      'unit_price': modifier.unitPrice,
                      'price_includes_tax': modifier.priceIncludesTax,
                    },
                ],
              },
          ],
        },
      },
    );
    final queue = [...current.queue];
    if (existingIndex >= 0) {
      queue[existingIndex] = record;
    } else {
      queue.add(record);
    }
    final updated = current.copyWith(queue: queue);
    await _storage.save(updated);
    state = AsyncData(updated);
    ref.read(appStoreProvider.notifier).addQueuedKitchenSale(sale);
    return sale;
  }

  Future<void> syncNow() async {
    final current = state.value ?? await future;
    final context = current.context;
    final pending = current.queue.where((item) => item.pending).toList();
    if (context == null || pending.isEmpty) return;
    state = AsyncData(current.copyWith(syncing: true));
    var queue = [...current.queue];
    try {
      final retailPending = pending
          .where((item) => item.payload['_kind'] != 'kitchen')
          .toList();
      for (var offset = 0; offset < retailPending.length; offset += 25) {
        final batch = retailPending.skip(offset).take(25).toList();
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
      for (final record in pending.where(
        (item) => item.payload['_kind'] == 'kitchen',
      )) {
        final index = queue.indexWhere(
          (item) => item.clientTransactionId == record.clientTransactionId,
        );
        if (index < 0) continue;
        try {
          final response = await ref
              .read(apiProvider)
              .createSalePayload(
                accessToken: await _token(),
                sell: Map<String, dynamic>.from(record.payload['sell'] as Map),
              );
          final transactionId =
              '${response['transaction_id'] ?? response['server_transaction_id'] ?? response['id'] ?? ''}';
          if (transactionId.isEmpty) {
            throw const ApiException(
              'Kitchen order synced without a transaction ID. Retry with the same order.',
            );
          }
          final isDraft = (record.payload['sell'] as Map)['status'] == 'draft';
          if (!isDraft) {
            queue[index] = queue[index].copyWith(
              status: 'print_pending',
              message: 'Order saved; kitchen printing pending.',
            );
            final interim = current.copyWith(queue: queue, syncing: true);
            state = AsyncData(interim);
            await _storage.save(interim);
            await ref
                .read(kitchenPrintingControllerProvider.notifier)
                .refresh();
            await ref
                .read(kitchenPrintingControllerProvider.notifier)
                .processTransaction(
                  transactionId,
                  locationId: context.locationId,
                );
          }
          queue[index] = queue[index].copyWith(
            status: 'synchronized',
            clearMessage: true,
          );
          ref
              .read(appStoreProvider.notifier)
              .applyOfflineSyncOutcome(
                localSaleId: record.localSaleId,
                status: SyncStatus.synced,
                serverId: transactionId,
                invoiceNo: response['invoice_no']?.toString(),
              );
          final interim = current.copyWith(queue: queue, syncing: true);
          state = AsyncData(interim);
          await _storage.save(interim);
        } catch (error) {
          queue[index] = queue[index].copyWith(
            status: queue[index].status == 'print_pending'
                ? 'print_pending'
                : 'temp_retry',
            message: error.toString(),
          );
          final interim = current.copyWith(queue: queue, syncing: true);
          state = AsyncData(interim);
          await _storage.save(interim);
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
    String provisional, {
    required String paymentMethod,
  }) {
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
            'unit_price': line.unitPriceExcludingTax / 100,
            'unit_price_inc_tax': line.unitPriceIncludingTax / 100,
            'item_tax': line.unitTax / 100,
            'line_discount_type': 'fixed',
            'line_discount_amount': line.discount / line.quantity / 100,
            if (line.itemNote.trim().isNotEmpty) 'note': line.itemNote.trim(),
            if (line.product.taxId.isNotEmpty)
              'tax_id': int.tryParse(line.product.taxId),
            'cached_price': {
              'unit_price_inc_tax': line.unitPriceIncludingTax / 100,
            },
            if (line.modifiers.isNotEmpty)
              'modifiers': [
                for (final modifier in line.modifiers)
                  {
                    'modifier_group_id': int.parse(modifier.modifierGroupId),
                    'variation_id': int.parse(modifier.variationId),
                    'quantity': modifier.quantity,
                    'unit_price_inc_tax': modifier.unitPrice / 100,
                  },
              ],
          },
      ],
      'client_calculation': ClientSaleCalculation.fromCart(
        lines: sale.items,
        orderDiscount: grossDiscount,
        finalTotal: sale.total,
      ),
      'payments': paymentMethod == 'due'
          ? <Map<String, dynamic>>[]
          : [
              {'method': paymentMethod, 'amount': sale.total / 100},
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
    final paymentOptions = _map(metadata['payment_methods']).entries
        .map((entry) => PaymentOption(code: entry.key, label: '${entry.value}'))
        .toList(growable: true);
    if (!paymentOptions.any(
      (option) => option.code.toLowerCase() == 'credit',
    )) {
      paymentOptions.add(
        const PaymentOption(code: 'credit', label: 'Credit sale'),
      );
    }
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
      paymentOptions: List.unmodifiable(paymentOptions),
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
      sellingPriceIncludesTax: true,
      unit: existing?.unit ?? 'pc',
      unitId: '${item['unit_id'] ?? existing?.unitId ?? ''}',
      taxId: taxId,
      active: true,
      imageUrl: existing?.imageUrl ?? '',
      nameEn: existing?.nameEn ?? '',
      nameAr: existing?.nameAr ?? '',
      modifierGroups: _modifierGroups(item['modifier_groups']),
    );
  }

  List<ModifierGroup> _modifierGroups(dynamic value) => _items(value)
      .map(
        (group) => ModifierGroup(
          id: '${group['id'] ?? ''}',
          name: '${group['name'] ?? ''}',
          isActive: _flag(group['is_active'], fallback: true),
          isRequired: _flag(group['is_required']),
          minSelections: _number(group['min_selections']).round(),
          maxSelections: group['max_selections'] == null
              ? null
              : _number(group['max_selections']).round(),
          options: _items(group['options'])
              .map(
                (option) => ModifierOption(
                  variationId: '${option['variation_id'] ?? ''}',
                  name: '${option['name'] ?? ''}',
                  subSku: '${option['sub_sku'] ?? ''}',
                  isActive: _flag(option['is_active'], fallback: true),
                  isAvailable: _flag(option['is_available'], fallback: true),
                  priceAdjustment: (_number(option['price_adjustment']) * 100)
                      .round(),
                  priceIncludesTax: _flag(
                    option['price_includes_tax'],
                    fallback: true,
                  ),
                ),
              )
              .toList(growable: false),
        ),
      )
      .where((group) => group.id.isNotEmpty)
      .toList(growable: false);

  bool _flag(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return const {'true', '1', 'yes'}.contains(value.toString().toLowerCase());
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

  void _restoreQueuedKitchenSales(OfflinePosState cached) {
    final store = ref.read(appStoreProvider);
    for (final record in cached.queue.where(
      (item) => item.payload['_kind'] == 'kitchen' && item.pending,
    )) {
      if (store.sales.any((sale) => sale.localId == record.localSaleId))
        continue;
      final sell = _map(record.payload['sell']);
      final snapshot = _map(record.payload['_snapshot']);
      final customer = cached.catalog.customers
          .where((item) => item.id == '${sell['contact_id']}')
          .firstOrNull;
      if (customer == null) continue;
      final lines = <CartLine>[];
      for (final raw in _items(snapshot['lines'])) {
        final product = cached.catalog.products
            .where(
              (item) =>
                  item.id == '${raw['product_id']}' &&
                  item.variationId == '${raw['variation_id']}',
            )
            .firstOrNull;
        if (product == null) continue;
        lines.add(
          CartLine(
            product: product,
            quantity: (raw['quantity'] as num?)?.toInt() ?? 1,
            unitPriceOverride: (raw['unit_price_override'] as num?)?.toInt(),
            discount: (raw['discount'] as num?)?.toInt() ?? 0,
            itemNote: '${raw['note'] ?? ''}',
            instanceId: raw['instance_id']?.toString(),
            modifiers: _items(raw['modifiers'])
                .map(
                  (modifier) => SelectedModifier(
                    modifierGroupId: '${modifier['group_id'] ?? ''}',
                    modifierGroupName: '${modifier['group_name'] ?? ''}',
                    variationId: '${modifier['variation_id'] ?? ''}',
                    name: '${modifier['name'] ?? ''}',
                    quantity: (modifier['quantity'] as num?)?.toInt() ?? 1,
                    unitPrice: (modifier['unit_price'] as num?)?.toInt() ?? 0,
                    priceIncludesTax: modifier['price_includes_tax'] != false,
                  ),
                )
                .toList(growable: false),
          ),
        );
      }
      if (lines.isEmpty) continue;
      ref
          .read(appStoreProvider.notifier)
          .addQueuedKitchenSale(
            Sale(
              localId: record.localSaleId,
              invoiceNo: record.provisionalInvoiceRef,
              createdAt: record.createdAt,
              updatedAt: record.createdAt,
              customer: customer,
              items: lines,
              paymentMethod: 'due',
              total: (snapshot['total'] as num?)?.toInt() ?? 0,
              tax: (snapshot['tax'] as num?)?.toInt() ?? 0,
              discount: (snapshot['discount'] as num?)?.toInt() ?? 0,
              syncStatus: SyncStatus.pending,
              status: '${sell['status'] ?? 'final'}',
              paymentStatus: 'due',
              locationId: '${sell['location_id'] ?? ''}',
              tableId: '${sell['table_id'] ?? ''}',
              waiterId: '${sell['service_staff_id'] ?? ''}',
              serviceTypeId: '${sell['types_of_service_id'] ?? ''}',
              saleNote: '${sell['sale_note'] ?? ''}',
              isKitchenOrder: true,
            ),
          );
    }
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
