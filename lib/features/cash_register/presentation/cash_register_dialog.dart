import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/entities.dart';
import '../../store/app_store.dart';
import '../domain/cash_register_entities.dart';
import 'cash_register_controller.dart';

Future<void> showCashRegisterDialog(BuildContext context, WidgetRef ref) async {
  final mobile = MediaQuery.sizeOf(context).width < 700;
  if (mobile) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FractionallySizedBox(
        heightFactor: .92,
        child: CashRegisterWorkspace(),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
          child: const CashRegisterWorkspace(),
        ),
      ),
    );
  }
}

class CashRegisterWorkspace extends ConsumerStatefulWidget {
  const CashRegisterWorkspace({super.key});

  @override
  ConsumerState<CashRegisterWorkspace> createState() =>
      _CashRegisterWorkspaceState();
}

class _CashRegisterWorkspaceState extends ConsumerState<CashRegisterWorkspace> {
  final openingController = TextEditingController(text: '0.00');
  String? locationId;

  @override
  void dispose() {
    openingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final register = ref.watch(cashRegisterControllerProvider);
    final locations = ref.watch(appStoreProvider).locations;
    locationId ??= locations.firstOrNull?.id;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Header(
            onRefresh: () =>
                ref.read(cashRegisterControllerProvider.notifier).refresh(),
          ),
          Expanded(
            child: register.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: _message(error),
                onRetry: () =>
                    ref.read(cashRegisterControllerProvider.notifier).refresh(),
              ),
              data: (value) => value == null
                  ? _closedView(locations)
                  : _openView(value, locations),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closedView(List<BusinessLocation> locations) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const _RegisterBanner(
        icon: Icons.lock_open_rounded,
        title: 'Start a cashier shift',
        description:
            'Choose the selling location and count the opening cash before taking payments.',
      ),
      const SizedBox(height: 24),
      DropdownButtonFormField<String>(
        initialValue: locationId,
        decoration: const InputDecoration(
          labelText: 'Business location',
          prefixIcon: Icon(Icons.storefront_outlined),
        ),
        items: locations
            .map(
              (location) => DropdownMenuItem<String>(
                value: location.id,
                child: Text(location.name),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => locationId = value),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: openingController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Opening cash',
          prefixIcon: Icon(Icons.payments_outlined),
          helperText: 'Cash physically available in the drawer.',
        ),
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: locations.isEmpty ? null : _open,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Open cash register'),
      ),
    ],
  );

  Widget _openView(CashRegister register, List<BusinessLocation> locations) {
    final location = locations
        .where((item) => item.id == register.locationId)
        .firstOrNull;
    return FutureBuilder<CashRegisterSummary>(
      future: ref.read(cashRegisterControllerProvider.notifier).summary(),
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _RegisterBanner(
            icon: Icons.point_of_sale_rounded,
            title: 'Register open',
            description:
                '${location?.name ?? 'Business location'} • Opened ${_dateTime(register.createdAt)}',
            trailing: const _StatusChip(label: 'Shift open'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _AmountCard(
                  label: 'Opening cash',
                  amount: register.openingCash,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AmountCard(
                  label: 'Expected total',
                  amount: snapshot.data?.expectedTotal,
                  icon: Icons.summarize_outlined,
                  loading: snapshot.connectionState == ConnectionState.waiting,
                ),
              ),
            ],
          ),
          if (snapshot.hasError) ...[
            const SizedBox(height: 12),
            Text(
              'Summary unavailable: ${_message(snapshot.error!)}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Cash movements',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _movement(true),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add cash'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _movement(false),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Remove cash'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB54747),
            ),
            onPressed: () => _close(snapshot.data),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Close and reconcile register'),
          ),
        ],
      ),
    );
  }

  Future<void> _open() async {
    final amount = double.tryParse(openingController.text.trim());
    if (locationId == null || amount == null || amount < 0) {
      _notice('Enter a valid opening cash amount.');
      return;
    }
    try {
      await ref
          .read(cashRegisterControllerProvider.notifier)
          .open(locationId!, amount);
    } catch (error) {
      _notice(_message(error));
    }
  }

  Future<void> _movement(bool cashIn) async {
    final amount = await _amountDialog(
      cashIn ? 'Add cash' : 'Remove cash',
      cashIn
          ? 'Record cash placed into the open drawer.'
          : 'Record cash taken from the open drawer.',
    );
    if (amount == null) return;
    try {
      final controller = ref.read(cashRegisterControllerProvider.notifier);
      if (cashIn) {
        await controller.cashIn(amount);
      } else {
        await controller.cashOut(amount);
      }
      if (mounted) _notice(cashIn ? 'Cash added.' : 'Cash removed.');
    } catch (error) {
      _notice(_message(error));
    }
  }

  Future<double?> _amountDialog(String title, String description) async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim());
              if (amount != null && amount > 0) {
                Navigator.pop(dialogContext, amount);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _close(CashRegisterSummary? summary) async {
    final cash = TextEditingController(
      text: (summary?.expectedTotals['cash'] ?? summary?.expectedTotal ?? 0)
          .toStringAsFixed(2),
    );
    final card = TextEditingController(text: '0.00');
    final cheque = TextEditingController(text: '0.00');
    final note = TextEditingController();
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close and reconcile'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Count the actual drawer and payment slips. Variances will be recorded in the register summary.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cash,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Actual cash *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: card,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Actual card total',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cheque,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Actual cheque total',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Closing note'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final actualCash = double.tryParse(cash.text.trim());
              if (actualCash == null || actualCash < 0) return;
              Navigator.pop(dialogContext, {
                'closing_amount': actualCash,
                'actual_totals': {
                  'cash': actualCash,
                  'card': double.tryParse(card.text.trim()) ?? 0,
                  'cheque': double.tryParse(cheque.text.trim()) ?? 0,
                },
                if (note.text.trim().isNotEmpty)
                  'closing_note': note.text.trim(),
              });
            },
            child: const Text('Close register'),
          ),
        ],
      ),
    );
    cash.dispose();
    card.dispose();
    cheque.dispose();
    note.dispose();
    if (payload == null) return;
    try {
      final result = await ref
          .read(cashRegisterControllerProvider.notifier)
          .close(payload);
      if (mounted) {
        _notice(
          'Register closed. Variance: ${_money(result.variance.values.fold(0, (a, b) => a + b))}',
        );
      }
    } catch (error) {
      _notice(_message(error));
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(22, 18, 12, 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE4EAE7))),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F3EF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.point_of_sale, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cash register',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              Text(
                'Open, manage and reconcile the cashier drawer.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

class _RegisterBanner extends StatelessWidget {
  const _RegisterBanner({
    required this.icon,
    required this.title,
    required this.description,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F7F5),
      border: Border.all(color: const Color(0xFFDDE8E3)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 30, color: AppColors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(description, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.amount,
    required this.icon,
    this.loading = false,
  });
  final String label;
  final double? amount;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE0E7E3)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          loading ? 'Loading…' : _money(amount ?? 0),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFDDF2E8),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _money(double value) => '₹${value.toStringAsFixed(2)}';

String _dateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} $hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _message(Object error) => error is ApiException
    ? error.message
    : error.toString().replaceFirst('Bad state: ', '');
