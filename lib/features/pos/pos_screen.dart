import 'package:flutter/material.dart' hide Text;
import 'package:retailflow_pos/shared/widgets/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../apis/api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/ui.dart';
import '../backend/presentation/backend_controller.dart';
import '../home/module_screens.dart' show showSaleReturnDialog;
import '../invoice_layouts/presentation/invoice_layout_controller.dart';
import '../printers/application/printer_controller.dart';
import '../store/app_store.dart';

final _posPaymentShortcutProvider =
    NotifierProvider.autoDispose<_PaymentShortcutNotifier, String?>(
      _PaymentShortcutNotifier.new,
    );

final _posCartKeyboardProvider =
    NotifierProvider.autoDispose<_CartKeyboardNotifier, _CartKeyboardState>(
      _CartKeyboardNotifier.new,
    );

final _posCartKeyDispatcherProvider =
    NotifierProvider<_CartKeyDispatcher, void>(_CartKeyDispatcher.new);

class _CartKeyDispatcher extends Notifier<void> {
  KeyEventResult Function(KeyEvent event)? _handler;

  @override
  void build() {}

  void register(KeyEventResult Function(KeyEvent event) handler) {
    _handler = handler;
  }

  KeyEventResult dispatch(KeyEvent event) =>
      _handler?.call(event) ?? KeyEventResult.ignored;
}

class _CartKeyboardState {
  const _CartKeyboardState({
    this.selectedProductId,
    this.quantityBuffer = '',
    this.paySelected = false,
  });

  final String? selectedProductId;
  final String quantityBuffer;
  final bool paySelected;

  _CartKeyboardState copyWith({
    String? selectedProductId,
    String? quantityBuffer,
    bool? paySelected,
    bool clearSelection = false,
  }) => _CartKeyboardState(
    selectedProductId: clearSelection
        ? null
        : selectedProductId ?? this.selectedProductId,
    quantityBuffer: quantityBuffer ?? this.quantityBuffer,
    paySelected: paySelected ?? this.paySelected,
  );
}

class _CartKeyboardNotifier extends Notifier<_CartKeyboardState> {
  @override
  _CartKeyboardState build() => const _CartKeyboardState();

  void select(String? productId) => state = productId == null
      ? const _CartKeyboardState()
      : _CartKeyboardState(selectedProductId: productId);

  void selectPay() =>
      state = state.copyWith(quantityBuffer: '', paySelected: true);

  void appendQuantityDigit(String digit) {
    final current = state.quantityBuffer;
    if (current.length >= 4 || (current.isEmpty && digit == '0')) return;
    state = state.copyWith(quantityBuffer: '$current$digit');
  }

  void removeQuantityDigit() {
    final current = state.quantityBuffer;
    if (current.isEmpty) return;
    state = state.copyWith(
      quantityBuffer: current.substring(0, current.length - 1),
    );
  }

  void clearQuantity() => state = state.copyWith(quantityBuffer: '');
}

