import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:eazy_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/entities.dart';
import '../../store/app_store.dart';
import '../../settings/application/pos_operating_mode_controller.dart';
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
  ConnectorAccess? _selectedForAccess;

  @override
  void dispose() {
    openingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final register = ref.watch(cashRegisterControllerProvider);
    final accessState = ref.watch(posRoleAccessProvider);
    final access = accessState.asData?.value.access;
    final locations = access == null
        ? <BusinessLocation>[]
        : ref
              .watch(appStoreProvider)
              .locations
              .where((item) => access.allowsLocation(item.id))
              .toList(growable: false);
    if (!identical(_selectedForAccess, access)) {
      _selectedForAccess = access;
      locationId = access?.defaultLocationId;
    }
    if (access != null && !locations.any((item) => item.id == locationId)) {
      locationId =
          access.defaultLocationId != null &&
              locations.any((item) => item.id == access.defaultLocationId)
          ? access.defaultLocationId
          : locations.firstOrNull?.id;
    }
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
            child: accessState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _ErrorState(
                message:
                    'Unable to verify your allowed POS locations. Reconnect and retry.',
                onRetry: () => ref.invalidate(posRoleAccessProvider),
              ),
              data: (_) => register.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorState(
                  message: _message(error),
                  onRetry: () => ref
                      .read(cashRegisterControllerProvider.notifier)
                      .refresh(),
                ),
                data: (value) =>
                    value != null && !access!.allowsLocation(value.locationId)
                    ? _ErrorState(
                        message:
                            'This register belongs to a location that is not allowed for this account.',
                        onRetry: () {
                          ref.invalidate(posRoleAccessProvider);
                          ref.invalidate(cashRegisterControllerProvider);
                        },
                      )
                    : value == null
                    ? _closedView(locations)
                    : _openView(value, locations),
              ),
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
      if (locations.isEmpty) ...[
        const Text(
          'No POS locations are assigned to this account.',
          style: TextStyle(color: AppColors.danger),
        ),
        const SizedBox(height: 16),
      ],
      DropdownButtonFormField<String>(
        initialValue: locationId,
        decoration: InputDecoration(
          labelText: context.tr('Business location'),
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
        decoration: InputDecoration(
          labelText: context.tr('Opening cash'),
          prefixIcon: Icon(Icons.payments_outlined),
          helperText: context.tr('Cash physically available in the drawer.'),
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
            onPressed: snapshot.data == null
                ? null
                : () => _close(snapshot.data!),
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
              decoration: InputDecoration(labelText: context.tr('Amount')),
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

  Future<void> _close(CashRegisterSummary summary) async {
    final paymentLabels = {
      for (final option in ref.read(appStoreProvider).paymentOptions)
        option.code: option.label,
    };
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RegisterReconciliationDialog(
        summary: summary,
        paymentLabels: paymentLabels,
      ),
    );
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

class _RegisterReconciliationDialog extends StatefulWidget {
  const _RegisterReconciliationDialog({
    required this.summary,
    required this.paymentLabels,
  });

  final CashRegisterSummary summary;
  final Map<String, String> paymentLabels;

  @override
  State<_RegisterReconciliationDialog> createState() =>
      _RegisterReconciliationDialogState();
}

class _RegisterReconciliationDialogState
    extends State<_RegisterReconciliationDialog> {
  late final Map<String, TextEditingController> _actualControllers;
  final _noteController = TextEditingController();

  List<String> get _methods {
    const preferred = [
      'cash',
      'card',
      'cheque',
      'bank_transfer',
      'other',
      'custom_pay_1',
      'custom_pay_2',
      'custom_pay_3',
      'custom_pay_4',
      'custom_pay_5',
      'custom_pay_6',
      'custom_pay_7',
    ];
    final available = <String>{
      ...widget.summary.expectedTotals.keys,
      ...widget.summary.actualTotals.keys,
    };
    final visible = available.where(_shouldShowMethod).toSet();
    return [
      ...preferred.where(visible.contains),
      ...visible.where((method) => !preferred.contains(method)),
    ];
  }

  bool _shouldShowMethod(String method) {
    if (!method.toLowerCase().startsWith('custom_pay_')) return true;

    const tolerance = 0.000001;
    return (widget.summary.expectedTotals[method] ?? 0).abs() > tolerance ||
        (widget.summary.actualTotals[method] ?? 0).abs() > tolerance ||
        (widget.summary.variance[method] ?? 0).abs() > tolerance;
  }

  @override
  void initState() {
    super.initState();
    _actualControllers = {
      for (final method in _methods)
        method: TextEditingController(
          text:
              (widget.summary.actualTotals[method] ??
                      (method == 'cash'
                          ? widget.summary.expectedTotals[method]
                          : 0) ??
                      0)
                  .toStringAsFixed(2),
        )..addListener(_changed),
    };
  }

  @override
  void dispose() {
    for (final controller in _actualControllers.values) {
      controller
        ..removeListener(_changed)
        ..dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  double _actual(String method) =>
      double.tryParse(_actualControllers[method]?.text.trim() ?? '') ?? 0;

  double get _actualTotal =>
      _methods.fold(0, (total, method) => total + _actual(method));

  double _variance(String method) =>
      _actual(method) - (widget.summary.expectedTotals[method] ?? 0);

  @override
  Widget build(BuildContext context) {
    final totalVariance = _actualTotal - widget.summary.expectedTotal;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3EF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Close and reconcile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (widget.summary.registerId.isNotEmpty)
                      'Register #${widget.summary.registerId}',
                    if (widget.summary.status.isNotEmpty)
                      _statusLabel(widget.summary.status),
                    'Review expected totals and enter the amounts counted.',
                  ].join(' • '),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('Close'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: SizedBox(
          width: 780,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReconciliationTotals(
                expected: widget.summary.expectedTotal,
                actual: _actualTotal,
                variance: totalVariance,
              ),
              const SizedBox(height: 14),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) => Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDDE5E1)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (constraints.maxWidth >= 650)
                          const _ReconciliationTableHeader(),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _methods.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: Color(0xFFE7ECE9),
                            ),
                            itemBuilder: (_, index) {
                              final method = _methods[index];
                              return _ReconciliationRow(
                                method: method,
                                label: _paymentLabel(method),
                                expected:
                                    widget.summary.expectedTotals[method] ?? 0,
                                variance: _variance(method),
                                controller: _actualControllers[method]!,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  context.tr('Closing note'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                minLines: 1,
                maxLines: 2,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: context.tr(
                    'Add a note about this register closing (optional)',
                  ),
                  prefixIcon: const Icon(Icons.notes_rounded),
                  counterText: '',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Confirm and close register'),
        ),
      ],
    );
  }

  String _paymentLabel(String method) {
    final configured = widget.paymentLabels[method];
    if (configured != null && configured.trim().isNotEmpty) return configured;
    const labels = {
      'cash': 'Cash',
      'card': 'Card',
      'cheque': 'Cheque',
      'bank_transfer': 'Bank transfer',
      'other': 'Other',
    };
    if (labels[method] case final label?) return label;
    final custom = RegExp(r'^custom_pay_(\d+)$').firstMatch(method);
    return custom == null
        ? method.replaceAll('_', ' ')
        : 'Custom payment ${custom.group(1)}';
  }

  String _statusLabel(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'close' || normalized == 'closed'
        ? 'Closed'
        : normalized == 'open'
        ? 'Open'
        : status;
  }

  void _submit() {
    final actuals = {for (final method in _methods) method: _actual(method)};
    if (actuals.values.any((amount) => amount < 0)) return;
    Navigator.pop(context, {
      'closing_amount': actuals['cash'] ?? 0,
      'actual_totals': actuals,
      if (_noteController.text.trim().isNotEmpty)
        'closing_note': _noteController.text.trim(),
    });
  }
}

class _ReconciliationTotals extends StatelessWidget {
  const _ReconciliationTotals({
    required this.expected,
    required this.actual,
    required this.variance,
  });

  final double expected;
  final double actual;
  final double variance;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = [
        _SummaryMetric(
          label: 'Expected',
          value: expected,
          icon: Icons.toll_outlined,
        ),
        _SummaryMetric(
          label: 'Counted',
          value: actual,
          icon: Icons.calculate_outlined,
        ),
        _SummaryMetric(
          label: 'Variance',
          value: variance,
          icon: Icons.warning_amber_rounded,
          variance: true,
        ),
      ];
      if (constraints.maxWidth < 520) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 8),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: 8),
            cards[2],
          ],
        );
      }
      return Row(
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(child: cards[index]),
          ],
        ],
      );
    },
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.variance = false,
  });

  final String label;
  final double value;
  final IconData icon;
  final bool variance;

  @override
  Widget build(BuildContext context) {
    final color = !variance || value == 0
        ? AppColors.primary
        : value < 0
        ? const Color(0xFFB54747)
        : const Color(0xFFB7791F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        border: Border.all(color: color.withValues(alpha: .18)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _money(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
        ],
      ),
    );
  }
}

