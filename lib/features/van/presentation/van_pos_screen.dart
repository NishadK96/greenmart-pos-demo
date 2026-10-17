import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
import '../../auth/auth_controller.dart';
import '../../backend/data/eazyerp_backend_repository.dart';
import '../../backend/presentation/backend_controller.dart';
import '../../cash_register/presentation/cash_register_controller.dart';
import '../../pos/pos_screen.dart' show showPosCustomerSelector;
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
    selectedCustomer: state.customers
        .where((customer) => customer.id == _customerId)
        .firstOrNull ?? state.customers.firstOrNull,
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
        _cart[product.id] = CartLine(product: product, quantity: next);
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
      _cart[product.id] = CartLine(product: product, quantity: value);
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
      await ref
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
      setState(() {
        _cart.clear();
        _pendingId = null;
        _pendingFingerprint = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Van sale completed.')));
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
      location?.name ?? 'Van location',
    );
    final bill = _bill(state, methods);
    return ColoredBox(
      color: const Color(0xFFF5F8F6),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'New van sale',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  location?.name ?? 'Van location',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: compact
                  ? ListView(
                      children: [catalog, const SizedBox(height: 14), bill],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(child: catalog),
                        ),
                        const SizedBox(width: 14),
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

  Widget _catalog(
    List<Product> products,
    bool allowOverselling,
    String location,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Products · $location',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Stock shown is the catalog balance; the server validates availability at checkout.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name, SKU or barcode',
            ),
          ),
          const SizedBox(height: 8),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No matching products.')),
            ),
          for (final product in products) ...[
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${product.sku} · catalog stock ${formatQuantity(product.stock)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(product.sellingPrice),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Add ${product.name}',
                    onPressed: () => _change(product, 1, allowOverselling),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _bill(AppState state, List<PaymentOption> methods) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Current order',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
          ),
          const SizedBox(height: 12),
          if (_cart.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Add products to start an order.')),
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
                  child: const Text('Edit'),
                ),
              ],
            ),
          ],
          const Divider(),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: methods.any((item) => item.code == _payment)
                ? _payment
                : methods.firstOrNull?.code,
            decoration: const InputDecoration(labelText: 'Payment method'),
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
          const SizedBox(height: 16),
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
}