class _PaymentShortcutNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void trigger(String code) => state = code;

  void clear() => state = null;
}

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _posFocus = FocusNode(debugLabel: 'POS keyboard controller');
  final Set<String> _favorites = {};
  final List<String> _recent = [];
  String _category = 'all', _query = '', _mode = 'all';
  bool _grid = true;
  bool _quickActionOpen = false;
  bool _cartKeyboardActive = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyCartKey);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyCartKey);
    _searchController.dispose();
    _searchFocus.dispose();
    _posFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStoreProvider);
    final products = _visibleProducts(state);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): _focusProductSearch,
        const SingleActivator(LogicalKeyboardKey.digit2, control: true):
            _focusProductSearch,
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            _openRecentSales(context, state),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            _openRecentSales(context, state),
        const SingleActivator(LogicalKeyboardKey.f4): () =>
            _openCustomerSelector(context, state),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
            _openCustomerSelector(context, state),
        const SingleActivator(LogicalKeyboardKey.f6): _editLatestCartPrice,
        const SingleActivator(LogicalKeyboardKey.digit6, control: true):
            _editLatestCartPrice,
        const SingleActivator(LogicalKeyboardKey.f8): _editGrossDiscount,
        const SingleActivator(LogicalKeyboardKey.digit8, control: true):
            _editGrossDiscount,
        const SingleActivator(LogicalKeyboardKey.f9): _triggerPaymentShortcut,
        const SingleActivator(LogicalKeyboardKey.f10): () =>
            _triggerPaymentShortcut('cash'),
        const SingleActivator(LogicalKeyboardKey.f11): () =>
            _triggerPaymentShortcut('card'),
        const SingleActivator(LogicalKeyboardKey.f12): () =>
            _triggerPaymentShortcut('credit'),
      },
      child: Focus(
        focusNode: _posFocus,
        autofocus: true,
        onKeyEvent: (_, event) {
          if (_quickActionOpen) {
            return KeyEventResult.ignored;
          }
          if (_searchFocus.hasFocus) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowDown &&
                state.cart.isNotEmpty) {
              _searchFocus.unfocus();
              return ref
                  .read(_posCartKeyDispatcherProvider.notifier)
                  .dispatch(event);
            }
            return KeyEventResult.ignored;
          }
          final focusContext = FocusManager.instance.primaryFocus?.context;
          if (focusContext?.widget is EditableText ||
              focusContext?.findAncestorWidgetOfExactType<EditableText>() !=
                  null) {
            return KeyEventResult.ignored;
          }
          return ref
              .read(_posCartKeyDispatcherProvider.notifier)
              .dispatch(event);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 930;
            if (!desktop) {
              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      10,
                      10,
                      10,
                      state.itemCount > 0 ? 88 : 10,
                    ),
                    child: _catalog(state, products),
                  ),
                  if (state.itemCount > 0)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Material(
                        color: const Color(0xFFF1F8F5),
                        elevation: 8,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFD6E6E0)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openCartSheet(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${state.itemCount} ${state.itemCount == 1 ? 'Item' : 'Items'}',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      state.customer?.name ??
                                          'Walk-in Customer',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    RiyalAmount(
                                      state.cartTotal,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      context.tr('View cart'),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _catalog(state, products)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: constraints.maxWidth >= 1240 ? 430 : 385,
                    child: const _CurrentOrder(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _editLatestCartPrice() {
    final state = ref.read(appStoreProvider);
    if (state.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Add an item before editing its price.')),
        ),
      );
      return;
    }
    final selectedId = ref.read(_posCartKeyboardProvider).selectedProductId;
    final selected = state.cart
        .where((line) => line.product.id == selectedId)
        .firstOrNull;
    _showUnitPriceEditor(context, ref, selected ?? state.cart.last);
  }

  void _triggerPaymentShortcut([String? preferredCode]) {
    final state = ref.read(appStoreProvider);
    final canPay =
        state.cart.isNotEmpty &&
        state.locations.isNotEmpty &&
        state.customers.isNotEmpty &&
        state.posPaymentOptions.isNotEmpty;
    if (!canPay) return;
    if (preferredCode != null &&
        !state.posPaymentOptions.any(
          (option) => option.code.toLowerCase() == preferredCode,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$preferredCode payment is not available.')),
      );
      return;
    }
    ref.read(_posPaymentShortcutProvider.notifier).trigger(preferredCode ?? '');
    if (MediaQuery.sizeOf(context).width < 930) {
      _openCartSheet(context);
    }
  }

  KeyEventResult _handleEarlyCartKey(KeyEvent event) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final editing =
        focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
    final canTakeCartFocus =
        _searchFocus.hasFocus || (_cartKeyboardActive && !editing);
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowDown ||
        !canTakeCartFocus ||
        _quickActionOpen ||
        ref.read(appStoreProvider).cart.isEmpty) {
      return KeyEventResult.ignored;
    }
    _cartKeyboardActive = true;
    _searchFocus.unfocus();
    _posFocus.requestFocus();
    final state = ref.read(appStoreProvider);
    final visualLines = state.cart.reversed.toList(growable: false);
    final keyboardState = ref.read(_posCartKeyboardProvider);
    final keyboard = ref.read(_posCartKeyboardProvider.notifier);
    if (keyboardState.paySelected) return KeyEventResult.handled;
    var selectedIndex = visualLines.indexWhere(
      (line) => line.product.id == keyboardState.selectedProductId,
    );
    if (selectedIndex < 0) selectedIndex = 0;
    if (selectedIndex == visualLines.length - 1) {
      keyboard.selectPay();
    } else {
      keyboard.select(visualLines[selectedIndex + 1].product.id);
    }
    return KeyEventResult.handled;
  }

  void _editGrossDiscount() {
    final state = ref.read(appStoreProvider);
    if (state.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Add an item before adding a discount.')),
        ),
      );
      return;
    }
    _showGrossDiscountEditor(context, ref, state);
  }

  void _focusProductSearch() {
    if (_quickActionOpen || !mounted) return;
    _searchFocus.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  Future<void> _openRecentSales(BuildContext context, AppState state) async {
    if (_quickActionOpen || !mounted) return;
    _quickActionOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _RecentSalesDialog(sales: state.sales),
      );
    } finally {
      _quickActionOpen = false;
    }
  }

  Future<void> _openCustomerSelector(
    BuildContext context,
    AppState state,
  ) async {
    if (_quickActionOpen || !mounted) return;
    _quickActionOpen = true;
    try {
      await _selectCustomer(context, ref, state);
    } finally {
      _quickActionOpen = false;
    }
  }

  List<Product> _visibleProducts(AppState state) {
    var rows = state.products.where((product) {
      final search = _query.toLowerCase();
      return product.active &&
          (_category == 'all' || product.categoryId == _category) &&
          (product.name.toLowerCase().contains(search) ||
              product.nameEn.toLowerCase().contains(search) ||
              product.nameAr.toLowerCase().contains(search) ||
              product.sku.toLowerCase().contains(search) ||
              product.barcode.toLowerCase().contains(search));
    }).toList();
    if (_mode == 'favorites') {
      rows = rows.where((p) => _favorites.contains(p.id)).toList();
    } else if (_mode == 'recent') {
      rows = rows.where((p) => _recent.contains(p.id)).toList()
        ..sort(
          (a, b) => _recent.indexOf(a.id).compareTo(_recent.indexOf(b.id)),
        );
    } else if (_mode == 'top') {
      final soldQuantity = <String, int>{};
      for (final sale in state.sales) {
        for (final line in sale.items) {
          soldQuantity.update(
            line.product.id,
            (quantity) => quantity + line.quantity,
            ifAbsent: () => line.quantity,
          );
        }
      }
      rows.sort(
        (a, b) => (soldQuantity[b.id] ?? 0).compareTo(soldQuantity[a.id] ?? 0),
      );
    }
    return rows;
  }

  Widget _catalog(AppState state, List<Product> products) => Column(
    children: [
      _searchBar(state, products),
      const SizedBox(height: 9),
      _categoryBar(state),
      const SizedBox(height: 9),
      Expanded(
        child: products.isEmpty
            ? const EmptyState('No products match this filter')
            : LayoutBuilder(
                builder: (context, constraints) {
                  if (!_grid) return _productList(products);
                  final columns = constraints.maxWidth >= 1040
                      ? 5
                      : constraints.maxWidth >= 600
                      ? 4
                      : constraints.maxWidth >= 470
                      ? 3
                      : 2;
                  final mobile = constraints.maxWidth < 470;
                  return GridView.builder(
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: mobile ? 222 : 188,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, index) => _productCard(products[index]),
                  );
                },
              ),
      ),
      if (MediaQuery.sizeOf(context).width >= 700) ...[
        const SizedBox(height: 8),
        _catalogFooter(products.length),
        const SizedBox(height: 7),
        _quickActions(),
      ],
    ],
  );

  Widget _searchBar(AppState state, List<Product> products) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: (value) => setState(() => _query = value),
          onSubmitted: (_) {
            if (products.length == 1 && _canSell(products.first)) {
              _addProduct(products.first);
              _searchController.clear();
              setState(() => _query = '');
            }
          },
          decoration: InputDecoration(
            hintText: context.tr(
              'Scan barcode or search product (Name, SKU, Barcode)',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: MediaQuery.sizeOf(context).width < 700
                ? null
                : const Padding(
                    padding: EdgeInsets.all(13),
                    child: Text(
                      'F2 / ⌃2',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('Scanner input is ready through the search field.'),
              ),
            ),
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
          label: MediaQuery.sizeOf(context).width < 700
              ? const SizedBox.shrink()
              : Text(context.tr('Scan')),
          style: MediaQuery.sizeOf(context).width < 700
              ? FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                )
              : null,
        ),
      ),
      if (MediaQuery.sizeOf(context).width >= 700) ...[
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _openCustomerSelector(context, state),
            icon: const Icon(Icons.person_outline_rounded, size: 19),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(state.customer?.name ?? 'Customer')),
                const SizedBox(width: 10),
                const Text(
                  'F4 / ⌃4',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  Widget _categoryBar(AppState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final cardWidth = compact ? 74.0 : 88.0;
        final filters = <Widget>[
          _categoryCard(
            label: context.tr('All'),
            icon: Icons.grid_view_rounded,
            selected: _mode == 'all' && _category == 'all',
            width: cardWidth,
            onTap: () => setState(() {
              _mode = 'all';
              _category = 'all';
            }),
          ),
          for (final category in state.categories)
            _categoryCard(
              label: context.tr(category.name),
              icon: _categoryIcon(category.name),
              selected: _mode == 'all' && _category == category.id,
              width: cardWidth,
              onTap: () => setState(() {
                _mode = 'all';
                _category = category.id;
              }),
            ),
          _categoryCard(
            label: context.tr('Favorites'),
            icon: Icons.star_border_rounded,
            selected: _mode == 'favorites',
            width: cardWidth,
            accentIcon: true,
            onTap: () => setState(() => _mode = 'favorites'),
          ),
          _categoryCard(
            label: context.tr('Recent'),
            icon: Icons.history_rounded,
            selected: _mode == 'recent',
            width: cardWidth,
            onTap: () => setState(() => _mode = 'recent'),
          ),
        ];
        return SizedBox(
          height: compact ? 76 : 84,
          child: ListView.separated(
            key: const ValueKey('pos-category-switcher'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
            physics: const BouncingScrollPhysics(),
            itemCount: filters.length,
            separatorBuilder: (_, __) => SizedBox(width: compact ? 6 : 8),
            itemBuilder: (_, index) => filters[index],
          ),
        );
      },
    );
  }

  Widget _categoryCard({
    required String label,
    required IconData icon,
    required bool selected,
    required double width,
    required VoidCallback onTap,
    bool accentIcon = false,
  }) => Semantics(
    button: true,
    selected: selected,
    label: '$label category',
    child: Material(
      color: selected ? const Color(0xFFEAF6F2) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : const Color(0xFFE1E7E4),
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 9, 7, 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: accentIcon && !selected
                      ? AppColors.accent
                      : selected
                      ? AppColors.primary
                      : const Color(0xFF53615C),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFF303B37),
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  IconData _categoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('grocer') || name.contains('food')) {
      return Icons.local_grocery_store_outlined;
    }
    if (name.contains('beverage') ||
        name.contains('drink') ||
        name.contains('juice')) {
      return Icons.local_drink_outlined;
    }
    if (name.contains('snack')) return Icons.cookie_outlined;
    if (name.contains('dairy') || name.contains('milk')) {
      return Icons.breakfast_dining_outlined;
    }
    if (name.contains('bakery') || name.contains('bread')) {
      return Icons.bakery_dining_outlined;
    }
    if (name.contains('house') || name.contains('clean')) {
      return Icons.cleaning_services_outlined;
    }
    if (name.contains('fruit') || name.contains('vegetable')) {
      return Icons.eco_outlined;
    }
    if (name.contains('meat')) return Icons.kebab_dining_outlined;
    if (name.contains('electronic')) return Icons.devices_other_outlined;
    return Icons.category_outlined;
  }

  Widget _productCard(Product product) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: _canSell(product) ? () => _addProduct(product) : null,
    child: Surface(
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ProductImage(
                    product.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Favorite'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 27,
                    height: 27,
                  ),
                  onPressed: () => setState(() {
                    _favorites.contains(product.id)
                        ? _favorites.remove(product.id)
                        : _favorites.add(product.id);
                  }),
                  icon: Icon(
                    _favorites.contains(product.id)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 18,
                    color: _favorites.contains(product.id)
                        ? AppColors.accent
                        : AppColors.muted,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: context.tr('Product actions'),
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'add') _addProduct(product);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'add',
                      child: Text(context.tr('Add to order')),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert_rounded, size: 17),
                ),
              ],
            ),
          ),
          Text(
            product.displayName(context.isArabic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          RiyalAmount(
            product.sellingPrice,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'SKU: ${product.sku}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: product.stock <= product.minimumStock
                      ? AppColors.danger
                      : const Color(0xFF38A96A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  product.stock == 0
                      ? context.tr('Out of stock')
                      : '${product.stock} ${context.tr('in stock')}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: product.stock <= product.minimumStock
                        ? AppColors.danger
                        : AppColors.muted,
                  ),
                ),
              ),
              SizedBox.square(
                dimension: 29,
                child: IconButton.filled(
                  padding: EdgeInsets.zero,
                  onPressed: _canSell(product)
                      ? () => _addProduct(product)
                      : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _productList(List<Product> products) => ListView.separated(
    itemCount: products.length,
    separatorBuilder: (_, __) => const SizedBox(height: 6),
    itemBuilder: (_, index) {
      final product = products[index];
      return Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFE2E8E5)),
        ),
        child: ListTile(
          dense: true,
          onTap: _canSell(product) ? () => _addProduct(product) : null,
          leading: ProductImage(product.imageUrl, width: 44, height: 44),
          title: Text(
            product.displayName(context.isArabic),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${product.sku} • ${product.stock} ${context.tr('in stock')}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RiyalAmount(
                product.sellingPrice,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 30,
                child: IconButton(
                  tooltip: context.tr('Add to order'),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8E5),
                    disabledForegroundColor: AppColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _canSell(product)
                      ? () => _addProduct(product)
                      : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _catalogFooter(int count) => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: const Color(0xFFE2E8E5)),
    ),
    child: Row(
      children: [
        FilledButton.tonalIcon(
          onPressed: () => setState(() => _grid = true),
          icon: const Icon(Icons.grid_view_rounded, size: 17),
          label: Text(context.tr('Grid')),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: () => setState(() => _grid = false),
          icon: const Icon(Icons.view_list_rounded, size: 18),
          label: Text(context.tr('List')),
        ),
        const Spacer(),
        Text(
          '$count products',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() => _mode = 'top'),
          icon: const Icon(Icons.trending_up_rounded, size: 17),
          label: Text(context.tr('Top selling')),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
        ),
      ],
    ),
  );

  Widget _quickActions() => SizedBox(
    height: 39,
    child: Row(
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _quickButton(
                Icons.history_rounded,
                'Recent Sales',
                () => _openRecentSales(context, ref.read(appStoreProvider)),
                shortcut: 'F3 / ⌃3',
              ),
              _quickButton(
                Icons.assignment_return_outlined,
                'Return',
                () => context.go('/sales'),
              ),
              _quickButton(
                Icons.search_rounded,
                'Price Check',
                _focusProductSearch,
              ),
              _quickButton(
                Icons.receipt_long_outlined,
                'Reprint Bill',
                () => context.go('/sales'),
              ),
              _quickButton(
                Icons.point_of_sale_outlined,
                'Open Drawer',
                () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('Cash drawer command is ready.')),
                  ),
                ),
              ),
              _quickButton(
                Icons.more_horiz_rounded,
                'More',
                () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('More cashier actions'))),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _quickButton(
    IconData icon,
    String label,
    VoidCallback action, {
    String? shortcut,
  }) => Padding(
    padding: const EdgeInsets.only(right: 5),
    child: OutlinedButton.icon(
      onPressed: action,
      icon: Icon(icon, size: 15),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10)),
          if (shortcut != null) ...[
            const SizedBox(width: 7),
            Text(
              shortcut,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    ),
  );

  void _addProduct(Product product) {
    ref.read(appStoreProvider.notifier).addToCart(product);
    ref.read(_posCartKeyboardProvider.notifier).select(product.id);
    setState(() {
      _recent.remove(product.id);
      _recent.insert(0, product.id);
      if (_recent.length > 12) _recent.removeLast();
    });
  }

  bool _canSell(Product product) =>
      product.stock > 0 || ref.read(appStoreProvider).allowOverselling;

  void _openCartSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        const FractionallySizedBox(heightFactor: .96, child: _CurrentOrder()),
  );
}

