import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../shared/models/entities.dart';
import '../../shared/widgets/ui.dart';
import '../store/app_store.dart';
import '../zatca/presentation/zatca_screen.dart';
import '../printers/application/printer_controller.dart';
import '../printers/application/printer_document_service.dart';

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
            child: Text(context.tr('Start a sale')),
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
                    sale.syncStatus == SyncStatus.pending
                        ? 'Offline sale saved'
                        : context.tr('Sale complete'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sale.syncStatus == SyncStatus.pending
                        ? '${sale.invoiceNo} • Waiting to synchronize'
                        : '${sale.invoiceNo} • Saved to EazyERP',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  Surface(
                    child: Column(
                      children: [
                        Text(
                          (ref
                                      .watch(appStoreProvider)
                                      .business
                                      ?.displayName(context.isArabic) ??
                                  '')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          context.tr('Thank you for shopping with us'),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const Divider(height: 28),
                        Row(
                          children: [
                            Text(sale.customer.name),
                            const Spacer(),
                            Text(sale.paymentMethod.toUpperCase()),
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
                                    '${line.quantity} × ${line.product.displayName(context.isArabic)}',
                                  ),
                                ),
                                RiyalAmount(line.total),
                              ],
                            ),
                          ),
                        const Divider(height: 28),
                        _row(
                          context,
                          'Subtotal',
                          sale.items.fold(0, (v, e) => v + e.subtotal),
                        ),
                        _row(context, 'Tax', sale.tax),
                        _row(context, 'Discount', -sale.discount),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text(
                              'TOTAL',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            RiyalAmount(
                              sale.total,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        StatusBadge(
                          sale.syncStatus == SyncStatus.pending
                              ? 'Provisional • Pending sync'
                              : sale.zatcaStatus == 'success'
                              ? 'Synchronized • ZATCA accepted'
                              : 'Synchronized',
                          color: sale.syncStatus == SyncStatus.pending
                              ? const Color(0xFFB7791F)
                              : AppColors.primary,
                        ),
                        if (sale.syncStatus == SyncStatus.pending) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'This is a provisional offline receipt, not a final ZATCA invoice. The official invoice number and ZATCA documents become available after synchronization.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final printerState = ref.read(
                              printerControllerProvider,
                            );
                            try {
                              await PrinterDocumentService.printReceiptTo(
                                sale,
                                ref
                                        .read(appStoreProvider)
                                        .business
                                        ?.displayName(context.isArabic) ??
                                    'GreenMart',
                                printerState.settings,
                                printer: printerState.selectedPrinter,
                                arabic:
                                    ref.read(localeProvider).languageCode ==
                                    'ar',
                              );
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Print failed: $error'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.print_outlined),
                          label: Text(context.tr('Print')),
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
                          label: Text(context.tr('Share')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => context.go('/pos'),
                    child: SizedBox(
                      width: double.infinity,
                      child: Center(child: Text(context.tr('Start new sale'))),
                    ),
                  ),
                  if (sale.serverId != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            showZatcaInvoiceDialog(context, ref, sale),
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('ZATCA invoice status & documents'),
                      ),
                    ),
                  ],
                  TextButton(
                    onPressed: () => context.go('/sales'),
                    child: Text(context.tr('View sales history')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(context.tr(label), style: const TextStyle(color: AppColors.muted)),
        const Spacer(),
        RiyalAmount(value),
      ],
    ),
  );
}
