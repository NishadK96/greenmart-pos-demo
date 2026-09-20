import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/product_card_style_picker.dart';
import '../../../shared/widgets/modifier_selection_dialog.dart';
import '../../../shared/widgets/ui.dart' show ProductImage;
import '../../store/app_store.dart';
import 'kitchen_printing_controller.dart';

/// A restaurant-focused order entry surface. Its draft is deliberately separate
/// from the retail POS cart so switching modes cannot change an open sale.
class KitchenPosScreen extends ConsumerStatefulWidget {
  const KitchenPosScreen({super.key});

  @override
  ConsumerState<KitchenPosScreen> createState() => _KitchenPosScreenState();
}

class _KitchenPosScreenState extends ConsumerState<KitchenPosScreen> {
  static const _border = Color(0xFFDCE5E2);
  final _search = TextEditingController();
  final _table = TextEditingController();
  final _focus = FocusNode();
  final Map<String, CartLine> _lines = {};
  List<CartLine>? _held;
  String _category = '';
  String _service = 'Dine in';
  String _note = '';
  int _addQuantity = 1;
  bool _showMobileOrder = false;
  bool _sending = false;
  String? _pendingClientTransactionId;
  String? _savedTransactionId;

  bool get _orderLocked => _pendingClientTransactionId != null;

  @override
  void dispose() {
    _search.dispose();
    _table.dispose();
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

  void _hold() {
    if (_lines.isEmpty || _orderLocked) return;
    setState(() {
      _held = List<CartLine>.unmodifiable(_lines.values);
      _lines.clear();
    });
    _show('Order held on this screen. Use Restore held order to continue.');
  }

  void _restore() {
    final held = _held;
    if (held == null) return;
    setState(() {
      for (final line in held) {
        final old = _lines[line.lineId];
        _lines[line.lineId] = old == null
            ? line
            : old.copyWith(quantity: old.quantity + line.quantity);
      }
      _held = null;
    });
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _sendToKitchen() => unawaited(_submitKitchenOrder());

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
        final note = [
          _service,
          if (_service == 'Dine in' && _table.text.trim().isNotEmpty)
            'Table ${_table.text.trim()}',
          if (_note.trim().isNotEmpty) _note.trim(),
        ].join(' · ');
        transactionId = await ref
            .read(kitchenPrintingControllerProvider.notifier)
            .createKitchenOrder(
              locationId: locationId!,
              customer: customer!,
              lines: _lines.values.toList(growable: false),
              clientTransactionId: _pendingClientTransactionId!,
              saleNote: note,
            );
        if (!mounted) return;
        setState(() => _savedTransactionId = transactionId);
      }
      final summary = await ref
          .read(kitchenPrintingControllerProvider.notifier)
          .processTransaction(transactionId, locationId: locationId);
      if (!mounted) return;
      setState(() {
        _lines.clear();
        _note = '';
        _table.clear();
        _pendingClientTransactionId = null;
        _savedTransactionId = null;
        _showMobileOrder = false;
      });
      _show(
        'Kitchen order #$transactionId saved and ${summary.printedCount} '
        'ticket(s) sent to the paired printer(s).',
      );
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
    final total = _lines.values.fold<int>(
      0,
      (sum, line) => sum + line.subtotal,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f6): _hold,
        const SingleActivator(LogicalKeyboardKey.f8): () =>
            _show('Print Bill is available after a kitchen order is saved.'),
        const SingleActivator(LogicalKeyboardKey.f9): _sendToKitchen,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            _header(desktop),
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
                          child: _order(total, desktop: true),
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
                                child: _order(total, desktop: false),
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

  Widget _header(bool desktop) {
    final title = const Row(
      children: [
        Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 25),
        SizedBox(width: 8),
        Expanded(
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
      ],
    );
    final controls = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _serviceButton('Dine in', Icons.restaurant_outlined),
          _serviceButton('Takeaway', Icons.shopping_bag_outlined),
          _serviceButton('Delivery', Icons.local_shipping_outlined),
          if (_service == 'Dine in') _tableCard(),
          if (desktop) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/pos'),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Normal POS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 9),
              ),
            ),
          ],
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
                Row(
                  children: [
                    Expanded(child: title),
                    IconButton(
                      tooltip: 'Switch to Normal POS',
                      onPressed: () => context.go('/pos'),
                      icon: const Icon(Icons.swap_horiz),
                      color: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: _mobileServiceButton('Dine in')),
                    const SizedBox(width: 5),
                    Expanded(child: _mobileServiceButton('Takeaway')),
                    const SizedBox(width: 5),
                    Expanded(child: _mobileServiceButton('Delivery')),
                  ],
                ),
                if (_service == 'Dine in') ...[
                  const SizedBox(height: 6),
                  _tableCard(mobile: true),
                ],
              ],
            ),
    );
  }

  Widget _serviceButton(String label, IconData icon) {
    final selected = _service == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        onPressed: _orderLocked ? null : () => setState(() => _service = label),
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

  Widget _mobileServiceButton(String label) {
    final selected = _service == label;
    return OutlinedButton(
      onPressed: _orderLocked ? null : () => setState(() => _service = label),
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

  Widget _tableCard({bool mobile = false}) => Container(
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
        const Text(
          'Table #',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: _table,
            readOnly: _orderLocked,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
            decoration: const InputDecoration(
              hintText: '—',
              isDense: true,
              filled: false,
              contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
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
      color: AppColors.canvas,
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
          width: mobile ? 100 : 180,
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
                    for (final category in categories)
                      _categoryChip(
                        category.id,
                        arabic && category.nameAr.trim().isNotEmpty
                            ? category.nameAr
                            : category.nameEn.trim().isNotEmpty
                            ? category.nameEn
                            : category.name,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _productGrid(products)),
      ],
    );
  }

  Widget _categoryChip(String id, String label) {
    final selected = _category == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: () => setState(() => _category = id),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : Colors.white,
          foregroundColor: selected ? Colors.white : AppColors.ink,
          side: BorderSide(color: selected ? AppColors.primary : _border),
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

  Widget _productGrid(List<Product> products) {
    if (products.isEmpty) {
      return const Center(child: Text('No items match this filter.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 440
            ? 3
            : constraints.maxWidth >= 260
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
            return Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
                side: const BorderSide(color: _border),
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

  Widget _order(int total, {required bool desktop}) => Container(
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
                  : () => setState(_lines.clear),
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
                onPressed: _lines.isEmpty || _orderLocked ? null : _hold,
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
                onPressed: () => _show(
                  'Print Bill is available after a kitchen order is saved.',
                ),
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
        if (_held != null)
          TextButton.icon(
            onPressed: _restore,
            icon: const Icon(Icons.restore),
            label: const Text('Restore held order'),
          ),
      ],
    ),
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