class _RecentSalesDialog extends ConsumerStatefulWidget {
  const _RecentSalesDialog({required this.sales});

  final List<Sale> sales;

  @override
  ConsumerState<_RecentSalesDialog> createState() => _RecentSalesDialogState();
}

class _RecentSalesDialogState extends ConsumerState<_RecentSalesDialog> {
  bool _printing = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final sales =
        widget.sales
            .where((sale) {
              if (query.isEmpty) return true;
              return sale.invoiceNo.toLowerCase().contains(query) ||
                  sale.customer.name.toLowerCase().contains(query) ||
                  sale.customer.phone.toLowerCase().contains(query) ||
                  sale.paymentMethod.toLowerCase().contains(query);
            })
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 700;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: .18),
      insetPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 0 : 36,
        vertical: mobile ? 0 : (size.height < 700 ? 12 : 28),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mobile ? 0 : 18),
        side: const BorderSide(color: Color(0xFFDDE5E2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mobile ? size.width : 1040,
          maxHeight: mobile ? size.height : 660,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
                  child: Row(
                    children: [
                      if (mobile)
                        IconButton(
                          tooltip: context.tr('Back'),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      if (!mobile)
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5F1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: AppColors.primary,
                            size: 21,
                          ),
                        ),
                      if (!mobile) const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('Recent Sales'),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (!mobile) ...[
                              const SizedBox(height: 2),
                              Text(
                                context.tr(
                                  'Review completed transactions without leaving the POS.',
                                ),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!mobile) ...[
                        _countPill(widget.sales.length),
                        const SizedBox(width: 8),
                        const StatusBadge('F3'),
                        const SizedBox(width: 4),
                      ],
                      if (!mobile)
                        IconButton(
                          tooltip: context.tr('Close'),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: SizedBox(
                    height: 46,
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: context.tr(
                          'Search invoice, customer, phone or payment method',
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 21),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: context.tr('Clear search'),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded, size: 19),
                              ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                if (wide) _tableHeader(),
                Expanded(
                  child: sales.isEmpty
                      ? EmptyState(
                          context.tr(
                            widget.sales.isEmpty
                                ? 'No completed sales are available yet'
                                : 'No sales match this search',
                          ),
                        )
                      : Scrollbar(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: sales.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 20,
                              endIndent: 20,
                            ),
                            itemBuilder: (_, index) =>
                                _saleRow(sales[index], wide),
                          ),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFBFB),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8E5))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        context.isArabic
                            ? query.isEmpty
                                  ? '${widget.sales.length} عملية بيع مكتملة'
                                  : 'عرض ${sales.length} من ${widget.sales.length} مبيعات'
                            : query.isEmpty
                            ? '${widget.sales.length} completed ${widget.sales.length == 1 ? 'sale' : 'sales'}'
                            : 'Showing ${sales.length} of ${widget.sales.length} sales',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.tr('Close')),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _countPill(int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F3),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      context.isArabic ? '$count مبيعات' : '$count sales',
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _tableHeader() => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    color: const Color(0xFFF6F8F7),
    child: Row(
      children: [
        const Expanded(flex: 2, child: _TableLabel('Invoice')),
        const Expanded(flex: 3, child: _TableLabel('Customer')),
        const Expanded(flex: 2, child: _TableLabel('Date & time')),
        const SizedBox(width: 108, child: _TableLabel('Payment')),
        const SizedBox(
          width: 105,
          child: _TableLabel('Total', textAlign: TextAlign.end),
        ),
        const SizedBox(
          width: 118,
          child: _TableLabel('Actions', textAlign: TextAlign.end),
        ),
      ],
    ),
  );

  Widget _saleRow(Sale sale, bool wide) {
    final invoice = sale.invoiceNo.isEmpty
        ? 'Sale ${sale.serverId ?? ''}'
        : sale.invoiceNo;
    final due = sale.paymentMethod.trim().toLowerCase() == 'due';
    if (!wide) {
      return InkWell(
        onTap: () => _showSaleDetails(sale),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 11, 12, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _paymentPill(sale.paymentMethod, due),
                  const SizedBox(width: 10),
                  Text(
                    money(sale.total),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    tooltip: context.tr('Print'),
                    onPressed: () => _printSale(sale),
                    icon: const Icon(Icons.print_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip: context.tr('View sale'),
                    onPressed: () => _showSaleDetails(sale),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              Text(
                sale.customer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt),
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showSaleDetails(sale),
      child: SizedBox(
        height: 62,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  invoice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (sale.customer.phone.trim().isNotEmpty)
                      Text(
                        sale.customer.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  DateFormat('dd MMM yyyy\nhh:mm a').format(sale.createdAt),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
              SizedBox(
                width: 108,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _paymentPill(sale.paymentMethod, due),
                ),
              ),
              SizedBox(
                width: 105,
                child: Text(
                  money(sale.total),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(
                width: 118,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: context.tr('Print'),
                      onPressed: () => _printSale(sale),
                      icon: const Icon(Icons.print_outlined, size: 19),
                    ),
                    IconButton(
                      tooltip: context.tr('View sale'),
                      onPressed: () => _showSaleDetails(sale),
                      icon: const Icon(Icons.visibility_outlined, size: 19),
                    ),
                    _saleMenu(sale),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentPill(String method, bool due) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: due ? const Color(0xFFFFF3DD) : const Color(0xFFE9F6EF),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      method.trim().isEmpty
          ? context.tr('Unknown')
          : context.tr(_titleCase(method)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: due ? const Color(0xFF9A5B00) : const Color(0xFF167A4C),
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  String _titleCase(String value) {
    final text = value.trim();
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

  Widget _saleMenu(Sale sale) => SizedBox(
    width: 34,
    child: PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: context.tr('Sale actions'),
      onSelected: (value) async {
        if (value == 'view') {
          await _showSaleDetails(sale);
        } else if (value == 'print') {
          await _printSale(sale);
        } else if (value == 'return') {
          await _returnSale(sale);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'view',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.visibility_outlined),
            title: Text(context.tr('View sale')),
          ),
        ),
        PopupMenuItem(
          value: 'print',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined),
            title: Text(context.tr('Print')),
          ),
        ),
        PopupMenuItem(
          value: 'return',
          enabled: sale.serverId != null,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.assignment_return_outlined),
            title: Text(
              sale.serverId == null
                  ? context.tr('Return (available after sync)')
                  : context.tr('Return'),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _showSaleDetails(Sale sale) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(sale.invoiceNo),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${sale.customer.name} • ${DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt)}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const Divider(height: 24),
              for (final line in sale.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line.quantity} × ${line.product.displayName(context.isArabic)}',
                        ),
                      ),
                      RiyalAmount(line.total),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  Text(
                    context.tr('Total'),
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  RiyalAmount(
                    sale.total,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () => _printSale(sale),
          icon: const Icon(Icons.print_outlined),
          label: Text(context.tr('Print')),
        ),
        OutlinedButton.icon(
          onPressed: sale.serverId == null
              ? null
              : () async {
                  Navigator.pop(dialogContext);
                  await _returnSale(sale);
                },
          icon: const Icon(Icons.assignment_return_outlined),
          label: Text(context.tr('Return')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.tr('Close')),
        ),
      ],
    ),
  );

  Future<void> _printSale(Sale sale) async {
    if (_printing) return;
    final isArabic = context.isArabic;
    final businessName =
        ref.read(appStoreProvider).business?.displayName(isArabic) ??
        'GreenMart';
    setState(() => _printing = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    context.tr(
                      'Preparing invoice and sending it to the printer…',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    await WidgetsBinding.instance.endOfFrame;
    final printerState = ref.read(printerControllerProvider);
    Object? failure;
    try {
      await ref
          .read(invoiceLayoutControllerProvider.notifier)
          .printSale(
            sale: sale,
            businessName: businessName,
            settings: printerState.settings,
            printer: printerState.selectedPrinter,
            arabic: isArabic,
          );
    } catch (error) {
      failure = error;
    } finally {
      navigator.pop();
      if (mounted) setState(() => _printing = false);
    }
    if (failure != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Print failed')}: $failure')),
      );
    }
  }

  Future<void> _returnSale(Sale sale) async {
    final completed = await showSaleReturnDialog(context, sale);
    if (!mounted || completed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('Sale return created successfully.'))),
    );
  }
}

