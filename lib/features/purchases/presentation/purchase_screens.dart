import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/ui.dart';
import '../../store/app_store.dart';
import '../../printers/application/printer_controller.dart';
import '../domain/purchase_entities.dart';
import 'purchase_controller.dart';
import 'purchase_document_export.dart';
import 'purchase_workspace_components.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});
  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  String search = '';
  String statusFilter = '', supplierFilter = '';
  PurchaseDateFilter dateFilter = PurchaseDateFilter.all;
  final selectedIds = <String>{};
  int page = 0, rowsPerPage = 20;
  bool openingDetail = false;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!tabs.indexIsChanging) {
          setState(() {
            selectedIds.clear();
            page = 0;
          });
        }
      });
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  PurchaseDocumentType get type => PurchaseDocumentType.values[tabs.index];

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(purchaseControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 22,
        18,
        compact ? 14 : 22,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(
            'Purchases',
            subtitle:
                'Manage orders, invoices and supplier returns in one place.',
            action: FilledButton.icon(
              onPressed: workspace.hasValue
                  ? () => _openForm(type, workspace.requireValue)
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                compact ? 'New order' : 'New ${_label(type, singular: true)}',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: workspace.when(
              loading: () => const PurchaseWorkspaceSkeleton(),
              error: (_, __) => PurchaseLoadError(
                onRetry: () => ref.invalidate(purchaseControllerProvider),
              ),
              data: _purchaseWorkspace,
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseWorkspace(PurchaseWorkspaceState workspace) {
    final documents = workspace.forType(type);
    final query = search.trim().toLowerCase();
    final rows = documents.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.reference.toLowerCase().contains(query) ||
          item.supplierName.toLowerCase().contains(query) ||
          item.status.toLowerCase().contains(query);
      final matchesStatus = statusFilter.isEmpty || item.status == statusFilter;
      final matchesSupplier =
          supplierFilter.isEmpty || item.supplierId == supplierFilter;
      final now = DateTime.now();
      final start = switch (dateFilter) {
        PurchaseDateFilter.all => null,
        PurchaseDateFilter.last7Days => now.subtract(const Duration(days: 7)),
        PurchaseDateFilter.last30Days => now.subtract(const Duration(days: 30)),
        PurchaseDateFilter.thisMonth => DateTime(now.year, now.month),
      };
      final matchesDate = start == null || !item.date.isBefore(start);
      return matchesQuery && matchesStatus && matchesSupplier && matchesDate;
    }).toList();
    final maxPage = rows.isEmpty ? 0 : ((rows.length - 1) ~/ rowsPerPage);
    if (page > maxPage) page = maxPage;
    final start = page * rowsPerPage;
    final visibleRows = rows.skip(start).take(rowsPerPage).toList();
    final hasFilters =
        search.isNotEmpty ||
        statusFilter.isNotEmpty ||
        supplierFilter.isNotEmpty ||
        dateFilter != PurchaseDateFilter.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PurchaseSummarySection(workspace: workspace),
        const SizedBox(height: 12),
        PurchaseSegmentedTabs(
          controller: tabs,
          counts: [
            workspace.orders.length,
            workspace.invoices.length,
            workspace.returns.length,
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Surface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: selectedIds.isNotEmpty
                      ? PurchaseBulkBar(
                          count: selectedIds.length,
                          onClear: () => setState(selectedIds.clear),
                          onMarkCompleted: () => _bulkComplete(workspace),
                        )
                      : PurchaseToolbar(
                          search: search,
                          onSearchChanged: (value) => setState(() {
                            search = value;
                            page = 0;
                          }),
                          status: statusFilter,
                          onStatusChanged: (value) => setState(() {
                            statusFilter = value ?? '';
                            page = 0;
                          }),
                          supplierId: supplierFilter,
                          onSupplierChanged: (value) => setState(() {
                            supplierFilter = value ?? '';
                            page = 0;
                          }),
                          dateFilter: dateFilter,
                          onDateChanged: (value) => setState(() {
                            dateFilter = value ?? PurchaseDateFilter.all;
                            page = 0;
                          }),
                          suppliers: workspace.suppliers,
                          onClear: _clearFilters,
                          onRefresh: () =>
                              ref.invalidate(purchaseControllerProvider),
                          hasActiveFilters: hasFilters,
                        ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: PurchaseDataView(
                    rows: visibleRows,
                    type: type,
                    selectedIds: selectedIds,
                    onSelectionChanged: (id, selected) => setState(() {
                      selected ? selectedIds.add(id) : selectedIds.remove(id);
                    }),
                    onSelectAll: (selected) => setState(() {
                      if (selected) {
                        selectedIds.addAll(visibleRows.map((e) => e.id));
                      } else {
                        selectedIds.removeAll(visibleRows.map((e) => e.id));
                      }
                    }),
                    onOpen: _showDetail,
                    actionsBuilder: (document) => _actions(document, workspace),
                    onCreate: () => _openForm(type, workspace),
                  ),
                ),
                const Divider(height: 1),
                PurchasePagination(
                  total: rows.length,
                  page: page,
                  rowsPerPage: rowsPerPage,
                  onPageChanged: (value) => setState(() => page = value),
                  onRowsPerPageChanged: (value) => setState(() {
                    rowsPerPage = value;
                    page = 0;
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _clearFilters() => setState(() {
    search = '';
    statusFilter = '';
    supplierFilter = '';
    dateFilter = PurchaseDateFilter.all;
    page = 0;
  });

  Future<void> _bulkComplete(PurchaseWorkspaceState workspace) async {
    final selected = workspace
        .forType(type)
        .where((item) => selectedIds.contains(item.id))
        .toList();
    if (type != PurchaseDocumentType.order) {
      _message(
        const ApiException('Bulk status updates apply to purchase orders.'),
      );
      return;
    }
    for (final document in selected) {
      await ref
          .read(purchaseControllerProvider.notifier)
          .changeOrderStatus(document.id, 'completed');
    }
    if (mounted) setState(selectedIds.clear);
  }

  Widget _actions(
    PurchaseDocument document,
    PurchaseWorkspaceState workspace,
  ) => PopupMenuButton<String>(
    tooltip: 'Purchase actions',
    icon: const Icon(Icons.more_vert_rounded),
    onSelected: (action) async {
      if (action == 'view') _showDetail(document);
      if (action == 'edit') {
        _openForm(document.type, workspace, document: document);
      }
      if (action == 'status') _changeStatus(document);
      if (action == 'delete') _delete(document);
    },
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'view',
        child: ListTile(
          leading: Icon(Icons.visibility_outlined),
          title: Text('View details'),
        ),
      ),
      if (document.type != PurchaseDocumentType.purchaseReturn)
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
        ),
      if (document.type == PurchaseDocumentType.order)
        const PopupMenuItem(
          value: 'status',
          child: ListTile(
            leading: Icon(Icons.sync_alt),
            title: Text('Change status'),
          ),
        ),
      if (document.type != PurchaseDocumentType.purchaseReturn)
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: AppColors.danger),
            title: Text('Delete'),
          ),
        ),
    ],
  );

  Future<void> _openForm(
    PurchaseDocumentType type,
    PurchaseWorkspaceState workspace, {
    PurchaseDocument? document,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog.fullscreen(
        child: PurchaseDocumentForm(
          type: type,
          workspace: workspace,
          document: document,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_label(type, singular: true)} saved successfully.'),
        ),
      );
    }
  }

  Future<void> _showDetail(PurchaseDocument summary) async {
    if (openingDetail) return;
    openingDetail = true;
    try {
      final detail = await ref
          .read(purchaseControllerProvider.notifier)
          .detail(summary.type, summary.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => PurchaseDetailDialog(document: detail),
      );
    } catch (error) {
      if (!mounted) return;
      _message(error);
    } finally {
      openingDetail = false;
    }
  }

  Future<void> _changeStatus(PurchaseDocument document) async {
    String value = document.status;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Change order status'),
          content: DropdownButtonFormField<String>(
            initialValue:
                [
                  'draft',
                  'ordered',
                  'partial',
                  'completed',
                  'cancelled',
                ].contains(value)
                ? value
                : 'draft',
            items:
                const ['draft', 'ordered', 'partial', 'completed', 'cancelled']
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
            onChanged: (item) => setLocal(() => value = item!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, value),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    try {
      await ref
          .read(purchaseControllerProvider.notifier)
          .changeOrderStatus(document.id, selected);
    } catch (error) {
      _message(error);
    }
  }

  Future<void> _delete(PurchaseDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_label(document.type, singular: true)}?'),
        content: Text(
          '${document.reference} will be removed if backend business rules allow it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(purchaseControllerProvider.notifier).remove(document);
    } catch (error) {
      _message(error);
    }
  }

  void _message(Object error) {
    final text = error is ApiException ? error.message : '$error';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class PurchaseDocumentForm extends ConsumerStatefulWidget {
  const PurchaseDocumentForm({
    super.key,
    required this.type,
    required this.workspace,
    this.document,
  });
  final PurchaseDocumentType type;
  final PurchaseWorkspaceState workspace;
  final PurchaseDocument? document;
  @override
  ConsumerState<PurchaseDocumentForm> createState() =>
      _PurchaseDocumentFormState();
}

class _PurchaseDocumentFormState extends ConsumerState<PurchaseDocumentForm> {
  final formKey = GlobalKey<FormState>();
  late String supplierId, locationId, status, shippingStatus;
  String discountType = 'fixed', payTermType = 'days';
  String? taxId, paymentMethod, paymentAccountId;
  late DateTime date;
  DateTime? deliveryDate;
  late final TextEditingController reference,
      notes,
      exchangeRate,
      discountAmount,
      shippingDetails,
      shippingCharges,
      payTermNumber,
      paymentAmount,
      paymentNote;
  final expenseNames = List.generate(4, (_) => TextEditingController());
  final expenseAmounts = List.generate(4, (_) => TextEditingController());
  late List<PurchaseLineRecord> lines;
  late List<Supplier> suppliers;
  String productSearch = '';

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    final app = ref.read(appStoreProvider);
    supplierId =
        doc?.supplierId ??
        (widget.workspace.suppliers.isEmpty
            ? ''
            : widget.workspace.suppliers.first.id);
    locationId =
        doc?.locationId ??
        (app.locations.isEmpty ? '' : app.locations.first.id);
    final defaultStatus = switch (widget.type) {
      PurchaseDocumentType.order => 'ordered',
      PurchaseDocumentType.invoice => 'received',
      PurchaseDocumentType.purchaseReturn => 'final',
    };
    final documentStatus = doc?.status;
    status =
        documentStatus != null && _valid(documentStatus, _statuses(widget.type))
        ? documentStatus
        : defaultStatus;
    shippingStatus = doc?.shippingStatus ?? 'ordered';
    discountType = doc?.discountType ?? 'fixed';
    taxId = doc?.taxId;
    payTermType = doc?.payTermType ?? 'days';
    deliveryDate = doc?.deliveryDate;
    date = doc?.date ?? DateTime.now();
    reference = TextEditingController(text: doc?.reference ?? '');
    notes = TextEditingController(text: doc?.notes ?? '');
    exchangeRate = TextEditingController(text: '${doc?.exchangeRate ?? 1}');
    discountAmount = TextEditingController(text: '${doc?.discountAmount ?? 0}');
    shippingDetails = TextEditingController(text: doc?.shippingDetails ?? '');
    shippingCharges = TextEditingController(
      text: '${doc?.shippingCharges ?? 0}',
    );
    payTermNumber = TextEditingController(
      text: doc?.payTermNumber?.toString() ?? '',
    );
    final payment = doc?.payments.firstOrNull;
    paymentAmount = TextEditingController(text: '${payment?.amount ?? 0}');
    paymentNote = TextEditingController(text: payment?.note ?? '');
    paymentMethod =
        payment?.method ??
        (app.checkoutPaymentOptions.isEmpty
            ? 'cash'
            : app.checkoutPaymentOptions.first.code);
    paymentAccountId = payment?.accountId;
    for (var i = 0; i < (doc?.expenses.length ?? 0) && i < 4; i++) {
      expenseNames[i].text = doc!.expenses[i].name;
      expenseAmounts[i].text = '${doc.expenses[i].amount}';
    }
    lines = [...?doc?.lines];
    suppliers = [...widget.workspace.suppliers];
  }

  @override
  void dispose() {
    reference.dispose();
    notes.dispose();
    exchangeRate.dispose();
    discountAmount.dispose();
    shippingDetails.dispose();
    shippingCharges.dispose();
    payTermNumber.dispose();
    paymentAmount.dispose();
    paymentNote.dispose();
    for (final controller in [...expenseNames, ...expenseAmounts]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appStoreProvider);
    final saving = ref.watch(purchaseControllerProvider).isLoading;
    final total = lines.fold<int>(
      0,
      (sum, line) => sum + line.lineTotal.round(),
    );
    final documentDiscount = _documentDiscount(total);
    final taxPercent = app.taxes
        .where((tax) => tax.id == taxId)
        .firstOrNull
        ?.value;
    final taxAmount = ((total - documentDiscount) * (taxPercent ?? 0) / 100)
        .round();
    final extras = expenseAmounts.fold<double>(
      0,
      (sum, field) => sum + (double.tryParse(field.text) ?? 0),
    );
    final grandTotal =
        total -
        documentDiscount +
        taxAmount +
        ((double.tryParse(shippingCharges.text) ?? 0) * 100).round() +
        (extras * 100).round();
    if (widget.type == PurchaseDocumentType.order) {
      return _buildPurchaseOrderForm(
        app: app,
        saving: saving,
        subtotal: total,
        documentDiscount: documentDiscount,
        taxAmount: taxAmount,
        grandTotal: grandTotal,
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: Text(
          '${widget.document == null ? 'Create' : 'Edit'} ${_label(widget.type, singular: true)}',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section(
              'Document details',
              Icons.description_outlined,
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field(
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue:
                                _valid(supplierId, suppliers.map((e) => e.id))
                                ? supplierId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Supplier *',
                            ),
                            items: suppliers
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(
                                      item.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            validator: (value) =>
                                value == null ? 'Select a supplier' : null,
                            onChanged: (value) => supplierId = value ?? '',
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: 'Add supplier',
                          onPressed: _addSupplier,
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                        ),
                      ],
                    ),
                  ),
                  _field(
                    DropdownButtonFormField<String>(
                      initialValue:
                          _valid(locationId, app.locations.map((e) => e.id))
                          ? locationId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Business location *',
                      ),
                      items: app.locations
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Select a location' : null,
                      onChanged: (value) => locationId = value ?? '',
                    ),
                  ),
                  _field(
                    TextFormField(
                      controller: reference,
                      decoration: const InputDecoration(
                        labelText: 'Reference number',
                        hintText: 'Auto-generated if empty',
                      ),
                    ),
                  ),
                  _field(
                    InkWell(
                      onTap: () async {
                        final value = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: date,
                        );
                        if (value != null) setState(() => date = value);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date *',
                          suffixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(
                          DateFormat.yMMMd().format(date),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  _field(
                    DropdownButtonFormField<String>(
                      initialValue: _valid(status, _statuses(widget.type))
                          ? status
                          : null,
                      decoration: const InputDecoration(labelText: 'Status *'),
                      items: _statuses(widget.type)
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => status = value!,
                    ),
                  ),
                  if (widget.type == PurchaseDocumentType.order)
                    _field(
                      DropdownButtonFormField<String>(
                        initialValue: shippingStatus,
                        decoration: const InputDecoration(
                          labelText: 'Shipping status',
                        ),
                        items:
                            const [
                                  'ordered',
                                  'packed',
                                  'shipped',
                                  'delivered',
                                  'cancelled',
                                ]
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) => shippingStatus = value!,
                      ),
                    ),
                  _field(
                    TextFormField(
                      controller: exchangeRate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Exchange rate',
                      ),
                      validator: (value) =>
                          (double.tryParse(value ?? '') ?? 0) <= 0
                          ? 'Enter a rate above zero'
                          : null,
                    ),
                  ),
                  _field(
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: payTermNumber,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Pay term',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 92,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: payTermType,
                            items: const [
                              DropdownMenuItem(
                                value: 'days',
                                child: Text('Days'),
                              ),
                              DropdownMenuItem(
                                value: 'months',
                                child: Text('Months'),
                              ),
                            ],
                            onChanged: (value) => payTermType = value!,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _field(
                    InkWell(
                      onTap: () async {
                        final value = await showDatePicker(
                          context: context,
                          firstDate: date,
                          lastDate: DateTime(2100),
                          initialDate: deliveryDate ?? date,
                        );
                        if (value != null) {
                          setState(() => deliveryDate = value);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Expected delivery',
                          suffixIcon: Icon(Icons.event_available_outlined),
                        ),
                        child: Text(
                          deliveryDate == null
                              ? 'Not set'
                              : DateFormat.yMMMd().format(deliveryDate!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 584,
                    child: TextFormField(
                      controller: notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(
              'Products',
              Icons.inventory_2_outlined,
              Column(
                children: [
                  Autocomplete<Product>(
                    displayStringForOption: (p) => '${p.name} • ${p.sku}',
                    optionsBuilder: (value) {
                      final q = value.text.toLowerCase().trim();
                      if (q.isEmpty) return const Iterable<Product>.empty();
                      return app.products.where(
                        (p) =>
                            p.name.toLowerCase().contains(q) ||
                            p.sku.toLowerCase().contains(q),
                      );
                    },
                    onSelected: _addProduct,
                    fieldViewBuilder: (_, controller, focus, submit) =>
                        TextField(
                          controller: controller,
                          focusNode: focus,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Search and add product by name or SKU',
                          ),
                        ),
                  ),
                  const SizedBox(height: 14),
                  if (lines.isEmpty)
                    const EmptyState(
                      'Search for products and add at least one line.',
                    )
                  else
                    ...lines.asMap().entries.map(
                      (entry) => _lineEditor(entry.key, entry.value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(
              'Purchase totals',
              Icons.calculate_outlined,
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _field(
                    DropdownButtonFormField<String>(
                      initialValue: discountType,
                      decoration: const InputDecoration(
                        labelText: 'Discount type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text('Fixed amount'),
                        ),
                        DropdownMenuItem(
                          value: 'percentage',
                          child: Text('Percentage'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => discountType = value!),
                    ),
                  ),
                  _field(
                    TextFormField(
                      controller: discountAmount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Discount amount',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  _field(
                    DropdownButtonFormField<String?>(
                      initialValue: taxId,
                      decoration: const InputDecoration(
                        labelText: 'Purchase tax',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...app.taxes.map(
                          (tax) => DropdownMenuItem<String?>(
                            value: tax.id,
                            child: Text(tax.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => taxId = value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(
              'Shipping and additional expenses',
              Icons.local_shipping_outlined,
              Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 584,
                        child: TextFormField(
                          controller: shippingDetails,
                          decoration: const InputDecoration(
                            labelText: 'Shipping details',
                          ),
                        ),
                      ),
                      _field(
                        TextFormField(
                          controller: shippingCharges,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Additional shipping charges',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: expenseNames[i],
                              decoration: InputDecoration(
                                labelText: 'Expense ${i + 1} name',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 220,
                            child: TextFormField(
                              controller: expenseAmounts[i],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.type == PurchaseDocumentType.invoice) ...[
              const SizedBox(height: 16),
              _section(
                'Add payment',
                Icons.payments_outlined,
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _field(
                      TextFormField(
                        controller: paymentAmount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Amount'),
                      ),
                    ),
                    _field(
                      DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment method',
                        ),
                        items: app.checkoutPaymentOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.code,
                                child: Text(option.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => paymentMethod = value,
                      ),
                    ),
                    _field(
                      DropdownButtonFormField<String?>(
                        initialValue: paymentAccountId,
                        decoration: const InputDecoration(
                          labelText: 'Payment account',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...widget.workspace.paymentAccounts.map(
                            (account) => DropdownMenuItem<String?>(
                              value: account.id,
                              child: Text(account.name),
                            ),
                          ),
                        ],
                        onChanged: (value) => paymentAccountId = value,
                      ),
                    ),
                    SizedBox(
                      width: 584,
                      child: TextFormField(
                        controller: paymentNote,
                        decoration: const InputDecoration(
                          labelText: 'Payment note',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 340,
                child: Surface(
                  child: Column(
                    children: [
                      _totalRow(
                        'Total items',
                        lines
                            .fold<double>(0, (sum, line) => sum + line.quantity)
                            .toStringAsFixed(2),
                      ),
                      const Divider(),
                      _totalRow(
                        'Document discount',
                        '-${money(documentDiscount)}',
                      ),
                      _totalRow('Tax', money(taxAmount)),
                      _totalRow('Grand total', money(grandTotal), strong: true),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderForm({
    required AppState app,
    required bool saving,
    required int subtotal,
    required int documentDiscount,
    required int taxAmount,
    required int grandTotal,
  }) {
    final itemCount = lines.fold<double>(0, (sum, line) => sum + line.quantity);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: Column(
            children: [
              _purchaseOrderHeader(saving),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= 1050;
                    final main = _purchaseOrderMain(app);
                    final side = _purchaseOrderSidebar(
                      app,
                      subtotal,
                      documentDiscount,
                      taxAmount,
                      grandTotal,
                      itemCount,
                    );
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(desktop ? 22 : 14),
                      child: desktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: main),
                                const SizedBox(width: 16),
                                SizedBox(width: 330, child: side),
                              ],
                            )
                          : Column(
                              children: [
                                main,
                                const SizedBox(height: 16),
                                side,
                              ],
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _purchaseOrderHeader(bool saving) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back to purchases',
          onPressed: saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Purchases  /  Purchase Orders',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                widget.document == null
                    ? 'Create Purchase Order'
                    : 'Edit Purchase Order',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Create and manage a new supplier order',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: saving ? null : () => _saveOrderAs('draft'),
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('Save as Draft'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(142, 46),
            side: const BorderSide(color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: saving ? null : () => _saveOrderAs('ordered'),
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: const Text('Create Order'),
          style: FilledButton.styleFrom(minimumSize: const Size(142, 46)),
        ),
      ],
    ),
  );

  Widget _purchaseOrderMain(AppState app) => Column(
    children: [
      _section(
        'Order Details',
        Icons.description_outlined,
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final fieldWidth = width >= 760 ? (width - 24) / 3 : width;
            return Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue:
                            _valid(supplierId, suppliers.map((e) => e.id))
                            ? supplierId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Supplier *',
                        ),
                        items: suppliers
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'Select a supplier' : null,
                        onChanged: (value) => supplierId = value ?? '',
                      ),
                      TextButton.icon(
                        onPressed: _addSupplier,
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('Add supplier'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _valid(locationId, app.locations.map((e) => e.id))
                        ? locationId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Business location *',
                    ),
                    items: app.locations
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Select a location' : null,
                    onChanged: (value) => locationId = value ?? '',
                  ),
                ),
                SizedBox(width: fieldWidth, child: _dateField()),
                SizedBox(
                  width: fieldWidth,
                  child: TextFormField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Reference number',
                      hintText: 'e.g. PO-2026-00124',
                    ),
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Order status *',
                    ),
                    items: _statuses(widget.type)
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_title(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => status = value!),
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: shippingStatus,
                    decoration: const InputDecoration(
                      labelText: 'Shipping status',
                    ),
                    items:
                        const [
                              'ordered',
                              'packed',
                              'shipped',
                              'delivered',
                              'cancelled',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_title(value)),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        setState(() => shippingStatus = value!),
                  ),
                ),
                SizedBox(width: fieldWidth, child: _deliveryField()),
                SizedBox(width: fieldWidth, child: _payTermField()),
                SizedBox(
                  width: fieldWidth,
                  child: TextFormField(
                    controller: exchangeRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Exchange rate',
                    ),
                    validator: (value) =>
                        (double.tryParse(value ?? '') ?? 0) <= 0
                        ? 'Enter a rate above zero'
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      _section(
        'Products',
        Icons.inventory_2_outlined,
        Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _browseProducts(app),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Product'),
              ),
            ),
            const SizedBox(height: 8),
            Autocomplete<Product>(
              displayStringForOption: (p) => '${p.name} • ${p.sku}',
              optionsBuilder: (value) {
                final q = value.text.toLowerCase().trim();
                if (q.isEmpty) return const Iterable<Product>.empty();
                return app.products.where(
                  (p) =>
                      p.name.toLowerCase().contains(q) ||
                      p.sku.toLowerCase().contains(q),
                );
              },
              onSelected: _addProduct,
              fieldViewBuilder: (_, controller, focus, submit) => TextField(
                controller: controller,
                focusNode: focus,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search products by name, SKU or barcode',
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F3EF),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No products added yet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'Search your inventory above to add products.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => _browseProducts(app),
                      icon: const Icon(Icons.inventory_2_outlined, size: 17),
                      label: const Text('Browse Products'),
                    ),
                  ],
                ),
              )
            else
              ...lines.asMap().entries.map(
                (entry) => _lineEditor(entry.key, entry.value),
              ),
            if (lines.isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF9),
                  border: Border.all(color: const Color(0xFFE2E8E6)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Product')),
                    Expanded(flex: 2, child: Text('SKU')),
                    Expanded(child: Text('Qty')),
                    Expanded(flex: 2, child: Text('Unit Cost')),
                    Expanded(child: Text('Tax')),
                    Expanded(child: Text('Discount')),
                    Expanded(child: Text('Total')),
                    Icon(Icons.more_horiz_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      _section(
        'Notes',
        Icons.notes_rounded,
        TextFormField(
          controller: notes,
          minLines: 3,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText:
                'Add supplier instructions, delivery notes, or internal comments...',
          ),
        ),
      ),
    ],
  );

  Widget _purchaseOrderSidebar(
    AppState app,
    int subtotal,
    int documentDiscount,
    int taxAmount,
    int grandTotal,
    double itemCount,
  ) => Column(
    children: [
      _section(
        'Order Summary',
        Icons.receipt_long_outlined,
        Column(
          children: [
            _totalRow('Subtotal', money(subtotal)),
            _totalRow('Item discount', '-${money(0)}'),
            _totalRow('Purchase tax', money(taxAmount)),
            _totalRow('Additional discount', '-${money(documentDiscount)}'),
            const Divider(height: 24),
            _totalRow('Total', money(grandTotal), strong: true),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_compact(itemCount)} items',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _section(
        'Discount & Tax',
        Icons.sell_outlined,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fixed', label: Text('Fixed amount')),
                ButtonSegment(value: 'percentage', label: Text('Percentage')),
              ],
              selected: {discountType},
              onSelectionChanged: (value) =>
                  setState(() => discountType = value.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: discountAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: taxId,
              decoration: const InputDecoration(labelText: 'Purchase tax'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None'),
                ),
                ...app.taxes.map(
                  (tax) => DropdownMenuItem<String?>(
                    value: tax.id,
                    child: Text(tax.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => taxId = value),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _section(
        'Payment & Delivery',
        Icons.local_shipping_outlined,
        Column(
          children: [
            _summaryFact(
              Icons.event_available_outlined,
              'Expected delivery',
              deliveryDate == null
                  ? 'Not set'
                  : DateFormat.yMMMd().format(deliveryDate!),
            ),
            const SizedBox(height: 8),
            _summaryFact(
              Icons.credit_card_outlined,
              'Payment terms',
              payTermNumber.text.isEmpty
                  ? 'Not set'
                  : '${payTermNumber.text} ${_title(payTermType)}',
            ),
            const SizedBox(height: 8),
            _summaryFact(
              Icons.local_shipping_outlined,
              'Shipping status',
              _title(shippingStatus),
            ),
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                'Shipping costs & expenses',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              children: [
                TextFormField(
                  controller: shippingDetails,
                  decoration: const InputDecoration(
                    labelText: 'Shipping details',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: shippingCharges,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Shipping charges',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                for (var i = 0; i < 4; i++) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: expenseNames[i],
                          decoration: InputDecoration(
                            labelText: 'Expense ${i + 1}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: expenseAmounts[i],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _dateField() => InkWell(
    onTap: () async {
      final value = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: date,
      );
      if (value != null) setState(() => date = value);
    },
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Order date *',
        suffixIcon: Icon(Icons.calendar_today_outlined),
      ),
      child: Text(DateFormat.yMMMd().format(date)),
    ),
  );

  Widget _deliveryField() => InkWell(
    onTap: () async {
      final value = await showDatePicker(
        context: context,
        firstDate: date,
        lastDate: DateTime(2100),
        initialDate: deliveryDate ?? date,
      );
      if (value != null) setState(() => deliveryDate = value);
    },
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Expected delivery',
        suffixIcon: Icon(Icons.calendar_today_outlined),
      ),
      child: Text(
        deliveryDate == null
            ? 'Not set'
            : DateFormat.yMMMd().format(deliveryDate!),
      ),
    ),
  );

  Widget _payTermField() => Row(
    children: [
      Expanded(
        child: TextFormField(
          controller: payTermNumber,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Payment term'),
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 92,
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: payTermType,
          items: const [
            DropdownMenuItem(value: 'days', child: Text('Days')),
            DropdownMenuItem(value: 'months', child: Text('Months')),
          ],
          onChanged: (value) => setState(() => payTermType = value!),
        ),
      ),
    ],
  );

  Widget _summaryFact(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE2E8E6)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );

  Future<void> _browseProducts(AppState app) async {
    final selected = await showDialog<Product>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Browse products'),
        content: SizedBox(
          width: 520,
          height: 420,
          child: app.products.isEmpty
              ? const Center(child: Text('No products are available.'))
              : ListView.separated(
                  itemCount: app.products.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final product = app.products[index];
                    return ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(product.displayName(context.isArabic)),
                      subtitle: Text(product.sku),
                      trailing: const Icon(Icons.add_circle_outline_rounded),
                      onTap: () => Navigator.pop(dialogContext, product),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (selected != null) _addProduct(selected);
  }

  Future<void> _saveOrderAs(String nextStatus) async {
    status = nextStatus;
    await _save();
  }

  String _title(String value) => value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  Widget _section(String title, IconData icon, Widget child) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 9),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _field(Widget child) => SizedBox(width: 286, child: child);

  Widget _lineEditor(int index, PurchaseLineRecord line) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F9F8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                line.sku,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: TextFormField(
            initialValue: _compact(line.quantity),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quantity'),
            onChanged: (v) => _replace(index, quantity: double.tryParse(v)),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: TextFormField(
            initialValue: (line.unitCost / 100).toStringAsFixed(2),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Unit cost'),
            onChanged: (v) =>
                _replace(index, unitCost: (double.tryParse(v) ?? 0) * 100),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 105,
          child: TextFormField(
            initialValue: _compact(line.discountPercent),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Discount %'),
            onChanged: (v) =>
                _replace(index, discountPercent: double.tryParse(v)),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 120,
          child: Text(
            money(line.lineTotal.round()),
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => lines.removeAt(index)),
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
        ),
      ],
    ),
  );

  Widget _totalRow(String label, String value, {bool strong = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: strong ? 20 : 14,
          fontWeight: FontWeight.w900,
          color: strong ? AppColors.primary : null,
        ),
      ),
    ],
  );

  void _addProduct(Product product) {
    final existing = lines.indexWhere(
      (line) => line.variationId == product.variationId,
    );
    setState(() {
      if (existing >= 0) {
        final old = lines[existing];
        lines[existing] = PurchaseLineRecord(
          productId: old.productId,
          variationId: old.variationId,
          name: old.name,
          sku: old.sku,
          quantity: old.quantity + 1,
          unitCost: old.unitCost,
          id: old.id,
          taxId: old.taxId,
          discountPercent: old.discountPercent,
        );
      } else {
        lines.add(
          PurchaseLineRecord(
            productId: product.id,
            variationId: product.variationId,
            name: product.displayName(context.isArabic),
            sku: product.sku,
            quantity: 1,
            unitCost: product.purchasePrice.toDouble(),
            taxId: product.taxId,
          ),
        );
      }
    });
  }

  void _replace(
    int index, {
    double? quantity,
    double? unitCost,
    double? discountPercent,
  }) {
    final old = lines[index];
    setState(
      () => lines[index] = PurchaseLineRecord(
        id: old.id,
        productId: old.productId,
        variationId: old.variationId,
        name: old.name,
        sku: old.sku,
        quantity: quantity ?? old.quantity,
        unitCost: unitCost ?? old.unitCost,
        taxId: old.taxId,
        discountPercent: discountPercent ?? old.discountPercent,
      ),
    );
  }

  int _documentDiscount(int subtotal) {
    final value = double.tryParse(discountAmount.text) ?? 0;
    if (discountType == 'percentage') {
      return (subtotal * value.clamp(0, 100) / 100).round();
    }
    return ((value * 100).round()).clamp(0, subtotal);
  }

  Future<void> _addSupplier() async {
    final key = GlobalKey<FormState>();
    final business = TextEditingController();
    final contact = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    final address = TextEditingController();
    final term = TextEditingController();
    var termType = 'days';
    final result = await showDialog<Supplier>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940, maxHeight: 850),
            child: Form(
              key: key,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(34, 30, 24, 26),
                    child: Row(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F3EF),
                            borderRadius: BorderRadius.circular(34),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 22),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add supplier',
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Add a new supplier to your business',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded, size: 30),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(34),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final twoColumns = constraints.maxWidth >= 680;
                          final fieldWidth = twoColumns
                              ? (constraints.maxWidth - 24) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: 24,
                            runSpacing: 22,
                            children: [
                              SizedBox(
                                width: fieldWidth,
                                child: _supplierField(
                                  label: 'Business name *',
                                  controller: business,
                                  icon: Icons.storefront_outlined,
                                  hint: 'Enter business name',
                                  validator: (value) =>
                                      value?.trim().isEmpty == true
                                      ? 'Enter the business name'
                                      : null,
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: _supplierField(
                                  label: 'Contact name *',
                                  controller: contact,
                                  icon: Icons.person_outline_rounded,
                                  hint: 'Enter contact name',
                                  validator: (value) =>
                                      value?.trim().isEmpty == true
                                      ? 'Enter the contact name'
                                      : null,
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: _supplierField(
                                  label: 'Mobile *',
                                  controller: mobile,
                                  icon: Icons.phone_android_outlined,
                                  hint: 'Enter mobile number',
                                  prefixText: '+91  ',
                                  keyboardType: TextInputType.phone,
                                  validator: (value) =>
                                      value?.trim().isEmpty == true
                                      ? 'Enter a mobile number'
                                      : null,
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: _supplierField(
                                  label: 'Email',
                                  controller: email,
                                  icon: Icons.mail_outline_rounded,
                                  hint: 'Enter email address',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    return text.isNotEmpty &&
                                            !text.contains('@')
                                        ? 'Enter a valid email address'
                                        : null;
                                  },
                                ),
                              ),
                              SizedBox(
                                width: constraints.maxWidth,
                                child: _supplierField(
                                  label: 'Address',
                                  controller: address,
                                  icon: Icons.location_on_outlined,
                                  hint: 'Enter full address',
                                  minLines: 2,
                                  maxLines: 3,
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: _supplierField(
                                  label: 'Default pay term',
                                  controller: term,
                                  icon: Icons.calendar_today_outlined,
                                  hint: 'Enter payment term (e.g. 30)',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    return text.isNotEmpty &&
                                            (int.tryParse(text) ?? 0) <= 0
                                        ? 'Enter a valid payment term'
                                        : null;
                                  },
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pay term unit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      initialValue: termType,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.calendar_today_outlined,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'days',
                                          child: Text('Days'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'months',
                                          child: Text('Months'),
                                        ),
                                      ],
                                      onChanged: (value) => setDialogState(
                                        () => termType = value!,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: constraints.maxWidth,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F8F5),
                                  border: Border.all(
                                    color: const Color(0xFFD5E9E2),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Payment terms',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'This will be used as the default payment term when creating purchase orders.',
                                            style: TextStyle(
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 34,
                      vertical: 20,
                    ),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(126, 50),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () async {
                            if (key.currentState?.validate() != true) return;
                            try {
                              final supplier = await ref
                                  .read(purchaseControllerProvider.notifier)
                                  .createSupplier(
                                    businessName: business.text,
                                    contactName: contact.text,
                                    mobile: mobile.text,
                                    email: email.text,
                                    address: address.text,
                                    payTermNumber: int.tryParse(term.text),
                                    payTermType: termType,
                                  );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, supplier);
                              }
                            } catch (error) {
                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error is ApiException
                                        ? error.message
                                        : '$error',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save supplier'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (final controller in [
      business,
      contact,
      mobile,
      email,
      address,
      term,
    ]) {
      controller.dispose();
    }
    if (result != null && mounted) {
      setState(() {
        suppliers = [...suppliers, result];
        supplierId = result.id;
      });
    }
  }

  Widget _supplierField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    String? prefixText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int minLines = 1,
    int maxLines = 1,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          prefixText: prefixText,
          hintText: hint,
        ),
      ),
    ],
  );

  Future<void> _save() async {
    if (formKey.currentState?.validate() != true) return;
    if (lines.isEmpty ||
        lines.any((line) => line.quantity <= 0 || line.unitCost < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one valid product line.')),
      );
      return;
    }
    final draft = PurchaseDraft(
      type: widget.type,
      supplierId: supplierId,
      locationId: locationId,
      date: date,
      status: status,
      shippingStatus: shippingStatus,
      reference: reference.text,
      notes: notes.text,
      lines: lines,
      purchaseOrderId: widget.document?.purchaseOrderId,
      exchangeRate: double.tryParse(exchangeRate.text) ?? 1,
      discountType: discountType,
      discountAmount: double.tryParse(discountAmount.text) ?? 0,
      taxId: taxId,
      shippingDetails: shippingDetails.text,
      shippingCharges: double.tryParse(shippingCharges.text) ?? 0,
      deliveryDate: deliveryDate,
      payTermNumber: int.tryParse(payTermNumber.text),
      payTermType: payTermType,
      expenses: [
        for (var i = 0; i < 4; i++)
          if (expenseNames[i].text.trim().isNotEmpty ||
              (double.tryParse(expenseAmounts[i].text) ?? 0) > 0)
            PurchaseExpense(
              name: expenseNames[i].text,
              amount: double.tryParse(expenseAmounts[i].text) ?? 0,
            ),
      ],
      payments:
          widget.type == PurchaseDocumentType.invoice &&
              (double.tryParse(paymentAmount.text) ?? 0) > 0
          ? [
              PurchasePaymentDraft(
                amount: double.parse(paymentAmount.text),
                method: paymentMethod ?? 'cash',
                paidOn: DateTime.now(),
                accountId: paymentAccountId,
                note: paymentNote.text,
              ),
            ]
          : const [],
    );
    try {
      await ref
          .read(purchaseControllerProvider.notifier)
          .save(draft, id: widget.document?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException ? error.message : '$error'),
        ),
      );
    }
  }
}

class PurchaseDetailDialog extends ConsumerWidget {
  const PurchaseDetailDialog({super.key, required this.document});
  final PurchaseDocument document;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtotal = document.lines.fold<double>(
      0,
      (sum, line) => sum + line.lineTotal,
    );
    final expenses = document.expenses.fold<double>(
      0,
      (sum, item) => sum + item.amount * 100,
    );
    final shipping = document.shippingCharges * 100;
    final discount = document.discountType == 'percentage'
        ? subtotal * document.discountAmount / 100
        : document.discountAmount * 100;
    final tax = (document.total - subtotal + discount - shipping - expenses)
        .clamp(0, double.infinity);
    final products = ref.watch(appStoreProvider).products;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 880),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 28, 24, 24),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4F0),
                      borderRadius: BorderRadius.circular(31),
                    ),
                    child: Icon(
                      _icon(document.type),
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.reference,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _detailTitle(_label(document.type, singular: true)),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    _detailTitle(document.status),
                    color: _statusColor(document.status),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 28),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(30, 0, 30, 20),
                children: [
                  _detailFacts(document),
                  const SizedBox(height: 28),
                  const Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Products',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailProductTable(document, products),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 470,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F7F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _detailTotalRow('Subtotal', subtotal.round()),
                            _detailTotalRow('Tax', tax.round()),
                            _detailTotalRow('Shipping', shipping.round()),
                            _detailTotalRow('Other charges', expenses.round()),
                            if (discount > 0)
                              _detailTotalRow('Discount', -discount.round()),
                            const Divider(height: 28),
                            _detailTotalRow(
                              'Total',
                              document.total,
                              strong: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (document.notes.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'Notes',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(document.notes),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _printDocument(context, ref, document),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _downloadDocument(context, document),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _detailFacts(PurchaseDocument document) => Container(
  decoration: BoxDecoration(
    border: Border.all(color: const Color(0xFFDCE5E2)),
    borderRadius: BorderRadius.circular(14),
  ),
  clipBehavior: Clip.antiAlias,
  child: LayoutBuilder(
    builder: (context, constraints) {
      final facts = [
        _PurchaseFact(
          Icons.person_outline_rounded,
          'Supplier',
          document.supplierName,
        ),
        _PurchaseFact(
          Icons.location_on_outlined,
          'Location',
          document.locationName,
        ),
        _PurchaseFact(
          Icons.calendar_today_outlined,
          'Date',
          DateFormat.yMMMd().format(document.date),
        ),
        _PurchaseFact(
          Icons.account_balance_wallet_outlined,
          'Total',
          money(document.total),
        ),
      ];
      if (constraints.maxWidth < 650) {
        return Wrap(
          children: facts
              .map(
                (fact) =>
                    SizedBox(width: constraints.maxWidth / 2, child: fact),
              )
              .toList(),
        );
      }
      return IntrinsicHeight(
        child: Row(
          children: facts.map((fact) => Expanded(child: fact)).toList(),
        ),
      );
    },
  ),
);

class _PurchaseFact extends StatelessWidget {
  const _PurchaseFact(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 138),
    padding: const EdgeInsets.all(22),
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: Color(0xFFE2E8E6))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4F0),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(height: 16),
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? '—' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

Widget _detailProductTable(
  PurchaseDocument document,
  List<Product> products,
) => Container(
  decoration: BoxDecoration(
    border: Border.all(color: const Color(0xFFE2E8E6)),
    borderRadius: BorderRadius.circular(14),
  ),
  clipBehavior: Clip.antiAlias,
  child: Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        color: const Color(0xFFF1F7F5),
        child: const Row(
          children: [
            Expanded(flex: 4, child: Text('Product')),
            Expanded(child: Center(child: Text('Quantity'))),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('Unit Price'),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('Total'),
              ),
            ),
          ],
        ),
      ),
      if (document.lines.isEmpty)
        const Padding(
          padding: EdgeInsets.all(28),
          child: EmptyState('No product lines were returned by the API.'),
        )
      else
        ...document.lines.map((line) {
          final matches = products.where(
            (product) => product.id == line.productId,
          );
          final imageUrl = matches.isEmpty ? '' : matches.first.imageUrl;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE7ECEA))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl.isEmpty
                            ? const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.primary,
                              )
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              line.sku.isEmpty ? 'SKU: —' : 'SKU: ${line.sku}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: Center(child: Text(_compact(line.quantity)))),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: RiyalAmount(line.unitCost.round()),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      money(line.lineTotal.round()),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
    ],
  ),
);

Widget _detailTotalRow(String label, int value, {bool strong = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: strong ? 18 : 14,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
                color: strong ? AppColors.primary : AppColors.ink,
              ),
            ),
          ),
          Text(
            value < 0 ? '-${money(-value)}' : money(value),
            style: TextStyle(
              fontSize: strong ? 22 : 14,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              color: strong ? AppColors.primary : AppColors.ink,
            ),
          ),
        ],
      ),
    );

Future<void> _printDocument(
  BuildContext context,
  WidgetRef ref,
  PurchaseDocument document,
) async {
  try {
    await printPurchaseOrder(document, ref.read(printerControllerProvider));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to print this purchase order: $error')),
    );
  }
}

Future<void> _downloadDocument(
  BuildContext context,
  PurchaseDocument document,
) async {
  try {
    final downloaded = await savePurchaseOrderPdf(document);
    if (!context.mounted) return;
    if (!downloaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Direct download is currently available on Flutter Web.',
          ),
        ),
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to download this purchase order: $error')),
    );
  }
}

String _detailTitle(String value) => value
    .split(RegExp(r'[ _-]+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
String _label(PurchaseDocumentType type, {bool singular = false}) =>
    switch (type) {
      PurchaseDocumentType.order =>
        singular ? 'purchase order' : 'purchase orders',
      PurchaseDocumentType.invoice =>
        singular ? 'purchase invoice' : 'purchase invoices',
      PurchaseDocumentType.purchaseReturn =>
        singular ? 'purchase return' : 'purchase returns',
    };
IconData _icon(PurchaseDocumentType type) => switch (type) {
  PurchaseDocumentType.order => Icons.assignment_outlined,
  PurchaseDocumentType.invoice => Icons.receipt_long_outlined,
  PurchaseDocumentType.purchaseReturn => Icons.keyboard_return,
};
Color _statusColor(String status) => switch (status.toLowerCase()) {
  'received' || 'completed' || 'delivered' => AppColors.primary,
  'cancelled' || 'rejected' => AppColors.danger,
  'partial' || 'pending' => AppColors.accent,
  _ => AppColors.muted,
};
List<String> _statuses(PurchaseDocumentType type) => switch (type) {
  PurchaseDocumentType.order => const [
    'draft',
    'ordered',
    'partial',
    'completed',
    'cancelled',
  ],
  PurchaseDocumentType.invoice => const ['draft', 'pending', 'received'],
  PurchaseDocumentType.purchaseReturn => const ['final'],
};
bool _valid(String value, Iterable<String> options) => options.contains(value);
String _compact(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