class _ReconciliationRow extends StatelessWidget {
  const _ReconciliationRow({
    required this.method,
    required this.label,
    required this.expected,
    required this.variance,
    required this.controller,
  });

  final String method;
  final String label;
  final double expected;
  final double variance;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final input = SizedBox(
        width: constraints.maxWidth < 650 ? double.infinity : 170,
        child: TextField(
          controller: controller,
          textAlign: TextAlign.end,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: 'SAR ',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          ),
        ),
      );
      final details = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _money(expected),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          _VarianceChip(value: variance),
        ],
      );
      final identity = Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _paymentIcon(method),
              size: 19,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
      if (constraints.maxWidth < 650) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: identity),
                  details,
                ],
              ),
              const SizedBox(height: 10),
              input,
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(
          children: [
            Expanded(flex: 3, child: identity),
            Expanded(
              flex: 2,
              child: Text(
                _money(expected),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(flex: 2, child: _VarianceChip(value: variance)),
            Expanded(
              flex: 2,
              child: Align(alignment: Alignment.centerRight, child: input),
            ),
          ],
        ),
      );
    },
  );
}

class _ReconciliationTableHeader extends StatelessWidget {
  const _ReconciliationTableHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
    color: const Color(0xFFF7F9F8),
    child: const Row(
      children: [
        Expanded(flex: 3, child: _TableHeading('PAYMENT METHOD')),
        Expanded(flex: 2, child: _TableHeading('EXPECTED')),
        Expanded(flex: 2, child: _TableHeading('VARIANCE')),
        Expanded(flex: 2, child: _TableHeading('COUNTED')),
      ],
    ),
  );
}

class _TableHeading extends StatelessWidget {
  const _TableHeading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: AppColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: .7,
    ),
  );
}

class _VarianceChip extends StatelessWidget {
  const _VarianceChip({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value == 0
        ? AppColors.primary
        : value < 0
        ? const Color(0xFFB54747)
        : const Color(0xFFB7791F);
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            '${value > 0 ? '+' : ''}${_money(value)}',
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _paymentIcon(String method) => switch (method) {
  'cash' => Icons.payments_outlined,
  'card' => Icons.credit_card_outlined,
  'cheque' => Icons.receipt_long_outlined,
  'bank_transfer' => Icons.account_balance_outlined,
  _ => Icons.more_horiz_rounded,
};

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
          tooltip: context.tr('Refresh'),
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: context.tr('Close'),
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

String _money(double value) {
  final negative = value < 0;
  final parts = value.abs().toStringAsFixed(2).split('.');
  final digits = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  return 'SAR ${negative ? '-' : ''}$grouped.${parts.last}';
}

String _dateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} $hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _message(Object error) => error is ApiException
    ? error.message
    : error.toString().replaceFirst('Bad state: ', '');