class _TableLabel extends StatelessWidget {
  const _TableLabel(this.text, {this.textAlign = TextAlign.start});

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Text(
    context.tr(text).toUpperCase(),
    textAlign: textAlign,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: .45,
    ),
  );
}

enum _CartLineAction { editPrice, discount, remove }

class _CartLineActionsDialog extends StatefulWidget {
  const _CartLineActionsDialog({required this.line});

  final CartLine line;

  @override
  State<_CartLineActionsDialog> createState() => _CartLineActionsDialogState();
}

class _CartLineActionsDialogState extends State<_CartLineActionsDialog> {
  var _selectedIndex = 0;

  static const _actions = [
    (
      action: _CartLineAction.editPrice,
      icon: Icons.edit_rounded,
      label: 'Edit unit price',
    ),
    (
      action: _CartLineAction.discount,
      icon: Icons.percent_rounded,
      label: 'Line discount',
    ),
    (
      action: _CartLineAction.remove,
      icon: Icons.delete_outline_rounded,
      label: 'Remove item',
    ),
  ];

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final delta = event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
      setState(() {
        _selectedIndex = (_selectedIndex + delta) % _actions.length;
        if (_selectedIndex < 0) _selectedIndex += _actions.length;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      Navigator.pop(context, _actions[_selectedIndex].action);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) => _onKeyEvent(event),
    child: AlertDialog(
      title: Text(widget.line.product.displayName(context.isArabic)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Use ↑ / ↓ to choose an action, then press Enter.'),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < _actions.length; index++) ...[
              Material(
                color: index == _selectedIndex
                    ? const Color(0xFFE4F3ED)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: index == _selectedIndex
                        ? AppColors.primary
                        : const Color(0xFFE1E8E5),
                  ),
                ),
                child: ListTile(
                  selected: index == _selectedIndex,
                  leading: Icon(
                    _actions[index].icon,
                    color: _actions[index].action == _CartLineAction.remove
                        ? AppColors.danger
                        : AppColors.primary,
                  ),
                  title: Text(context.tr(_actions[index].label)),
                  trailing: index == _selectedIndex
                      ? const Icon(Icons.keyboard_return_rounded, size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, _actions[index].action),
                ),
              ),
              if (index != _actions.length - 1) const SizedBox(height: 7),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
      ],
    ),
  );
}

class _KeyboardPaymentGrid extends StatefulWidget {
  const _KeyboardPaymentGrid({
    required this.options,
    required this.paymentTotal,
    required this.iconFor,
    required this.onSubmit,
    required this.onCancel,
  });

  final List<PaymentOption> options;
  final int paymentTotal;
  final IconData Function(String code) iconFor;
  final ValueChanged<PaymentOption> onSubmit;
  final VoidCallback onCancel;

  @override
  State<_KeyboardPaymentGrid> createState() => _KeyboardPaymentGridState();
}

class _KeyboardPaymentGridState extends State<_KeyboardPaymentGrid> {
  var _selectedIndex = 0;
  var _armed = false;

