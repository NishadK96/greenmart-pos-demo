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
import '../../cash_register/domain/cash_register_entities.dart';
import '../../cash_register/presentation/cash_register_controller.dart';
import '../../cash_register/presentation/cash_register_dialog.dart';
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
      // Capture provider dependencies before the first async gap. This provider
      // is refreshed explicitly, so its Ref can be disposed while an older
      // request is still completing.
      final api = ref.read(apiProvider);
      final store = ref.read(appStoreProvider);
      final auth = ref.read(authControllerProvider.notifier);
      final authFuture = ref.watch(authControllerProvider.future);

      Future<List<Sale>> load(String token) {
        return api.kitchenOrders(
          accessToken: token,
          products: store.products,
          customers: store.customers,
          locationId: locationId,
        );
      }

      var token = await authFuture;
      if (token == null || token.isEmpty || token == 'offline-local-session') {
        throw const ApiException(
          'Recent kitchen orders require an online session.',
        );
      }
      try {
        return await load(token);
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
        token = await auth.refreshAccessToken();
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
  String _service = 'Takeaway';
  String? _tableId;
  String? _waiterId;
  String? _serviceTypeId;
  String _note = '';
  int _guests = 1;
  int _grossDiscount = 0;
  int _addQuantity = 1;
  String? _selectedLineId;
  String _keypadInput = '';
  String _keypadMode = 'qty';
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

  void _selectLine(CartLine line) => setState(() {
    _selectedLineId = line.lineId;
    _keypadInput = '';
  });

  void _keypadPress(String value) {
    if (_orderLocked || _lines.isEmpty) return;
    if (value == 'clear') {
      setState(() => _keypadInput = '');
      return;
    }
    if (value == 'backspace') {
      setState(() {
        if (_keypadInput.isNotEmpty) {
          _keypadInput = _keypadInput.substring(0, _keypadInput.length - 1);
        }
      });
      return;
    }
    final line = _lines[_selectedLineId] ?? _lines.values.last;
    if (value == '+' || value == '-') {
      _changeQuantity(line, value == '+' ? 1 : -1);
      return;
    }
    if (value == 'enter') {
      final enteredAmount = double.tryParse(_keypadInput);
      final enteredQuantity = int.tryParse(_keypadInput);
      if (_keypadMode == 'discount' &&
          enteredAmount != null &&
          enteredAmount >= 0) {
        setState(() {
          final maximum = _lines.values.fold<int>(
            0,
            (sum, item) => sum + _kitchenLineTotal(item),
          );
          _grossDiscount = min((enteredAmount * 100).round(), maximum);
          _keypadInput = '';
        });
      } else if (enteredQuantity != null &&
          enteredQuantity > 0 &&
          enteredQuantity <= 999) {
        setState(() {
          _lines[line.lineId] = line.copyWith(quantity: enteredQuantity);
          _keypadInput = '';
          _selectedLineId = line.lineId;
        });
      }
      return;
    }
    if (value == '.') {
      if (_keypadMode == 'discount' && !_keypadInput.contains('.')) {
        setState(
          () => _keypadInput = _keypadInput.isEmpty ? '0.' : '$_keypadInput.',
        );
      }
      return;
    }
    final maximumLength = _keypadMode == 'discount' ? 8 : 3;
    if (_keypadInput.length < maximumLength) {
      setState(() => _keypadInput += value);
    }
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
      _service = 'Takeaway';
      _guests = 1;
      _note = '';
      _grossDiscount = 0;
      _selectedLineId = null;
      _keypadInput = '';
      _keypadMode = 'qty';
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
    final locationId = _locationId(store);
    final customer = _customer(store);
    if (locationId == null || locationId.isEmpty || customer == null) {
      _show('Refresh customer and business location data before billing.');
      return;
    }
    final register = await _requireOpenRegister(locationId);
    if (register == null || !mounted) return;
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
    setState(() => _sending = true);
    try {
      var transactionId = _savedTransactionId;
      final creatingSale = transactionId == null;
      if (transactionId == null) {
        _pendingClientTransactionId ??= _newClientTransactionId();
        transactionId = await ref
            .read(kitchenPrintingControllerProvider.notifier)
            .createKitchenOrder(
              locationId: locationId,
              cashRegisterId: register.id,
              customer: customer,
              lines: _lines.values.toList(growable: false),
              clientTransactionId: _pendingClientTransactionId!,
              saleNote: _composedSaleNote(),
              tableId: _service == 'Dine in' ? _tableId : null,
              serviceStaffId: _waiterId,
              serviceTypeId: _serviceTypeId,
              grossDiscount: _grossDiscount,
              paymentMethod: method.code,
            );
      }
      if (!creatingSale) {
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
      }
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
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 403 && _savedTransactionId != null) {
        _show(
          'This account cannot settle an existing kitchen order. Ask an administrator to enable the Sell Update permission.',
        );
      } else if (error.statusCode == 403) {
        _show(
          'This account cannot create a sale. Ask an administrator to enable Sell Create or Direct Sell Access.',
        );
      } else {
        _show('Billing needs attention: ${error.message}');
      }
    } catch (error) {
      if (mounted) _show('Billing needs attention: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<CashRegister?> _requireOpenRegister(String locationId) async {
    CashRegister? register;
    try {
      register = await ref.read(cashRegisterControllerProvider.future);
    } catch (error) {
      debugPrint('Unable to load cash register: $error');
    }
    if (!mounted) return null;
    if (register == null) {
      final openRegister = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.point_of_sale_rounded),
          title: const Text('Open cash register'),
          content: const Text(
            'A cashier shift must be open before Bill & Pay can complete this order. The current order is safe and will not be created again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Open register'),
            ),
          ],
        ),
      );
      if (openRegister != true || !mounted) return null;
      await showCashRegisterDialog(context, ref);
      if (!mounted) return null;
      register = ref.read(cashRegisterControllerProvider).asData?.value;
      if (register == null) {
        _show('Open the cash register to continue with Bill & Pay.');
        return null;
      }
    }
    if (register.locationId != locationId) {
      _show(
        'The open cash register belongs to another location. Close it and open a register for this store.',
      );
      return null;
    }
    return register;
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
    final maximum = _lines.values.fold<int>(
      0,
      (sum, line) => sum + _kitchenLineTotal(line),
    );
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
      final loadedOrders = await ref.refresh(
        kitchenOrdersProvider(locationId).future,
      );
      final orders = [...loadedOrders]
        ..sort((a, b) {
          if (a.status == b.status) return 0;
          return a.status == 'draft' ? -1 : 1;
        });
      if (!mounted) return;
      final heldCount = orders.where((order) => order.status == 'draft').length;
      final selected = await showDialog<Sale>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final colors = theme.colorScheme;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 640),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Held & recent orders',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Resume held tickets or review recent kitchen orders.',
                                style: TextStyle(color: Color(0xFF64726F)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _OrderSummaryChip(
                          icon: Icons.pause_circle_outline_rounded,
                          label: '$heldCount held',
                          emphasized: heldCount > 0,
                        ),
                        _OrderSummaryChip(
                          icon: Icons.receipt_long_outlined,
                          label: '${orders.length} total',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (orders.isEmpty)
                      Container(
                        height: 190,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLowest,
                          border: Border.all(color: colors.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 38),
                            SizedBox(height: 10),
                            Text(
                              'No kitchen orders found',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 4),
                            Text('Held orders will appear here.'),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: orders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final order = orders[index];
                            final isHeld = order.status == 'draft';
                            final orderNumber = order.invoiceNo.isEmpty
                                ? 'Order #${order.serverId}'
                                : order.invoiceNo;
                            return Material(
                              color: isHeld
                                  ? const Color(0xFFF2FAF7)
                                  : colors.surfaceContainerLowest,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: isHeld
                                      ? const Color(0xFFB9E3D6)
                                      : colors.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () =>
                                    Navigator.pop(dialogContext, order),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final compact =
                                          constraints.maxWidth < 500;
                                      final details = Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  orderNumber,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isHeld
                                                      ? const Color(0xFFD5F3E9)
                                                      : colors
                                                            .secondaryContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(99),
                                                ),
                                                child: Text(
                                                  isHeld
                                                      ? 'Held'
                                                      : order.paymentStatus,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            order.customer.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF56635F),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${order.items.length} items  •  ${money(order.total)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      );
                                      final action = FilledButton.icon(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, order),
                                        icon: Icon(
                                          isHeld
                                              ? Icons.play_arrow_rounded
                                              : Icons.visibility_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          isHeld
                                              ? 'Resume order'
                                              : 'View order',
                                        ),
                                      );
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: isHeld
                                                  ? const Color(0xFFD5F3E9)
                                                  : colors.secondaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                            ),
                                            child: Icon(
                                              isHeld
                                                  ? Icons.pause_rounded
                                                  : Icons.receipt_long_outlined,
                                              color: isHeld
                                                  ? const Color(0xFF08745D)
                                                  : colors.onSecondaryContainer,
                                            ),
                                          ),
                                          const SizedBox(width: 13),
                                          Expanded(
                                            child: compact
                                                ? Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      details,
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      action,
                                                    ],
                                                  )
                                                : Row(
                                                    children: [
                                                      Expanded(child: details),
                                                      const SizedBox(width: 16),
                                                      action,
                                                    ],
                                                  ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (selected != null && mounted) _loadOrder(selected);
    } catch (error, stackTrace) {
      debugPrint('Unable to load recent kitchen orders: $error\n$stackTrace');
      if (mounted) {
        _show(
          'Unable to load held orders. Check the connection and try again.',
        );
      }
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
          : 'Takeaway';
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
                          width: width >= 1500 ? 360 : 330,
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
        OutlinedButton.icon(
          key: const ValueKey('kitchen-held-orders'),
          onPressed: locationId.isEmpty
              ? null
              : () => _showRecentOrders(locationId),
          icon: const Icon(Icons.pause_circle_outline_rounded, size: 17),
          label: const Text('Held orders'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
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
      margin: EdgeInsets.fromLTRB(desktop ? 8 : 8, 5, desktop ? 8 : 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: desktop
          ? Row(
              children: [
                SizedBox(width: 275, child: title),
                const SizedBox(width: 8),
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
          minimumSize: const Size(0, 36),
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
        height: mobile ? 44 : 36,
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
    height: mobile ? 44 : 36,
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
        height: mobile ? 44 : 36,
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      color: const Color(0xFFFAFCFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: desktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
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
                const ProductCardStylePicker(mode: 'kitchen'),
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
          const SizedBox(height: 6),
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
          width: mobile ? 112 : 148,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
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
        const SizedBox(width: 8),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: OutlinedButton(
        key: ValueKey(
          id.isEmpty ? 'kitchen-category-all' : 'kitchen-category-$id',
        ),
        onPressed: () => setState(() => _category = id),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : background,
          foregroundColor: selected ? Colors.white : AppColors.ink,
          side: BorderSide(color: selected ? AppColors.primary : border),
          minimumSize: const Size(double.infinity, 46),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
        final columns = constraints.maxWidth >= 1120
            ? 8
            : constraints.maxWidth >= 800
            ? 6
            : constraints.maxWidth >= 620
            ? 5
            : constraints.maxWidth >= 440
            ? 4
            : constraints.maxWidth >= 220
            ? 2
            : 1;
        return GridView.builder(
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent:
                ref.watch(productCardImagesProvider)['kitchen'] == true
                ? 142
                : 82,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
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
                borderRadius: BorderRadius.circular(7),
                side: BorderSide(color: _productBorders[paletteIndex]),
              ),
              child: InkWell(
                key: ValueKey('kitchen-product-${product.id}'),
                borderRadius: BorderRadius.circular(7),
                onTap: _orderLocked ? null : () => _add(product),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      RiyalAmount(
                        product.sellingPrice,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
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
    margin: EdgeInsets.fromLTRB(
      0,
      MediaQuery.sizeOf(context).height < 720 ? 4 : 8,
      8,
      MediaQuery.sizeOf(context).height < 720 ? 4 : 8,
    ),
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).height < 720 ? 7 : 10),
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
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${_lines.length} items',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: _note.isEmpty ? 'Add order note' : 'Edit order note',
              onPressed: _orderLocked ? null : _editNote,
              icon: const Icon(Icons.note_add_outlined, size: 17),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
            ),
            TextButton(
              onPressed: _lines.isEmpty || _orderLocked
                  ? null
                  : () => setState(() {
                      _lines.clear();
                      _grossDiscount = 0;
                    }),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
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
        const Divider(height: 10),
        if (desktop)
          Expanded(child: _orderItems())
        else
          SizedBox(height: 220, child: _orderItems()),
        if (!desktop || _note.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _orderLocked ? null : _editNote,
            icon: const Icon(Icons.note_add_outlined, size: 17),
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
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.muted,
            ),
          ),
        const Divider(height: 12),
        if (desktop && MediaQuery.sizeOf(context).height < 720)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sub ${moneyAmount(subtotal)}',
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                'Tax ${moneyAmount(tax)}',
                style: const TextStyle(fontSize: 11),
              ),
              InkWell(
                onTap: _lines.isEmpty || _orderLocked
                    ? null
                    : _editGrossDiscount,
                child: Text(
                  'Disc ${moneyAmount(_grossDiscount)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          )
        else ...[
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
        ],
        const Divider(height: 12),
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
        const SizedBox(height: 6),
        if (_savedTransactionId != null || _orderLocked) ...[
          Text(
            _savedTransactionId != null
                ? 'Order #$_savedTransactionId is saved. Retry kitchen printing; do not create the sale again.'
                : 'Submission was not confirmed. Retry this same order to avoid a duplicate sale.',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _lines.isEmpty || _orderLocked || _sending
                    ? null
                    : () => unawaited(_saveDraft()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pause_outlined, size: 18),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Hold',
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
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.print_outlined, size: 18),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Print',
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
              child: FilledButton.icon(
                key: const ValueKey('send-to-kitchen'),
                onPressed: _sending ? null : _sendToKitchen,
                icon: const Icon(Icons.soup_kitchen_rounded, size: 17),
                label: Text(_sending ? 'Sending…' : 'Kitchen'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: _lines.isEmpty || _sending
              ? null
              : () => unawaited(_billAndPay()),
          icon: const Icon(Icons.point_of_sale_outlined),
          label: const Text('Bill & Pay'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        if (desktop) ...[const SizedBox(height: 6), _numericKeypad()],
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

  Widget _numericKeypad() {
    Widget keypadKey(String label, {String? value, Color? color}) => Expanded(
      child: OutlinedButton(
        onPressed: _orderLocked ? null : () => _keypadPress(value ?? label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 27),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          foregroundColor: color ?? AppColors.ink,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );

    Widget keypadRow(List<Widget> children) => Row(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) const SizedBox(width: 4),
        ],
      ],
    );

    ButtonStyle modeStyle(bool selected) => OutlinedButton.styleFrom(
      minimumSize: const Size(0, 26),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      backgroundColor: selected ? AppColors.primary : Colors.white,
      foregroundColor: selected ? Colors.white : AppColors.ink,
      side: BorderSide(color: selected ? AppColors.primary : _border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _keypadMode = 'qty';
                  _keypadInput = '';
                }),
                style: modeStyle(_keypadMode == 'qty'),
                child: Text(
                  _keypadMode == 'qty' && _keypadInput.isNotEmpty
                      ? 'Qty $_keypadInput'
                      : 'Qty',
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: OutlinedButton(
                onPressed: null,
                style: modeStyle(false),
                child: const Text('Price'),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _keypadMode = 'discount';
                  _keypadInput = '';
                }),
                style: modeStyle(_keypadMode == 'discount'),
                child: Text(
                  _keypadMode == 'discount' && _keypadInput.isNotEmpty
                      ? 'Disc $_keypadInput'
                      : 'Disc',
                ),
              ),
            ),
            const SizedBox(width: 4),
            keypadKey('Clear', value: 'clear', color: AppColors.danger),
          ],
        ),
        const SizedBox(height: 4),
        keypadRow([
          keypadKey('7'),
          keypadKey('8'),
          keypadKey('9'),
          keypadKey('+'),
        ]),
        const SizedBox(height: 4),
        keypadRow([
          keypadKey('4'),
          keypadKey('5'),
          keypadKey('6'),
          keypadKey('−', value: '-'),
        ]),
        const SizedBox(height: 4),
        keypadRow([
          keypadKey('1'),
          keypadKey('2'),
          keypadKey('3'),
          keypadKey('⌫', value: 'backspace'),
        ]),
        const SizedBox(height: 4),
        keypadRow([
          keypadKey('0'),
          keypadKey('.'),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _orderLocked ? null : () => _keypadPress('enter'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 27),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text('Enter'),
            ),
          ),
        ]),
      ],
    );
  }

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
        final selected = (_selectedLineId ?? lines.last.lineId) == line.lineId;
        return InkWell(
          onTap: () => _selectLine(line),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF0F8F5) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        key: ValueKey('kitchen-cart-modifiers-${line.lineId}'),
                        onTap:
                            line.product.modifierGroups.any(
                                  (group) => group.isActive,
                                ) &&
                                !_orderLocked
                            ? () => unawaited(_add(line.product))
                            : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  line.product.displayName(
                                    Localizations.localeOf(
                                          context,
                                        ).languageCode ==
                                        'ar',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      RiyalAmount(line.subtotal),
                      if (line.product.modifierGroups.any(
                        (group) => group.isActive,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: OutlinedButton.icon(
                            key: ValueKey(
                              'kitchen-cart-add-modifiers-${line.lineId}',
                            ),
                            onPressed: _orderLocked
                                ? null
                                : () => unawaited(_add(line.product)),
                            icon: const Icon(Icons.tune_rounded, size: 15),
                            label: const Text('Add modifiers'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              backgroundColor: const Color(0xFFEAF6F2),
                              side: const BorderSide(color: Color(0xFF9FCFC2)),
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
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
                      if (line.itemNote.isNotEmpty)
                        Text(
                          line.itemNote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Decrease quantity',
                  onPressed: () => _changeQuantity(line, -1),
                  icon: const Icon(Icons.remove, size: 16),
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(30),
                    maximumSize: const Size.square(30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: Color(0xFF98A6A1)),
                  ),
                ),
                const SizedBox(width: 4),
                Text('${line.quantity}'),
                const SizedBox(width: 4),
                IconButton.outlined(
                  tooltip: 'Increase quantity',
                  onPressed: () => _changeQuantity(line, 1),
                  icon: const Icon(Icons.add, size: 16),
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(30),
                    maximumSize: const Size.square(30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: Color(0xFF98A6A1)),
                  ),
                ),
                IconButton(
                  tooltip: line.itemNote.isEmpty
                      ? 'Add item note'
                      : 'Edit item note',
                  onPressed: _orderLocked
                      ? null
                      : () => unawaited(_editItemNote(line)),
                  icon: const Icon(Icons.edit_note_outlined, size: 17),
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(28, 30),
                    maximumSize: const Size(28, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove item',
                  onPressed: () => setState(() => _lines.remove(line.lineId)),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.danger,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 30,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(28, 30),
                    maximumSize: const Size(28, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
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

class _OrderSummaryChip extends StatelessWidget {
  const _OrderSummaryChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: emphasized
            ? const Color(0xFFDDF5ED)
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: emphasized
                ? const Color(0xFF08745D)
                : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: emphasized
                  ? const Color(0xFF075E4D)
                  : colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
