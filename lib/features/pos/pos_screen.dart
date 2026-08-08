import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/ui.dart';
import '../store/app_store.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String category = 'all', query = '';
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStoreProvider);
    final products = state.products
        .where(
          (p) =>
              p.active &&
              (category == 'all' || p.categoryId == category) &&
              (p.name.toLowerCase().contains(query.toLowerCase()) ||
                  p.barcode.contains(query)),
        )
        .toList();
    final desktop = MediaQuery.sizeOf(context).width > 900;
    final discovery = _Discovery(
      products: products,
      selected: category,
      onCategory: (v) => setState(() => category = v),
      onSearch: (v) => setState(() => query = v),
    );
    if (desktop)
      return Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: discovery),
            const SizedBox(width: 20),
            SizedBox(width: 430, child: _Cart()),
          ],
        ),
      );
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          child: discovery,
        ),
        if (state.itemCount > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: FilledButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: .82,
                  builder: (_, controller) =>
                      _Cart(scrollController: controller),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Text(
                        '${state.itemCount}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('View cart'),
                    const Spacer(),
                    Text(
                      money(state.cartTotal),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Discovery extends ConsumerWidget {
  const _Discovery({
    required this.products,
    required this.selected,
    required this.onCategory,
    required this.onSearch,
  });
  final List<Product> products;
  final String selected;
  final ValueChanged<String> onCategory, onSearch;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStoreProvider);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Point of Sale',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Scan barcode or search product to add',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5EAE8)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person_outline, size: 18, color: AppColors.muted),
                  SizedBox(width: 7),
                  Text(
                    'Register 01',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search by name, SKU or barcode...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Scanner input is ready through the search field.',
                  ),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = state.categories[i];
              return ChoiceChip(
                label: Text('${c.icon}  ${c.name}'),
                selected: selected == c.id,
                onSelected: (_) => onCategory(c.id),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: products.isEmpty
              ? const EmptyState('No products match this filter')
              : LayoutBuilder(
                  builder: (context, c) {
                    final count = c.maxWidth > 900
                        ? 4
                        : c.maxWidth > 620
                        ? 4
                        : c.maxWidth > 390
                        ? 3
                        : 2;
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        mainAxisExtent: 238,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: products.length,
                      itemBuilder: (_, i) {
                        final p = products[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: p.stock > 0
                              ? () => ref
                                    .read(appStoreProvider.notifier)
                                    .addToCart(p)
                              : null,
                          child: Stack(
                            children: [
                              Surface(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Image.asset(
                                          p.imageAsset,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Icon(
                                            _productIcon(p.categoryId),
                                            size: 42,
                                            color: AppColors.ink.withValues(
                                              alpha: .7,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          money(p.sellingPrice),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          p.stock == 0
                                              ? 'Out'
                                              : '${p.stock} ${p.unit}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: p.stock <= p.minimumStock
                                                ? AppColors.danger
                                                : AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 9,
                                right: 9,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x2210231F),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5EAE8)),
          ),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Grid'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.view_list_rounded, size: 19),
                label: const Text('List'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.swap_vert, size: 18),
                label: const Text('Top selling'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _productIcon(String c) => c == 'beverages'
      ? Icons.local_drink_outlined
      : c == 'snacks'
      ? Icons.cookie_outlined
      : c == 'household'
      ? Icons.cleaning_services_outlined
      : c == 'personal'
      ? Icons.spa_outlined
      : Icons.shopping_basket_outlined;
}

class _Cart extends ConsumerWidget {
  const _Cart({this.scrollController});
  final ScrollController? scrollController;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStoreProvider);
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5EAE8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Current order',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (s.cart.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        ref.read(appStoreProvider.notifier).clearCart(),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.itemCount} items • ${s.customer?.name ?? 'Walk-in Customer'}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _customer(context, ref, s),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                ),
              ],
            ),
            const Divider(height: 28),
            Expanded(
              child: s.cart.isEmpty
                  ? const EmptyState('Tap a product to start a sale')
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: s.cart.length,
                      separatorBuilder: (_, __) => const Divider(height: 22),
                      itemBuilder: (_, i) {
                        final line = s.cart[i];
                        return Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.asset(
                                line.product.imageAsset,
                                width: 58,
                                height: 58,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${money(line.product.sellingPrice)} each',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => ref
                                  .read(appStoreProvider.notifier)
                                  .quantity(line.product.id, -1),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '${line.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              onPressed: () => ref
                                  .read(appStoreProvider.notifier)
                                  .quantity(line.product.id, 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            SizedBox(
                              width: 72,
                              child: Text(
                                money(line.total),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const Divider(height: 24),
            _sum('Subtotal', s.cartSubtotal),
            _sum('Tax (5%)', s.cartTax),
            _sum('Discount', -s.cartDiscount),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Grand Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    money(s.cartTotal),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _customer(context, ref, s),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Customer'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: s.cart.isEmpty
                        ? null
                        : () => _payment(context, ref, s),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Payment'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sum(String label, int amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const Spacer(),
        Text(money(amount)),
      ],
    ),
  );
  void _customer(BuildContext context, WidgetRef ref, AppState s) => showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Select customer'),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in s.customers)
              ListTile(
                title: Text(c.name),
                subtitle: c.phone.isEmpty ? null : Text(c.phone),
                onTap: () {
                  ref.read(appStoreProvider.notifier).selectCustomer(c);
                  Navigator.pop(dialogContext);
                },
              ),
          ],
        ),
      ),
    ),
  );
  void _payment(BuildContext context, WidgetRef ref, AppState s) =>
      showModalBottomSheet(
        context: context,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Collect ${money(s.cartTotal)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              for (final m in PaymentMethod.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      ref.read(appStoreProvider.notifier).checkout(m);
                      Navigator.pop(sheetContext);
                      context.go('/receipt');
                    },
                    icon: Icon(
                      m == PaymentMethod.cash
                          ? Icons.payments
                          : m == PaymentMethod.card
                          ? Icons.credit_card
                          : Icons.qr_code,
                    ),
                    label: Text(
                      m == PaymentMethod.digital
                          ? 'UPI / Digital'
                          : m.name[0].toUpperCase() + m.name.substring(1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
