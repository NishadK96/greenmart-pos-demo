import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/ui.dart';
import '../../store/app_store.dart';
import '../domain/purchase_entities.dart';
import 'purchase_controller.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});
  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  String search = '';

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          PageTitle(
            'Purchases',
            subtitle: 'Manage orders, received invoices and supplier returns.',
            action: FilledButton.icon(
              onPressed: workspace.hasValue
                  ? () => _openForm(type, workspace.requireValue)
                  : null,
              icon: const Icon(Icons.add),
              label: Text('New ${_label(type, singular: true)}'),
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TabBar(
              controller: tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(
                  icon: Icon(Icons.assignment_outlined),
                  text: 'Purchase orders',
                ),
                Tab(
                  icon: Icon(Icons.receipt_long_outlined),
                  text: 'Purchase invoices',
                ),
                Tab(
                  icon: Icon(Icons.keyboard_return),
                  text: 'Purchase returns',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: workspace.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error is ApiException ? error.message : '$error',
                retry: () => ref.invalidate(purchaseControllerProvider),
              ),
              data: (data) => _documentList(data.forType(type), data),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentList(
    List<PurchaseDocument> documents,
    PurchaseWorkspaceState workspace,
  ) {
    final query = search.trim().toLowerCase();
    final rows = documents.where((item) {
      return query.isEmpty ||
          item.reference.toLowerCase().contains(query) ||
          item.supplierName.toLowerCase().contains(query) ||
          item.status.toLowerCase().contains(query);
    }).toList();
    return Surface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => search = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search reference, supplier or status',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.outlined(
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(purchaseControllerProvider),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? EmptyState('No ${_label(type)} found.')
                : LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth < 760
                        ? ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) =>
                                _mobileRow(rows[index], workspace),
                          )
                        : _desktopTable(rows, workspace),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _mobileRow(
    PurchaseDocument document,
    PurchaseWorkspaceState workspace,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    leading: CircleAvatar(
      backgroundColor: AppColors.primary.withValues(alpha: .1),
      child: Icon(_icon(document.type), color: AppColors.primary),
    ),
    title: Text(
      document.reference,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      '${document.supplierName}\n${DateFormat.yMMMd().format(document.date)}',
    ),
    isThreeLine: true,
    trailing: _actions(document, workspace),
    onTap: () => _showDetail(document, workspace),
  );

  Widget _desktopTable(
    List<PurchaseDocument> rows,
    PurchaseWorkspaceState workspace,
  ) => SingleChildScrollView(
    child: DataTable(
      columns: const [
        DataColumn(label: Text('Reference')),
        DataColumn(label: Text('Supplier')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Total'), numeric: true),
        DataColumn(label: Text('')),
      ],
      rows: rows
          .map(
            (document) => DataRow(
              onSelectChanged: (_) => _showDetail(document, workspace),
              cells: [
                DataCell(
                  Text(
                    document.reference,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                DataCell(Text(document.supplierName)),
                DataCell(Text(DateFormat.yMMMd().format(document.date))),
                DataCell(
                  StatusBadge(
                    document.status,
                    color: _statusColor(document.status),
                  ),
                ),
                DataCell(
                  Text(
                    money(document.total),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                DataCell(_actions(document, workspace)),
              ],
            ),
          )
          .toList(growable: false),
    ),
  );

  Widget _actions(
    PurchaseDocument document,
    PurchaseWorkspaceState workspace,
  ) => PopupMenuButton<String>(
    onSelected: (action) async {
      if (action == 'view') _showDetail(document, workspace);
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

  Future<void> _showDetail(
    PurchaseDocument summary,
    PurchaseWorkspaceState workspace,
  ) async {
    showDialog<void>(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final detail = await ref
          .read(purchaseControllerProvider.notifier)
          .detail(summary.type, summary.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (_) => PurchaseDetailDialog(document: detail),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _message(error);
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
  late DateTime date;
  late final TextEditingController reference, notes;
  late List<PurchaseLineRecord> lines;
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
    status =
        doc?.status ??
        (widget.type == PurchaseDocumentType.invoice ? 'received' : 'draft');
    shippingStatus = doc?.shippingStatus ?? 'ordered';
    date = doc?.date ?? DateTime.now();
    reference = TextEditingController(text: doc?.reference ?? '');
    notes = TextEditingController(text: doc?.notes ?? '');
    lines = [...?doc?.lines];
  }

  @override
  void dispose() {
    reference.dispose();
    notes.dispose();
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
                    DropdownButtonFormField<String>(
                      initialValue:
                          _valid(
                            supplierId,
                            widget.workspace.suppliers.map((e) => e.id),
                          )
                          ? supplierId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Supplier *',
                      ),
                      items: widget.workspace.suppliers
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Select a supplier' : null,
                      onChanged: (value) => supplierId = value ?? '',
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
                        child: Text(DateFormat.yMMMd().format(date)),
                      ),
                    ),
                  ),
                  _field(
                    DropdownButtonFormField<String>(
                      initialValue: status,
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
                      _totalRow('Grand total', money(total), strong: true),
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
        );
      } else {
        lines.add(
          PurchaseLineRecord(
            productId: product.id,
            variationId: product.variationId,
            name: product.name,
            sku: product.sku,
            quantity: 1,
            unitCost: product.purchasePrice.toDouble(),
            taxId: product.taxId,
          ),
        );
      }
    });
  }

  void _replace(int index, {double? quantity, double? unitCost}) {
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
        discountPercent: old.discountPercent,
      ),
    );
  }

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

class PurchaseDetailDialog extends StatelessWidget {
  const PurchaseDetailDialog({super.key, required this.document});
  final PurchaseDocument document;
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: .1),
                  child: Icon(_icon(document.type), color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.reference,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _label(document.type, singular: true),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  document.status,
                  color: _statusColor(document.status),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Wrap(
                  spacing: 30,
                  runSpacing: 15,
                  children: [
                    _fact('Supplier', document.supplierName),
                    _fact('Location', document.locationName),
                    _fact('Date', DateFormat.yMMMd().format(document.date)),
                    _fact('Total', money(document.total)),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Products',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ...document.lines.map(
                  (line) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.name),
                    subtitle: Text(
                      '${_compact(line.quantity)} × ${money(line.unitCost.round())}',
                    ),
                    trailing: Text(
                      money(line.lineTotal.round()),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (document.lines.isEmpty)
                  const EmptyState(
                    'No product lines were returned by the API.',
                  ),
                if (document.notes.isNotEmpty) ...[
                  const Divider(),
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
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Surface(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

Widget _fact(String label, String value) => SizedBox(
  width: 160,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      Text(
        value.isEmpty ? '—' : value,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ],
  ),
);
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
