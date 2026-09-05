import 'package:flutter/material.dart' hide Text;
import 'package:retailflow_pos/shared/widgets/localized_text.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/entities.dart';
import '../domain/purchase_entities.dart';
import 'purchase_controller.dart';

enum PurchaseDateFilter { all, last7Days, last30Days, thisMonth }

class PurchaseSummarySection extends StatelessWidget {
  const PurchaseSummarySection({super.key, required this.workspace});

  final PurchaseWorkspaceState workspace;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final openOrders = workspace.orders.where(
      (item) => !const {'completed', 'cancelled'}.contains(item.status),
    );
    final awaitingDelivery = openOrders.where(
      (item) => item.shippingStatus != 'delivered',
    );
    final pendingInvoices = workspace.invoices.where(
      (item) => !const {'received', 'completed'}.contains(item.status),
    );
    final pendingValue = pendingInvoices.fold<int>(
      0,
      (sum, item) => sum + item.total,
    );
    final monthPurchases = workspace.invoices
        .where(
          (item) => item.date.year == now.year && item.date.month == now.month,
        )
        .fold<int>(0, (sum, item) => sum + item.total);
    final returnValue = workspace.returns.fold<int>(
      0,
      (sum, item) => sum + item.total,
    );

    final cards = [
      _SummaryData(
        'Open orders',
        '${openOrders.length}',
        '${awaitingDelivery.length} awaiting delivery',
        Icons.pending_actions_outlined,
        const Color(0xFF3D6C9E),
      ),
      _SummaryData(
        'Pending invoices',
        '${pendingInvoices.length}',
        '${money(pendingValue)} outstanding',
        Icons.receipt_long_outlined,
        const Color(0xFFB7791F),
      ),
      _SummaryData(
        'Purchases this month',
        money(monthPurchases),
        '${workspace.invoices.length} total invoices',
        Icons.trending_up_rounded,
        AppColors.primary,
      ),
      _SummaryData(
        'Returns',
        '${workspace.returns.length}',
        '${money(returnValue)} returned',
        Icons.keyboard_return_rounded,
        const Color(0xFFB6543C),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 380
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _PurchaseSummaryCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _PurchaseSummaryCard extends StatelessWidget {
  const _PurchaseSummaryCard({required this.data});
  final _SummaryData data;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE4E9E7)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(data.icon, color: data.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.context,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class PurchaseSegmentedTabs extends StatelessWidget {
  const PurchaseSegmentedTabs({
    super.key,
    required this.controller,
    required this.counts,
  });
  final TabController controller;
  final List<int> counts;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE1E7E5))),
    ),
    child: TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.primary, width: 2.5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
      ),
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.muted,
      tabs: [
        _tab('Purchase orders', counts[0]),
        _tab('Purchase invoices', counts[1]),
        _tab('Purchase returns', counts[2]),
      ],
    ),
  );

  Tab _tab(String label, int count) => Tab(
    height: 46,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 22),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F2),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class PurchaseToolbar extends StatelessWidget {
  const PurchaseToolbar({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.status,
    required this.onStatusChanged,
    required this.supplierId,
    required this.onSupplierChanged,
    required this.dateFilter,
    required this.onDateChanged,
    required this.suppliers,
    required this.onClear,
    required this.onRefresh,
    required this.hasActiveFilters,
  });

  final String search, status, supplierId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged, onSupplierChanged;
  final PurchaseDateFilter dateFilter;
  final ValueChanged<PurchaseDateFilter?> onDateChanged;
  final List<Supplier> suppliers;
  final VoidCallback onClear, onRefresh;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 850;
      final searchField = TextFormField(
        initialValue: search,
        onChanged: onSearchChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 21),
          hintText: context.tr('Search reference, supplier or status'),
          suffixIcon: search.isEmpty
              ? null
              : IconButton(
                  tooltip: context.tr('Clear search'),
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
        ),
      );
      if (compact) {
        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: hasActiveFilters,
              smallSize: 8,
              child: IconButton.outlined(
                tooltip: context.tr('Filters'),
                onPressed: () => _showFilters(context),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.outlined(
              tooltip: context.tr('Refresh purchases'),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(flex: 3, child: searchField),
          const SizedBox(width: 10),
          Expanded(child: _statusFilter()),
          const SizedBox(width: 10),
          Expanded(child: _supplierFilter()),
          const SizedBox(width: 10),
          Expanded(child: _dateFilter()),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _showFilters(context),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Filters'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(102, 48),
              side: const BorderSide(color: Color(0xFFE0E6E4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(width: 6),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: context.tr('Refresh purchases'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );
    },
  );

  Widget _statusFilter() => DropdownButtonFormField<String>(
    initialValue: status,
    isExpanded: true,
    decoration: const InputDecoration(labelText: null),
    items: const [
      DropdownMenuItem(value: '', child: Text('Status')),
      DropdownMenuItem(value: 'draft', child: Text('Draft')),
      DropdownMenuItem(value: 'ordered', child: Text('Ordered')),
      DropdownMenuItem(value: 'partial', child: Text('Partially received')),
      DropdownMenuItem(value: 'pending', child: Text('Pending')),
      DropdownMenuItem(value: 'received', child: Text('Received')),
      DropdownMenuItem(value: 'completed', child: Text('Completed')),
      DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
      DropdownMenuItem(value: 'final', child: Text('Returned')),
    ],
    onChanged: onStatusChanged,
  );

  Widget _supplierFilter() => DropdownButtonFormField<String>(
    initialValue: supplierId,
    isExpanded: true,
    decoration: const InputDecoration(labelText: null),
    items: [
      const DropdownMenuItem(value: '', child: Text('Supplier')),
      for (final supplier in suppliers)
        DropdownMenuItem(
          value: supplier.id,
          child: Text(supplier.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onSupplierChanged,
  );

  Widget _dateFilter() => DropdownButtonFormField<PurchaseDateFilter>(
    initialValue: dateFilter,
    isExpanded: true,
    decoration: const InputDecoration(labelText: null),
    items: const [
      DropdownMenuItem(value: PurchaseDateFilter.all, child: Text('Date')),
      DropdownMenuItem(
        value: PurchaseDateFilter.last7Days,
        child: Text('Last 7 days'),
      ),
      DropdownMenuItem(
        value: PurchaseDateFilter.last30Days,
        child: Text('Last 30 days'),
      ),
      DropdownMenuItem(
        value: PurchaseDateFilter.thisMonth,
        child: Text('This month'),
      ),
    ],
    onChanged: onDateChanged,
  );

  Future<void> _showFilters(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filter purchases',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _statusFilter(),
            const SizedBox(height: 12),
            _supplierFilter(),
            const SizedBox(height: 12),
            _dateFilter(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      onClear();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear filters'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Show results'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class PurchaseBulkBar extends StatelessWidget {
  const PurchaseBulkBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onMarkCompleted,
  });
  final int count;
  final VoidCallback onClear, onMarkCompleted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFE2F0EC),
      border: Border.all(color: const Color(0xFFBED8D1)),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'purchase' : 'purchases'} selected',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onMarkCompleted,
          icon: const Icon(Icons.task_alt_rounded, size: 18),
          label: const Text('Mark completed'),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onClear, child: const Text('Clear selection')),
      ],
    ),
  );
}

