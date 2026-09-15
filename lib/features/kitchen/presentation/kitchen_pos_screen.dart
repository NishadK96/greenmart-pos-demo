import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
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

  void _add(Product product) {
    setState(() {
      final old = _lines[product.id];
      _lines[product.id] = CartLine(
        product: product,
        quantity: (old?.quantity ?? 0) + _addQuantity,
      );
      _search.clear();
    });
    _focus.requestFocus();
  }

  void _changeQuantity(CartLine line, int delta) {
    setState(() {
      final next = line.quantity + delta;
      if (next <= 0) {
        _lines.remove(line.product.id);
      } else {
        _lines[line.product.id] = line.copyWith(quantity: next);
      }
    });
  }

  void _hold() {
    if (_lines.isEmpty) return;
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
        final old = _lines[line.product.id];
        _lines[line.product.id] = old == null
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

  void _sendToKitchen() {
    if (_lines.isEmpty) {
      _show('Add an item before sending an order.');
      return;
    }
    final kitchen = ref.read(kitchenPrintingControllerProvider).asData?.value;
    if (kitchen?.hasActiveRoutes != true) {
      _show('Set up a kitchen printer route in Printer settings first.');
      return;
    }
    // The Connector print-job API accepts only a finalized sell transaction
    // with is_kitchen_order=1. Its current sale endpoint discards that field.
    // Never turn this kitchen draft into a charged retail sale or report success.
    _show(
      'Kitchen order submission needs the backend Connector sale API to save '
      'is_kitchen_order=1. This draft has not been sent or printed.',
    );
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
        onPressed: () => setState(() => _service = label),
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : Colors.white,
          foregroundColor: selected ? Colors.white : AppColors.ink,
          side: BorderSide(color: selected ? Colors.white : _border),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  Widget _mobileServiceButton(String label) {
    final selected = _service == label;
    return OutlinedButton(
      onPressed: () => setState(() => _service = label),
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
    width: mobile ? double.infinity : 140,
    height: mobile ? 40 : 48,
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
          child: TextField(
            controller: _table,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 14, color: AppColors.ink),
            decoration: const InputDecoration(
              hintText: 'Table #',
              isCollapsed: true,
              filled: false,
              contentPadding: EdgeInsets.zero,
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
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
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
              ),
              if (MediaQuery.sizeOf(context).width < 600)
                PopupMenuButton<String>(
                  key: const ValueKey('kitchen-category-menu'),
                  tooltip: 'Choose category',
                  onSelected: (id) => setState(() => _category = id),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: '', child: Text('All')),
                    for (final category in categories)
                      PopupMenuItem(
                        value: category.id,
                        child: Text(
                          arabic && category.nameAr.trim().isNotEmpty
                              ? category.nameAr
                              : category.nameEn.trim().isNotEmpty
                              ? category.nameEn
                              : category.name,
                        ),
                      ),
                  ],
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
            ],
          ),
          const SizedBox(height: 8),
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
                  onPressed: _editAddQuantity,
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
            Expanded(child: _productGrid(products))
          else
            SizedBox(height: 420, child: _productGrid(products)),
        ],
      ),
    );
  }

  Widget _categoryChip(String id, String label) {
    final selected = _category == id;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: OutlinedButton(
        onPressed: () => setState(() => _category = id),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : Colors.white,
          foregroundColor: selected ? Colors.white : AppColors.ink,
          side: BorderSide(color: selected ? AppColors.primary : _border),
          minimumSize: const Size(62, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
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
            : 2;
        return GridView.builder(
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: constraints.maxWidth < 440 ? 92 : 104,
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
                onTap: () => _add(product),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
              onPressed: _lines.isEmpty ? null : () => setState(_lines.clear),
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
          onPressed: _editNote,
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
        const Text(
          'Order entry preview — sending and printing require the backend '
          'kitchen-order flag to be saved.',
          style: TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('send-to-kitchen'),
          onPressed: _sendToKitchen,
          icon: const Icon(Icons.soup_kitchen_rounded),
          label: const Text('Send to Kitchen (F9)'),
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
                onPressed: _lines.isEmpty ? null : _hold,
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
                onPressed: () => setState(() => _lines.remove(line.product.id)),
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
