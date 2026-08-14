import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../apis/api.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/ui.dart';
import '../store/app_store.dart';
import '../backend/presentation/backend_controller.dart';

class PagePad extends StatelessWidget {
  const PagePad({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(20), child: child);
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    final today = s.sales
        .where((e) => e.createdAt.day == DateTime.now().day)
        .toList();
    final sales = today.fold(0, (v, e) => v + e.total);
    final low = s.products.where((p) => p.stock <= p.minimumStock).toList();
    return PagePad(
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2810231F),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (_, c) => Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusBadge(
                          context.tr('Store open'),
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${context.tr('Good morning')}, ${s.user?.name ?? ''}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr(
                            'Your store is on track. Here’s today at a glance.',
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (c.maxWidth > 650)
                    Row(
                      children: [
                        _quick(
                          context,
                          'New sale',
                          Icons.point_of_sale,
                          () => context.go('/pos'),
                          true,
                        ),
                        const SizedBox(width: 9),
                        _quick(
                          context,
                          'Inventory',
                          Icons.inventory_2_outlined,
                          () => context.go('/inventory'),
                          false,
                        ),
                        const SizedBox(width: 9),
                        _quick(
                          context,
                          'Reports',
                          Icons.bar_chart_rounded,
                          () => context.go('/reports'),
                          false,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (_, c) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: c.maxWidth > 1050
                  ? 6
                  : c.maxWidth > 600
                  ? 3
                  : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                MetricCard(
                  label: "Today's sales",
                  value: money(sales),
                  icon: Icons.trending_up,
                ),
                MetricCard(
                  label: 'Transactions',
                  value: '${today.length}',
                  icon: Icons.receipt_long,
                ),
                MetricCard(
                  label: 'Gross profit',
                  value: money(s.profitLoss?.grossProfit ?? 0),
                  icon: Icons.savings_outlined,
                ),
                MetricCard(
                  label: 'Low stock',
                  value: '${low.length}',
                  icon: Icons.warning_amber,
                  tint: AppColors.accent,
                ),
                MetricCard(
                  label: 'Expenses',
                  value: money(s.profitLoss?.totalExpenses ?? 0),
                  icon: Icons.payments_outlined,
                ),
                MetricCard(
                  label: 'Total purchases',
                  value: money(s.profitLoss?.totalPurchases ?? 0),
                  icon: Icons.local_shipping_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (_, c) {
              final recent = _recentSales(context, s);
              final stock = _lowStock(context, low);
              return c.maxWidth > 780
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: recent),
                        const SizedBox(width: 16),
                        Expanded(child: stock),
                      ],
                    )
                  : Column(
                      children: [recent, const SizedBox(height: 16), stock],
                    );
            },
          ),
          const SizedBox(height: 20),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('7-day sales summary'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final h in [70, 98, 62, 120, 88, 132, 110])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Container(
                              height: h.toDouble(),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: .18),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
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
        ],
      ),
    );
  }

  Widget _quick(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback tap,
    bool strong,
  ) => Material(
    color: strong ? AppColors.accent : Colors.white.withValues(alpha: .09),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(
          children: [
            Icon(icon, color: strong ? AppColors.navy : Colors.white),
            const SizedBox(height: 6),
            Text(
              context.tr(label),
              style: TextStyle(
                color: strong ? AppColors.navy : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _recentSales(BuildContext context, AppState s) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Recent sales'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        for (final sale in s.sales.take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.receipt_outlined)),
            title: Text(sale.invoiceNo),
            subtitle: Text(sale.customer.name),
            trailing: Text(
              money(sale.total),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    ),
  );
  Widget _lowStock(BuildContext context, List<Product> low) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Low stock'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        for (final p in low.take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr(p.name)),
            subtitle: Text('${context.tr('Minimum')} ${p.minimumStock}'),
            trailing: StatusBadge('${p.stock} left', color: AppColors.danger),
          ),
      ],
    ),
  );
}

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  final _minStockController = TextEditingController();
  final _maxStockController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  String query = '';
  String categoryId = 'all';
  String status = 'all';
  String sortBy = 'name';
  bool onlyActive = false;
  int page = 0;
  static const pageSize = 9;

  @override
  void dispose() {
    _searchController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final normalizedQuery = query.trim().toLowerCase();
    final minStock = int.tryParse(_minStockController.text);
    final maxStock = int.tryParse(_maxStockController.text);
    final minPrice = double.tryParse(_minPriceController.text);
    final maxPrice = double.tryParse(_maxPriceController.text);
    final rows = s.products.where((product) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery) ||
          context.tr(product.name).toLowerCase().contains(normalizedQuery) ||
          product.sku.toLowerCase().contains(normalizedQuery) ||
          product.barcode.toLowerCase().contains(normalizedQuery);
      final matchesCategory =
          categoryId == 'all' || product.categoryId == categoryId;
      final matchesStatus = switch (status) {
        'active' => product.active,
        'inactive' => !product.active,
        'low' => product.stock > 0 && product.stock <= product.minimumStock,
        'out' => product.stock <= 0,
        _ => true,
      };
      final matchesStock =
          (minStock == null || product.stock >= minStock) &&
          (maxStock == null || product.stock <= maxStock);
      final matchesPrice =
          (minPrice == null || product.sellingPrice >= minPrice) &&
          (maxPrice == null || product.sellingPrice <= maxPrice);
      return matchesQuery &&
          matchesCategory &&
          matchesStatus &&
          matchesStock &&
          matchesPrice &&
          (!onlyActive || product.active);
    }).toList();
    rows.sort(switch (sortBy) {
      'price_low' => (a, b) => a.sellingPrice.compareTo(b.sellingPrice),
      'price_high' => (a, b) => b.sellingPrice.compareTo(a.sellingPrice),
      'stock_low' => (a, b) => a.stock.compareTo(b.stock),
      _ =>
        (a, b) => context
            .tr(a.name)
            .toLowerCase()
            .compareTo(context.tr(b.name).toLowerCase()),
    });
    final totalPages = rows.isEmpty ? 1 : (rows.length / pageSize).ceil();
    final safePage = page.clamp(0, totalPages - 1);
    final start = safePage * pageSize;
    final visibleRows = rows.skip(start).take(pageSize).toList(growable: false);
    final lowStock = s.products
        .where(
          (product) =>
              product.stock > 0 && product.stock <= product.minimumStock,
        )
        .length;
    final outOfStock = s.products.where((product) => product.stock <= 0).length;
    final stockValue = s.products.fold<int>(
      0,
      (value, product) =>
          value +
          (product.purchasePrice * (product.stock > 0 ? product.stock : 0)),
    );
    final mobile = MediaQuery.sizeOf(context).width < 700;

    final productGrid = _productGrid(rows, visibleRows);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageTitle(
                  'Products',
                  subtitle: 'Manage pricing, stock and barcodes.',
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => context.go('/products/create'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.tr('New product')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          )
        else
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const PageTitle(
                'Products',
                subtitle: 'Manage pricing, stock and barcodes.',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/products/import'),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(context.tr('Import')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/products/bulk'),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: Text(context.tr('Bulk update')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/products/quick'),
                    icon: const Icon(Icons.bolt_outlined),
                    label: Text(context.tr('Quick add')),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/products/create'),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('New product')),
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = mobile
                ? 4
                : constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            final cardWidth =
                (constraints.maxWidth - ((columns - 1) * 10)) / columns;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: cardWidth / (mobile ? 86 : 72),
              children: [
                _productMetric(
                  'Total Products',
                  '${s.products.length}',
                  Icons.inventory_2_outlined,
                  AppColors.primary,
                ),
                _productMetric(
                  'Low Stock',
                  '$lowStock',
                  Icons.warning_amber_rounded,
                  const Color(0xFFD88900),
                ),
                _productMetric(
                  'Out of Stock',
                  '$outOfStock',
                  Icons.remove_shopping_cart_outlined,
                  AppColors.danger,
                ),
                _productMetric(
                  'Total Stock Value',
                  money(stockValue),
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF286B9B),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Surface(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final search = TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {
                  query = value;
                  page = 0;
                }),
                decoration: InputDecoration(
                  hintText: 'Search name, SKU or barcode',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => setState(() {
                            _searchController.clear();
                            query = '';
                            page = 0;
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              );
              final filters = Row(
                children: [
                  Expanded(child: _categoryFilter(s)),
                  const SizedBox(width: 8),
                  Expanded(child: _statusFilter()),
                ],
              );
              if (mobile) {
                return Column(
                  children: [
                    search,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _mobileFilterButton(
                            Icons.category_outlined,
                            categoryId == 'all'
                                ? 'Categories'
                                : _categoryName(s),
                            () => _showMobileFilters(s),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _mobileFilterButton(
                            Icons.check_circle_outline,
                            status == 'all' ? 'Status' : _statusName(status),
                            () => _showMobileFilters(s),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _mobileFilterButton(
                            Icons.filter_alt_outlined,
                            'Filters',
                            () => _showMobileFilters(s),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return compact
                  ? Column(
                      children: [search, const SizedBox(height: 9), filters],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 3, child: search),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: filters),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (mobile)
          SizedBox(
            height: rows.isEmpty
                ? 180
                : (((visibleRows.length / 2).ceil() * 222) - 12).toDouble(),
            child: productGrid,
          )
        else
          Expanded(child: productGrid),
        const SizedBox(height: 12),
        _pagination(rows.length, safePage, totalPages, mobile: mobile),
      ],
    );

    return Padding(
      padding: EdgeInsets.all(mobile ? 12 : 20),
      child: mobile ? SingleChildScrollView(child: content) : content,
    );
  }

  Widget _productGrid(List<Product> rows, List<Product> visibleRows) {
    if (rows.isEmpty) {
      return const EmptyState('No products match these filters');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = MediaQuery.sizeOf(context).width < 700;
        final columns = mobile
            ? 2
            : constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 580
            ? 2
            : 1;
        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: MediaQuery.sizeOf(context).width < 700
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: visibleRows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: mobile ? 210 : (columns == 1 ? 178 : 160),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (_, index) => mobile
              ? _mobileProductCard(visibleRows[index])
              : _productCard(visibleRows[index]),
        );
      },
    );
  }

  Widget _productMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Surface(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 7 : 12,
        vertical: mobile ? 7 : 9,
      ),
      child: Flex(
        direction: mobile ? Axis.vertical : Axis.horizontal,
        mainAxisAlignment: mobile
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: mobile
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: mobile ? 28 : 34,
            height: mobile ? 28 : 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: mobile ? 15 : 18),
          ),
          SizedBox(width: mobile ? 0 : 9, height: mobile ? 4 : 0),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mobile ? 12 : 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: mobile ? 7 : 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _categoryName(AppState state) {
    for (final category in state.categories) {
      if (category.id == categoryId) return context.tr(category.name);
    }
    return 'Categories';
  }

  String _statusName(String value) => switch (value) {
    'active' => 'Active',
    'inactive' => 'Inactive',
    'low' => 'Low stock',
    'out' => 'Out of stock',
    _ => 'Status',
  };

  Widget _mobileFilterButton(
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.keyboard_arrow_down, size: 16),
      ],
    ),
  );

  Widget _categoryFilter(AppState state) => DropdownButtonFormField<String>(
    initialValue: categoryId,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Category',
      prefixIcon: Icon(Icons.category_outlined, size: 19),
      isDense: true,
    ),
    items: [
      const DropdownMenuItem(value: 'all', child: Text('All categories')),
      for (final category in state.categories)
        DropdownMenuItem(
          value: category.id,
          child: Text(context.tr(category.name)),
        ),
    ],
    onChanged: (value) => setState(() {
      categoryId = value ?? 'all';
      page = 0;
    }),
  );

  Widget _statusFilter() => DropdownButtonFormField<String>(
    initialValue: status,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Status',
      prefixIcon: Icon(Icons.flag_outlined, size: 19),
      isDense: true,
    ),
    items: const [
      DropdownMenuItem(value: 'all', child: Text('All statuses')),
      DropdownMenuItem(value: 'active', child: Text('Active')),
      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
      DropdownMenuItem(value: 'low', child: Text('Low stock')),
      DropdownMenuItem(value: 'out', child: Text('Out of stock')),
    ],
    onChanged: (value) => setState(() {
      status = value ?? 'all';
      page = 0;
    }),
  );

  Widget _mobileProductCard(Product product) {
    final out = product.stock <= 0;
    final low = !out && product.stock <= product.minimumStock;
    final stockColor = !product.active
        ? AppColors.muted
        : out
        ? AppColors.danger
        : low
        ? const Color(0xFFD88900)
        : const Color(0xFF16814E);
    final statusLabel = !product.active
        ? 'Inactive'
        : out
        ? 'Out of stock'
        : low
        ? 'Low stock'
        : 'In stock';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Color(0xFFE1E8E5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/products/edit', extra: product),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Center(
                    child: ProductImage(
                      product.imageUrl,
                      width: 78,
                      height: 78,
                      fit: BoxFit.contain,
                    ),
                  ),
                  PositionedDirectional(
                    end: -8,
                    top: -8,
                    child: PopupMenuButton<String>(
                      tooltip: 'Product actions',
                      onSelected: (action) => _productAction(product, action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'status',
                          child: Text(
                            product.active ? 'Deactivate' : 'Activate',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete product'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                context.tr(product.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'SKU: ${product.sku}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 8),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      money(product.sellingPrice),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stockColor.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${product.stock} ${product.unit}',
                      style: TextStyle(
                        color: stockColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: stockColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: stockColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.go('/products/edit', extra: product),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      backgroundColor: const Color(0xFFEAF5F1),
                    ),
                    child: const Text('View', style: TextStyle(fontSize: 9)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMobileFilters(AppState state) async {
    var draftCategory = categoryId;
    var draftStatus = status;
    var draftSort = sortBy;
    var draftOnlyActive = onlyActive;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => FractionallySizedBox(
          heightFactor: .9,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD4D0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        draftCategory = 'all';
                        draftStatus = 'all';
                        draftSort = 'name';
                        draftOnlyActive = false;
                        _minStockController.clear();
                        _maxStockController.clear();
                        _minPriceController.clear();
                        _maxPriceController.clear();
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: draftCategory,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All categories'),
                          ),
                          for (final category in state.categories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(context.tr(category.name)),
                            ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => draftCategory = value ?? 'all'),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      RadioGroup<String>(
                        groupValue: draftStatus,
                        onChanged: (value) =>
                            setSheetState(() => draftStatus = value ?? 'all'),
                        child: Column(
                          children: [
                            for (final option in const [
                              ('all', 'All'),
                              ('active', 'In stock'),
                              ('low', 'Low stock'),
                              ('out', 'Out of stock'),
                            ])
                              RadioListTile<String>(
                                value: option.$1,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(option.$2),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _rangeFields(
                        'Stock range',
                        _minStockController,
                        _maxStockController,
                      ),
                      const SizedBox(height: 18),
                      _rangeFields(
                        'Price range',
                        _minPriceController,
                        _maxPriceController,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Sort by',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: draftSort,
                        items: const [
                          DropdownMenuItem(
                            value: 'name',
                            child: Text('Name (A to Z)'),
                          ),
                          DropdownMenuItem(
                            value: 'price_low',
                            child: Text('Price: Low to high'),
                          ),
                          DropdownMenuItem(
                            value: 'price_high',
                            child: Text('Price: High to low'),
                          ),
                          DropdownMenuItem(
                            value: 'stock_low',
                            child: Text('Stock: Low to high'),
                          ),
                        ],
                        onChanged: (value) =>
                            setSheetState(() => draftSort = value ?? 'name'),
                      ),
                      const SizedBox(height: 14),
                      CheckboxListTile(
                        value: draftOnlyActive,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Only active products'),
                        onChanged: (value) => setSheetState(
                          () => draftOnlyActive = value ?? false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            categoryId = draftCategory;
                            status = draftStatus;
                            sortBy = draftSort;
                            onlyActive = draftOnlyActive;
                            page = 0;
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Apply filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rangeFields(
    String label,
    TextEditingController minimum,
    TextEditingController maximum,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: minimum,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Min'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('–'),
          ),
          Expanded(
            child: TextField(
              controller: maximum,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Max'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _productCard(Product product) {
    final out = product.stock <= 0;
    final low = !out && product.stock <= product.minimumStock;
    final stockColor = !product.active
        ? AppColors.muted
        : out
        ? AppColors.danger
        : low
        ? const Color(0xFFD88900)
        : const Color(0xFF16814E);
    final statusLabel = !product.active
        ? 'Inactive'
        : out
        ? 'Out of stock'
        : low
        ? 'Low stock'
        : 'In stock';

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE1E8E5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/products/edit', extra: product),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F8),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: ProductImage(
                      product.imageUrl,
                      width: 58,
                      height: 58,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(product.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SKU: ${product.sku}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          money(product.sellingPrice),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Product actions',
                    padding: EdgeInsets.zero,
                    onSelected: (action) => _productAction(product, action),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'status',
                        child: Text(product.active ? 'Deactivate' : 'Activate'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete product'),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              const Divider(height: 16),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: stockColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: stockColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${product.stock} ${product.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 9),
                  IconButton(
                    tooltip: 'Edit product',
                    onPressed: () =>
                        context.go('/products/edit', extra: product),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pagination(
    int total,
    int currentPage,
    int totalPages, {
    bool mobile = false,
  }) => Container(
    height: mobile ? 96 : 48,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE1E8E5)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: mobile
        ? Column(
            children: [
              Text(
                total == 0
                    ? '0 products'
                    : 'Showing ${currentPage * pageSize + 1}–${(currentPage * pageSize + pageSize).clamp(0, total)} of $total products',
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _pageButton(
                    Icons.first_page_rounded,
                    currentPage == 0 ? null : () => setState(() => page = 0),
                  ),
                  _pageButton(
                    Icons.chevron_left_rounded,
                    currentPage == 0
                        ? null
                        : () => setState(() => page = currentPage - 1),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${currentPage + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Text(
                      'of $totalPages',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  _pageButton(
                    Icons.chevron_right_rounded,
                    currentPage >= totalPages - 1
                        ? null
                        : () => setState(() => page = currentPage + 1),
                  ),
                  _pageButton(
                    Icons.last_page_rounded,
                    currentPage >= totalPages - 1
                        ? null
                        : () => setState(() => page = totalPages - 1),
                  ),
                ],
              ),
            ],
          )
        : Row(
            children: [
              Text(
                total == 0
                    ? '0 products'
                    : 'Showing ${currentPage * pageSize + 1}–${(currentPage * pageSize + pageSize).clamp(0, total)} of $total',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Previous page',
                onPressed: currentPage == 0
                    ? null
                    : () => setState(() => page = currentPage - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${currentPage + 1} / $totalPages',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: currentPage >= totalPages - 1
                    ? null
                    : () => setState(() => page = currentPage + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
  );

  Widget _pageButton(IconData icon, VoidCallback? onPressed) => IconButton(
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
  );

  Future<void> _productAction(Product product, String action) async {
    if (action == 'edit') {
      context.go('/products/edit', extra: product);
      return;
    }
    if (action == 'status') {
      try {
        await ref
            .read(backendControllerProvider.notifier)
            .updateProductStatus(product, !product.active);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                product.active ? 'Product deactivated.' : 'Product activated.',
              ),
            ),
          );
      } on ApiException catch (error) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          '“${product.name}” can only be deleted if it has no transaction history. Otherwise deactivate it instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(backendControllerProvider.notifier).deleteProduct(product);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product deleted.')));
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});
  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    return PagePad(
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              const PageTitle(
                'Categories',
                subtitle: 'Organize products for faster checkout.',
              ),
              FilledButton.icon(
                onPressed: _busy ? null : () => _showEditor(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New category'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: c.maxWidth > 900
                      ? 4
                      : c.maxWidth > 500
                      ? 3
                      : 2,
                  mainAxisExtent: 130,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: s.categories.length,
                itemBuilder: (_, i) {
                  final cat = s.categories[i];
                  final count = s.products
                      .where((p) => p.categoryId == cat.id)
                      .length;
                  return Surface(
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.category_outlined, size: 26),
                            const Spacer(),
                            Text(
                              context.tr(cat.name),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$count products • ${cat.subCategories.length} subcategories',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          right: -8,
                          top: -10,
                          child: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'manage') _showSubcategories(cat);
                              if (action == 'sub') _showEditor(parent: cat);
                              if (action == 'edit') _showEditor(category: cat);
                              if (action == 'delete') _deleteCategory(cat);
                            },
                            itemBuilder: (_) => [
                              if (cat.subCategories.isNotEmpty)
                                const PopupMenuItem(
                                  value: 'manage',
                                  child: Text('Manage subcategories'),
                                ),
                              PopupMenuItem(
                                value: 'sub',
                                child: Text('Add subcategory'),
                              ),
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete / replace'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditor({Category? category, Category? parent}) async {
    final name = TextEditingController(
      text: category?.nameEn.isNotEmpty == true
          ? category!.nameEn
          : category?.name ?? '',
    );
    final arabic = TextEditingController(text: category?.nameAr ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          category == null
              ? (parent == null ? 'Create category' : 'Create subcategory')
              : 'Edit category',
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'English name *'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: arabic,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'Arabic name (optional)',
                ),
              ),
              if (parent != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Parent: ${parent.name}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final controller = ref.read(backendControllerProvider.notifier);
      if (category == null) {
        await controller.createCategory(
          name: name.text.trim(),
          nameAr: arabic.text.trim(),
          parentId: parent?.id,
        );
      } else {
        await controller.updateCategory(
          id: category.id,
          name: name.text.trim(),
          nameAr: arabic.text.trim(),
        );
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category saved.')));
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
      name.dispose();
      arabic.dispose();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final state = ref.read(appStoreProvider);
    final parent = state.categories
        .where((item) => item.subCategories.any((sub) => sub.id == category.id))
        .firstOrNull;
    final options = (parent?.subCategories ?? state.categories)
        .where((item) => item.id != category.id)
        .toList();
    String? replacementId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Delete or replace category'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete “${category.name}”. If it is in use, select a compatible replacement.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: replacementId,
                  decoration: const InputDecoration(
                    labelText: 'Replacement (if required)',
                  ),
                  items: options
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => replacementId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(backendControllerProvider.notifier)
          .deleteCategory(id: category.id, replacementId: replacementId);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Category deleted.')));
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSubcategories(Category parent) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_categoryLabel(parent)} subcategories'),
        content: SizedBox(
          width: 480,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: parent.subCategories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final sub = parent.subCategories[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_categoryLabel(sub)),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    Navigator.pop(dialogContext);
                    if (action == 'edit') _showEditor(category: sub);
                    if (action == 'delete') _deleteCategory(sub);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete / replace'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showEditor(parent: parent);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add subcategory'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(Category category) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    if (arabic && category.nameAr.trim().isNotEmpty) return category.nameAr;
    if (category.nameEn.trim().isNotEmpty) return category.nameEn;
    return context.tr(category.name);
  }
}

class LegacyPurchasesScreen extends ConsumerWidget {
  const LegacyPurchasesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return PagePad(
      child: Column(
        children: [
          const PageTitle(
            'Purchases',
            subtitle: 'Purchase APIs are not available in Connector.',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Surface(
              child: s.purchases.isEmpty
                  ? const EmptyState(
                      'BACKEND CHANGE REQUIRED: No purchase API is available.',
                    )
                  : ListView.separated(
                      itemCount: s.purchases.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final p = s.purchases[i];
                        return ListTile(
                          title: Text(
                            p.invoiceNo,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${p.supplier.name} • ${p.items.length} lines',
                          ),
                          trailing: Text(
                            money(p.total),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final low = s.stockItems.where((p) => p.stock <= p.minimumStock).length,
        out = s.stockItems.where((p) => p.stock == 0).length;
    final rows = s.stockItems
        .where(
          (p) =>
              filter == 'All' ||
              filter == 'Low stock' && p.stock <= p.minimumStock ||
              filter == 'Out of stock' && p.stock == 0,
        )
        .toList();
    return PagePad(
      child: Column(
        children: [
          const PageTitle(
            'Inventory',
            subtitle: 'Live stock reported by EazyERP.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Products',
                  value: '${s.stockItems.length}',
                  icon: Icons.inventory_2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Low stock',
                  value: '$low',
                  icon: Icons.warning_amber,
                  tint: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricCard(
                  label: 'Out of stock',
                  value: '$out',
                  icon: Icons.remove_shopping_cart,
                  tint: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'All', label: Text(context.tr('All'))),
                ButtonSegment(
                  value: 'Low stock',
                  label: Text(context.tr('Low stock')),
                ),
                ButtonSegment(
                  value: 'Out of stock',
                  label: Text(context.tr('Out of stock')),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (v) => setState(() => filter = v.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Surface(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final p = rows[i];
                  return ListTile(
                    title: Text(
                      context.tr(p.name),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Min ${p.minimumStock} • ${p.locationName} • ${money(p.unitPrice)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge(
                          p.stock == 0
                              ? 'Out of stock'
                              : p.stock <= p.minimumStock
                              ? 'Low: ${p.stock}'
                              : 'In stock: ${p.stock}',
                          color: p.stock <= p.minimumStock
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final customers = s.customers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(query.toLowerCase()) ||
              customer.phone.contains(query) ||
              customer.email.toLowerCase().contains(query.toLowerCase()),
        )
        .toList(growable: false);
    return PagePad(
      child: Column(
        children: [
          PageTitle(
            'Customers',
            subtitle: 'Customer profiles for faster billing.',
            action: FilledButton.icon(
              onPressed: () => _customerForm(context, ref),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(context.tr('Add customer')),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: context.tr('Search customers'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Surface(
              child: ListView.separated(
                itemCount: customers.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final c = customers[i];
                  return ListTile(
                    onTap: () => _customerForm(context, ref, c),
                    leading: CircleAvatar(child: Text(c.name[0])),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      c.phone.isEmpty ? 'Default billing customer' : c.phone,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _customerForm(
    BuildContext context,
    WidgetRef ref, [
    Customer? existing,
  ]) async {
    final name = TextEditingController(text: existing?.name);
    final mobile = TextEditingController(text: existing?.phone);
    final email = TextEditingController(text: existing?.email);
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        String? error;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              context.tr(existing == null ? 'Add customer' : 'Edit customer'),
            ),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: context.tr('Customer name'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? context.tr('Required')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: mobile,
                      decoration: InputDecoration(
                        labelText: context.tr('Mobile'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? context.tr('Required')
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: email,
                      decoration: InputDecoration(
                        labelText: context.tr('Email'),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(color: AppColors.danger),
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
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final controller = ref.read(
                            backendControllerProvider.notifier,
                          );
                          if (existing == null) {
                            await controller.createCustomer(
                              name: name.text.trim(),
                              mobile: mobile.text.trim(),
                              email: email.text.trim(),
                            );
                          } else {
                            await controller.updateCustomer(
                              customer: existing,
                              name: name.text.trim(),
                              mobile: mobile.text.trim(),
                              email: email.text.trim(),
                              taxNumber: existing.taxNumber ?? '',
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (exception) {
                          setState(() {
                            saving = false;
                            error = exception.toString();
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Save')),
              ),
            ],
          ),
        );
      },
    );
    name.dispose();
    mobile.dispose();
    email.dispose();
  }
}

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});
  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String period = 'Today';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final now = DateTime.now();
    final start = switch (period) {
      'Yesterday' => DateTime(now.year, now.month, now.day - 1),
      'This week' => DateTime(now.year, now.month, now.day - now.weekday + 1),
      'This month' => DateTime(now.year, now.month),
      _ => DateTime(now.year, now.month, now.day),
    };
    final end = period == 'Yesterday'
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day + 1);
    final sales = s.sales
        .where(
          (sale) =>
              !sale.createdAt.isBefore(start) && sale.createdAt.isBefore(end),
        )
        .toList(growable: false);
    return PagePad(
      child: Column(
        children: [
          const PageTitle(
            'Sales history',
            subtitle: 'Local and synchronized transactions.',
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final value in [
                  'Today',
                  'Yesterday',
                  'This week',
                  'This month',
                ])
                  ChoiceChip(
                    label: Text(context.tr(value)),
                    selected: period == value,
                    onSelected: (_) => setState(() => period = value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Surface(
              child: ListView.separated(
                itemCount: sales.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final sale = sales[i];
                  return ListTile(
                    onTap: () => _details(context, sale),
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(
                      sale.invoiceNo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${sale.customer.name} • ${sale.items.length} lines • ${sale.paymentMethod}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusBadge(
                          sale.syncStatus.name,
                          color: sale.syncStatus == SyncStatus.pending
                              ? AppColors.accent
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          money(sale.total),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _details(BuildContext context, Sale sale) => showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(sale.invoiceNo),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${sale.customer.name} • ${sale.paymentMethod}'),
            const Divider(),
            for (final line in sale.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${line.quantity} × ${context.tr(line.product.name)}',
                      ),
                    ),
                    Text(money(line.total)),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Text(
                  context.tr('Total'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  money(sale.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.tr('Close')),
        ),
        FilledButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Print preview is ready; connect a printer implementation in Phase 2.',
              ),
            ),
          ),
          icon: const Icon(Icons.print_outlined),
          label: Text(context.tr('Print')),
        ),
      ],
    ),
  );
}

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    final report = s.profitLoss;
    final total = report?.totalSales ?? 0;
    final trend = s.sales.take(10).toList().reversed.toList();
    final maxSale = trend.fold<int>(
      0,
      (maximum, sale) => sale.total > maximum ? sale.total : maximum,
    );
    final units = <String, int>{};
    for (final sale in s.sales) {
      for (final item in sale.items) {
        units.update(
          context.tr(item.product.name),
          (v) => v + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
    }
    final top = units.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return PagePad(
      child: ListView(
        children: [
          const PageTitle(
            'Sales report',
            subtitle: 'Performance reported by EazyERP.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, c) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: c.maxWidth > 800 ? 4 : 2,
              childAspectRatio: 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                MetricCard(
                  label: 'Total sales',
                  value: money(total),
                  icon: Icons.trending_up,
                ),
                MetricCard(
                  label: 'Total orders',
                  value: '${s.sales.length}',
                  icon: Icons.receipt,
                ),
                MetricCard(
                  label: 'Gross profit',
                  value: money(report?.grossProfit ?? 0),
                  icon: Icons.analytics_outlined,
                ),
                MetricCard(
                  label: 'Net profit',
                  value: money(report?.netProfit ?? 0),
                  icon: Icons.account_balance_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Sales trend'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final sale in trend)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Container(
                              height: maxSale == 0
                                  ? 0
                                  : 160 * sale.total / maxSale,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: .22),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
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
          const SizedBox(height: 18),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Top selling products'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                for (final e in top.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.key),
                    trailing: StatusBadge('${e.value} sold'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return PagePad(
      child: ListView(
        children: [
          const PageTitle(
            'Synchronization',
            subtitle: 'Refresh data directly from EazyERP.',
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (_, c) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: c.maxWidth > 700 ? 3 : 1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.3,
              children: [
                const MetricCard(
                  label: 'Internet status',
                  value: 'Online',
                  icon: Icons.wifi,
                ),
                MetricCard(
                  label: 'Products',
                  value: '${s.products.length}',
                  icon: Icons.inventory_2_outlined,
                ),
                MetricCard(
                  label: 'Customers',
                  value: '${s.customers.length}',
                  icon: Icons.people_outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('Backend data'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.invalidate(backendControllerProvider),
                      icon: const Icon(Icons.sync),
                      label: Text(context.tr('Sync now')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_done_outlined),
                  title: Text('API-backed mode'),
                  subtitle: Text(
                    'Products, categories, customers, sales, stock, and reports are loaded from EazyERP.',
                  ),
                  trailing: StatusBadge('Connected'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStoreProvider);
    final business = state.business;
    final user = state.user;
    final locationNames = state.locations.map((item) => item.name).join(', ');
    final sections = [
      (
        'Business profile',
        '${business?.name ?? ''} • ${business?.currencyCode ?? ''} • ${business?.timeZone ?? ''}',
        Icons.store_outlined,
      ),
      (
        'Tax settings',
        business?.taxLabel.isNotEmpty == true
            ? business!.taxLabel
            : 'No default business tax',
        Icons.percent,
      ),
      ('Business locations', locationNames, Icons.location_on_outlined),
      (
        'User & profile',
        '${user?.name ?? ''} • ${user?.isAdmin == true ? 'Administrator' : user?.username ?? ''}',
        Icons.person_outline,
      ),
    ];
    return PagePad(
      child: ListView(
        children: [
          const PageTitle(
            'Settings',
            subtitle: 'Configure your business and connected services.',
          ),
          const SizedBox(height: 18),
          for (final section in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Surface(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(section.$3)),
                  title: Text(
                    context.tr(section.$1),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(context.tr(section.$2)),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
