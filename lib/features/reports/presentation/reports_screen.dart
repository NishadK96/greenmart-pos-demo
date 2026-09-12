import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:eazy_pos/shared/widgets/localized_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/pdf_fonts.dart';
import '../../../shared/widgets/ui.dart';
import '../../auth/auth_controller.dart';
import '../../printers/application/printer_controller.dart';
import '../../printers/application/printer_document_service.dart';
import '../../store/app_store.dart';
import '../domain/report_models.dart';

final reportProvider = FutureProvider.autoDispose
    .family<ReportResult, ReportRequest>((ref, request) async {
      final token = ref.watch(authControllerProvider).asData?.value;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          'Your session has expired. Please sign in again.',
        );
      }
      final json = await ref
          .watch(apiProvider)
          .report(token, request.kind.path, request.parameters);
      return ReportResult.fromJson(request.kind, json);
    });

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late ReportRequest request;
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    request = ReportRequest(
      kind: ReportKind.sales,
      startDate: today.subtract(const Duration(days: 29)),
      endDate: today,
    );
  }

  void update(ReportRequest value) => setState(() => request = value);

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(reportProvider(request));
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(
            'Reports',
            subtitle: request.kind.description,
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: exporting ? null : _printReport,
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Print'),
                ),
                PopupMenuButton<String>(
                  enabled: !exporting,
                  tooltip: context.tr('Export'),
                  onSelected: (format) =>
                      format == 'pdf' ? _exportPdfReport() : _exportCsvReport(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                    PopupMenuItem(value: 'csv', child: Text('Export CSV')),
                  ],
                  child: IgnorePointer(
                    child: OutlinedButton.icon(
                      onPressed: exporting ? null : () {},
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Export'),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Refresh'),
                  onPressed: exporting
                      ? null
                      : () => ref.invalidate(reportProvider(request)),
                  icon: exporting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ReportTabs(
            selected: request.kind,
            onSelected: (kind) => update(request.copyWith(kind: kind, page: 1)),
          ),
          const SizedBox(height: 12),
          _ReportFilters(request: request, onChanged: update),
          const SizedBox(height: 14),
          Expanded(
            child: result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ReportError(
                message: error.toString(),
                onRetry: () => ref.invalidate(reportProvider(request)),
              ),
              data: (data) => _ReportBody(
                kind: request.kind,
                result: data,
                onPageChanged: (page) => update(request.copyWith(page: page)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<ReportResult> _loadCompleteReport() async {
    final token = ref.read(authControllerProvider).asData?.value;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Your session has expired. Please sign in again.',
      );
    }
    final api = ref.read(apiProvider);
    if (request.kind == ReportKind.inventoryValuation) {
      final json = await api.report(
        token,
        request.kind.path,
        request.copyWith(page: 1).parameters,
      );
      return ReportResult.fromJson(request.kind, json);
    }

    final rows = <Map<String, dynamic>>[];
    ReportResult? first;
    var page = 1;
    var lastPage = 1;
    do {
      final pageRequest = request.copyWith(page: page, perPage: 100);
      final json = await api.report(
        token,
        request.kind.path,
        pageRequest.parameters,
      );
      final result = ReportResult.fromJson(request.kind, json);
      first ??= result;
      rows.addAll(result.rows);
      lastPage = result.lastPage;
      page++;
    } while (page <= lastPage && page <= 1000);

    final base = first;
    return ReportResult(
      rows: rows,
      summary: base.summary,
      insights: base.insights,
      page: 1,
      lastPage: 1,
      total: rows.length,
    );
  }

  Future<void> _printReport() async {
    await _runExportAction(() async {
      final result = await _loadCompleteReport();
      final bytes = await _buildReportPdf(request, result);
      final printer = ref.read(printerControllerProvider).selectedPrinter;
      await PrinterDocumentService.printPdfBytes(
        bytes,
        name: _reportFileName(request, 'pdf'),
        printer: printer,
        format: PdfPageFormat.a4.landscape,
      );
    }, successMessage: 'Report sent to printer');
  }

  Future<void> _exportPdfReport() async {
    await _runExportAction(() async {
      final result = await _loadCompleteReport();
      final bytes = await _buildReportPdf(request, result);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export ${request.kind.label} report',
        fileName: _reportFileName(request, 'pdf'),
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      if (path == null) throw const _ExportCancelled();
    }, successMessage: 'PDF report exported successfully');
  }

  Future<void> _exportCsvReport() async {
    await _runExportAction(() async {
      final result = await _loadCompleteReport();
      final bytes = _buildReportCsv(request, result);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export ${request.kind.label} report',
        fileName: _reportFileName(request, 'csv'),
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
      if (path == null) throw const _ExportCancelled();
    }, successMessage: 'Report exported successfully');
  }

  Future<void> _runExportAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => exporting = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on _ExportCancelled {
      // The user closed the native save dialog.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to complete report action: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }
}

class _ReportTabs extends StatelessWidget {
  const _ReportTabs({required this.selected, required this.onSelected});
  final ReportKind selected;
  final ValueChanged<ReportKind> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final kind in ReportKind.values) ...[
          ChoiceChip(
            label: Text(kind.label),
            selected: kind == selected,
            onSelected: (_) => onSelected(kind),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _ReportFilters extends ConsumerWidget {
  const _ReportFilters({required this.request, required this.onChanged});
  final ReportRequest request;
  final ValueChanged<ReportRequest> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(appStoreProvider).locations;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final controlWidth = compact ? constraints.maxWidth - 32 : 220.0;
        return Surface(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: controlWidth,
                child: DropdownButtonFormField<String>(
                  initialValue: request.locationId,
                  decoration: InputDecoration(
                    labelText: context.tr('Location'),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All locations'),
                    ),
                    ...locations.map(
                      (location) => DropdownMenuItem(
                        value: location.id,
                        child: Text(
                          location.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => onChanged(
                    request.copyWith(locationId: value ?? '', page: 1),
                  ),
                ),
              ),
              SizedBox(
                width: controlWidth,
                child: _DateButton(
                  label: request.kind == ReportKind.inventoryValuation
                      ? 'As of'
                      : 'From',
                  value: request.kind == ReportKind.inventoryValuation
                      ? request.endDate
                      : request.startDate,
                  onChanged: (value) => onChanged(
                    request.kind == ReportKind.inventoryValuation
                        ? request.copyWith(endDate: value, page: 1)
                        : request.copyWith(startDate: value, page: 1),
                  ),
                ),
              ),
              if (request.kind != ReportKind.inventoryValuation)
                SizedBox(
                  width: controlWidth,
                  child: _DateButton(
                    label: 'To',
                    value: request.endDate,
                    onChanged: (value) =>
                        onChanged(request.copyWith(endDate: value, page: 1)),
                  ),
                ),
              if (request.kind != ReportKind.inventoryValuation)
                SizedBox(
                  width: controlWidth,
                  child: DropdownButtonFormField<int>(
                    initialValue: request.perPage,
                    decoration: InputDecoration(
                      labelText: context.tr('Rows per page'),
                      isDense: true,
                    ),
                    items: const [10, 20, 50]
                        .map(
                          (count) => DropdownMenuItem(
                            value: count,
                            child: Text('$count rows'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(request.copyWith(perPage: value, page: 1));
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      minimumSize: const Size.fromHeight(48),
    ),
    onPressed: () async {
      final selected = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 366)),
        initialDate: value,
      );
      if (selected != null) onChanged(selected);
    },
    icon: const Icon(Icons.calendar_today_outlined, size: 17),
    label: Text('$label: ${_shortDate(value)}'),
  );
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.kind,
    required this.result,
    required this.onPageChanged,
  });
  final ReportKind kind;
  final ReportResult result;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      _SummaryGrid(summary: result.summary),
      if (result.insights.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Insights(kind: kind, rows: result.insights),
      ],
      if (kind != ReportKind.inventoryValuation) ...[
        const SizedBox(height: 14),
        _ReportTable(kind: kind, rows: result.rows),
        const SizedBox(height: 10),
        _Pagination(result: result, onChanged: onPageChanged),
      ],
    ],
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty)
      return const Surface(child: Text('No summary available.'));
    final entries = summary.entries
        .where((entry) => entry.key != 'as_of')
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1000
            ? 4
            : constraints.maxWidth > 600
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in entries)
              SizedBox(
                width: width,
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(entry.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 5),
                      _reportValue(
                        entry.key,
                        entry.value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.kind, required this.rows});
  final ReportKind kind;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final config = switch (kind) {
      ReportKind.sales || ReportKind.purchases => ('period', 'final_total'),
      ReportKind.productSales => ('product_name', 'sales_total'),
      ReportKind.payments => ('label', 'total_amount'),
      _ => ('', ''),
    };
    final visible = rows.take(10).toList();
    final maximum = visible.fold<double>(0, (max, row) {
      final value = _number(row[config.$2]);
      return value > max ? value : max;
    });
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kind == ReportKind.productSales ? 'Top performance' : 'Overview',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final row in visible) ...[
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    row[config.$1]?.toString() ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LinearProgressIndicator(
                    value: maximum == 0 ? 0 : _number(row[config.$2]) / maximum,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 105,
                  child: RiyalAmount(
                    toPaise(_number(row[config.$2])),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.kind, required this.rows});
  final ReportKind kind;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final columns = _columns[kind]!;
    return Surface(
      child: rows.isEmpty
          ? const EmptyState('No report records match these filters')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  for (final column in columns)
                    DataColumn(label: Text(column.$2)),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        for (final column in columns)
                          DataCell(
                            column.$3
                                ? RiyalAmount(toPaise(_number(row[column.$1])))
                                : Text(row[column.$1]?.toString() ?? '-'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.result, required this.onChanged});
  final ReportResult result;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('${result.total} records'),
      const Spacer(),
      IconButton(
        tooltip: context.tr('Previous page'),
        onPressed: result.page > 1 ? () => onChanged(result.page - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text('Page ${result.page} of ${result.lastPage}'),
      IconButton(
        tooltip: context.tr('Next page'),
        onPressed: result.page < result.lastPage
            ? () => onChanged(result.page + 1)
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Surface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
          const SizedBox(height: 10),
          const Text(
            'Unable to load report',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

const _columns = <ReportKind, List<(String, String, bool)>>{
  ReportKind.sales: [
    ('invoice_no', 'Invoice', false),
    ('transaction_date', 'Date', false),
    ('customer', 'Customer', false),
    ('payment_status', 'Payment', false),
    ('tax_amount', 'Tax', true),
    ('final_total', 'Total', true),
  ],
  ReportKind.productSales: [
    ('product', 'Product', false),
    ('sku', 'SKU', false),
    ('category', 'Category', false),
    ('variation', 'Variation', false),
    ('quantity', 'Quantity', false),
    ('subtotal', 'Sales', true),
  ],
  ReportKind.purchases: [
    ('ref_no', 'Reference', false),
    ('transaction_date', 'Date', false),
    ('supplier', 'Supplier', false),
    ('payment_status', 'Payment', false),
    ('tax_amount', 'Tax', true),
    ('final_total', 'Total', true),
  ],
  ReportKind.taxes: [
    ('reference', 'Reference', false),
    ('transaction_date', 'Date', false),
    ('type', 'Type', false),
    ('contact', 'Contact', false),
    ('tax_amount', 'Tax', true),
    ('final_total', 'Total', true),
  ],
  ReportKind.payments: [
    ('reference', 'Reference', false),
    ('paid_on', 'Paid on', false),
    ('contact', 'Contact', false),
    ('payment_method_label', 'Method', false),
    ('amount', 'Amount', true),
  ],
  ReportKind.registers: [
    ('id', 'Register', false),
    ('opened_at', 'Opened', false),
    ('closed_at', 'Closed', false),
    ('location', 'Location', false),
    ('user', 'User', false),
    ('status', 'Status', false),
    ('total_amount', 'Total', true),
  ],
  ReportKind.inventoryValuation: [],
  ReportKind.stockMovements: [
    ('reference', 'Reference', false),
    ('transaction_date', 'Date', false),
    ('movement_type', 'Movement', false),
    ('location', 'Location', false),
    ('direction', 'Direction', false),
    ('quantity', 'Quantity', false),
    ('value', 'Value', true),
  ],
  ReportKind.returns: [
    ('reference', 'Reference', false),
    ('parent_reference', 'Original', false),
    ('transaction_date', 'Date', false),
    ('return_type', 'Type', false),
    ('contact', 'Contact', false),
    ('final_total', 'Total', true),
  ],
};

String _label(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

Widget _reportValue(String key, dynamic value, {TextStyle? style}) {
  if (key == 'profit_margin') {
    return Text('${_number(value).toStringAsFixed(1)}%', style: style);
  }
  if (key.contains('count') || key == 'row_count' || key == 'quantity') {
    return Text(_number(value).toStringAsFixed(0), style: style);
  }
  return RiyalAmount(toPaise(_number(value)), style: style);
}

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

class _ExportCancelled implements Exception {
  const _ExportCancelled();
}

String _reportFileName(ReportRequest request, String extension) {
  final from = _apiDate(request.startDate);
  final to = _apiDate(request.endDate);
  return 'eazy-pos-${request.kind.path}-$from-to-$to.$extension';
}

List<Map<String, dynamic>> _exportRows(ReportKind kind, ReportResult result) {
  if (kind != ReportKind.inventoryValuation) return result.rows;
  return result.summary.entries
      .map(
        (entry) => <String, dynamic>{
          'metric': _label(entry.key),
          'value': entry.value,
        },
      )
      .toList(growable: false);
}

List<(String, String, bool)> _exportColumns(
  ReportKind kind,
  ReportResult result,
) {
  if (kind == ReportKind.inventoryValuation) {
    return const [('metric', 'Metric', false), ('value', 'Value', false)];
  }
  return _columns[kind] ?? const [];
}

Future<Uint8List> _buildReportPdf(
  ReportRequest request,
  ReportResult result,
) async {
  final document = pw.Document(title: '${request.kind.label} report');
  final theme = await PdfFonts.arabicTheme();
  final rows = _exportRows(request.kind, result);
  final columns = _exportColumns(request.kind, result);
  final range = request.kind == ReportKind.inventoryValuation
      ? 'As of ${_apiDate(request.endDate)}'
      : '${_apiDate(request.startDate)} to ${_apiDate(request.endDate)}';

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Eazy POS - ${request.kind.label} Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(range, style: const pw.TextStyle(color: PdfColors.grey700)),
          pw.SizedBox(height: 10),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (_) => [
        if (result.summary.isNotEmpty) ...[
          pw.Wrap(
            spacing: 16,
            runSpacing: 8,
            children: result.summary.entries
                .map(
                  (entry) => pw.Text(
                    '${_label(entry.key)}: ${entry.value}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                )
                .toList(growable: false),
          ),
          pw.SizedBox(height: 16),
        ],
        if (rows.isEmpty)
          pw.Text('No report records match these filters')
        else
          pw.TableHelper.fromTextArray(
            headers: columns.map((column) => column.$2).toList(),
            data: rows
                .map(
                  (row) => columns
                      .map(
                        (column) => column.$3
                            ? _number(row[column.$1]).toStringAsFixed(2)
                            : row[column.$1]?.toString() ?? '-',
                      )
                      .toList(),
                )
                .toList(growable: false),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green50),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellBuilder: (_, value, __) => PdfFonts.text(value.toString()),
          ),
      ],
    ),
  );
  return document.save();
}

Uint8List _buildReportCsv(ReportRequest request, ReportResult result) {
  final rows = _exportRows(request.kind, result);
  final columns = _exportColumns(request.kind, result);
  final output = StringBuffer();
  output.writeln(columns.map((column) => _csvCell(column.$2)).join(','));
  for (final row in rows) {
    output.writeln(columns.map((column) => _csvCell(row[column.$1])).join(','));
  }
  // UTF-8 BOM keeps Arabic text readable when opened directly in Excel.
  return Uint8List.fromList([
    0xEF,
    0xBB,
    0xBF,
    ...utf8.encode(output.toString()),
  ]);
}

String _csvCell(dynamic value) {
  final text = value?.toString() ?? '';
  return '"${text.replaceAll('"', '""')}"';
}

String _apiDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
