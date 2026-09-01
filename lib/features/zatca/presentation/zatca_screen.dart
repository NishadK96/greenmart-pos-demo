import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/ui.dart';
import '../../printers/application/printer_controller.dart';
import '../../printers/application/printer_document_service.dart';
import '../domain/zatca_entities.dart';
import 'zatca_controller.dart';

class ZatcaScreen extends ConsumerStatefulWidget {
  const ZatcaScreen({super.key});

  @override
  ConsumerState<ZatcaScreen> createState() => _ZatcaScreenState();
}

class _ZatcaScreenState extends ConsumerState<ZatcaScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(zatcaControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _ZatcaNavigation(
            selected: tab,
            onSelected: (value) => setState(() => tab = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (tab) {
              1 => const _TransactionsTab(isReturn: false),
              2 => const _TransactionsTab(isReturn: true),
              3 => const _SettingsTab(),
              _ => status.when(
                loading: () => const _ZatcaLoading(),
                error: (error, _) => _ZatcaError(
                  message: error.toString(),
                  onRetry: () => ref
                      .read(zatcaControllerProvider.notifier)
                      .refreshStatus(),
                ),
                data: (data) => RefreshIndicator(
                  onRefresh: () => ref
                      .read(zatcaControllerProvider.notifier)
                      .refreshStatus(),
                  child: ListView(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ZATCA e-invoicing',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Manage compliance, EGS devices and invoice submissions.',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          IconButton.outlined(
                            tooltip: 'Refresh status',
                            onPressed: () => ref
                                .read(zatcaControllerProvider.notifier)
                                .refreshStatus(),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _IntegrationBanner(status: data),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (_, constraints) => GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: constraints.maxWidth >= 850 ? 3 : 1,
                          childAspectRatio: constraints.maxWidth >= 850
                              ? 2.5
                              : 3.2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _Metric(
                              'Pending',
                              data.totals.pending,
                              Icons.schedule_outlined,
                              const Color(0xFFB7791F),
                            ),
                            _Metric(
                              'Successful',
                              data.totals.success,
                              Icons.verified_outlined,
                              const Color(0xFF16885F),
                            ),
                            _Metric(
                              'Failed',
                              data.totals.failed,
                              Icons.error_outline,
                              const Color(0xFFC94B4B),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Surface(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
                              child: Text(
                                'EGS devices / business locations',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (data.locations.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(28),
                                child: EmptyState(
                                  'No permitted business locations were returned.',
                                ),
                              )
                            else
                              for (final location in data.locations)
                                _LocationRow(
                                  location: location,
                                  enabled:
                                      data.installed &&
                                      data.subscriptionEnabled,
                                  onConfigure: () => showDialog<void>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) =>
                                        _OnboardingDialog(location: location),
                                  ),
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Surface(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.security_outlined,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Security: the six-digit Fatoora OTP is sent directly to the backend for onboarding and is never saved by this app. Certificates, private keys and client secrets remain backend-only.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _ZatcaNavigation extends StatelessWidget {
  const _ZatcaNavigation({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          icon: Icon(Icons.dashboard_outlined),
          label: Text('Overview'),
        ),
        ButtonSegment(
          value: 1,
          icon: Icon(Icons.receipt_long_outlined),
          label: Text('Sales invoices'),
        ),
        ButtonSegment(
          value: 2,
          icon: Icon(Icons.assignment_return_outlined),
          label: Text('Sale returns'),
        ),
        ButtonSegment(
          value: 3,
          icon: Icon(Icons.tune_outlined),
          label: Text('Settings'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onSelected(value.first),
      showSelectedIcon: false,
    ),
  );
}

class _ZatcaLoading extends StatelessWidget {
  const _ZatcaLoading();

  @override
  Widget build(BuildContext context) => Center(
    child: Surface(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text(
              'Loading ZATCA status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6),
            Text(
              'Checking the integration and permitted business locations. This should only take a few seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TransactionsTab extends ConsumerStatefulWidget {
  const _TransactionsTab({required this.isReturn});
  final bool isReturn;

  @override
  ConsumerState<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<_TransactionsTab> {
  final search = TextEditingController();
  final selected = <String>{};
  String status = '';
  int page = 1;
  bool syncing = false;
  late Future<ZatcaPage> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<ZatcaPage> _load() {
    final filter = ZatcaListFilter(
      status: status,
      search: search.text.trim(),
      page: page,
      perPage: 20,
    );
    final controller = ref.read(zatcaControllerProvider.notifier);
    return widget.isReturn
        ? controller.returns(filter)
        : controller.invoices(filter);
  }

  void _reload({bool firstPage = false}) {
    if (firstPage) {
      page = 1;
      selected.clear();
    }
    setState(() => future = _load());
  }

  void _togglePageSelection(List<ZatcaTransaction> items, bool selectedAll) {
    setState(() {
      final ids = items.map((item) => item.id);
      if (selectedAll) {
        selected.addAll(ids);
      } else {
        selected.removeAll(ids);
      }
    });
  }

  Future<void> _syncSelected() async {
    if (selected.isEmpty || syncing) return;
    setState(() => syncing = true);
    try {
      final controller = ref.read(zatcaControllerProvider.notifier);
      final result = widget.isReturn
          ? await controller.syncReturnsBulk(selected.toList())
          : await controller.syncInvoicesBulk(selected.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.successful} synchronized, ${result.failed} failed.',
          ),
        ),
      );
      selected.clear();
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (_, constraints) {
          final compact = constraints.maxWidth < 720;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isReturn ? 'ZATCA sale returns' : 'ZATCA sales invoices',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                widget.isReturn
                    ? 'Select one or more returns and send them to ZATCA together.'
                    : 'Select one or more invoices and send them to ZATCA together.',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          );
          final action = FilledButton.icon(
            onPressed: selected.isEmpty || syncing ? null : _syncSelected,
            icon: syncing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text('Send selected to ZATCA (${selected.length})'),
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 12), action],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    action,
                  ],
                );
        },
      ),
      const SizedBox(height: 14),
      Surface(
        child: LayoutBuilder(
          builder: (_, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: constraints.maxWidth < 680 ? constraints.maxWidth : 420,
                child: TextField(
                  controller: search,
                  onSubmitted: (_) => _reload(firstPage: true),
                  decoration: InputDecoration(
                    hintText: 'Search invoice, customer or mobile',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: () => _reload(firstPage: true),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'ZATCA status'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All statuses')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'not_synced',
                      child: Text('Not synced'),
                    ),
                    DropdownMenuItem(
                      value: 'success',
                      child: Text('Successful'),
                    ),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (value) {
                    status = value ?? '';
                    _reload(firstPage: true);
                  },
                ),
              ),
              IconButton.outlined(
                tooltip: 'Refresh',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: FutureBuilder<ZatcaPage>(
          future: future,
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ZatcaError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }
            final data = snapshot.requireData;
            if (data.items.isEmpty) {
              return const Surface(
                child: EmptyState('No ZATCA records match these filters.'),
              );
            }
            final pageIds = data.items.map((item) => item.id).toSet();
            final selectedOnPage = pageIds.intersection(selected).length;
            final allOnPageSelected =
                pageIds.isNotEmpty && selectedOnPage == pageIds.length;
            return Surface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Row(
                      children: [
                        Checkbox(
                          value: allOnPageSelected,
                          tristate: selectedOnPage > 0 && !allOnPageSelected,
                          onChanged: (checked) =>
                              _togglePageSelection(data.items, checked == true),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _togglePageSelection(
                              data.items,
                              !allOnPageSelected,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                allOnPageSelected
                                    ? 'All ${data.items.length} ${widget.isReturn ? 'returns' : 'invoices'} on this page selected'
                                    : 'Select all ${data.items.length} ${widget.isReturn ? 'returns' : 'invoices'} on this page',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (selected.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(selected.clear),
                            child: const Text('Clear selection'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: data.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = data.items[index];
                        return CheckboxListTile(
                          value: selected.contains(item.id),
                          onChanged: (checked) => setState(() {
                            checked == true
                                ? selected.add(item.id)
                                : selected.remove(item.id);
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.invoiceNo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              StatusBadge(
                                item.status,
                                color: _zatcaStatusColor(item.status),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${item.customerName ?? 'Walk-in Customer'} • ${item.locationName ?? 'Location unavailable'}\n${item.transactionDate} • ${money(toPaise(item.total))}',
                          ),
                          secondary: IconButton(
                            tooltip: 'Open ZATCA record',
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => _TransactionDialog(
                                item: item,
                                isReturn: widget.isReturn,
                                onChanged: _reload,
                              ),
                            ),
                            icon: const Icon(Icons.more_vert),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text('${data.total} records')),
                        IconButton(
                          onPressed: page > 1
                              ? () {
                                  page--;
                                  _reload();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${data.currentPage} / ${data.lastPage}'),
                        IconButton(
                          onPressed: page < data.lastPage
                              ? () {
                                  page++;
                                  _reload();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right),
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
    ],
  );
}

Color _zatcaStatusColor(String status) => switch (status.toLowerCase()) {
  'success' || 'successful' => AppColors.primary,
  'failed' => const Color(0xFFC94B4B),
  _ => const Color(0xFFB7791F),
};

class _TransactionDialog extends ConsumerStatefulWidget {
  const _TransactionDialog({
    required this.item,
    required this.isReturn,
    required this.onChanged,
  });
  final ZatcaTransaction item;
  final bool isReturn;
  final VoidCallback onChanged;

  @override
  ConsumerState<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends ConsumerState<_TransactionDialog> {
  bool busy = false;

  Future<void> _run(
    Future<void> Function(ZatcaController controller) task,
  ) async {
    setState(() => busy = true);
    try {
      await task(ref.read(zatcaControllerProvider.notifier));
      widget.onChanged();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('ZATCA • ${widget.item.invoiceNo}'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Submission status')),
              StatusBadge(
                widget.item.status,
                color: _zatcaStatusColor(widget.item.status),
              ),
            ],
          ),
          const Divider(height: 28),
          _detail('Customer', widget.item.customerName ?? 'Walk-in Customer'),
          _detail('Location', widget.item.locationName ?? 'Unavailable'),
          _detail('Transaction date', widget.item.transactionDate),
          _detail('Total', money(toPaise(widget.item.total))),
          if (widget.item.parentInvoiceNo != null)
            _detail('Parent invoice', widget.item.parentInvoiceNo!),
        ],
      ),
    ),
    actions: [
      FilledButton.icon(
        onPressed: busy
            ? null
            : () => _run((controller) async {
                if (widget.isReturn) {
                  await controller.syncReturnsBulk([widget.item.id]);
                } else {
                  await controller.syncInvoicesBulk([widget.item.id]);
                }
              }),
        icon: const Icon(Icons.sync),
        label: const Text('Submit / retry'),
      ),
      if (widget.isReturn) ...[
        OutlinedButton(
          onPressed: busy
              ? null
              : () => _run((controller) async {
                  final qr = await controller.returnQr(widget.item.id);
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'QR payload available (${qr.value.length} characters).',
                        ),
                      ),
                    );
                }),
          child: const Text('QR payload'),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => _run((controller) async {
                  final file = await controller.downloadReturnXml(
                    widget.item.id,
                  );
                  await FilePicker.platform.saveFile(
                    fileName: file.fileName,
                    bytes: file.bytes,
                  );
                }),
          child: const Text('XML'),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => _run((controller) async {
                  final file = await controller.downloadReturnPdf(
                    widget.item.id,
                  );
                  final printerState = ref.read(printerControllerProvider);
                  await PrinterDocumentService.printPdfBytes(
                    file.bytes,
                    name: file.fileName,
                    printer: printerState.selectedPrinter,
                    previewBeforePrinting:
                        printerState.settings.previewBeforePrinting,
                  );
                }),
          child: const Text('Print PDF/A-3'),
        ),
      ],
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();
  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late Future<(ZatcaSettings, ZatcaSyncSummary)> future;
  ZatcaSettings? settings;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<(ZatcaSettings, ZatcaSyncSummary)> _load() async {
    final controller = ref.read(zatcaControllerProvider.notifier);
    final result = await (controller.settings(), controller.syncSummary()).wait;
    settings = result.$1;
    return result;
  }

  Future<void> _save() async {
    final value = settings;
    if (value == null || saving) return;
    setState(() => saving = true);
    try {
      settings = await ref
          .read(zatcaControllerProvider.notifier)
          .updateSettings({
            'sync_frequency': value.syncFrequency,
            'disable_discount': value.disableDiscount,
            'disable_order_tax': value.disableOrderTax,
            'default_sales_discount': value.defaultSalesDiscount,
          });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ZATCA settings saved.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _update({String? frequency, bool? discount, bool? orderTax}) {
    final value = settings!;
    setState(
      () => settings = ZatcaSettings(
        syncFrequency: frequency ?? value.syncFrequency,
        disableDiscount: discount ?? value.disableDiscount,
        disableOrderTax: orderTax ?? value.disableOrderTax,
        defaultSalesDiscount: value.defaultSalesDiscount,
        locations: value.locations,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(ZatcaSettings, ZatcaSyncSummary)>(
    future: future,
    builder: (_, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return _ZatcaError(
          message: snapshot.error.toString(),
          onRetry: () => setState(() => future = _load()),
        );
      final summary = snapshot.requireData.$2;
      final value = settings!;
      return ListView(
        children: [
          const Text(
            'ZATCA settings',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Configure automatic reporting and review synchronization health.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (_, constraints) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: constraints.maxWidth >= 850 ? 4 : 2,
              childAspectRatio: constraints.maxWidth >= 850 ? 2.2 : 1.7,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _Metric(
                  'Total invoices',
                  summary.totalInvoices,
                  Icons.receipt_long_outlined,
                  const Color(0xFF3976C4),
                ),
                _Metric(
                  'Pending',
                  summary.pending,
                  Icons.schedule_outlined,
                  const Color(0xFFB7791F),
                ),
                _Metric(
                  'Successful',
                  summary.successful,
                  Icons.verified_outlined,
                  AppColors.primary,
                ),
                _Metric(
                  'Failed',
                  summary.failed,
                  Icons.error_outline,
                  const Color(0xFFC94B4B),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Submission policy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: value.syncFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Auto sync frequency',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'disable',
                      child: Text('Manual only'),
                    ),
                    DropdownMenuItem(
                      value: 'instant',
                      child: Text('Instant — required for B2B clearance'),
                    ),
                    DropdownMenuItem(
                      value: 'daily',
                      child: Text('Daily — B2C reporting queue'),
                    ),
                  ],
                  onChanged: (frequency) => _update(frequency: frequency),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disable invoice discounts'),
                  subtitle: const Text('Prevent discounts on ZATCA invoices.'),
                  value: value.disableDiscount,
                  onChanged: (enabled) => _update(discount: enabled),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disable order-level tax'),
                  subtitle: const Text('Use line-level tax calculation only.'),
                  value: value.disableOrderTax,
                  onChanged: (enabled) => _update(orderTax: enabled),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save settings'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business location sync windows',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final location in value.locations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.store_outlined),
                    ),
                    title: Text(location.name),
                    subtitle: Text(
                      location.syncFrom == null
                          ? 'Sync start not configured'
                          : 'Sync from ${location.syncFrom}',
                    ),
                  ),
                const Divider(),
                Text(
                  'Developer synced: ${summary.developerSynced}  •  Simulation synced: ${summary.simulationSynced}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _IntegrationBanner extends StatelessWidget {
  const _IntegrationBanner({required this.status});
  final ZatcaIntegrationStatus status;
  @override
  Widget build(BuildContext context) {
    final ready = status.installed && status.subscriptionEnabled;
    return Surface(
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: ready
                ? const Color(0xFFE3F5EF)
                : const Color(0xFFFFE9E5),
            child: Icon(
              ready
                  ? Icons.verified_user_outlined
                  : Icons.warning_amber_rounded,
              color: ready ? AppColors.primary : const Color(0xFFC94B4B),
            ),
          ),
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'ZATCA module available' : 'ZATCA setup unavailable',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Sync frequency: ${status.syncFrequency}${status.version == null ? '' : ' • v${status.version}'}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          StatusBadge(
            status.installed ? 'Installed' : 'Not installed',
            color: status.installed
                ? AppColors.primary
                : const Color(0xFFC94B4B),
          ),
          StatusBadge(
            status.subscriptionEnabled
                ? 'Subscription enabled'
                : 'Subscription disabled',
            color: status.subscriptionEnabled
                ? AppColors.primary
                : const Color(0xFFC94B4B),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Surface(
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ],
    ),
  );
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.location,
    required this.enabled,
    required this.onConfigure,
  });
  final ZatcaLocationStatus location;
  final bool enabled;
  final VoidCallback onConfigure;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final compact = constraints.maxWidth < 620;
      final details = Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEAF4F1),
            child: Icon(Icons.store_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  location.configured
                      ? '${location.portalMode ?? 'Configured'}${location.syncFrom == null ? '' : ' • Sync from ${location.syncFrom}'}'
                      : 'Device onboarding required',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
      final actions = Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusBadge(
            location.configured ? 'Configured' : 'Not configured',
            color: location.configured
                ? AppColors.primary
                : const Color(0xFFB7791F),
          ),
          OutlinedButton(
            onPressed: enabled ? onConfigure : null,
            child: Text(location.configured ? 'Reconfigure' : 'Onboard device'),
          ),
        ],
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE4EAE7))),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: actions),
                ],
              )
            : Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 12),
                  actions,
                ],
              ),
      );
    },
  );
}

class _OnboardingDialog extends ConsumerStatefulWidget {
  const _OnboardingDialog({required this.location});
  final ZatcaLocationStatus location;
  @override
  ConsumerState<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends ConsumerState<_OnboardingDialog> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  String portalMode = 'simulation';
  String invoiceType = '1100';
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in [
        'otp',
        'email',
        'common',
        'unit',
        'organization',
        'vat',
        'vatName',
        'address',
        'category',
        'crn',
        'street',
        'building',
        'plot',
        'district',
        'city',
        'postal',
      ])
        key: TextEditingController(),
    };
    fields['common']!.text = '${widget.location.name} Device';
    fields['unit']!.text = widget.location.name;
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880, maxHeight: 760),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE3F5EF),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Onboard ZATCA device',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.location.name,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const Text(
                    'Environment & authorization',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _grid([
                    DropdownButtonFormField<String>(
                      initialValue: portalMode,
                      decoration: const InputDecoration(
                        labelText: 'Portal environment *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'developer-portal',
                          child: Text('Developer portal'),
                        ),
                        DropdownMenuItem(
                          value: 'simulation',
                          child: Text('Simulation'),
                        ),
                        DropdownMenuItem(
                          value: 'core',
                          child: Text('Production / Core'),
                        ),
                      ],
                      onChanged: (value) => portalMode = value ?? portalMode,
                    ),
                    TextFormField(
                      controller: fields['otp'],
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Fatoora OTP *',
                        counterText: '',
                        helperText: 'Used once and never stored',
                      ),
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value ?? '')
                          ? null
                          : 'Enter the 6-digit OTP',
                    ),
                    TextFormField(
                      controller: fields['email'],
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Device contact email *',
                      ),
                      validator: required,
                    ),
                  ]),
                  const SizedBox(height: 18),
                  const Text(
                    'Organization',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _grid([
                    _field('common', 'Device / common name *'),
                    _field('unit', 'Organization unit / branch *'),
                    _field('organization', 'Legal organization name *'),
                    TextFormField(
                      controller: fields['vat'],
                      keyboardType: TextInputType.number,
                      maxLength: 15,
                      decoration: const InputDecoration(
                        labelText: 'Saudi VAT number *',
                        counterText: '',
                      ),
                      validator: (value) =>
                          RegExp(r'^3\d{13}3$').hasMatch(value ?? '')
                          ? null
                          : 'Enter a valid 15-digit VAT number',
                    ),
                    _field('vatName', 'VAT display name'),
                    _field('crn', 'Commercial registration no.'),
                    DropdownButtonFormField<String>(
                      initialValue: invoiceType,
                      decoration: const InputDecoration(
                        labelText: 'Invoice type *',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '1100',
                          child: Text('Both standard & simplified'),
                        ),
                        DropdownMenuItem(
                          value: '0100',
                          child: Text('Simplified only'),
                        ),
                        DropdownMenuItem(
                          value: '1000',
                          child: Text('Standard only'),
                        ),
                      ],
                      onChanged: (value) => invoiceType = value ?? invoiceType,
                    ),
                    _field('category', 'Business category *'),
                  ]),
                  const SizedBox(height: 18),
                  const Text(
                    'Registered address',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _grid([
                    _field('address', 'National short address *'),
                    _field('street', 'Street'),
                    _field('building', 'Building number'),
                    _field('plot', 'Secondary / plot number'),
                    _field('district', 'District'),
                    _field('city', 'City'),
                    _field('postal', 'Postal code'),
                  ]),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFC94B4B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: saving ? null : _submit,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(saving ? 'Onboarding…' : 'Onboard device'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(String key, String label) => TextFormField(
    controller: fields[key],
    decoration: InputDecoration(labelText: label),
    validator: label.endsWith('*') ? required : null,
  );
  Widget _grid(List<Widget> children) => LayoutBuilder(
    builder: (_, constraints) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final child in children)
          SizedBox(
            width: constraints.maxWidth >= 720
                ? (constraints.maxWidth - 24) / 3
                : constraints.maxWidth,
            child: child,
          ),
      ],
    ),
  );
  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(zatcaControllerProvider.notifier)
          .onboard(
            widget.location.id,
            ZatcaOnboardingDraft(
              portalMode: portalMode,
              otp: fields['otp']!.text,
              email: fields['email']!.text.trim(),
              commonName: fields['common']!.text.trim(),
              organizationUnitName: fields['unit']!.text.trim(),
              organizationName: fields['organization']!.text.trim(),
              vatNumber: fields['vat']!.text.trim(),
              vatName: fields['vatName']!.text.trim(),
              invoiceType: invoiceType,
              registeredAddress: fields['address']!.text.trim(),
              businessCategory: fields['category']!.text.trim(),
              crn: fields['crn']!.text.trim(),
              streetName: fields['street']!.text.trim(),
              buildingNumber: fields['building']!.text.trim(),
              plotIdentification: fields['plot']!.text.trim(),
              subDivisionName: fields['district']!.text.trim(),
              cityName: fields['city']!.text.trim(),
              postalNumber: fields['postal']!.text.trim(),
            ),
          );
      fields['otp']!.clear();
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      fields['otp']!.clear();
      if (mounted)
        setState(() {
          saving = false;
          error = exception.toString();
        });
    }
  }
}

class _ZatcaError extends StatelessWidget {
  const _ZatcaError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Surface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: Color(0xFFC94B4B),
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load ZATCA integration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showZatcaInvoiceDialog(
  BuildContext context,
  WidgetRef ref,
  Sale sale,
) async {
  final saleId = sale.serverId;
  if (saleId == null || saleId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This sale has no server transaction ID.')),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _InvoiceDialog(sale: sale),
  );
}

Future<void> showZatcaReturnDialog(
  BuildContext context,
  WidgetRef ref,
  SaleReturnRecord record,
) async {
  if (record.id.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This return has no server transaction ID.'),
      ),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReturnSyncDialog(record: record),
  );
}

class _ReturnSyncDialog extends ConsumerStatefulWidget {
  const _ReturnSyncDialog({required this.record});
  final SaleReturnRecord record;

  @override
  ConsumerState<_ReturnSyncDialog> createState() => _ReturnSyncDialogState();
}

class _ReturnSyncDialogState extends ConsumerState<_ReturnSyncDialog> {
  bool working = false;
  ZatcaOperationResult? result;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    final successful = result?.success == true;
    final statusColor = result == null
        ? const Color(0xFFB7791F)
        : successful
        ? AppColors.primary
        : const Color(0xFFC94B4B);
    final reference = widget.record.invoiceNo.isEmpty
        ? 'Return #${widget.record.id}'
        : widget.record.invoiceNo;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 28,
        vertical: compact ? 18 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 28,
                  compact ? 20 : 26,
                  compact ? 12 : 20,
                  18,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: statusColor.withValues(alpha: .10),
                      child: Icon(
                        successful
                            ? Icons.verified_outlined
                            : Icons.assignment_return_outlined,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reference,
                            style: TextStyle(
                              fontSize: compact ? 21 : 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'ZATCA credit note submission',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: working ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.all(compact ? 20 : 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .075),
                        border: Border.all(
                          color: statusColor.withValues(alpha: .18),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            successful
                                ? Icons.check_circle_outline
                                : result == null
                                ? Icons.info_outline
                                : Icons.error_outline,
                            color: statusColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result?.message ??
                                  'Submit this sales return to create and send its ZATCA credit note. The backend validates, signs and transmits the document.',
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                          if (result != null) ...[
                            const SizedBox(width: 10),
                            StatusBadge(result!.status, color: statusColor),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _returnDetail(
                      'Original invoice',
                      widget.record.parentInvoiceNo,
                    ),
                    const Divider(height: 1),
                    _returnDetail('Customer', widget.record.customerName),
                    const Divider(height: 1),
                    _returnDetail('Refund total', money(widget.record.total)),
                    const SizedBox(height: 14),
                    const Text(
                      'Return status and signed credit-note downloads are not exposed by the current backend API. This screen reports only the result returned by the submit/retry endpoint.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 28,
                  16,
                  compact ? 20 : 28,
                  compact ? 20 : 24,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE0E7E4))),
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: working ? null : _sync,
                            icon: working
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            label: Text(
                              result == null
                                  ? 'Submit credit note'
                                  : 'Check / resubmit',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: working
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          OutlinedButton(
                            onPressed: working
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: working ? null : _sync,
                            icon: working
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            label: Text(
                              result == null
                                  ? 'Submit credit note'
                                  : 'Check / resubmit',
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

  Widget _returnDetail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Future<void> _sync() async {
    setState(() => working = true);
    try {
      final response = await ref
          .read(zatcaControllerProvider.notifier)
          .syncReturn(widget.record.id);
      if (mounted) setState(() => result = response);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }
}

class _InvoiceDialog extends ConsumerStatefulWidget {
  const _InvoiceDialog({required this.sale});
  final Sale sale;
  @override
  ConsumerState<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends ConsumerState<_InvoiceDialog> {
  late Future<ZatcaInvoiceStatus> future;
  bool working = false;
  @override
  void initState() {
    super.initState();
    future = ref
        .read(zatcaControllerProvider.notifier)
        .invoiceStatus(widget.sale.serverId!);
  }

  void reload() => setState(
    () => future = ref
        .read(zatcaControllerProvider.notifier)
        .invoiceStatus(widget.sale.serverId!),
  );
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 620;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 28,
        vertical: compact ? 18 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: size.height - (compact ? 36 : 56),
        ),
        child: FutureBuilder<ZatcaInvoiceStatus>(
          future: future,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const SizedBox(
                height: 320,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading ZATCA invoice status…'),
                    ],
                  ),
                ),
              );
            if (snapshot.hasError)
              return SizedBox(
                height: 320,
                child: _ZatcaError(
                  message: snapshot.error.toString(),
                  onRetry: reload,
                ),
              );
            final data = snapshot.data!;
            final document = data.document;
            final success = data.status.toLowerCase() == 'success';
            final statusColor = success
                ? AppColors.primary
                : data.status.toLowerCase() == 'failed'
                ? const Color(0xFFC94B4B)
                : const Color(0xFFB7791F);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 20 : 28,
                      compact ? 20 : 26,
                      compact ? 12 : 20,
                      18,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            success
                                ? Icons.verified_outlined
                                : Icons.receipt_long_outlined,
                            color: statusColor,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.sale.invoiceNo,
                                style: TextStyle(
                                  fontSize: compact ? 22 : 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'ZATCA e-invoice details',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: working
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.all(compact ? 20 : 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .075),
                            border: Border.all(
                              color: statusColor.withValues(alpha: .16),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                success
                                    ? Icons.check_circle_outline
                                    : Icons.schedule_outlined,
                                color: statusColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      success
                                          ? 'Invoice submitted successfully'
                                          : 'Invoice awaiting submission',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      success
                                          ? 'Signed and accepted in the ${document?.portalMode ?? 'configured'} environment.'
                                          : 'Submit this invoice to generate its compliance data.',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(data.status, color: statusColor),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Compliance information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE0E7E4)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              _detail(
                                Icons.numbers_outlined,
                                'Invoice counter value (ICV)',
                                document?.icv ?? 'Not generated',
                              ),
                              const Divider(height: 1),
                              _detail(
                                Icons.fingerprint,
                                'Unique identifier (UUID)',
                                document?.uuid ?? 'Not generated',
                              ),
                              const Divider(height: 1),
                              _detail(
                                Icons.cloud_outlined,
                                'Environment',
                                document?.portalMode ?? '—',
                              ),
                              const Divider(height: 1),
                              _detail(
                                Icons.schedule_outlined,
                                'Signing time',
                                document?.signingTime ?? '—',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Invoice documents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _documentButton(
                              icon: Icons.qr_code_2,
                              label: 'View QR',
                              onPressed: document == null || working
                                  ? null
                                  : _showQr,
                            ),
                            _documentButton(
                              icon: Icons.code,
                              label: 'Download XML',
                              onPressed: document == null || working
                                  ? null
                                  : _downloadXml,
                            ),
                            _documentButton(
                              icon: Icons.picture_as_pdf_outlined,
                              label: 'Download PDF/A-3',
                              onPressed: document == null || working
                                  ? null
                                  : _downloadPdf,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 20 : 28,
                      16,
                      compact ? 20 : 28,
                      compact ? 20 : 24,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE0E7E4))),
                    ),
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                onPressed: working ? null : _sync,
                                icon: const Icon(Icons.sync),
                                label: Text(
                                  success
                                      ? 'Check status again'
                                      : 'Submit invoice',
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: working
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              OutlinedButton(
                                onPressed: working
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                onPressed: working ? null : _sync,
                                icon: const Icon(Icons.sync),
                                label: Text(
                                  success
                                      ? 'Check status again'
                                      : 'Submit invoice',
                                ),
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
    );
  }

  Widget _detail(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: SelectableText(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _documentButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 19),
    label: Text(label),
  );
  Future<void> _run(Future<void> Function() action) async {
    setState(() => working = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _sync() => _run(() async {
    final result = await ref
        .read(zatcaControllerProvider.notifier)
        .syncInvoice(widget.sale.serverId!);
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    reload();
  });
  Future<void> _showQr() => _run(() async {
    final qr = await ref
        .read(zatcaControllerProvider.notifier)
        .qr(widget.sale.serverId!);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ZATCA QR payload'),
        content: SizedBox(width: 460, child: SelectableText(qr.value)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  });
  Future<void> _downloadXml() => _run(() async {
    final file = await ref
        .read(zatcaControllerProvider.notifier)
        .downloadXml(widget.sale.serverId!);
    await FilePicker.platform.saveFile(
      dialogTitle: 'Save signed ZATCA XML',
      fileName: file.fileName,
      bytes: file.bytes,
    );
  });
  Future<void> _downloadPdf() => _run(() async {
    final file = await ref
        .read(zatcaControllerProvider.notifier)
        .downloadPdf(widget.sale.serverId!);
    final printerState = ref.read(printerControllerProvider);
    await PrinterDocumentService.printPdfBytes(
      file.bytes,
      name: file.fileName,
      printer: printerState.selectedPrinter,
      previewBeforePrinting: printerState.settings.previewBeforePrinting,
    );
  });
}
