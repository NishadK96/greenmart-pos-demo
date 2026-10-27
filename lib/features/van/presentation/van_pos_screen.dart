import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import 'package:eazy_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/auth_controller.dart';
import '../../backend/data/eazyerp_backend_repository.dart';
import '../../backend/presentation/backend_controller.dart';
import '../../cash_register/presentation/cash_register_controller.dart';
import '../../invoice_layouts/presentation/invoice_layout_controller.dart';
import '../../pos/pos_screen.dart' show showPosCustomerSelector;
import '../../printers/application/printer_controller.dart';
import '../../settings/application/payment_method_settings_controller.dart';
import '../../store/app_store.dart';

/// Manual route billing. The open register determines the van/location used
/// by the backend; pump/route scheduling and vehicle transfers are not assumed.
class VanPosScreen extends ConsumerStatefulWidget {
  const VanPosScreen({super.key});

  @override
  ConsumerState<VanPosScreen> createState() => _VanPosScreenState();
}

class _VanPosScreenState extends ConsumerState<VanPosScreen> {
  final _search = TextEditingController();
  final _cart = <String, CartLine>{};
  String? _customerId;
  String _payment = 'cash';
  bool _busy = false;
  bool _showMobileCart = false;
  String? _error;
  String? _pendingId;
  String? _pendingFingerprint;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _total => _cart.values.fold(0, (sum, line) => sum + line.total);

  Future<void> _selectCustomer(AppState state) => showPosCustomerSelector(
    context,
    ref,
    state,
    selectedCustomer:
        state.customers
            .where((customer) => customer.id == _customerId)
            .firstOrNull ??
        state.customers.firstOrNull,
    onSelected: (customer) => setState(() {
      _customerId = customer.id;
      _pendingId = null;
      _pendingFingerprint = null;
    }),
  );

  void _change(Product product, double delta, bool allowOverselling) {
    final current = _cart[product.id]?.quantity ?? 0;
    final next = ((current + delta) * 10000).round() / 10000;
    if (next > product.stock && !allowOverselling) {
      setState(
        () => _error = 'Only ${formatQuantity(product.stock)} available.',
      );
      return;
    }
    setState(() {
      if (next <= 0) {
        _cart.remove(product.id);
      } else {
        _cart[product.id] = (_cart[product.id] ?? CartLine(product: product))
            .copyWith(quantity: next);
      }
      _pendingId = null;
      _pendingFingerprint = null;
      _error = null;
    });
  }