class PurchaseDataView extends StatelessWidget {
  const PurchaseDataView({
    super.key,
    required this.rows,
    required this.type,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onSelectAll,
    required this.onOpen,
    required this.actionsBuilder,
    required this.onCreate,
  });

  final List<PurchaseDocument> rows;
  final PurchaseDocumentType type;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onSelectionChanged;
  final ValueChanged<bool> onSelectAll;
  final ValueChanged<PurchaseDocument> onOpen;
  final Widget Function(PurchaseDocument document) actionsBuilder;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return PurchaseEmptyState(type: type, onCreate: onCreate);
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 760
          ? ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => PurchaseMobileCard(
                document: rows[index],
                selected: selectedIds.contains(rows[index].id),
                onSelected: (value) =>
                    onSelectionChanged(rows[index].id, value),
                onOpen: () => onOpen(rows[index]),
                actions: actionsBuilder(rows[index]),
              ),
            )
          : PurchaseTable(
              rows: rows,
              selectedIds: selectedIds,
              onSelectionChanged: onSelectionChanged,
              onSelectAll: onSelectAll,
              onOpen: onOpen,
              actionsBuilder: actionsBuilder,
              showDelivery: constraints.maxWidth >= 1040,
            ),
    );
  }
}

class PurchaseTable extends StatelessWidget {
  const PurchaseTable({
    super.key,
    required this.rows,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.onSelectAll,
    required this.onOpen,
    required this.actionsBuilder,
    required this.showDelivery,
  });
  final List<PurchaseDocument> rows;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onSelectionChanged;
  final ValueChanged<bool> onSelectAll;
  final ValueChanged<PurchaseDocument> onOpen;
  final Widget Function(PurchaseDocument document) actionsBuilder;
  final bool showDelivery;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        rows.isNotEmpty && rows.every((e) => selectedIds.contains(e.id));
    return SingleChildScrollView(
      child: Theme(
        data: Theme.of(context).copyWith(
          dataTableTheme: DataTableThemeData(
            headingRowHeight: 52,
            dataRowMinHeight: 62,
            dataRowMaxHeight: 66,
            headingRowColor: WidgetStateProperty.all(Colors.white),
            headingTextStyle: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .35,
            ),
            dataTextStyle: const TextStyle(color: AppColors.ink, fontSize: 13),
            dividerThickness: 1,
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 22,
            horizontalMargin: 16,
            columns: [
              DataColumn(
                label: Checkbox(
                  value: allSelected,
                  tristate: selectedIds.isNotEmpty && !allSelected,
                  onChanged: (value) => onSelectAll(value ?? false),
                ),
              ),
              const DataColumn(label: Text('REFERENCE')),
              const DataColumn(label: Text('SUPPLIER')),
              const DataColumn(label: Text('ORDER DATE')),
              if (showDelivery)
                const DataColumn(label: Text('EXPECTED / RECEIVED')),
              const DataColumn(label: Text('STATUS')),
              const DataColumn(label: Text('ITEMS'), numeric: true),
              const DataColumn(label: Text('TOTAL'), numeric: true),
              const DataColumn(label: Text('ACTIONS')),
            ],
            rows: [
              for (final document in rows)
                DataRow(
                  selected: selectedIds.contains(document.id),
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFFE8F3F0);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xFFF5F8F7);
                    }
                    return Colors.white;
                  }),
                  onSelectChanged: (_) => onOpen(document),
                  cells: [
                    DataCell(
                      Checkbox(
                        value: selectedIds.contains(document.id),
                        onChanged: (value) =>
                            onSelectionChanged(document.id, value ?? false),
                      ),
                    ),
                    DataCell(
                      Text(
                        document.reference,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Text(
                          document.supplierName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(DateFormat('dd MMM yyyy').format(document.date)),
                    ),
                    if (showDelivery)
                      DataCell(
                        Text(
                          document.deliveryDate == null
                              ? '—'
                              : DateFormat(
                                  'dd MMM yyyy',
                                ).format(document.deliveryDate!),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    DataCell(PurchaseStatusChip(status: document.status)),
                    DataCell(
                      Text(
                        document.lines.isEmpty
                            ? '—'
                            : document.lines
                                  .fold<double>(
                                    0,
                                    (sum, line) => sum + line.quantity,
                                  )
                                  .toStringAsFixed(0),
                      ),
                    ),
                    DataCell(
                      Text(
                        money(document.total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(actionsBuilder(document)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PurchaseMobileCard extends StatelessWidget {
  const PurchaseMobileCard({
    super.key,
    required this.document,
    required this.selected,
    required this.onSelected,
    required this.onOpen,
    required this.actions,
  });
  final PurchaseDocument document;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onOpen;
  final Widget actions;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFE8F3F0) : Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xFFB8D8D0) : const Color(0xFFE4E9E7),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: selected, onChanged: (v) => onSelected(v ?? false)),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          document.reference,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      PurchaseStatusChip(status: document.status),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    document.supplierName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat.yMMMd().format(document.date),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const Spacer(),
                      Text(
                        document.lines.isEmpty
                            ? 'Items —'
                            : '${document.lines.length} items',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        money(document.total),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions,
          ],
        ),
      ),
    ),
  );
}

class PurchaseStatusChip extends StatelessWidget {
  const PurchaseStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'ordered' => const Color(0xFF3D6C9E),
      'partial' => const Color(0xFFB7791F),
      'pending' => const Color(0xFF9A6B1A),
      'received' || 'completed' || 'delivered' => const Color(0xFF23735E),
      'cancelled' => const Color(0xFFB54444),
      'final' || 'returned' => const Color(0xFFB6543C),
      _ => const Color(0xFF66716E),
    };
    final label = switch (normalized) {
      'partial' => 'Partially received',
      'final' => 'Returned',
      _ =>
        normalized.isEmpty
            ? 'Unknown'
            : '${normalized[0].toUpperCase()}${normalized.substring(1)}',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class PurchasePagination extends StatelessWidget {
  const PurchasePagination({
    super.key,
    required this.total,
    required this.page,
    required this.rowsPerPage,
    required this.onPageChanged,
    required this.onRowsPerPageChanged,
  });
  final int total, page, rowsPerPage;
  final ValueChanged<int> onPageChanged, onRowsPerPageChanged;

  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : (total / rowsPerPage).ceil();
    final first = total == 0 ? 0 : page * rowsPerPage + 1;
    final last = ((page + 1) * rowsPerPage).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Text(
            'Showing $first–$last of $total purchases',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rows per page',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: rowsPerPage,
                underline: const SizedBox.shrink(),
                items: const [10, 20, 50]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text('$value')),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onRowsPerPageChanged(value);
                },
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: context.tr('Previous page'),
                onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${page + 1} / $pages',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr('Next page'),
                onPressed: page + 1 < pages
                    ? () => onPageChanged(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PurchaseEmptyState extends StatelessWidget {
  const PurchaseEmptyState({
    super.key,
    required this.type,
    required this.onCreate,
  });
  final PurchaseDocumentType type;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      PurchaseDocumentType.order => 'purchase order',
      PurchaseDocumentType.invoice => 'purchase invoice',
      PurchaseDocumentType.purchaseReturn => 'purchase return',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F3F0),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${label}s yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first $label to start tracking supplier purchases.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text('Create $label'),
            ),
          ],
        ),
      ),
    );
  }
}

class PurchaseWorkspaceSkeleton extends StatelessWidget {
  const PurchaseWorkspaceSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(child: _block(height: 82)),
            if (i < 3) const SizedBox(width: 12),
          ],
        ],
      ),
      const SizedBox(height: 12),
      _block(height: 50),
      const SizedBox(height: 12),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE4E9E7)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _block(height: 48),
              const SizedBox(height: 14),
              for (var i = 0; i < 5; i++) ...[
                _block(height: 48),
                if (i < 4) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  Widget _block({required double height}) => Container(
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE9EEEC),
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

class PurchaseLoadError extends StatelessWidget {
  const PurchaseLoadError({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.cloud_off_outlined, color: AppColors.danger),
        ),
        const SizedBox(height: 14),
        const Text(
          'Unable to load purchases',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'Check your connection and try again.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}

class _SummaryData {
  const _SummaryData(
    this.label,
    this.value,
    this.context,
    this.icon,
    this.color,
  );
  final String label, value, context;
  final IconData icon;
  final Color color;
}
