import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/product_card_style_picker.dart';
import '../../../shared/widgets/modifier_selection_dialog.dart';
import '../../../shared/widgets/ui.dart' show ProductImage;
import '../../store/app_store.dart';
import '../../auth/auth_controller.dart';
import '../../invoice_layouts/presentation/invoice_layout_controller.dart';
import '../../printers/application/printer_controller.dart';
import 'kitchen_printing_controller.dart';

typedef _RestaurantContext = ({
  List<RestaurantTable> tables,
  List<LookupOption> staff,
  List<LookupOption> serviceTypes,
});

final kitchenRestaurantContextProvider = FutureProvider.autoDispose
    .family<_RestaurantContext, String>((ref, locationId) async {
      Future<_RestaurantContext> load(String token) async {
        final api = ref.read(apiProvider);
        final results = await Future.wait<Object>([
          api.restaurantTables(token, locationId),
          api.restaurantServiceStaff(token),
          api.restaurantServiceTypes(token),
        ]);
        return (
          tables: results[0] as List<RestaurantTable>,
          staff: results[1] as List<LookupOption>,
          serviceTypes: results[2] as List<LookupOption>,
        );
      }

      var token = await ref.watch(authControllerProvider.future);
      if (token == null || token.isEmpty || token == 'offline-local-session') {
        throw const ApiException(
          'Restaurant order details require an online session.',
        );
      }
      try {
        return await load(token);
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        token = await ref
            .read(authControllerProvider.notifier)
            .refreshAccessToken();
        return load(token);
      }
    });

final kitchenOrdersProvider = FutureProvider.autoDispose
    .family<List<Sale>, String>((ref, locationId) async {
      Future<List<Sale>> load(String token) {
        final store = ref.read(appStoreProvider);
        return ref
            .read(apiProvider)
            .kitchenOrders(
              accessToken: token,
              products: store.products,
              customers: store.customers,
              locationId: locationId,
            );
      }

      var token = await ref.watch(authControllerProvider.future);
      if (token == null || token.isEmpty || token == 'offline-local-session') {
        throw const ApiException(
          'Recent kitchen orders require an online session.',
        );
      }
      try {
        return await load(token);
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        token = await ref
            .read(authControllerProvider.notifier)
            .refreshAccessToken();
        return load(token);
      }
    });

/// A restaurant-focused order entry surface. Its draft is deliberately separate
/// from the retail POS cart so switching modes cannot change an open sale.
class KitchenPosScreen extends ConsumerStatefulWidget {
  const KitchenPosScreen({super.key});

  @override
  ConsumerState<KitchenPosScreen> createState() => _KitchenPosScreenState();
}

class _KitchenPosScreenState extends ConsumerState<KitchenPosScreen> {
  static const _border = Color(0xFFDCE5E2);
  static const _categoryBackgrounds = <Color>[
    Color(0xFFE8F7ED),
    Color(0xFFE9F3FF),
    Color(0xFFFFF1E7),
    Color(0xFFF2ECFF),
    Color(0xFFFFEAF1),
    Color(0xFFE8FAF7),
  ];
  static const _categoryBorders = <Color>[
    Color(0xFFBDE4C9),
    Color(0xFFBEDAF7),
    Color(0xFFF4CBAE),
    Color(0xFFD8C8F3),
    Color(0xFFF1BED0),
    Color(0xFFB8E8E0),
  ];
  static const _productBackgrounds = <Color>[
    Color(0xFFFFF8E3),
    Color(0xFFEAF6FF),
    Color(0xFFFFEDF3),
    Color(0xFFEBF8ED),
    Color(0xFFFFF0E6),
    Color(0xFFF2EDFF),
  ];
  static const _productBorders = <Color>[
    Color(0xFFF1D797),
    Color(0xFFB9DDF3),
    Color(0xFFF2C2D2),
    Color(0xFFBFE1C5),
    Color(0xFFF0C8AD),
    Color(0xFFD6C8F0),
  ];
  final _search = TextEditingController();
  final _focus = FocusNode();
  final Map<String, CartLine> _lines = {};
  String _category = '';
  String _service = 'Dine in';
  String? _tableId;
  String? _waiterId;
  String? _serviceTypeId;
  String _note = '';
  int _guests = 1;
  int _grossDiscount = 0;
  int _addQuantity = 1;
  bool _showMobileOrder = false;
  bool _sending = false;
  String? _pendingClientTransactionId;
  String? _savedTransactionId;
  Sale? _activeOrder;