  Future<void> _setQuantity(Product product, bool allowOverselling) async {
    final controller = TextEditingController(
      text: formatQuantity(_cart[product.id]?.quantity ?? 1),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quantity · ${product.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    if (!value.isFinite ||
        value <= 0 ||
        value > 9999 ||
        (value > product.stock && !allowOverselling)) {
      setState(() => _error = 'Enter a valid quantity within available stock.');
      return;
    }
    setState(() {
      _cart[product.id] = (_cart[product.id] ?? CartLine(product: product))
          .copyWith(quantity: value);
      _pendingId = null;
      _pendingFingerprint = null;
      _error = null;
    });
  }

  Future<void> _setUnitPrice(CartLine line) async {
    final controller = TextEditingController(
      text: (line.unitPrice / 100).toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        void apply() {
          if (!formKey.currentState!.validate()) return;
          final parsed = double.parse(controller.text.trim());
          Navigator.pop(dialogContext, (parsed * 100).round());
        }

        return AlertDialog(
          title: Text('Edit unit price · ${line.product.name}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Unit price'),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                return parsed == null || !parsed.isFinite || parsed < 0
                    ? 'Enter a valid amount'
                    : null;
              },
              onFieldSubmitted: (_) => apply(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            if (line.unitPriceOverride != null)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, -1),
                child: const Text('Use default price'),
              ),
            FilledButton(onPressed: apply, child: const Text('Apply')),
          ],
        );
      },
    );
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (amount == null || !mounted) return;
    setState(() {
      _cart[line.product.id] = line.copyWith(
        unitPriceOverride: amount < 0 ? null : amount,
        clearUnitPriceOverride: amount < 0,
      );
      _pendingId = null;
      _pendingFingerprint = null;
      _error = null;
    });
  }

  String _transactionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _checkout(AppState state, String paymentMethod) async {
    if (_busy || _cart.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final register = await ref.read(cashRegisterControllerProvider.future);
      if (register == null)
        throw const ApiException('Open a van cash register before selling.');
      if (!state.locations.any((item) => item.id == register.locationId)) {
        throw const ApiException(
          'The register location is unavailable. Refresh and retry.',
        );
      }
      final customer =
          state.customers.where((item) => item.id == _customerId).firstOrNull ??
          state.customers.firstOrNull;
      if (customer == null)
        throw const ApiException('Select a customer before selling.');
      if (paymentMethod == 'credit' && customer.isWalkIn) {
        throw const ApiException(
          'Select a registered customer for a credit sale.',
        );
      }
      final token = await ref.read(authControllerProvider.future);
      if (token == null || token == 'offline-local-session') {
        throw const ApiException(
          'Van checkout requires an online connection. No sale was recorded.',
        );
      }
      final lines = _cart.values.toList(growable: false);
      final fingerprint =
          '${register.id}|${register.locationId}|${customer.id}|$paymentMethod|'
          '${lines.map((line) => '${line.product.id}:${line.quantity}:${line.unitPrice}').join(',')}';
      if (_pendingFingerprint != fingerprint) {
        _pendingFingerprint = fingerprint;
        _pendingId = _transactionId();
      }
      final created = await ref
          .read(backendRepositoryProvider)
          .createSale(
            accessToken: token,
            locationId: register.locationId,
            cashRegisterId: register.id,
            customer: customer,
            lines: lines,
            paymentMethod: paymentMethod,
            total: _total,
            grossDiscount: 0,
            clientTransactionId: _pendingId!,
            isCreditSale: paymentMethod == 'credit',
          );
      if (!mounted) return;
      final now = DateTime.now();
      final completedSale = Sale(
        localId: 'server-${created.id}',
        serverId: created.id,
        invoiceNo: created.invoiceNo,
        createdAt: now,
        updatedAt: now,
        customer: customer,
        items: lines,
        paymentMethod: paymentMethod,
        total: _total,
        tax: lines.fold<int>(0, (sum, line) => sum + line.tax),
        discount: 0,
        syncStatus: SyncStatus.synced,
        status: 'final',
        paymentStatus: paymentMethod == 'credit' ? 'due' : 'paid',
        locationId: register.locationId,
      );
      setState(() {
        _cart.clear();
        _pendingId = null;
        _pendingFingerprint = null;
      });
      final printers = ref.read(printerControllerProvider);
      if (printers.settings.posPrintingEnabled && created.id.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Van sale completed${created.invoiceNo.isEmpty ? '' : ' • ${created.invoiceNo}'} • Printing…',
            ),
          ),
        );
        try {
          await _printCompletedSaleWithRetry(
            completedSale,
            state.business?.name ?? 'Eazy POS',
            arabic:
                Localizations.localeOf(context).languageCode.toLowerCase() ==
                'ar',
          );
        } catch (printError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sale completed, but receipt printing failed: $printError',
                ),
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printers.settings.posPrintingEnabled
                  ? 'Van sale completed.'
                  : 'Van sale completed • Printing is turned off.',
            ),
          ),
        );
      }
      if (!mounted) return;
      if (created.id.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (_) => VanSalePdfDialog(
            transactionId: created.id,
            invoiceNo: created.invoiceNo,
          ),
        );
      }
      try {
        await ref
            .read(backendControllerProvider.notifier)
            .refreshSalesHistory();
      } catch (_) {
        // Sale is already confirmed; the history can be refreshed later.
      }
    } catch (error) {
      if (mounted)
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to submit sale. Check your connection and retry.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printCompletedSaleWithRetry(
    Sale sale,
    String businessName, {
    required bool arabic,
  }) async {
    Object? lastError;
    for (final delay in const [
      Duration.zero,
      Duration(milliseconds: 700),
      Duration(seconds: 2),
    ]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      try {
        final printers = ref.read(printerControllerProvider);
        await ref
            .read(invoiceLayoutControllerProvider.notifier)
            .printSale(
              sale: sale,
              businessName: businessName,
              settings: printers.settings,
              printers: printers.selectedPrinters,
              arabic: arabic,
            );
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Unable to print the completed sale.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStoreProvider);
    final register = ref.watch(cashRegisterControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 850;
    final locationId = register.asData?.value?.locationId;
    final location = state.locations
        .where((item) => item.id == locationId)
        .firstOrNull;
    final query = _search.text.trim().toLowerCase();
    final products = state.products
        .where(
          (product) =>
              product.active &&
              product.sellingPrice > 0 &&
              product.variationId.isNotEmpty &&
              (query.isEmpty ||
                  '${product.name} ${product.sku} ${product.barcode}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList(growable: false);
    final methods = ref
        .watch(paymentMethodSettingsProvider)
        .apply(state.posPaymentOptions)
        .where(
          (option) => !option.isCustom && option.code.toLowerCase() != 'due',
        )
        .toList(growable: false);
    if (locationId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            register.isLoading
                ? 'Loading register…'
                : 'Open the cash register assigned to your van location to start selling.',
          ),
        ),
      );
    }
    final catalog = _catalog(
      products,
      state.allowOverselling,
      location?.name ?? context.tr('Van location'),
    );
    final bill = _bill(state, methods);
    return ColoredBox(
      color: const Color(0xFFF5F8F7),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.primary,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'New van sale',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!compact)
                  Text(
                    location?.name ?? context.tr('Van location'),
                    style: const TextStyle(color: AppColors.muted),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: compact
                  ? Column(
                      children: [
                        _mobileWorkspaceSwitcher(),
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            key: ValueKey(
                              _showMobileCart
                                  ? 'van-mobile-cart'
                                  : 'van-mobile-products',
                            ),
                            child: _showMobileCart ? bill : catalog,
                          ),
                        ),
                        if (!_showMobileCart && _cart.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _mobileCartBar(),
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(child: catalog),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: SingleChildScrollView(child: bill),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileWorkspaceSwitcher() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F0ED),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: _mobileWorkspaceButton(
            label: context.tr('Products'),
            icon: Icons.inventory_2_outlined,
            selected: !_showMobileCart,
            onPressed: () => setState(() => _showMobileCart = false),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _mobileWorkspaceButton(
            label: '${context.tr('Current order')} (${_cart.length})',
            icon: Icons.shopping_cart_outlined,
            selected: _showMobileCart,
            onPressed: () => setState(() => _showMobileCart = true),
          ),
        ),
      ],
    ),
  );

  Widget _mobileWorkspaceButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) => Material(
    color: selected ? Colors.white : Colors.transparent,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.primaryDark : AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _mobileCartBar() => Material(
    color: Colors.white,
    elevation: 8,
    shadowColor: const Color(0x24173B32),
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_cart.length} ${context.tr(_cart.length == 1 ? 'item' : 'items')}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  money(_total),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => setState(() => _showMobileCart = true),
            icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 19),
            label: const Text('View cart'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _catalog(
    List<Product> products,
    bool allowOverselling,
    String location,
  ) => _panel(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${context.tr('Products')} · $location',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Stock shown is the catalog balance; the server validates availability at checkout.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search name, SKU or barcode…',
              filled: true,
              fillColor: Color(0xFFF7FAF9),
            ),
          ),
          const SizedBox(height: 12),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 36,
                    color: AppColors.muted,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No matching products',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Try another name, SKU or barcode.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          for (final product in products) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8F7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE7EEEB)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ProductImage(
                      product.imageUrl,
                      width: 48,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${product.sku}  ·  ${context.tr('catalog stock')} ${formatQuantity(product.stock)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    money(product.sellingPrice),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: '${context.tr('Add')} ${product.name}',
                    onPressed: () => _change(product, 1, allowOverselling),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFDDF4EC),
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(42, 42),
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _bill(AppState state, List<PaymentOption> methods) => _panel(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Current order',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _selectCustomer(state),
            icon: const Icon(Icons.person_search_outlined),
            label: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                state.customers
                        .where((customer) => customer.id == _customerId)
                        .firstOrNull
                        ?.name ??
                    state.customers.firstOrNull?.name ??
                    'Search or add customer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              side: const BorderSide(color: Color(0xFFDDE7E3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_cart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 42, horizontal: 12),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFF2F7F5),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Add products to start an order',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Search or scan items from the catalog to add them to this sale.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          for (final line in _cart.values) ...[
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.product.name),
              subtitle: Text(
                '${formatQuantity(line.quantity)} × ${money(line.unitPrice)}',
              ),
              trailing: Text(
                money(line.total),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () => _setQuantity(line.product, state.allowOverselling),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () =>
                      _change(line.product, -1, state.allowOverselling),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Decrease quantity',
                ),
                Text(formatQuantity(line.quantity)),
                IconButton(
                  onPressed: () =>
                      _change(line.product, 1, state.allowOverselling),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Increase quantity',
                ),
                TextButton(
                  onPressed: () =>
                      _setQuantity(line.product, state.allowOverselling),
                  child: const Text('Qty'),
                ),
                TextButton(
                  onPressed: () => _setUnitPrice(line),
                  child: const Text('Price'),
                ),
              ],
            ),
          ],
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                money(_total),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: methods.any((item) => item.code == _payment)
                ? _payment
                : methods.firstOrNull?.code,
            decoration: const InputDecoration(
              labelText: 'Payment method',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
            items: [
              for (final method in methods)
                DropdownMenuItem(value: method.code, child: Text(method.label)),
            ],
            onChanged: (value) => setState(() {
              _payment = value ?? _payment;
              _pendingId = null;
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy || _cart.isEmpty || methods.isEmpty
                ? null
                : () => _checkout(
                    state,
                    methods.any((item) => item.code == _payment)
                        ? _payment
                        : methods.first.code,
                  ),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(_busy ? 'Submitting…' : 'Complete sale'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Online checkout only. No sale is recorded until the server confirms it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _panel({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE6EEEA)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A173B32),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class VanSalePdfDialog extends ConsumerStatefulWidget {
  const VanSalePdfDialog({
    super.key,
    required this.transactionId,
    required this.invoiceNo,
  });

  final String transactionId;
  final String invoiceNo;

  @override
  ConsumerState<VanSalePdfDialog> createState() => _VanSalePdfDialogState();
}

class _VanSalePdfDialogState extends ConsumerState<VanSalePdfDialog> {
  bool _loading = false;
  String? _error;

  Future<void> _export({required bool share}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ref.read(authControllerProvider.future);
      if (token == null || token == 'offline-local-session') {
        throw const ApiException('Reconnect to download the invoice PDF.');
      }
      final file = await ref
          .read(apiProvider)
          .finalizedSaleInvoicePdf(token, widget.transactionId);
      final name = widget.invoiceNo.trim().isEmpty
          ? widget.transactionId
          : widget.invoiceNo.trim();
      final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
      final filename = 'invoice-$safeName.pdf';
      if (share) {
        await Printing.sharePdf(bytes: file.bytes, filename: filename);
      } else {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save invoice PDF',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
          bytes: file.bytes,
        );
        if (path == null) return;
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Unable to prepare the invoice PDF. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Van sale completed'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.invoiceNo.trim().isEmpty
              ? 'The sale was confirmed by the server.'
              : 'Invoice ${widget.invoiceNo} is ready.',
        ),
        if (_loading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context),
        child: const Text('Done'),
      ),
      TextButton.icon(
        onPressed: _loading ? null : () => _export(share: false),
        icon: const Icon(Icons.download_outlined),
        label: const Text('Download PDF'),
      ),
      FilledButton.icon(
        onPressed: _loading ? null : () => _export(share: true),
        icon: const Icon(Icons.share_outlined),
        label: const Text('Share PDF'),
      ),
    ],
  );
}
