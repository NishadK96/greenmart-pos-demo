import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/ui.dart';
import '../store/app_store.dart';
import '../backend/presentation/backend_controller.dart';

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
                  context.tr(p.name).contains(query) ||
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
                    Text(context.tr('View cart')),
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
                    context.tr('Point of Sale'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    context.tr('Scan barcode or search product to add'),
                    style: const TextStyle(color: AppColors.muted),
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
                decoration: InputDecoration(
                  hintText: context.tr('Search by name, SKU or barcode...'),
                  prefixIcon: const Icon(Icons.search),
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
            itemCount: state.categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return ChoiceChip(
                  label: Text(context.tr('All')),
                  selected: selected == 'all',
                  onSelected: (_) => onCategory('all'),
                );
              }
              final c = state.categories[i - 1];
              return ChoiceChip(
                label: Text(context.tr(c.name)),
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
                                        child: ProductImage(
                                          p.imageUrl,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      context.tr(p.name),
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
                                              ? context.tr('Out')
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
                              PositionedDirectional(
                                top: 9,
                                end: 9,
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
                label: Text(context.tr('Grid')),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.view_list_rounded, size: 19),
                label: Text(context.tr('List')),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.swap_vert, size: 18),
                label: Text(context.tr('Top selling')),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
                  context.tr('Current Order'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (s.cart.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        ref.read(appStoreProvider.notifier).clearCart(),
                    child: Text(context.tr('Clear')),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.itemCount} ${context.tr(s.itemCount == 1 ? 'item' : 'items')} • ${s.customer?.name ?? context.tr('Walk-in Customer')}',
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
                              child: ProductImage(
                                line.product.imageUrl,
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
                                    context.tr(line.product.name),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${money(line.product.sellingPrice)} ${context.tr('each')}',
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
            _sum(context, 'Subtotal', s.cartSubtotal),
            _sum(context, 'Tax', s.cartTax),
            _sum(context, 'Discount', -s.cartDiscount),
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
                    context.tr('Grand Total'),
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
                    label: Text(context.tr('Customer')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed:
                        s.cart.isEmpty ||
                            s.locations.isEmpty ||
                            s.customers.isEmpty ||
                            s.paymentOptions.isEmpty
                        ? null
                        : () => _payment(context, ref, s),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(context.tr('Payment')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sum(BuildContext context, String label, int amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(context.tr(label), style: const TextStyle(color: AppColors.muted)),
        const Spacer(),
        Text(money(amount)),
      ],
    ),
  );
  void _customer(BuildContext context, WidgetRef ref, AppState s) => showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.tr('Select customer')),
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
        builder: (sheetContext) {
          var submitting = false;
          return StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${context.tr('Collect')} ${money(s.cartTotal)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (submitting)
                    const Center(child: CircularProgressIndicator())
                  else
                    for (final option in s.paymentOptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            setState(() => submitting = true);
                            try {
                              await ref
                                  .read(backendControllerProvider.notifier)
                                  .checkout(option.code);
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              context.go('/receipt');
                            } catch (error) {
                              if (!sheetContext.mounted) return;
                              setState(() => submitting = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          },
                          icon: Icon(
                            option.code == 'cash'
                                ? Icons.payments
                                : option.code == 'card'
                                ? Icons.credit_card
                                : Icons.account_balance_outlined,
                          ),
                          label: Text(context.tr(option.label)),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      );
}
