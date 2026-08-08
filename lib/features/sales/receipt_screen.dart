import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/ui.dart';
import '../store/app_store.dart';

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sale = ref.watch(appStoreProvider).lastSale;
    if (sale == null)
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/pos'),
            child: const Text('Start a sale'),
          ),
        ),
      );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFFDDEFEA),
                    child: Icon(
                      Icons.check_rounded,
                      size: 42,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sale complete',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${sale.invoiceNo} • Saved offline',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  Surface(
                    child: Column(
                      children: [
                        const Text(
                          'GREENMART',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const Text(
                          'Thank you for shopping with us',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        const Divider(height: 28),
                        Row(
                          children: [
                            Text(sale.customer.name),
                            const Spacer(),
                            Text(sale.paymentMethod.name.toUpperCase()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final line in sale.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${line.quantity} × ${line.product.name}',
                                  ),
                                ),
                                Text(money(line.total)),
                              ],
                            ),
                          ),
                        const Divider(height: 28),
                        _row(
                          'Subtotal',
                          sale.items.fold(0, (v, e) => v + e.subtotal),
                        ),
                        _row('Tax', sale.tax),
                        _row('Discount', -sale.discount),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              'TOTAL',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            Text(
                              money(sale.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const StatusBadge(
                          'Pending synchronization',
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mock print preview completed.',
                                  ),
                                ),
                              ),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('Print'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sharing adapter is ready for Phase 2.',
                                  ),
                                ),
                              ),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => context.go('/pos'),
                    child: const SizedBox(
                      width: double.infinity,
                      child: Center(child: Text('Start new sale')),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/sales'),
                    child: const Text('View sales history'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const Spacer(),
        Text(money(value)),
      ],
    ),
  );
}
