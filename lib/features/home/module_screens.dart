import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/ui.dart';
import '../store/app_store.dart';

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
                        const StatusBadge(
                          'STORE OPEN',
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Good morning, Nishad',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your store is on track. Here’s today at a glance.',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
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
                          'Add stock',
                          Icons.add_box_outlined,
                          () => context.go('/purchases'),
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
                const MetricCard(
                  label: 'Gross profit',
                  value: '—',
                  icon: Icons.savings_outlined,
                ),
                MetricCard(
                  label: 'Low stock',
                  value: '${low.length}',
                  icon: Icons.warning_amber,
                  tint: AppColors.accent,
                ),
                MetricCard(
                  label: 'Pending sync',
                  value: '${s.syncQueue.length}',
                  icon: Icons.sync,
                ),
                MetricCard(
                  label: 'Purchases today',
                  value:
                      '${s.purchases.where((p) => p.createdAt.day == DateTime.now().day).length}',
                  icon: Icons.local_shipping_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (_, c) {
              final recent = _recentSales(s);
              final stock = _lowStock(low);
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
                const Text(
                  '7-day sales summary',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
              label,
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

  Widget _recentSales(AppState s) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent sales',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
  Widget _lowStock(List<Product> low) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Low stock',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        for (final p in low.take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.name),
            subtitle: Text('Minimum ${p.minimumStock}'),
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
  String query = '';
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final rows = s.products
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return PagePad(
      child: Column(
        children: [
          PageTitle(
            'Products',
            subtitle: 'Manage pricing, stock and barcodes.',
            action: FilledButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Search products',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Surface(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final p = rows[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        p.imageAsset,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${p.sku} • ${p.barcode}'),
                    trailing: SizedBox(
                      width: 190,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          StatusBadge(
                            '${p.stock} ${p.unit}',
                            color: p.stock <= p.minimumStock
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            money(p.sellingPrice),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
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

  void _add(BuildContext context) {
    final name = TextEditingController(),
        price = TextEditingController(),
        stock = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add product'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Selling price'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Opening stock'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              final n = DateTime.now().microsecondsSinceEpoch;
              ref
                  .read(appStoreProvider.notifier)
                  .addProduct(
                    Product(
                      id: 'p$n',
                      name: name.text.trim(),
                      sku: 'SKU-$n',
                      barcode: '890$n',
                      categoryId: 'grocery',
                      purchasePrice:
                          toPaise(double.tryParse(price.text) ?? 0) * 7 ~/ 10,
                      sellingPrice: toPaise(double.tryParse(price.text) ?? 0),
                      stock: int.tryParse(stock.text) ?? 0,
                      minimumStock: 5,
                    ),
                  );
              Navigator.pop(dialogContext);
            },
            child: const Text('Save product'),
          ),
        ],
      ),
    );
  }
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return PagePad(
      child: Column(
        children: [
          const PageTitle(
            'Categories',
            subtitle: 'Organize products for faster checkout.',
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
                itemCount: s.categories.skip(1).length,
                itemBuilder: (_, i) {
                  final cat = s.categories.skip(1).elementAt(i);
                  final count = s.products
                      .where((p) => p.categoryId == cat.id)
                      .length;
                  return Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 26)),
                        const Spacer(),
                        Text(
                          cat.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '$count products',
                          style: const TextStyle(color: AppColors.muted),
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

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return PagePad(
      child: Column(
        children: [
          PageTitle(
            'Purchases',
            subtitle: 'Receive supplier stock locally.',
            action: FilledButton.icon(
              onPressed: () => _add(context, ref, s),
              icon: const Icon(Icons.add),
              label: const Text('Add purchase'),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Surface(
              child: ListView.separated(
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

  void _add(BuildContext context, WidgetRef ref, AppState s) {
    Product selected = s.products.first;
    final qty = TextEditingController(text: '10'),
        rate = TextEditingController(
          text: (selected.purchasePrice / 100).toString(),
        );
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Receive purchase'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Product>(
                  initialValue: selected,
                  items: [
                    for (final p in s.products)
                      DropdownMenuItem(value: p, child: Text(p.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) set(() => selected = v);
                  },
                  decoration: const InputDecoration(labelText: 'Product'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Purchase rate'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Save draft'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(appStoreProvider.notifier)
                    .savePurchase(
                      selected.id,
                      int.tryParse(qty.text) ?? 0,
                      toPaise(double.tryParse(rate.text) ?? 0),
                    );
                Navigator.pop(context);
              },
              child: const Text('Save purchase'),
            ),
          ],
        ),
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
    final low = s.products.where((p) => p.stock <= p.minimumStock).length,
        out = s.products.where((p) => p.stock == 0).length;
    final rows = s.products
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
            subtitle: 'Live local stock and adjustments.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Products',
                  value: '${s.products.length}',
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
              segments: const [
                ButtonSegment(value: 'All', label: Text('All')),
                ButtonSegment(value: 'Low stock', label: Text('Low stock')),
                ButtonSegment(
                  value: 'Out of stock',
                  label: Text('Out of stock'),
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
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Min ${p.minimumStock} • Cost ${money(p.purchasePrice)} • Sell ${money(p.sellingPrice)}',
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
                        IconButton(
                          onPressed: () => _adjust(context, p),
                          icon: const Icon(Icons.tune),
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

  void _adjust(BuildContext context, Product p) {
    final q = TextEditingController(text: '1');
    String reason = 'Increase';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text('Adjust ${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                items: ['Increase', 'Decrease', 'Damage', 'Correction']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => set(() => reason = v!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: q,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                final n = int.tryParse(q.text) ?? 0;
                ref
                    .read(appStoreProvider.notifier)
                    .adjustStock(
                      p.id,
                      ['Decrease', 'Damage'].contains(reason) ? -n : n,
                      reason,
                    );
                Navigator.pop(context);
              },
              child: const Text('Apply adjustment'),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return PagePad(
      child: Column(
        children: [
          const PageTitle(
            'Customers',
            subtitle: 'Customer profiles for faster billing.',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Surface(
              child: ListView.separated(
                itemCount: s.customers.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final c = s.customers[i];
                  return ListTile(
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
}

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return PagePad(
      child: Column(
        children: [
          const PageTitle(
            'Sales history',
            subtitle: 'Local and synchronized transactions.',
          ),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Today')),
                Chip(label: Text('Yesterday')),
                Chip(label: Text('This week')),
                Chip(label: Text('This month')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Surface(
              child: ListView.separated(
                itemCount: s.sales.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final sale = s.sales[i];
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
                      '${sale.customer.name} • ${sale.items.length} lines • ${sale.paymentMethod.name}',
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
            Text('${sale.customer.name} • ${sale.paymentMethod.name}'),
            const Divider(),
            for (final line in sale.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${line.quantity} × ${line.product.name}'),
                    ),
                    Text(money(line.total)),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w800),
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
          child: const Text('Close'),
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
          label: const Text('Print'),
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
    final total = s.sales.fold(0, (v, e) => v + e.total);
    final tax = s.sales.fold(0, (v, e) => v + e.tax);
    final units = <String, int>{};
    for (final sale in s.sales) {
      for (final item in sale.items) {
        units.update(
          item.product.name,
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
            subtitle: 'Performance from locally available transactions.',
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
                  label: 'Average order',
                  value: money(s.sales.isEmpty ? 0 : total ~/ s.sales.length),
                  icon: Icons.analytics_outlined,
                ),
                MetricCard(
                  label: 'Tax collected',
                  value: money(tax),
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
                const Text(
                  'Sales trend',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final h in [
                        46,
                        80,
                        66,
                        120,
                        94,
                        145,
                        126,
                        164,
                        136,
                        170,
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Container(
                              height: h.toDouble(),
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
                const Text(
                  'Top selling products',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
            subtitle: 'Offline changes remain safely queued on this device.',
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
                  label: 'Pending records',
                  value: '${s.syncQueue.length}',
                  icon: Icons.pending_actions,
                  tint: AppColors.accent,
                ),
                const MetricCard(
                  label: 'Failed records',
                  value: '0',
                  icon: Icons.error_outline,
                  tint: AppColors.danger,
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
                    const Expanded(
                      child: Text(
                        'Sync queue',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No server endpoint configured. Local records remain pending.',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync now'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (s.syncQueue.isEmpty)
                  const EmptyState('All local records are synchronized')
                else
                  for (final item in s.syncQueue)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: Text('${item.entityType} • ${item.entityId}'),
                      subtitle: Text(
                        'Queued ${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const StatusBadge(
                        'Pending',
                        color: AppColors.accent,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => PagePad(
    child: ListView(
      children: [
        const PageTitle(
          'Settings',
          subtitle: 'Configure your business and connected services.',
        ),
        const SizedBox(height: 18),
        for (final section in const [
          (
            'Business profile',
            'GreenMart • INR • RF invoice prefix',
            Icons.store_outlined,
          ),
          ('Tax settings', 'Standard tax mode • ZATCA disabled', Icons.percent),
          (
            'Invoice settings',
            'Receipt template and numbering',
            Icons.receipt_outlined,
          ),
          ('Printer settings', 'Mock printer • 80mm', Icons.print_outlined),
          ('Sync settings', 'Manual sync • Auto-sync ready', Icons.sync),
          ('Appearance', 'Light theme', Icons.palette_outlined),
          ('User & profile', 'Nishad • Administrator', Icons.person_outline),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Surface(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(section.$3)),
                title: Text(
                  section.$1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(section.$2),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
      ],
    ),
  );
}
