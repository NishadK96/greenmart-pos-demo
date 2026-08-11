import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';
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
  String query = '';
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStoreProvider);
    final rows = s.products
        .where(
          (p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              context.tr(p.name).contains(query),
        )
        .toList();
    return PagePad(
      child: Column(
        children: [
          const PageTitle(
            'Products',
            subtitle: 'Manage pricing, stock and barcodes.',
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: context.tr('Search products'),
              prefixIcon: const Icon(Icons.search),
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
                      child: ProductImage(
                        p.imageUrl,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      context.tr(p.name),
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
                itemCount: s.categories.length,
                itemBuilder: (_, i) {
                  final cat = s.categories[i];
                  final count = s.products
                      .where((p) => p.categoryId == cat.id)
                      .length;
                  return Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.category_outlined, size: 26),
                        const Spacer(),
                        Text(
                          context.tr(cat.name),
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