  bool get _orderLocked => _pendingClientTransactionId != null;

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<Product> _visible(AppState store) {
    final query = _search.text.trim().toLowerCase();
    return store.products
        .where((product) {
          if (!product.active) return false;
          if (_category.isNotEmpty && product.categoryId != _category)
            return false;
          if (query.isEmpty) return true;
          return product.name.toLowerCase().contains(query) ||
              product.nameEn.toLowerCase().contains(query) ||
              product.nameAr.contains(query) ||
              product.sku.toLowerCase().contains(query) ||
              product.barcode.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _add(Product product) async {
    if (_orderLocked) return;
    final modifiers = await selectProductModifiers(context, product);
    if (modifiers == null || !mounted || _orderLocked) return;
    final lineId = CartLine(product: product, modifiers: modifiers).lineId;
    setState(() {
      final old = _lines[lineId];
      _lines[lineId] = CartLine(
        product: product,
        quantity: (old?.quantity ?? 0) + _addQuantity,
        modifiers: modifiers,
      );
      _search.clear();
    });
    _focus.requestFocus();
  }

  void _changeQuantity(CartLine line, int delta) {
    if (_orderLocked) return;
    setState(() {
      final next = line.quantity + delta;
      if (next <= 0) {
        _lines.remove(line.lineId);
      } else {
        _lines[line.lineId] = line.copyWith(quantity: next);
      }
    });
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _sendToKitchen() => unawaited(_submitKitchenOrder());

  String _composedSaleNote() => [
    _service,
    'Pax $_guests',
    if (_note.trim().isNotEmpty) _note.trim(),
  ].join(' · ');

  // Kitchen lines do not support per-item discounts. Build the payable amount
  // from the visible line subtotal so stale/legacy discount values cannot make
  // a newly entered kitchen order appear as zero.
  int _kitchenLineTotal(CartLine line) =>
      line.subtotal + (line.product.sellingPriceIncludesTax ? 0 : line.tax);

  Customer? _customer(AppState store) =>
      store.customer ?? store.customers.firstOrNull;

  String? _locationId(AppState store) {
    final kitchen = ref.read(kitchenPrintingControllerProvider).asData?.value;
    return kitchen?.locationId.isNotEmpty == true
        ? kitchen!.locationId
        : store.locations.firstOrNull?.id;
  }

  void _newOrder() {
    if (_lines.isNotEmpty || _orderLocked || _savedTransactionId != null) {
      _show('Save or clear the current order before starting another one.');
      return;
    }
    _resetOrder();
  }

  void _resetOrder() {
    setState(() {
      _lines.clear();
      _activeOrder = null;
      _savedTransactionId = null;
      _pendingClientTransactionId = null;
      _tableId = null;
      _waiterId = null;
      _serviceTypeId = null;
      _service = 'Dine in';
      _guests = 1;
      _note = '';
      _grossDiscount = 0;
      _showMobileOrder = false;
    });
  }

  Sale? _currentSale(String transactionId, String paymentMethod) {
    final store = ref.read(appStoreProvider);
    final customer = _customer(store);
    if (customer == null) return null;
    final lines = _lines.values.toList(growable: false);
    final total = max(
      0,
      lines.fold<int>(0, (sum, line) => sum + _kitchenLineTotal(line)) -
          _grossDiscount,
    );
    return Sale(
      localId: 'server-$transactionId',
      serverId: transactionId,
      invoiceNo: _activeOrder?.invoiceNo ?? '',
      createdAt: _activeOrder?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      customer: customer,
      items: lines,
      paymentMethod: paymentMethod,
      total: total,
      tax: lines.fold<int>(0, (sum, line) => sum + line.tax),
      discount: _grossDiscount,
      syncStatus: SyncStatus.synced,
      status: 'final',
      paymentStatus: paymentMethod == 'due' ? 'due' : 'paid',
      locationId: _locationId(store) ?? '',
      tableId: _tableId ?? '',
      waiterId: _waiterId ?? '',
      serviceTypeId: _serviceTypeId ?? '',
      saleNote: _composedSaleNote(),
      isKitchenOrder: true,
    );
  }

  Future<void> _printBill() async {
    final transactionId = _savedTransactionId;
    if (transactionId == null || transactionId.isEmpty) {
      _show('Save or send the order before printing its bill.');
      return;
    }
    final sale = _currentSale(
      transactionId,
      _activeOrder?.paymentMethod ?? 'due',
    );
    if (sale == null) return;
    setState(() => _sending = true);
    try {
      final store = ref.read(appStoreProvider);
      final printers = ref.read(printerControllerProvider);
      await ref
          .read(invoiceLayoutControllerProvider.notifier)
          .printSale(
            sale: sale,
            businessName: store.business?.name ?? 'Eazy POS',
            settings: printers.settings,
            printers: printers.selectedPrinters,
            arabic:
                Localizations.localeOf(context).languageCode.toLowerCase() ==
                'ar',
          );
      if (mounted) _show('Bill sent to the selected billing printer.');
    } catch (error) {
      if (mounted) _show('Unable to print this bill: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _billAndPay() async {
    if (_sending || _lines.isEmpty) return;
    final store = ref.read(appStoreProvider);
    final methods = store.checkoutPaymentOptions
        .where((option) => option.code.toLowerCase() != 'due')
        .toList(growable: false);
    if (methods.isEmpty) {
      _show('No payment methods are configured for this location.');
      return;
    }
    final method = await showDialog<PaymentOption>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select payment method'),
        children: [
          for (final option in methods)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, option),
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(option.label),
              ),
            ),
        ],
      ),
    );
    if (method == null || !mounted) return;
    final locationId = _locationId(store);
    final customer = _customer(store);
    if (locationId == null || locationId.isEmpty || customer == null) {
      _show('Refresh customer and business location data before billing.');
      return;
    }
    setState(() => _sending = true);
    try {
      var transactionId = _savedTransactionId;
      if (transactionId == null) {
        _pendingClientTransactionId ??= _newClientTransactionId();
        transactionId = await ref
            .read(kitchenPrintingControllerProvider.notifier)
            .createKitchenOrder(
              locationId: locationId,
              customer: customer,
              lines: _lines.values.toList(growable: false),
              clientTransactionId: _pendingClientTransactionId!,
              saleNote: _composedSaleNote(),
              tableId: _service == 'Dine in' ? _tableId : null,
              serviceStaffId: _waiterId,
              serviceTypeId: _serviceTypeId,
              grossDiscount: _grossDiscount,
            );
      }
      await ref
          .read(kitchenPrintingControllerProvider.notifier)
          .updateKitchenOrder(
            transactionId: transactionId,
            locationId: locationId,
            customer: customer,
            lines: _lines.values.toList(growable: false),
            status: 'final',
            tableId: _service == 'Dine in' ? _tableId : null,
            serviceStaffId: _waiterId,
            serviceTypeId: _serviceTypeId,
            saleNote: _composedSaleNote(),
            grossDiscount: _grossDiscount,
            paymentMethod: method.code,
          );
      await ref
          .read(kitchenPrintingControllerProvider.notifier)
          .processTransaction(transactionId, locationId: locationId);
      if (!mounted) return;
      setState(() => _savedTransactionId = transactionId);
      await _printBill();
      if (!mounted) return;
      ref.invalidate(kitchenOrdersProvider(locationId));
      _show('Order #$transactionId paid and completed.');
      _resetOrder();
    } catch (error) {
      if (mounted) _show('Billing needs attention: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _editGrossDiscount() async {
    var text = (_grossDiscount / 100).toStringAsFixed(2);
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Order discount'),
        content: TextFormField(
          initialValue: text,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Discount amount'),
          onChanged: (value) => text = value,
          onFieldSubmitted: (_) => Navigator.pop(
            dialogContext,
            ((double.tryParse(text) ?? 0) * 100).round(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              ((double.tryParse(text) ?? 0) * 100).round(),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    final maximum = _lines.values.fold<int>(0, (sum, line) => sum + line.total);
    if (amount != null && mounted) {
      setState(() => _grossDiscount = amount.clamp(0, maximum));
    }
  }

  Future<void> _editItemNote(CartLine line) async {
    final controller = TextEditingController(text: line.itemNote);
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Note: ${line.product.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Preparation instructions for this item',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null && mounted) {
      setState(() {
        _lines[line.lineId] = line.copyWith(itemNote: note.trim());
      });
    }
  }

  Future<void> _showRecentOrders(String locationId) async {
    if (_orderLocked) return;
    setState(() => _sending = true);
    try {
      ref.invalidate(kitchenOrdersProvider(locationId));
      final orders = await ref.read(kitchenOrdersProvider(locationId).future);
      if (!mounted) return;
      final selected = await showDialog<Sale>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Recent kitchen orders'),
          content: SizedBox(
            width: 620,
            height: 520,
            child: orders.isEmpty
                ? const Center(child: Text('No kitchen orders found.'))
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final order = orders[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            order.status == 'draft'
                                ? Icons.pause_outlined
                                : Icons.receipt_long_outlined,
                          ),
                        ),
                        title: Text(
                          order.invoiceNo.isEmpty
                              ? 'Order #${order.serverId}'
                              : order.invoiceNo,
                        ),
                        subtitle: Text(
                          '${order.customer.name} • ${order.items.length} items • '
                          '${order.status == 'draft' ? 'Draft' : order.paymentStatus}',
                        ),
                        trailing: RiyalAmount(order.total),
                        onTap: () => Navigator.pop(dialogContext, order),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (selected != null && mounted) _loadOrder(selected);
    } catch (error) {
      if (mounted) _show('Unable to load recent kitchen orders: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _loadOrder(Sale order) {
    final pax = RegExp(
      r'(?:Pax|Guests?)\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(order.saleNote);
    final service = order.saleNote.split('·').first.trim();
    setState(() {
      _lines
        ..clear()
        ..addEntries(order.items.map((line) => MapEntry(line.lineId, line)));
      _activeOrder = order;
      _savedTransactionId = order.serverId;
      _pendingClientTransactionId = null;
      _tableId = order.tableId.isEmpty ? null : order.tableId;
      _waiterId = order.waiterId.isEmpty ? null : order.waiterId;
      _serviceTypeId = order.serviceTypeId.isEmpty ? null : order.serviceTypeId;
      _service = const ['Dine in', 'Takeaway', 'Delivery'].contains(service)
          ? service
          : 'Dine in';
      _guests = int.tryParse(pax?.group(1) ?? '') ?? 1;
      _note = order.saleNote
          .split('·')
          .skip(2)
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' · ');
      _grossDiscount = order.discount;
      _showMobileOrder = true;
    });
  }

  Future<void> _saveDraft() async {
    if (_sending || _orderLocked || _lines.isEmpty) return;
    final store = ref.read(appStoreProvider);
    final locationId = _locationId(store);
    final customer = _customer(store);
    if (locationId == null || locationId.isEmpty || customer == null) {
      _show('Refresh customer and business location data before saving.');
      return;
    }
    setState(() => _sending = true);
    try {
      var transactionId = _savedTransactionId;
      if (transactionId == null) {
        _pendingClientTransactionId ??= _newClientTransactionId();
        transactionId = await ref
            .read(kitchenPrintingControllerProvider.notifier)
            .createKitchenOrder(
              locationId: locationId,
              customer: customer,
              lines: _lines.values.toList(growable: false),
              clientTransactionId: _pendingClientTransactionId!,
              saleNote: _composedSaleNote(),
              status: 'draft',
              tableId: _service == 'Dine in' ? _tableId : null,
              serviceStaffId: _waiterId,
              serviceTypeId: _serviceTypeId,
              suspended: true,
              grossDiscount: _grossDiscount,
            );
      } else {
        await ref
            .read(kitchenPrintingControllerProvider.notifier)
            .updateKitchenOrder(
              transactionId: transactionId,
              locationId: locationId,
              customer: customer,
              lines: _lines.values.toList(growable: false),
              status: 'draft',
              tableId: _service == 'Dine in' ? _tableId : null,
              serviceStaffId: _waiterId,
              serviceTypeId: _serviceTypeId,
              saleNote: _composedSaleNote(),
              grossDiscount: _grossDiscount,
              suspended: true,
            );
      }
      ref.invalidate(kitchenOrdersProvider(locationId));
      if (!mounted) return;
      _show('Order #$transactionId saved as draft.');
      _resetOrder();
    } catch (error) {
      if (mounted) _show('Unable to save this draft: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitKitchenOrder() async {
    if (_sending) return;
    if (_lines.isEmpty && _savedTransactionId == null) {
      _show('Add an item before sending an order.');
      return;
    }
    final kitchen = ref.read(kitchenPrintingControllerProvider).asData?.value;
    if (_savedTransactionId == null && kitchen?.hasActiveRoutes != true) {
      _show('Set up a kitchen printer route in Printer settings first.');
      return;
    }
    final store = ref.read(appStoreProvider);
    final locationId = kitchen?.locationId.isNotEmpty == true
        ? kitchen!.locationId
        : store.locations.firstOrNull?.id;
    final customer = store.customer ?? store.customers.firstOrNull;
    if (_savedTransactionId == null &&
        (locationId == null || locationId.isEmpty || customer == null)) {
      _show('Refresh customer and business location data before sending.');
      return;
    }
    setState(() => _sending = true);
    try {
      var transactionId = _savedTransactionId;
      if (transactionId == null) {
        _pendingClientTransactionId ??= _newClientTransactionId();
        final note = _composedSaleNote();
        transactionId = await ref
            .read(kitchenPrintingControllerProvider.notifier)
            .createKitchenOrder(
              locationId: locationId!,
              customer: customer!,
              lines: _lines.values.toList(growable: false),
              clientTransactionId: _pendingClientTransactionId!,
              saleNote: note,
              tableId: _service == 'Dine in' ? _tableId : null,
              serviceStaffId: _waiterId,
              serviceTypeId: _serviceTypeId,
              grossDiscount: _grossDiscount,
            );
        if (!mounted) return;
        setState(() => _savedTransactionId = transactionId);
      } else if (_activeOrder != null) {
        await ref
            .read(kitchenPrintingControllerProvider.notifier)
            .updateKitchenOrder(
              transactionId: transactionId,
              locationId: locationId!,
              customer: customer!,
              lines: _lines.values.toList(growable: false),
              status: 'final',
              tableId: _service == 'Dine in' ? _tableId : null,
              serviceStaffId: _waiterId,
              serviceTypeId: _serviceTypeId,
              saleNote: _composedSaleNote(),
              grossDiscount: _grossDiscount,
            );
      }
      final summary = await ref
          .read(kitchenPrintingControllerProvider.notifier)
          .processTransaction(transactionId, locationId: locationId);
      if (!mounted) return;
      ref.invalidate(kitchenOrdersProvider(locationId!));
      _show(
        'Kitchen order #$transactionId saved and ${summary.printedCount} '
        'ticket(s) sent to the paired printer(s).',
      );
      _resetOrder();
    } catch (error) {
      if (!mounted) return;
      setState(() => _showMobileOrder = true);
      _show(
        _savedTransactionId == null
            ? 'Kitchen order not confirmed. Retry this same order: $error'
            : 'Kitchen order #$_savedTransactionId is saved. Printing needs attention; retry without creating another sale: $error',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _newClientTransactionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final products = _visible(store);
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 960;
    final subtotal = _lines.values.fold<int>(
      0,
      (sum, line) => sum + line.subtotal,
    );
    final tax = _lines.values.fold<int>(0, (sum, line) => sum + line.tax);
    final total = max(
      0,
      _lines.values.fold<int>(0, (sum, line) => sum + _kitchenLineTotal(line)) -
          _grossDiscount,
    );
    final kitchen = ref.watch(kitchenPrintingControllerProvider).asData?.value;
    final locationId = kitchen?.locationId.isNotEmpty == true
        ? kitchen!.locationId
        : store.locations.firstOrNull?.id ?? '';
    final restaurantContext = locationId.isEmpty
        ? null
        : ref.watch(kitchenRestaurantContextProvider(locationId)).asData?.value;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f6): () =>
            unawaited(_saveDraft()),
        const SingleActivator(LogicalKeyboardKey.f8): () =>
            unawaited(_printBill()),
        const SingleActivator(LogicalKeyboardKey.f9): _sendToKitchen,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            _header(desktop, restaurantContext, locationId),
            Expanded(
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _catalog(store, products, desktop: true),
                        ),
                        SizedBox(
                          width: width >= 1300 ? 390 : 320,
                          child: _order(
                            total,
                            subtotal: subtotal,
                            tax: tax,
                            desktop: true,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        if (_showMobileOrder)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: _order(
                                  total,
                                  subtotal: subtotal,
                                  tax: tax,
                                  desktop: false,
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: _catalog(store, products, desktop: true),
                          ),
                        Material(
                          color: Colors.white,
                          child: InkWell(
                            key: const ValueKey('kitchen-mobile-order-toggle'),
                            onTap: () => setState(
                              () => _showMobileOrder = !_showMobileOrder,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _showMobileOrder
                                        ? Icons.restaurant_menu_outlined
                                        : Icons.receipt_long_outlined,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _showMobileOrder
                                          ? 'Back to menu'
                                          : 'View order (${_lines.length})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  RiyalAmount(total),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    bool desktop,
    _RestaurantContext? restaurant,
    String locationId,
  ) {
    final title = Row(
      children: [
        const Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 25),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Kitchen POS',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          tooltip: 'New order',
          onPressed: _newOrder,
          icon: const Icon(Icons.add_circle_outline),
          color: Colors.white,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: 'Recent orders',
          onPressed: locationId.isEmpty
              ? null
              : () => _showRecentOrders(locationId),
          icon: const Icon(Icons.receipt_long_outlined),
          color: Colors.white,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
    final controls = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _serviceButton(
            'Dine in',
            Icons.restaurant_outlined,
            restaurant?.serviceTypes ?? const [],
          ),
          _serviceButton(
            'Takeaway',
            Icons.shopping_bag_outlined,
            restaurant?.serviceTypes ?? const [],
          ),
          _serviceButton(
            'Delivery',
            Icons.local_shipping_outlined,
            restaurant?.serviceTypes ?? const [],
          ),
          if (_service == 'Dine in') _tableCard(restaurant?.tables ?? const []),
          _guestCard(),
          _waiterCard(restaurant?.staff ?? const []),
        ],
      ),
    );
    return Container(
      margin: EdgeInsets.fromLTRB(desktop ? 12 : 8, 7, desktop ? 12 : 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: desktop
          ? Row(
              children: [
                SizedBox(width: 190, child: title),
                const SizedBox(width: 16),
                Expanded(child: controls),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Expanded(child: title)]),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _mobileServiceButton(
                        'Dine in',
                        restaurant?.serviceTypes ?? const [],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _mobileServiceButton(
                        'Takeaway',
                        restaurant?.serviceTypes ?? const [],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _mobileServiceButton(
                        'Delivery',
                        restaurant?.serviceTypes ?? const [],
                      ),
                    ),
                  ],
                ),
                if (_service == 'Dine in') ...[
                  const SizedBox(height: 6),
                  _tableCard(restaurant?.tables ?? const [], mobile: true),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _guestCard(mobile: true)),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: _waiterCard(
                        restaurant?.staff ?? const [],
                        mobile: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  void _selectService(String label, List<LookupOption> serviceTypes) {
    String? matchedId;
    final lookup = label.toLowerCase().replaceAll(' ', '');
    for (final option in serviceTypes) {
      final name = option.name.toLowerCase().replaceAll(' ', '');
      if (name.contains(lookup) || lookup.contains(name)) {
        matchedId = option.id;
        break;
      }
    }
    setState(() {
      _service = label;
      _serviceTypeId = matchedId;
      if (label != 'Dine in') _tableId = null;
    });
  }

  Widget _serviceButton(
    String label,
    IconData icon,
    List<LookupOption> serviceTypes,
  ) {
    final selected = _service == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        onPressed: _orderLocked
            ? null
            : () => _selectService(label, serviceTypes),
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : Colors.white,
          foregroundColor: selected ? Colors.white : AppColors.ink,
          side: BorderSide(color: selected ? Colors.white : _border),
          minimumSize: const Size(0, 40),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  Widget _mobileServiceButton(String label, List<LookupOption> serviceTypes) {
    final selected = _service == label;
    return OutlinedButton(
      onPressed: _orderLocked
          ? null
          : () => _selectService(label, serviceTypes),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.primary : Colors.white,
        foregroundColor: selected ? Colors.white : AppColors.ink,
        side: BorderSide(color: selected ? Colors.white : _border),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _tableCard(List<RestaurantTable> tables, {bool mobile = false}) =>
      Container(
        key: const ValueKey('kitchen-table-card'),
        width: mobile ? double.infinity : 156,
        height: mobile ? 44 : 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.table_restaurant_outlined,
              size: 17,
              color: AppColors.ink,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: tables.any((table) => table.id == _tableId)
                      ? _tableId
                      : null,
                  isExpanded: true,
                  hint: const Text('Select table'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No table'),
                    ),
                    for (final table in tables)
                      DropdownMenuItem<String?>(
                        value: table.id,
                        child: Text(
                          table.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _orderLocked
                      ? null
                      : (value) => setState(() => _tableId = value),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _guestCard({bool mobile = false}) => Container(
    width: mobile ? null : 112,
    height: mobile ? 44 : 40,
    margin: EdgeInsets.only(right: mobile ? 0 : 6),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: [
        const Icon(Icons.groups_2_outlined, size: 17),
        IconButton(
          tooltip: 'Remove guest',
          onPressed: _orderLocked || _guests <= 1
              ? null
              : () => setState(() => _guests--),
          icon: const Icon(Icons.remove, size: 15),
          constraints: const BoxConstraints.tightFor(width: 25, height: 34),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: const Size(25, 34),
            maximumSize: const Size(25, 34),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        Expanded(
          child: Text(
            '$_guests',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Add guest',
          onPressed: _orderLocked || _guests >= 99
              ? null
              : () => setState(() => _guests++),
          icon: const Icon(Icons.add, size: 15),
          constraints: const BoxConstraints.tightFor(width: 25, height: 34),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: const Size(25, 34),
            maximumSize: const Size(25, 34),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    ),
  );

  Widget _waiterCard(List<LookupOption> staff, {bool mobile = false}) =>
      Container(
        width: mobile ? null : 170,
        height: mobile ? 44 : 40,
        margin: EdgeInsets.only(right: mobile ? 0 : 6),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, size: 17),
            const SizedBox(width: 6),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: staff.any((item) => item.id == _waiterId)
                      ? _waiterId
                      : null,
                  isExpanded: true,
                  hint: const Text('Waiter'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No waiter'),
                    ),
                    for (final member in staff)
                      DropdownMenuItem<String?>(
                        value: member.id,
                        child: Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _orderLocked
                      ? null
                      : (value) => setState(() => _waiterId = value),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _catalog(
    AppState store,
    List<Product> products, {
    required bool desktop,
  }) {
    final categories = store.categories.where((item) => item.active).toList();
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: const Color(0xFFFAFCFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: ProductCardStylePicker(mode: 'kitchen'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _focus,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (products.length == 1) _add(products.first);
                  },
                  decoration: InputDecoration(
                    hintText: MediaQuery.sizeOf(context).width < 600
                        ? 'Search items'
                        : 'Search item name, SKU or barcode…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? MediaQuery.sizeOf(context).width < 600
                              ? IconButton(
                                  tooltip: 'Focus barcode scanner input',
                                  onPressed: _focus.requestFocus,
                                  icon: const Icon(
                                    Icons.qr_code_scanner_outlined,
                                  ),
                                )
                              : null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              if (MediaQuery.sizeOf(context).width >= 600) ...[
                const SizedBox(width: 7),
                IconButton.outlined(
                  tooltip: 'Focus barcode scanner input',
                  onPressed: _focus.requestFocus,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                ),
                const SizedBox(width: 6),
              ],
              if (MediaQuery.sizeOf(context).width < 600) ...[
                const SizedBox(width: 6),
                OutlinedButton(
                  key: const ValueKey('kitchen-add-quantity'),
                  onPressed: _orderLocked ? null : _editAddQuantity,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                  ),
                  child: Text('x$_addQuantity'),
                ),
              ] else
                Tooltip(
                  message: 'Quantity added per product tap',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Decrease add quantity',
                          onPressed: _addQuantity <= 1
                              ? null
                              : () => setState(() => _addQuantity--),
                          icon: const Icon(Icons.remove, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 29,
                            height: 38,
                          ),
                        ),
                        Text('x$_addQuantity'),
                        IconButton(
                          tooltip: 'Increase add quantity',
                          onPressed: () => setState(() => _addQuantity++),
                          icon: const Icon(Icons.add, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 29,
                            height: 38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (desktop)
            Expanded(child: _categoryProductArea(products, categories, arabic))
          else
            SizedBox(
              height: 420,
              child: _categoryProductArea(products, categories, arabic),
            ),
        ],
      ),
    );
  }

  Widget _categoryProductArea(
    List<Product> products,
    List<Category> categories,
    bool arabic,
  ) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('kitchen-category-panel'),
          width: mobile ? 112 : 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Categories',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _categoryChip('', 'All'),
                    for (var index = 0; index < categories.length; index++)
                      _categoryChip(
                        categories[index].id,
                        arabic && categories[index].nameAr.trim().isNotEmpty
                            ? categories[index].nameAr
                            : categories[index].nameEn.trim().isNotEmpty
                            ? categories[index].nameEn
                            : categories[index].name,
                        paletteIndex: index,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _productGrid(products, categories)),
      ],
    );
  }

  Widget _categoryChip(String id, String label, {int? paletteIndex}) {
    final selected = _category == id;
    final colorIndex = (paletteIndex ?? 0) % _categoryBackgrounds.length;
    final background = id.isEmpty
        ? AppColors.primary
        : _categoryBackgrounds[colorIndex];
    final border = id.isEmpty
        ? AppColors.primary
        : _categoryBorders[colorIndex];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        key: ValueKey(
          id.isEmpty ? 'kitchen-category-all' : 'kitchen-category-$id',
        ),
        onPressed: () => setState(() => _category = id),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : background,
          foregroundColor: selected ? Colors.white : AppColors.ink,
          side: BorderSide(color: selected ? AppColors.primary : border),
          minimumSize: const Size(double.infinity, 64),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _editAddQuantity() async {
    var entered = '$_addQuantity';
    final quantity = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quantity per item tap'),
        content: TextFormField(
          initialValue: entered,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Quantity'),
          onChanged: (value) => entered = value,
          onFieldSubmitted: (_) =>
              Navigator.pop(dialogContext, int.tryParse(entered)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(entered)),
            child: const Text('Set quantity'),
          ),
        ],
      ),
    );
    if (mounted && quantity != null && quantity >= 1 && quantity <= 999) {
      setState(() => _addQuantity = quantity);
    }
  }

  Widget _productGrid(List<Product> products, List<Category> categories) {
    if (products.isEmpty) {
      return const Center(child: Text('No items match this filter.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 520
            ? 3
            : constraints.maxWidth >= 210
            ? 2
            : 1;
        return GridView.builder(
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent:
                ref.watch(productCardImagesProvider)['kitchen'] == true
                ? 176
                : constraints.maxWidth < 440
                ? 92
                : 104,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (_, index) {
            final product = products[index];
            final categoryIndex = categories.indexWhere(
              (category) => category.id == product.categoryId,
            );
            final paletteIndex = categoryIndex >= 0
                ? categoryIndex % _productBackgrounds.length
                : product.categoryId.hashCode.abs() %
                      _productBackgrounds.length;
            return Material(
              color: _productBackgrounds[paletteIndex],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
                side: BorderSide(color: _productBorders[paletteIndex]),
              ),
              child: InkWell(
                key: ValueKey('kitchen-product-${product.id}'),
                borderRadius: BorderRadius.circular(9),
                onTap: _orderLocked ? null : () => _add(product),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (ref.watch(productCardImagesProvider)['kitchen'] ==
                          true) ...[
                        Expanded(
                          child: ProductImage(
                            product.imageUrl,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        product.displayName(
                          Localizations.localeOf(context).languageCode == 'ar',
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      RiyalAmount(
                        product.sellingPrice,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _order(
    int total, {
    required int subtotal,
    required int tax,
    required bool desktop,
  }) => Container(
    margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Current Order',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: _lines.isEmpty || _orderLocked
                  ? null
                  : () => setState(() {
                      _lines.clear();
                      _grossDiscount = 0;
                    }),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 17),
                  SizedBox(width: 4),
                  Text('Clear All'),
                ],
              ),
            ),
          ],
        ),
        const Divider(),
        if (desktop)
          Expanded(child: _orderItems())
        else
          SizedBox(height: 220, child: _orderItems()),
        OutlinedButton.icon(
          onPressed: _orderLocked ? null : _editNote,
          icon: const Icon(Icons.note_add_outlined, size: 19),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _note.isEmpty ? 'Add order note…' : _note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size(0, 46),
            foregroundColor: AppColors.muted,
          ),
        ),
        const Divider(height: 24),
        _amountRow('Subtotal', subtotal),
        const SizedBox(height: 5),
        _amountRow('Tax', tax),
        const SizedBox(height: 5),
        InkWell(
          onTap: _lines.isEmpty || _orderLocked ? null : _editGrossDiscount,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(child: Text('Discount')),
                RiyalAmount(-_grossDiscount),
                const SizedBox(width: 4),
                const Icon(Icons.edit_outlined, size: 15),
              ],
            ),
          ),
        ),
        const Divider(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            RiyalAmount(
              total,
              key: const ValueKey('kitchen-order-total'),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _savedTransactionId != null
              ? 'Order #$_savedTransactionId is saved. Retry kitchen printing; do not create the sale again.'
              : _orderLocked
              ? 'Submission was not confirmed. Retry this same order to avoid a duplicate sale.'
              : 'This finalizes an unpaid kitchen sale and prints routed kitchen tickets.',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('send-to-kitchen'),
          onPressed: _sending ? null : _sendToKitchen,
          icon: const Icon(Icons.soup_kitchen_rounded),
          label: Text(
            _sending
                ? 'Saving and printing…'
                : _savedTransactionId != null
                ? 'Retry kitchen printing (F9)'
                : _orderLocked
                ? 'Retry kitchen submission (F9)'
                : 'Send to Kitchen (F9)',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _lines.isEmpty || _orderLocked || _sending
                    ? null
                    : () => unawaited(_saveDraft()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pause_outlined, size: 18),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Hold (F6)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _savedTransactionId == null || _sending
                    ? null
                    : () => unawaited(_printBill()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.print_outlined, size: 18),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Print Bill (F8)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _lines.isEmpty || _orderLocked || _sending
              ? null
              : () => unawaited(_billAndPay()),
          icon: const Icon(Icons.point_of_sale_outlined),
          label: const Text('Bill & Pay'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
        ),
        if (_activeOrder != null) ...[
          const SizedBox(height: 6),
          Text(
            'Editing ${_activeOrder!.invoiceNo.isEmpty ? 'order #${_activeOrder!.serverId}' : _activeOrder!.invoiceNo}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _amountRow(String label, int amount) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: AppColors.muted)),
      ),
      RiyalAmount(amount),
    ],
  );

  Widget _orderItems() {
    if (_lines.isEmpty) {
      return const Center(child: Text('Tap an item to start an order.'));
    }
    final lines = _lines.values.toList(growable: false);
    return ListView.separated(
      itemCount: lines.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final line = lines[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.displayName(
                        Localizations.localeOf(context).languageCode == 'ar',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    RiyalAmount(line.subtotal),
                    if (line.modifiers.isNotEmpty)
                      Text(
                        line.modifiers
                            .map((modifier) => modifier.name)
                            .join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _orderLocked
                          ? null
                          : () => unawaited(_editItemNote(line)),
                      icon: const Icon(Icons.edit_note_outlined, size: 15),
                      label: Text(
                        line.itemNote.isEmpty ? 'Add item note' : line.itemNote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: 'Decrease quantity',
                onPressed: () => _changeQuantity(line, -1),
                icon: const Icon(Icons.remove, size: 18),
                constraints: const BoxConstraints.tightFor(
                  width: 33,
                  height: 33,
                ),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 8),
              Text('${line.quantity}'),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Increase quantity',
                onPressed: () => _changeQuantity(line, 1),
                icon: const Icon(Icons.add, size: 18),
                constraints: const BoxConstraints.tightFor(
                  width: 33,
                  height: 33,
                ),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 3),
              IconButton(
                tooltip: 'Remove item',
                onPressed: () => setState(() => _lines.remove(line.lineId)),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.danger,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note);
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Order note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Preparation instructions',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (note != null && mounted) setState(() => _note = note.trim());
    controller.dispose();
  }
}
