import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../apis/api.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/ui.dart';
import '../backend/presentation/backend_controller.dart';
import '../store/app_store.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final Set<String> _favorites = {};
  final List<String> _recent = [];
  String _category = 'all', _query = '', _mode = 'all';
  bool _grid = true;
  bool _quickActionOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
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
      },
      child: Focus(
        autofocus: true,
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
            if (products.length == 1 && products.first.stock > 0) {
              _addProduct(products.first);
              _searchController.clear();
              setState(() => _query = '');
            }
          },
          decoration: InputDecoration(
            hintText: 'Scan barcode or search product (Name, SKU, Barcode)',
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
            const SnackBar(
              content: Text('Scanner input is ready through the search field.'),
            ),
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
          label: MediaQuery.sizeOf(context).width < 700
              ? const SizedBox.shrink()
              : const Text('Scan'),
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
    onTap: product.stock > 0 ? () => _addProduct(product) : null,
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
                  tooltip: 'Favorite',
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
                  tooltip: 'Product actions',
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'add') _addProduct(product);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'add', child: Text('Add to order')),
                  ],
                  icon: const Icon(Icons.more_vert_rounded, size: 17),
                ),
              ],
            ),
          ),
          Text(
            context.tr(product.name),
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
                      ? 'Out of stock'
                      : '${product.stock} in stock',
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
                  onPressed: product.stock > 0
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
          onTap: product.stock > 0 ? () => _addProduct(product) : null,
          leading: ProductImage(product.imageUrl, width: 44, height: 44),
          title: Text(
            context.tr(product.name),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('${product.sku} • ${product.stock} in stock'),
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
                  tooltip: 'Add to order',
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
                  onPressed: product.stock > 0
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
                  const SnackBar(
                    content: Text('Cash drawer command is ready.'),
                  ),
                ),
              ),
              _quickButton(
                Icons.more_horiz_rounded,
                'More',
                () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('More cashier actions')),
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
    setState(() {
      _recent.remove(product.id);
      _recent.insert(0, product.id);
      if (_recent.length > 12) _recent.removeLast();
    });
  }

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

class _RecentSalesDialog extends StatefulWidget {
  const _RecentSalesDialog({required this.sales});

  final List<Sale> sales;

  @override
  State<_RecentSalesDialog> createState() => _RecentSalesDialogState();
}