  void _move(int delta) {
    if (widget.options.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(
        0,
        widget.options.length - 1,
      );
      _armed = false;
    });
  }

  KeyEventResult _onKeyEvent(KeyEvent event, int columns) {
    if (event is! KeyDownEvent || widget.options.isEmpty) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-columns);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(columns);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_armed) {
        widget.onSubmit(widget.options[_selectedIndex]);
      } else {
        setState(() => _armed = true);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (widget.options.isEmpty) {
        return Center(child: Text(context.tr('No payment methods available.')));
      }
      final columns = constraints.maxWidth >= 480 ? 2 : 1;
      final selected = widget.options[_selectedIndex];
      return Focus(
        autofocus: true,
        onKeyEvent: (_, event) => _onKeyEvent(event, columns),
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 92,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: widget.options.length,
                itemBuilder: (_, index) {
                  final option = widget.options[index];
                  final isSelected = index == _selectedIndex;
                  final isArmed = isSelected && _armed;
                  return Semantics(
                    selected: isSelected,
                    button: true,
                    label:
                        '${context.tr(option.label)} payment${isArmed ? ', ready to confirm' : ''}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: .14,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: FilledButton.tonalIcon(
                        onPressed: () => widget.onSubmit(option),
                        style: FilledButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          backgroundColor: isArmed
                              ? AppColors.primary
                              : isSelected
                              ? const Color(0xFFDDF1E9)
                              : null,
                          foregroundColor: isArmed ? Colors.white : null,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFFD8E2DE),
                            width: isSelected ? 2 : 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(widget.iconFor(option.code)),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(option.label),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (option.code == 'credit')
                              Text(
                                context.tr('Pay later • Customer required'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (isArmed)
                              Text(
                                context.tr('Press Enter again to confirm'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7F5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _armed
                      ? '${context.tr(selected.label)} selected for ${money(widget.paymentTotal)}. Press Enter again to complete the sale, or use an arrow key to change.'
                      : 'Keyboard: use arrow keys to select a payment method, then press Enter twice to confirm.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _armed ? AppColors.primary : AppColors.muted,
                    fontSize: 11,
                    fontWeight: _armed ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showUnitPriceEditor(
  BuildContext context,
  WidgetRef ref,
  CartLine line,
) async {
  final controller = TextEditingController(
    text: (line.unitPrice / 100).toStringAsFixed(2),
  );
  final formKey = GlobalKey<FormState>();
  final amount = await showDialog<int>(
    context: context,
    builder: (dialogContext) {
      void apply() {
        if (!formKey.currentState!.validate()) return;
        Navigator.pop(
          dialogContext,
          (double.parse(controller.text.trim()) * 100).round(),
        );
      }

      return AlertDialog(
        title: Text(context.tr('Edit unit price')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.tr('Unit price'),
              prefixIcon: Padding(
                padding: EdgeInsets.all(14),
                child: RiyalSymbol(size: 16),
              ),
              prefixIconConstraints: BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
            ),
            validator: (value) {
              final parsed = double.tryParse(value?.trim() ?? '');
              return parsed == null || parsed < 0
                  ? context.tr('Enter a valid amount')
                  : null;
            },
            onFieldSubmitted: (_) => apply(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          if (line.unitPriceOverride != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, -1),
              child: Text(context.tr('Use default price')),
            ),
          FilledButton(onPressed: apply, child: Text(context.tr('Apply'))),
        ],
      );
    },
  );
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  if (amount == null) return;
  ref
      .read(appStoreProvider.notifier)
      .unitPrice(line.product.id, amount < 0 ? null : amount);
}

Future<void> _showGrossDiscountEditor(
  BuildContext context,
  WidgetRef ref,
  AppState state,
) async {
  var discountType = state.grossDiscountType;
  final controller = TextEditingController(
    text: discountType == 'percentage'
        ? (state.grossDiscountRate == 0
              ? ''
              : state.grossDiscountRate.toStringAsFixed(2))
        : (state.cartGrossDiscount == 0
              ? ''
              : (state.cartGrossDiscount / 100).toStringAsFixed(2)),
  );
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<(String, double)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(context.tr('Gross discount')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'fixed',
                    label: Text(context.tr('Amount')),
                    icon: RiyalSymbol(size: 15),
                  ),
                  ButtonSegment(
                    value: 'percentage',
                    label: Text(context.tr('Rate')),
                    icon: Icon(Icons.percent_rounded, size: 16),
                  ),
                ],
                selected: {discountType},
                onSelectionChanged: (selection) {
                  setDialogState(() {
                    discountType = selection.first;
                    controller.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: discountType == 'percentage'
                      ? context.tr('Discount rate')
                      : context.tr('Discount amount'),
                  prefixIcon: discountType == 'percentage'
                      ? const Icon(Icons.percent_rounded, size: 18)
                      : const Padding(
                          padding: EdgeInsets.all(14),
                          child: RiyalSymbol(size: 16),
                        ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  helperText: discountType == 'percentage'
                      ? context.tr('Maximum 100%')
                      : '${context.tr('Maximum')} ${money(state.maximumGrossDiscount)}',
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed < 0) {
                    return context.tr('Enter a valid amount');
                  }
                  if (discountType == 'percentage' && parsed > 100) {
                    return context.tr('Discount rate cannot exceed 100%');
                  }
                  if (discountType == 'fixed' &&
                      (parsed * 100).round() > state.maximumGrossDiscount) {
                    return context.tr('Discount cannot exceed subtotal');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          if (state.cartGrossDiscount > 0)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, const ('fixed', 0)),
              child: Text(context.tr('Remove discount')),
            ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, (
                discountType,
                double.parse(controller.text.trim()),
              ));
            },
            child: Text(context.tr('Apply')),
          ),
        ],
      ),
    ),
  );
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  if (result != null) {
    final store = ref.read(appStoreProvider.notifier);
    if (result.$1 == 'percentage') {
      store.setGrossDiscountPercentage(result.$2);
    } else {
      store.setGrossDiscount((result.$2 * 100).round());
    }
  }
}

class _CurrentOrder extends ConsumerWidget {
  const _CurrentOrder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStoreProvider);
    final paymentShortcut = ref.watch(_posPaymentShortcutProvider);
    final keyboardState = ref.watch(_posCartKeyboardProvider);
    if (paymentShortcut != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted ||
            ref.read(_posPaymentShortcutProvider) != paymentShortcut) {
          return;
        }
        ref.read(_posPaymentShortcutProvider.notifier).clear();
        _payment(
          context,
          ref,
          state,
          preferredCode: paymentShortcut.isEmpty ? null : paymentShortcut,
        );
      });
    }
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final compactHeight = MediaQuery.sizeOf(context).height < 800;
    final lineHeight = compactHeight ? 86.0 : 92.0;
    final separatorHeight = compactHeight ? 5.0 : 6.0;
    final visualLines = state.cart.reversed.toList(growable: false);
    final selectedProductId =
        visualLines.any(
          (line) => line.product.id == keyboardState.selectedProductId,
        )
        ? keyboardState.selectedProductId
        : visualLines.firstOrNull?.product.id;
    if (selectedProductId != keyboardState.selectedProductId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(_posCartKeyboardProvider.notifier).select(selectedProductId);
        }
      });
    }
    ref
        .read(_posCartKeyDispatcherProvider.notifier)
        .register(
          (event) => _handleCartKey(
            context,
            ref,
            state,
            visualLines,
            selectedProductId,
            event,
          ),
        );
    return Focus(
      autofocus: !mobile,
      onKeyEvent: (_, event) => _handleCartKey(
        context,
        ref,
        state,
        visualLines,
        selectedProductId,
        event,
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: mobile
              ? const BorderRadius.vertical(top: Radius.circular(22))
              : BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8E5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            children: [
              if (mobile) ...[
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4DCD9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
              _orderHeader(context, ref, state),
              const Divider(height: 14),
              Expanded(
                child: state.cart.isEmpty
                    ? const EmptyState('Tap a product to start a sale')
                    : Scrollbar(
                        thumbVisibility: state.cart.length > 4,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: state.cart.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: separatorHeight),
                          itemBuilder: (_, index) {
                            final line =
                                state.cart[state.cart.length - 1 - index];
                            final selected =
                                line.product.id == selectedProductId;
                            return KeyedSubtree(
                              key: ValueKey('cart-line-${line.product.id}'),
                              child: Builder(
                                builder: (lineContext) {
                                  if (selected) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (lineContext.mounted) {
                                            Scrollable.ensureVisible(
                                              lineContext,
                                              duration: const Duration(
                                                milliseconds: 140,
                                              ),
                                              alignmentPolicy:
                                                  ScrollPositionAlignmentPolicy
                                                      .keepVisibleAtEnd,
                                            );
                                          }
                                        });
                                  }
                                  return _cartLine(
                                    context,
                                    ref,
                                    line,
                                    lineHeight,
                                    selected: selected,
                                    quantityBuffer: selected
                                        ? keyboardState.quantityBuffer
                                        : '',
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
              if (state.cart.isNotEmpty) ...[
                const Divider(height: 8),
                _cartActions(context, ref, state),
                const SizedBox(height: 8),
                _checkoutFooter(
                  context,
                  ref,
                  state,
                  paySelected: keyboardState.paySelected,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleCartKey(
    BuildContext context,
    WidgetRef ref,
    AppState state,
    List<CartLine> visualLines,
    String? selectedProductId,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    if (visualLines.isEmpty) return KeyEventResult.ignored;

    final keyboard = ref.read(_posCartKeyboardProvider.notifier);
    final paySelected = ref.read(_posCartKeyboardProvider).paySelected;
    final liveSelectedProductId =
        ref.read(_posCartKeyboardProvider).selectedProductId ??
        selectedProductId;
    var selectedIndex = visualLines.indexWhere(
      (line) => line.product.id == liveSelectedProductId,
    );
    if (selectedIndex < 0) selectedIndex = 0;
    final selectedLine = visualLines[selectedIndex];
    final key = event.logicalKey;

    if (paySelected) {
      if (key == LogicalKeyboardKey.arrowUp) {
        keyboard.select(visualLines.last.product.id);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (_canPay(state)) _payment(context, ref, state);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      if (delta > 0 && selectedIndex == visualLines.length - 1) {
        keyboard.selectPay();
        return KeyEventResult.handled;
      }
      final next = (selectedIndex + delta).clamp(0, visualLines.length - 1);
      keyboard.select(visualLines[next].product.id);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd ||
        key == LogicalKeyboardKey.equal) {
      keyboard.clearQuantity();
      ref.read(appStoreProvider.notifier).quantity(selectedLine.product.id, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      keyboard.clearQuantity();
      if (selectedLine.quantity > 1) {
        ref
            .read(appStoreProvider.notifier)
            .quantity(selectedLine.product.id, -1);
      } else {
        _confirmRemoveLine(context, ref, selectedLine);
      }
      return KeyEventResult.handled;
    }
    final digit = _quantityDigit(key);
    if (digit != null) {
      keyboard.appendQuantityDigit(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      keyboard.removeQuantityDigit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (ref.read(_posCartKeyboardProvider).quantityBuffer.isNotEmpty) {
        keyboard.clearQuantity();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.delete) {
      keyboard.clearQuantity();
      _confirmRemoveLine(context, ref, selectedLine);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      final buffer = ref.read(_posCartKeyboardProvider).quantityBuffer;
      if (buffer.isNotEmpty) {
        final requested = int.tryParse(buffer);
        keyboard.clearQuantity();
        if (requested == null || requested < 1) return KeyEventResult.handled;
        if (!state.allowOverselling && requested > selectedLine.product.stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Only ${selectedLine.product.stock} available in stock.',
              ),
            ),
          );
          return KeyEventResult.handled;
        }
        ref
            .read(appStoreProvider.notifier)
            .quantity(
              selectedLine.product.id,
              requested - selectedLine.quantity,
            );
      } else {
        _openKeyboardLineActions(context, ref, selectedLine);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String? _quantityDigit(LogicalKeyboardKey key) {
    final digits = {
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };
    return digits[key];
  }

  Future<void> _openKeyboardLineActions(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
  ) async {
    final action = await showDialog<_CartLineAction>(
      context: context,
      builder: (_) => _CartLineActionsDialog(line: line),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _CartLineAction.editPrice:
        await _showUnitPriceEditor(context, ref, line);
        return;
      case _CartLineAction.discount:
        await _discount(context, ref, line);
        return;
      case _CartLineAction.remove:
        await _confirmRemoveLine(context, ref, line);
        return;
    }
  }

  Future<void> _confirmRemoveLine(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
  ) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Remove item?')),
        content: Text(
          'Remove ${line.product.displayName(context.isArabic)} from the order?',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('Remove')),
          ),
        ],
      ),
    );
    if (remove == true) {
      ref.read(appStoreProvider.notifier).remove(line.product.id);
    }
  }

  Widget _orderHeader(
    BuildContext context,
    WidgetRef ref,
    AppState state,
  ) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              context.tr('Current Order'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const StatusBadge('Dine In'),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => _selectCustomer(context, ref, state),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          ),
        ],
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              '${state.itemCount} items • ${state.customer?.name ?? context.tr('Walk-in Customer')}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: () => _note(context),
            icon: const Icon(Icons.note_alt_outlined, size: 16),
            label: Text(context.tr('Add Note')),
          ),
        ],
      ),
      if (MediaQuery.sizeOf(context).width >= 930)
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Keyboard: ↑ ↓ select item or Pay  •  type quantity + Enter  •  Enter activates',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  );

  Widget _cartLine(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
    double lineHeight, {
    required bool selected,
    required String quantityBuffer,
  }) => MouseRegion(
    onEnter: (_) =>
        ref.read(_posCartKeyboardProvider.notifier).select(line.product.id),
    child: Semantics(
      selected: selected,
      label:
          '${line.product.displayName(context.isArabic)}, quantity ${line.quantity}, ${money(line.total)}',
      hint: selected
          ? 'Selected. Use arrow keys to move, type a quantity and press Enter, or press Enter for item actions.'
          : 'Press the arrow keys to select this item.',
      child: SizedBox(
        height: lineHeight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0F8F5) : const Color(0xFFFAFCFB),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE3EAE7),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 6, 5),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 40,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0xFFE5EBE8)),
                        ),
                        child: ProductImage(
                          line.product.imageUrl,
                          key: ValueKey('cart-image-${line.product.id}'),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.product.displayName(context.isArabic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 1),
                            InkWell(
                              onTap: () => _discount(context, ref, line),
                              borderRadius: BorderRadius.circular(5),
                              child: Text(
                                line.discount == 0
                                    ? context.tr('Add discount')
                                    : '${context.tr('Discount')} ${money(line.discount)}',
                                style: TextStyle(
                                  color: line.discount == 0
                                      ? AppColors.primary
                                      : AppColors.danger,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      RiyalAmount(
                        line.total,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('Remove item'),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                        onPressed: () => ref
                            .read(appStoreProvider.notifier)
                            .remove(line.product.id),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.danger,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: context.tr('Edit price (F6 for latest item)'),
                        child: SizedBox(
                          height: 29,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showUnitPriceEditor(context, ref, line),
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              backgroundColor: const Color(0xFFEAF6F2),
                              side: const BorderSide(color: Color(0xFF9ACBBC)),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 13),
                            label: Row(
                              children: [
                                Text(
                                  context.tr('Edit price'),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'F6',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                RiyalAmount(
                                  line.unitPrice,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 29,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFC9D5D0)),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          _quantityButton(
                            Icons.remove_rounded,
                            () => ref
                                .read(appStoreProvider.notifier)
                                .quantity(line.product.id, -1),
                          ),
                          SizedBox(
                            width: 28,
                            child: Text(
                              quantityBuffer.isEmpty
                                  ? '${line.quantity}'
                                  : '${quantityBuffer}_',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: quantityBuffer.isEmpty
                                    ? null
                                    : AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _quantityButton(
                            Icons.add_rounded,
                            () => ref
                                .read(appStoreProvider.notifier)
                                .quantity(line.product.id, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _quantityButton(IconData icon, VoidCallback action) => IconButton(
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 30, height: 32),
    onPressed: action,
    icon: Icon(icon, size: 17),
  );

  Widget _cartActions(BuildContext context, WidgetRef ref, AppState state) =>
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () {
                ref.read(appStoreProvider.notifier).holdCart();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('Sale held.')),
                    action: SnackBarAction(
                      label: context.tr('Resume'),
                      onPressed: () => ref
                          .read(appStoreProvider.notifier)
                          .resumeLastHeldCart(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.pause_rounded, size: 17),
              label: Text(context.tr('Hold Sale')),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: TextButton.icon(
              onPressed: () => ref.read(appStoreProvider.notifier).clearCart(),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 17,
                color: AppColors.danger,
              ),
              label: Text(context.tr('Clear Cart')),
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 700) ...[
            const SizedBox(width: 7),
            IconButton.outlined(
              onPressed: () => _note(context),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ],
      );

  Widget _checkoutFooter(
    BuildContext context,
    WidgetRef ref,
    AppState state, {
    required bool paySelected,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F8F5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFD5E4DE)),
    ),
    child: Column(
      children: [
        _totals(context, ref, state),
        const SizedBox(height: 7),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: Semantics(
            key: const ValueKey('pos-pay-keyboard-target'),
            button: true,
            selected: paySelected,
            label: context.isArabic
                ? 'ادفع الآن ${money(state.cartTotal)}'
                : 'Pay now ${money(state.cartTotal)}',
            hint: paySelected
                ? 'Selected. Press Enter to choose a payment method.'
                : 'Press the down arrow after the last cart item to select.',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: paySelected
                      ? const Color(0xFFF4B942)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: FilledButton(
                onPressed: _canPay(state)
                    ? () => _payment(context, ref, state)
                    : null,
                style: FilledButton.styleFrom(
                  elevation: paySelected ? 4 : 0,
                  shadowColor: AppColors.primary.withValues(alpha: .35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (_, constraints) => Row(
                    children: [
                      if (constraints.maxWidth >= 300) ...[
                        Icon(
                          paySelected
                              ? Icons.keyboard_return_rounded
                              : Icons.lock_outline_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                      ],
                      Text(
                        context.tr('Pay now'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            money(state.cartTotal),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      _paymentKeyBadge(
                        paySelected ? 'ENTER' : 'F9',
                        onPrimary: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _paymentShortcuts(context, ref, state),
      ],
    ),
  );

  Widget _totals(BuildContext context, WidgetRef ref, AppState state) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _compactTotal(context, 'Subtotal', state.cartSubtotal),
          ),
          const SizedBox(width: 12),
          Expanded(child: _compactTotal(context, 'Tax', state.cartTax)),
        ],
      ),
      if (state.cartLineDiscount > 0)
        _sum(
          context,
          'Line discounts',
          -state.cartLineDiscount,
          color: AppColors.danger,
        ),
      const SizedBox(height: 3),
      _grossDiscountAction(context, ref, state),
      const Divider(height: 12),
      Row(
        children: [
          Text(
            context.tr('Grand Total'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const Spacer(),
          RiyalAmount(
            state.cartTotal,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
        ],
      ),
      if (state.cartDiscount > 0)
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'You save ${money(state.cartDiscount)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
    ],
  );

  Widget _compactTotal(BuildContext context, String label, int value) => Row(
    children: [
      Text(
        context.tr(label),
        style: const TextStyle(color: AppColors.muted, fontSize: 11),
      ),
      const Spacer(),
      RiyalAmount(value, style: const TextStyle(fontSize: 11)),
    ],
  );

  Widget _grossDiscountAction(
    BuildContext context,
    WidgetRef ref,
    AppState state,
  ) {
    final hasDiscount = state.cartGrossDiscount > 0;
    final rate = state.grossDiscountRate.toStringAsFixed(
      state.grossDiscountRate % 1 == 0 ? 0 : 2,
    );
    final label = hasDiscount
        ? (state.grossDiscountType == 'percentage'
              ? '${context.tr('Gross discount')} ($rate%)'
              : context.tr('Gross discount'))
        : context.tr('Add gross discount');
    return Material(
      color: const Color(0xFFEAF6F2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF9ACBBC)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _grossDiscount(context, ref, state),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            children: [
              const Icon(
                Icons.percent_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (hasDiscount) ...[
                RiyalAmount(
                  -state.cartGrossDiscount,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'F8',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sum(
    BuildContext context,
    String label,
    int value, {
    Color? color,
    VoidCallback? onTap,
    bool editable = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(
              context.tr(label),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (editable) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.edit_outlined,
                size: 12,
                color: AppColors.primary,
              ),
            ],
            const Spacer(),
            RiyalAmount(value, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    ),
  );

  Widget _paymentShortcuts(
    BuildContext context,
    WidgetRef ref,
    AppState state,
  ) {
    final options = state.posPaymentOptions;
    PaymentOption? optionFor(String code) => options
        .where((option) => option.code.toLowerCase() == code)
        .firstOrNull;
    final shortcuts = [
      optionFor('cash'),
      optionFor('card'),
      optionFor('credit'),
    ].whereType<PaymentOption>().toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final buttonWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final option in shortcuts)
              SizedBox(
                width: buttonWidth,
                child: _quickPaymentButton(context, ref, state, option),
              ),
            SizedBox(
              width: buttonWidth,
              child: OutlinedButton.icon(
                onPressed: _canPay(state)
                    ? () => _payment(context, ref, state)
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFB9C8C2)),
                ),
                icon: const Icon(Icons.more_horiz_rounded, size: 16),
                label: Text(
                  context.tr('More'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _quickPaymentButton(
    BuildContext context,
    WidgetRef ref,
    AppState state,
    PaymentOption option,
  ) => OutlinedButton(
    onPressed: _canPay(state)
        ? () => _payment(context, ref, state, preferredCode: option.code)
        : null,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFB9C8C2)),
    ),
    child: Row(
      children: [
        Icon(_paymentIcon(option.code), size: 15),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            context.tr(option.label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 4),
        _paymentKeyBadge(_paymentShortcutLabel(option.code)),
      ],
    ),
  );

  Widget _paymentKeyBadge(String label, {bool onPrimary = false}) => Container(
    constraints: const BoxConstraints(minWidth: 27),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    decoration: BoxDecoration(
      color: onPrimary
          ? Colors.white.withValues(alpha: .17)
          : const Color(0xFFE3F1EC),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: TextStyle(
        color: onPrimary ? Colors.white : AppColors.primary,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
  );

  bool _canPay(AppState state) =>
      state.cart.isNotEmpty &&
      state.locations.isNotEmpty &&
      state.customers.isNotEmpty &&
      state.posPaymentOptions.isNotEmpty;

  String _paymentShortcutLabel(String code) => switch (code.toLowerCase()) {
    'cash' => 'F10',
    'card' => 'F11',
    'credit' => 'F12',
    _ => '',
  };

  Future<void> _grossDiscount(
    BuildContext context,
    WidgetRef ref,
    AppState state,
  ) async {
    var discountType = state.grossDiscountType;
    final controller = TextEditingController(
      text: discountType == 'percentage'
          ? (state.grossDiscountRate == 0
                ? ''
                : state.grossDiscountRate.toStringAsFixed(2))
          : (state.cartGrossDiscount == 0
                ? ''
                : (state.cartGrossDiscount / 100).toStringAsFixed(2)),
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('Gross discount')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'fixed',
                      label: Text(context.tr('Amount')),
                      icon: RiyalSymbol(size: 15),
                    ),
                    ButtonSegment(
                      value: 'percentage',
                      label: Text(context.tr('Rate')),
                      icon: Icon(Icons.percent_rounded, size: 16),
                    ),
                  ],
                  selected: {discountType},
                  onSelectionChanged: (selection) {
                    setDialogState(() {
                      discountType = selection.first;
                      controller.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: discountType == 'percentage'
                        ? context.tr('Discount rate')
                        : context.tr('Discount amount'),
                    prefixIcon: discountType == 'percentage'
                        ? const Icon(Icons.percent_rounded, size: 18)
                        : const Padding(
                            padding: EdgeInsets.all(14),
                            child: RiyalSymbol(size: 16),
                          ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    helperText: discountType == 'percentage'
                        ? context.tr('Maximum 100%')
                        : '${context.tr('Maximum')} ${money(state.maximumGrossDiscount)}',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed < 0) {
                      return context.tr('Enter a valid amount');
                    }
                    if (discountType == 'percentage' && parsed > 100) {
                      return context.tr('Discount rate cannot exceed 100%');
                    }
                    if (discountType == 'fixed' &&
                        (parsed * 100).round() > state.maximumGrossDiscount) {
                      return context.tr('Discount cannot exceed subtotal');
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(dialogContext, (
                      discountType,
                      double.parse(controller.text.trim()),
                    ));
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Cancel')),
            ),
            if (state.cartGrossDiscount > 0)
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, const ('fixed', 0)),
                child: Text(context.tr('Remove discount')),
              ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, (
                  discountType,
                  double.parse(controller.text.trim()),
                ));
              },
              child: Text(context.tr('Apply')),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (result != null) {
      final store = ref.read(appStoreProvider.notifier);
      if (result.$1 == 'percentage') {
        store.setGrossDiscountPercentage(result.$2);
      } else {
        store.setGrossDiscount((result.$2 * 100).round());
      }
    }
  }

  Future<void> _discount(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
  ) async {
    final controller = TextEditingController(
      text: line.discount == 0 ? '' : (line.discount / 100).toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Line discount')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.tr('Discount amount'),
              prefixIcon: const Padding(
                padding: EdgeInsets.all(14),
                child: RiyalSymbol(size: 16),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              helperText: '${context.tr('Maximum')} ${money(line.subtotal)}',
            ),
            validator: (value) {
              final parsed = double.tryParse(value?.trim() ?? '');
              if (parsed == null || parsed < 0)
                return context.tr('Enter a valid amount');
              if ((parsed * 100).round() > line.subtotal)
                return context.tr('Discount cannot exceed subtotal');
              return null;
            },
            onFieldSubmitted: (_) {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                (double.parse(controller.text.trim()) * 100).round(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          if (line.discount > 0)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 0),
              child: Text(context.tr('Remove discount')),
            ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                (double.parse(controller.text.trim()) * 100).round(),
              );
            },
            child: Text(context.tr('Apply')),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (amount != null)
      ref.read(appStoreProvider.notifier).discount(line.product.id, amount);
  }

  void _note(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Order note')),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: context.tr('Add a note for this sale...'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Save note')),
          ),
        ],
      ),
    ).whenComplete(
      () => Future<void>.delayed(
        const Duration(milliseconds: 400),
        controller.dispose,
      ),
    );
  }

  void _payment(
    BuildContext context,
    WidgetRef ref,
    AppState state, {
    String? preferredCode,
  }) {
    final pageContext = context;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var preferredSubmitted = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) {
        var submitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (preferredCode != null && !preferredSubmitted) {
              preferredSubmitted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!sheetContext.mounted) return;
                final option = state.posPaymentOptions
                    .where((item) => _paymentMatches(item.code, preferredCode))
                    .firstOrNull;
                if (option == null) return;
                _handlePaymentOption(
                  sheetContext: sheetContext,
                  pageContext: pageContext,
                  ref: ref,
                  state: state,
                  code: option.code,
                  router: router,
                  messenger: messenger,
                  submitting: (value) {
                    if (sheetContext.mounted) {
                      setSheetState(() => submitting = value);
                    }
                  },
                );
              });
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height *
                    (MediaQuery.sizeOf(context).width < 700 ? .96 : .82),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Select payment method'),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                context.isArabic
                                    ? 'تحصيل ${money(state.cartTotal)}'
                                    : 'Collect ${money(state.cartTotal)}',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: submitting
                              ? null
                              : () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (submitting)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Flexible(
                      child: _KeyboardPaymentGrid(
                        options: state.posPaymentOptions,
                        paymentTotal: state.cartTotal,
                        iconFor: _paymentIcon,
                        onCancel: () => Navigator.pop(sheetContext),
                        onSubmit: (option) => _handlePaymentOption(
                          sheetContext: sheetContext,
                          pageContext: pageContext,
                          ref: ref,
                          state: state,
                          code: option.code,
                          router: router,
                          messenger: messenger,
                          submitting: (value) =>
                              setSheetState(() => submitting = value),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _paymentMatches(String backendCode, String shortcut) {
    if (backendCode == shortcut) return true;
    if (shortcut == 'upi') return backendCode == 'bank_transfer';
    return false;
  }

  Future<void> _handlePaymentOption({
    required BuildContext sheetContext,
    required BuildContext pageContext,
    required WidgetRef ref,
    required AppState state,
    required String code,
    required GoRouter router,
    required ScaffoldMessengerState messenger,
    required ValueChanged<bool> submitting,
  }) async {
    if (code != 'credit') {
      await _submitPayment(
        sheetContext,
        ref,
        code,
        router,
        messenger,
        submitting,
      );
      return;
    }

    final customer = state.customer;
    if (customer == null || customer.isWalkIn) {
      final selectCustomer = await showDialog<bool>(
        context: sheetContext,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.person_add_alt_1_rounded,
            color: AppColors.primary,
            size: 34,
          ),
          title: Text(dialogContext.tr('Select a customer first')),
          content: Text(
            dialogContext.tr(
              'Credit cannot be assigned to the Walk-in Customer. Select the customer who will pay this invoice later.',
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.tr('Cancel')),
            ),
            FilledButton.icon(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.people_outline_rounded),
              label: Text(dialogContext.tr('Select customer')),
            ),
          ],
        ),
      );
      if (selectCustomer == true && sheetContext.mounted) {
        Navigator.pop(sheetContext);
        await _selectCustomer(pageContext, ref, state);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.account_balance_wallet_outlined,
          color: AppColors.primary,
          size: 34,
        ),
        title: Text(dialogContext.tr('Confirm credit sale')),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                dialogContext.tr(
                  'No payment will be collected now. The full invoice amount will be recorded as due.',
                ),
              ),
              const SizedBox(height: 18),
              _creditDetail(dialogContext.tr('Customer'), customer.name),
              _creditDetail(
                dialogContext.tr('Credit amount'),
                money(state.cartTotal),
              ),
              _creditDetail(
                dialogContext.tr('Payment term'),
                _paymentTermLabel(dialogContext, customer),
              ),
              _creditDetail(
                dialogContext.tr('Due date'),
                _creditDueDate(customer),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.tr('Cancel')),
          ),
          FilledButton.icon(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_rounded),
            label: Text(dialogContext.tr('Create credit sale')),
          ),
        ],
      ),
    );
    if (confirmed == true && sheetContext.mounted) {
      await _submitPayment(
        sheetContext,
        ref,
        'credit',
        router,
        messenger,
        submitting,
      );
    }
  }

  Widget _creditDetail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  String _paymentTermLabel(BuildContext context, Customer customer) {
    final number = int.tryParse(customer.payTermNumber);
    if (number == null || number <= 0) return context.tr('Not specified');
    return '$number ${context.tr(customer.payTermType == 'months' ? 'months' : 'days')}';
  }

  String _creditDueDate(Customer customer) {
    final number = int.tryParse(customer.payTermNumber);
    if (number == null || number <= 0) return '—';
    final now = DateTime.now();
    final due = customer.payTermType == 'months'
        ? DateTime(now.year, now.month + number, now.day)
        : now.add(Duration(days: number));
    return DateFormat('dd MMM yyyy').format(due);
  }

  Future<void> _submitPayment(
    BuildContext sheetContext,
    WidgetRef ref,
    String code,
    GoRouter router,
    ScaffoldMessengerState messenger,
    ValueChanged<bool> submitting,
  ) async {
    submitting(true);
    try {
      final sale = await ref
          .read(backendControllerProvider.notifier)
          .checkout(code);
      if (!sheetContext.mounted) return;
      final successMessage =
          '${sheetContext.tr('Sale complete')} • ${sale.invoiceNo} • ${sheetContext.tr('New sale ready')}';
      Navigator.pop(sheetContext);
      router.go('/pos');
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!sheetContext.mounted) return;
      submitting(false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : error.toString(),
          ),
        ),
      );
    }
  }

  IconData _paymentIcon(String code) => switch (code) {
    'cash' => Icons.payments_outlined,
    'card' => Icons.credit_card_rounded,
    'cheque' => Icons.account_balance_wallet_outlined,
    'bank_transfer' => Icons.account_balance_outlined,
    'credit' => Icons.account_balance_wallet_outlined,
    _ => Icons.more_horiz_rounded,
  };
}

Future<void> _selectCustomer(
  BuildContext context,
  WidgetRef ref,
  AppState state,
) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (_) => _CustomerSelectorDialog(
    customers: state.customers,
    selectedCustomer: state.customer,
    onSelected: (customer) {
      ref.read(appStoreProvider.notifier).selectCustomer(customer);
    },
    onCreate: ({required name, required mobile, required email}) => ref
        .read(backendControllerProvider.notifier)
        .createCustomer(name: name, mobile: mobile, email: email),
  ),
);

class _CustomerSelectorDialog extends StatefulWidget {
  const _CustomerSelectorDialog({
    required this.customers,
    required this.selectedCustomer,
    required this.onSelected,
    required this.onCreate,
  });

  final List<Customer> customers;
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onSelected;
  final Future<Customer> Function({
    required String name,
    required String mobile,
    required String email,
  })
  onCreate;

  @override
  State<_CustomerSelectorDialog> createState() =>
      _CustomerSelectorDialogState();
}

class _CustomerSelectorDialogState extends State<_CustomerSelectorDialog> {
  final _searchController = TextEditingController();
  late final List<Customer> _customers;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _customers = [...widget.customers];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final customers = _customers
        .where((customer) {
          if (query.isEmpty) return true;
          return customer.name.toLowerCase().contains(query) ||
              customer.phone.toLowerCase().contains(query) ||
              customer.email.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 700;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: .18),
      insetPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 0 : 36,
        vertical: mobile ? 0 : (size.height < 650 ? 12 : 28),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mobile ? 0 : 18),
        side: const BorderSide(color: Color(0xFFDDE5E2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mobile ? size.width : 660,
          maxHeight: mobile ? size.height : 620,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
              child: Row(
                children: [
                  if (mobile)
                    IconButton(
                      tooltip: context.tr('Back'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_search_outlined,
                      color: AppColors.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Select customer'),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Assign a customer to the current order.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!mobile) ...[
                    const StatusBadge('F4'),
                    const SizedBox(width: 4),
                  ],
                  if (!mobile)
                    IconButton(
                      tooltip: context.tr('Close'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: SizedBox(
                height: 46,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: context.tr('Search name, phone or email'),
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.tr('Clear search'),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            Expanded(
              child: customers.isEmpty
                  ? EmptyState(
                      _customers.isEmpty
                          ? 'No customers are available'
                          : 'No customers match this search',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      itemCount: customers.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 64),
                      itemBuilder: (_, index) => _customerRow(customers[index]),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFB),
                border: Border(top: BorderSide(color: Color(0xFFE2E8E5))),
              ),
              child: Row(
                children: [
                  Text(
                    query.isEmpty
                        ? '${_customers.length} ${_customers.length == 1 ? 'customer' : 'customers'}'
                        : 'Showing ${customers.length} of ${_customers.length}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _createCustomer,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(context.tr(mobile ? 'New' : 'New customer')),
                  ),
                  if (!mobile) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.tr('Cancel')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCustomer() async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    var saving = false;
    String? error;
    final customer = await showDialog<Customer>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.tr('New customer')),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.tr('Customer name'),
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => value?.trim().isEmpty ?? true
                        ? context.tr('Customer name is required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: mobile,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: context.tr('Mobile number'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    validator: (value) => value?.trim().isEmpty ?? true
                        ? context.tr('Mobile number is required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: context.tr('Email (optional)'),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isNotEmpty &&
                          !RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(text)) {
                        return context.tr('Enter a valid email address');
                      }
                      return null;
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final created = await widget.onCreate(
                          name: name.text.trim(),
                          mobile: mobile.text.trim(),
                          email: email.text.trim(),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, created);
                        }
                      } on ApiException catch (exception) {
                        setDialogState(() {
                          saving = false;
                          error = exception.message;
                        });
                      } catch (_) {
                        setDialogState(() {
                          saving = false;
                          error = context.tr(
                            'Unable to create customer. Please try again.',
                          );
                        });
                      }
                    },
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text(
                saving ? context.tr('Saving...') : context.tr('Create'),
              ),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    mobile.dispose();
    email.dispose();
    if (customer == null || !mounted) return;
    setState(() => _customers.add(customer));
    widget.onSelected(customer);
    Navigator.pop(context);
  }

  Widget _customerRow(Customer customer) {
    final selected = widget.selectedCustomer?.id == customer.id;
    final walkIn = customer.id == 'walkin';
    final initials = customer.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Material(
      color: selected ? const Color(0xFFF0F8F5) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          widget.onSelected(customer);
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: walkIn
                    ? const Color(0xFFE8F4F0)
                    : const Color(0xFFF1F4F3),
                child: walkIn
                    ? const Icon(
                        Icons.directions_walk_rounded,
                        color: AppColors.primary,
                        size: 20,
                      )
                    : Text(
                        initials.isEmpty ? '?' : initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (walkIn) ...[
                          const SizedBox(width: 8),
                          const StatusBadge('Default'),
                        ],
                      ],
                    ),
                    if (customer.phone.isNotEmpty || customer.email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          [
                            if (customer.phone.isNotEmpty) customer.phone,
                            if (customer.email.isNotEmpty) customer.email,
                          ].join('  •  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 21,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                  size: 21,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