class _RecentSalesDialogState extends State<_RecentSalesDialog> {
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
                          tooltip: 'Back',
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
                            const Text(
                              'Recent Sales',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (!mobile) ...[
                              const SizedBox(height: 2),
                              const Text(
                                'Review completed transactions without leaving the POS.',
                                style: TextStyle(
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
                          tooltip: 'Close',
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
                        hintText:
                            'Search invoice, customer, phone or payment method',
                        prefixIcon: const Icon(Icons.search_rounded, size: 21),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
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
                          widget.sales.isEmpty
                              ? 'No completed sales are available yet'
                              : 'No sales match this search',
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
                        query.isEmpty
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
                        child: const Text('Close'),
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
      '$count sales',
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
    child: const Row(
      children: [
        Expanded(flex: 2, child: _TableLabel('Invoice')),
        Expanded(flex: 3, child: _TableLabel('Customer')),
        Expanded(flex: 2, child: _TableLabel('Date & time')),
        SizedBox(width: 108, child: _TableLabel('Payment')),
        SizedBox(
          width: 105,
          child: _TableLabel('Total', textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 82,
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
                    tooltip: 'View sale',
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
                width: 82,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'View sale',
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
      method.trim().isEmpty ? 'Unknown' : _titleCase(method),
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
      tooltip: 'Sale actions',
      onSelected: (value) {
        if (value == 'view') _showSaleDetails(sale);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'view',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.visibility_outlined),
            title: Text('View sale'),
          ),
        ),
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined),
            title: Text('Reprint (available in F7)'),
          ),
        ),
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.assignment_return_outlined),
            title: Text('Return (available in F5)'),
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
                        child: Text('${line.quantity} × ${line.product.name}'),
                      ),
                      RiyalAmount(line.total),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  const Text(
                    'Total',
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
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _TableLabel extends StatelessWidget {
  const _TableLabel(this.text, {this.textAlign = TextAlign.start});

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: textAlign,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: .45,
    ),
  );
}

class _CurrentOrder extends ConsumerWidget {
  const _CurrentOrder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStoreProvider);
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final compactHeight = MediaQuery.sizeOf(context).height < 800;
    final lineHeight = mobile
        ? (compactHeight ? 66.0 : 82.0)
        : (compactHeight ? 50.0 : 66.0);
    final separatorHeight = compactHeight ? 4.0 : 8.0;
    return Material(
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
            const Divider(height: 18),
            Expanded(
              child: state.cart.isEmpty
                  ? const EmptyState('Tap a product to start a sale')
                  : Scrollbar(
                      thumbVisibility: state.cart.length > 6,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: state.cart.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: separatorHeight),
                        itemBuilder: (_, index) => _cartLine(
                          context,
                          ref,
                          state.cart[index],
                          lineHeight,
                        ),
                      ),
                    ),
            ),
            if (state.cart.isNotEmpty) ...[
              const Divider(height: 10),
              _cartActions(context, ref, state),
              const SizedBox(height: 9),
              _totals(context, ref, state),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _canPay(state)
                      ? () => _payment(context, ref, state)
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'PAY  ${money(state.cartTotal)}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (!mobile) ...[
                        const Spacer(),
                        const StatusBadge('F9', color: Colors.white),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              _paymentShortcuts(context, ref, state),
            ],
          ],
        ),
      ),
    );
  }

  Widget _orderHeader(
    BuildContext context,
    WidgetRef ref,
    AppState state,
  ) => Column(
    children: [
      Row(
        children: [
          Text(
            context.tr('Current Order'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          const StatusBadge('Dine In'),
          const Spacer(),
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
            label: const Text('Add Note'),
          ),
        ],
      ),
    ],
  );

  Widget _cartLine(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
    double lineHeight,
  ) => SizedBox(
    height: lineHeight,
    child: Row(
      children: [
        ProductImage(line.product.imageUrl, width: 36, height: 42),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.tr(line.product.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 1),
              InkWell(
                onTap: () => _editPrice(context, ref, line),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RiyalAmount(
                      line.unitPrice,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.edit_outlined,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _discount(context, ref, line),
                child: Text(
                  line.discount == 0
                      ? 'Add discount'
                      : 'Discount ${money(line.discount)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE1E7E4)),
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
                width: 25,
                child: Text(
                  '${line.quantity}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
        const SizedBox(width: 8),
        SizedBox(
          width: 61,
          child: Text(
            money(line.total),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
        IconButton(
          tooltip: 'Remove item',
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              ref.read(appStoreProvider.notifier).remove(line.product.id),
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
        ),
      ],
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
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(appStoreProvider.notifier).holdCart();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Sale held.'),
                    action: SnackBarAction(
                      label: 'Resume',
                      onPressed: () => ref
                          .read(appStoreProvider.notifier)
                          .resumeLastHeldCart(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.pause_rounded, size: 17),
              label: const Text('Hold Sale'),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => ref.read(appStoreProvider.notifier).clearCart(),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 17,
                color: AppColors.danger,
              ),
              label: const Text('Clear Cart'),
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 700) ...[
            const SizedBox(width: 7),
            OutlinedButton(
              onPressed: () => _note(context),
              child: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ],
      );

  Widget _totals(BuildContext context, WidgetRef ref, AppState state) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5EAE8)),
        ),
        child: Column(
          children: [
            _sum(context, 'Subtotal', state.cartSubtotal),
            _sum(
              context,
              'Line discounts',
              -state.cartLineDiscount,
              color: AppColors.danger,
            ),
            _sum(
              context,
              'Gross discount',
              -state.cartGrossDiscount,
              color: AppColors.danger,
              onTap: () => _grossDiscount(context, ref, state),
              editable: true,
            ),
            _sum(context, 'Tax', state.cartTax),
            const Divider(height: 16),
            Row(
              children: [
                Text(
                  context.tr('Grand Total'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                RiyalAmount(
                  state.cartTotal,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
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
        ),
      );

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
    const shortcuts = [
      ('cash', 'Cash', Icons.payments_outlined),
      ('upi', 'UPI', Icons.qr_code_rounded),
      ('card', 'Card', Icons.credit_card_rounded),
      ('split', 'Split', Icons.call_split_rounded),
      ('credit', 'Credit', Icons.person_outline_rounded),
    ];
    return Row(
      children: [
        for (var index = 0; index < shortcuts.length; index++) ...[
          if (index > 0) const SizedBox(width: 5),
          Expanded(
            child: OutlinedButton(
              onPressed: _canPay(state)
                  ? () => _payment(
                      context,
                      ref,
                      state,
                      preferredCode: shortcuts[index].$1,
                    )
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 42),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(shortcuts[index].$3, size: 16),
                  Text(
                    shortcuts[index].$2,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _canPay(AppState state) =>
      state.cart.isNotEmpty &&
      state.locations.isNotEmpty &&
      state.customers.isNotEmpty &&
      state.paymentOptions.isNotEmpty;

  Future<void> _editPrice(
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
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Edit unit price')),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Unit price',
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
              child: const Text('Use default price'),
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
    if (amount == null) return;
    ref
        .read(appStoreProvider.notifier)
        .unitPrice(line.product.id, amount < 0 ? null : amount);
  }

  Future<void> _grossDiscount(
    BuildContext context,
    WidgetRef ref,
    AppState state,
  ) async {
    final controller = TextEditingController(
      text: state.cartGrossDiscount == 0
          ? ''
          : (state.cartGrossDiscount / 100).toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Gross discount')),
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
              helperText:
                  '${context.tr('Maximum')} ${money(state.maximumGrossDiscount)}',
            ),
            validator: (value) {
              final parsed = double.tryParse(value?.trim() ?? '');
              if (parsed == null || parsed < 0) {
                return context.tr('Enter a valid amount');
              }
              if ((parsed * 100).round() > state.maximumGrossDiscount) {
                return context.tr('Discount cannot exceed subtotal');
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('Cancel')),
          ),
          if (state.cartGrossDiscount > 0)
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
    if (amount != null) {
      ref.read(appStoreProvider.notifier).setGrossDiscount(amount);
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
        title: const Text('Order note'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Add a note for this sale...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Save note'),
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
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) {
        var submitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) => ConstrainedBox(
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
                            const Text(
                              'Select payment method',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Collect ${money(state.cartTotal)}',
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
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(22),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            mainAxisExtent: 72,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                      itemCount: state.paymentOptions.length,
                      itemBuilder: (_, index) {
                        final option = state.paymentOptions[index];
                        final highlighted =
                            preferredCode != null &&
                            _paymentMatches(option.code, preferredCode);
                        return highlighted
                            ? FilledButton.icon(
                                onPressed: () => _submitPayment(
                                  sheetContext,
                                  ref,
                                  option.code,
                                  router,
                                  messenger,
                                  (value) =>
                                      setSheetState(() => submitting = value),
                                ),
                                icon: Icon(_paymentIcon(option.code)),
                                label: Text(context.tr(option.label)),
                              )
                            : FilledButton.tonalIcon(
                                onPressed: () => _submitPayment(
                                  sheetContext,
                                  ref,
                                  option.code,
                                  router,
                                  messenger,
                                  (value) =>
                                      setSheetState(() => submitting = value),
                                ),
                                icon: Icon(_paymentIcon(option.code)),
                                label: Text(context.tr(option.label)),
                              );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _paymentMatches(String backendCode, String shortcut) {
    if (backendCode == shortcut) return true;
    if (shortcut == 'upi') return backendCode == 'bank_transfer';
    if (shortcut == 'credit') return backendCode == 'cheque';
    return false;
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
      await ref.read(backendControllerProvider.notifier).checkout(code);
      if (!sheetContext.mounted) return;
      Navigator.pop(sheetContext);
      router.go('/receipt');
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
  ),
);

class _CustomerSelectorDialog extends StatefulWidget {
  const _CustomerSelectorDialog({
    required this.customers,
    required this.selectedCustomer,
    required this.onSelected,
  });

  final List<Customer> customers;
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onSelected;

  @override
  State<_CustomerSelectorDialog> createState() =>
      _CustomerSelectorDialogState();
}

class _CustomerSelectorDialogState extends State<_CustomerSelectorDialog> {
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
    final customers = widget.customers
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
                      tooltip: 'Back',
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
                      tooltip: 'Close',
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
                    hintText: 'Search name, phone or email',
                    prefixIcon: const Icon(Icons.search_rounded, size: 21),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
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
                      widget.customers.isEmpty
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
                        ? '${widget.customers.length} ${widget.customers.length == 1 ? 'customer' : 'customers'}'
                        : 'Showing ${customers.length} of ${widget.customers.length}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
