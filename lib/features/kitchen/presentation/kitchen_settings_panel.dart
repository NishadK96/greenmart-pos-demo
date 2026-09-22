import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../shared/models/entities.dart';
import '../../../shared/widgets/localized_text.dart';
import '../../printers/application/printer_controller.dart';
import '../../printers/application/printer_document_service.dart';
import '../domain/kitchen_entities.dart';
import 'kitchen_printing_controller.dart';

class KitchenSettingsPanel extends ConsumerWidget {
  const KitchenSettingsPanel({required this.locations, super.key});

  final List<BusinessLocation> locations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(kitchenPrintingControllerProvider);
    final controller = ref.read(kitchenPrintingControllerProvider.notifier);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: asyncState.when(
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _ErrorState(
            message: error.toString(),
            onRetry: controller.refresh,
          ),
          data: (state) =>
              _KitchenSettingsContent(state: state, locations: locations),
        ),
      ),
    );
  }
}

class _KitchenSettingsContent extends ConsumerWidget {
  const _KitchenSettingsContent({required this.state, required this.locations});

  final KitchenPrintingState state;
  final List<BusinessLocation> locations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(kitchenPrintingControllerProvider.notifier);
    final printerState = ref.watch(printerControllerProvider);
    final printerController = ref.read(printerControllerProvider.notifier);
    final settings = state.settings;
    final options = state.options;
    if (settings == null || options == null) {
      return const Text('Kitchen settings are unavailable.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Restaurant & kitchen printing',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ERP controls item routing and durable jobs. This device controls the physical printers.',
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh kitchen configuration',
              onPressed: state.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (state.message != null) ...[
          const SizedBox(height: 12),
          _Notice(message: state.message!),
        ],
        if (!state.canManageSettings) ...[
          const SizedBox(height: 12),
          const _Notice(
            message:
                'You can view kitchen configuration, but this account cannot change templates, receipt settings, or printer routes. Business Settings permission is required.',
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 270,
              child: DropdownButtonFormField<String>(
                key: ValueKey(state.locationId),
                initialValue: state.locationId,
                decoration: const InputDecoration(
                  labelText: 'Business location',
                ),
                items: locations
                    .map(
                      (location) => DropdownMenuItem(
                        value: location.id,
                        child: Text(location.name),
                      ),
                    )
                    .toList(),
                onChanged: state.busy
                    ? null
                    : (value) {
                        if (value != null) controller.selectLocation(value);
                      },
              ),
            ),
            SizedBox(
              width: 270,
              child: DropdownButtonFormField<String>(
                initialValue: _validTemplate(
                  settings.selectedTemplate,
                  settings.templates,
                ),
                decoration: const InputDecoration(
                  labelText: 'Default kitchen template',
                ),
                items: settings.templates
                    .map(
                      (template) => DropdownMenuItem(
                        value: template.key,
                        child: Text(template.name),
                      ),
                    )
                    .toList(),
                onChanged: state.busy || !state.canManageSettings
                    ? null
                    : (value) {
                        if (value != null) {
                          controller.updateSettings({
                            'kitchen_order_template': value,
                          });
                        }
                      },
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _previewTemplate(
                context,
                controller,
                settings.selectedTemplate,
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Preview template'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 10),
        const Text(
          'Receipt behavior',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Print receipt after invoice finalization'),
          subtitle: const Text('This is saved to the selected ERP location.'),
          value: settings.printReceiptOnInvoice,
          onChanged: state.busy || !state.canManageSettings
              ? null
              : (value) => controller.updateSettings({
                  'print_receipt_on_invoice': value,
                }),
        ),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String>(
                initialValue: settings.receiptPrinterType,
                decoration: const InputDecoration(
                  labelText: 'ERP receipt printer type',
                ),
                items: const [
                  DropdownMenuItem(value: 'browser', child: Text('Browser')),
                  DropdownMenuItem(value: 'printer', child: Text('Printer')),
                ],
                onChanged: state.busy || !state.canManageSettings
                    ? null
                    : (value) {
                        if (value != null) {
                          controller.updateSettings({
                            'receipt_printer_type': value,
                          });
                        }
                      },
              ),
            ),
            SizedBox(
              width: 280,
              child: DropdownButtonFormField<String?>(
                initialValue: _validPrinter(settings.receiptPrinterId, options),
                decoration: const InputDecoration(
                  labelText: 'ERP receipt printer',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Not selected'),
                  ),
                  ...options.printers.map(
                    (printer) => DropdownMenuItem<String?>(
                      value: printer.id,
                      child: Text(printer.name),
                    ),
                  ),
                ],
                onChanged: state.busy || !state.canManageSettings
                    ? null
                    : (value) => controller.updateSettings({
                        'printer_id': value == null
                            ? null
                            : int.tryParse(value) ?? value,
                      }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Divider(),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pair ERP printers to this device',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text('Required before a kitchen job can print locally.'),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: printerState.scanning ? null : printerController.scan,
              icon: const Icon(Icons.search),
              label: const Text('Scan printers'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (options.printers.isEmpty)
          const _EmptyLine(
            text: 'No ERP printers are assigned to this location.',
          )
        else
          ...options.printers.map(
            (erpPrinter) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PrinterBindingRow(
                erpPrinter: erpPrinter,
                localPrinters: printerState.printers,
                selectedUrl:
                    printerState.settings.kitchenPrinterBindings[erpPrinter.id],
                onChanged: (printer) => printerController.bindKitchenPrinter(
                  erpPrinter.id,
                  printer,
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category printer routing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Subcategory rules take precedence over category rules.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed:
                  !state.canManageSettings ||
                      options.printers.isEmpty ||
                      options.categories.isEmpty
                  ? null
                  : () => _showRouteEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add route'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.routes.isEmpty)
          const _EmptyLine(
            text: 'No routes yet. Kitchen items will remain unassigned.',
          )
        else
          ...state.routes.map(
            (route) => _RouteTile(
              route: route,
              busy: state.busy,
              onEdit: state.canManageSettings
                  ? () => _showRouteEditor(context, ref, route: route)
                  : null,
              onDelete: state.canManageSettings
                  ? () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete route'),
                          content: Text(
                            'Stop sending ${route.category.name} items to ${route.printer.name}? Existing jobs will be kept.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete route'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true)
                        await controller.deleteRoute(route.id);
                    }
                  : null,
            ),
          ),
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Kitchen print jobs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: state.jobsAccessDenied
                  ? null
                  : () => controller.refreshJobs(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.jobsAccessDenied)
          const _Notice(
            message:
                'Kitchen job history is unavailable for this account. Ask the backend administrator to grant sales access for kitchen print jobs.',
          )
        else if (state.jobs.isEmpty)
          const _EmptyLine(text: 'No kitchen print jobs for this location.')
        else
          ...state.jobs
              .take(20)
              .map(
                (job) => _JobTile(
                  job: job,
                  paired: printerState.kitchenPrinter(job.printer.id) != null,
                  onPrint: () async {
                    try {
                      await controller.printJob(job);
                      if (context.mounted)
                        _snack(context, 'Kitchen job printed.');
                    } catch (error) {
                      if (context.mounted) _snack(context, error.toString());
                    }
                  },
                ),
              ),
      ],
    );
  }

  static String? _validTemplate(
    String selected,
    List<KitchenTemplate> templates,
  ) => templates.any((item) => item.key == selected)
      ? selected
      : templates.firstOrNull?.key;

  static String? _validPrinter(
    String? selected,
    KitchenPrinterOptions options,
  ) => options.printers.any((item) => item.id == selected) ? selected : null;
}

class _PrinterBindingRow extends StatelessWidget {
  const _PrinterBindingRow({
    required this.erpPrinter,
    required this.localPrinters,
    required this.selectedUrl,
    required this.onChanged,
  });

  final KitchenErpPrinter erpPrinter;
  final List<Printer> localPrinters;
  final String? selectedUrl;
  final ValueChanged<Printer?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(12),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              erpPrinter.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              erpPrinter.connectionType ?? 'ERP printer',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
        final picker = DropdownButtonFormField<String?>(
          initialValue: localPrinters.any((item) => item.url == selectedUrl)
              ? selectedUrl
              : null,
          decoration: const InputDecoration(labelText: 'Local Windows printer'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Not paired'),
            ),
            ...localPrinters
                .where((printer) => printer.url != 'system-print-dialog')
                .map(
                  (printer) => DropdownMenuItem<String?>(
                    value: printer.url,
                    child: Text(printer.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
          ],
          onChanged: (url) => onChanged(
            url == null
                ? null
                : localPrinters.firstWhere((item) => item.url == url),
          ),
        );
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [label, const SizedBox(height: 10), picker],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 16),
            SizedBox(width: 360, child: picker),
          ],
        );
      },
    ),
  );
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.route,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final KitchenPrinterRoute route;
  final bool busy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      child: Icon(route.isActive ? Icons.route : Icons.pause_outlined),
    ),
    title: Text(
      route.subCategory == null
          ? route.category.name
          : '${route.category.name} / ${route.subCategory!.name}',
    ),
    subtitle: Text(
      '${route.printer.name} · ${route.template?.name ?? 'Location default'} · Priority ${route.priority}',
    ),
    trailing: Wrap(
      children: [
        IconButton(
          tooltip: 'Edit route',
          onPressed: busy ? null : onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Delete route',
          onPressed: busy ? null : onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
  );
}

class _JobTile extends StatelessWidget {
  const _JobTile({
    required this.job,
    required this.paired,
    required this.onPrint,
  });

  final KitchenPrintJob job;
  final bool paired;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final needsAction = job.status == 'pending' || job.status == 'failed';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        job.status == 'printed'
            ? Icons.check_circle
            : job.status == 'failed'
            ? Icons.error_outline
            : Icons.print_outlined,
        color: job.status == 'printed'
            ? Colors.green
            : job.status == 'failed'
            ? Colors.red
            : null,
      ),
      title: Text('Order ${job.transactionId} · ${job.printer.name}'),
      subtitle: Text(
        '${job.items.length} item(s) · ${job.template} · ${job.status}'
        '${job.lastError == null ? '' : '\n${job.lastError}'}',
      ),
      isThreeLine: job.lastError != null,
      trailing: needsAction
          ? FilledButton.tonalIcon(
              onPressed: paired ? onPrint : null,
              icon: const Icon(Icons.refresh),
              label: Text(job.status == 'failed' ? 'Retry' : 'Print'),
            )
          : null,
    );
  }
}

class _RouteEditor extends StatefulWidget {
  const _RouteEditor({required this.options, this.route});

  final KitchenPrinterOptions options;
  final KitchenPrinterRoute? route;

  @override
  State<_RouteEditor> createState() => _RouteEditorState();
}

class _RouteEditorState extends State<_RouteEditor> {
  late String _categoryId;
  String? _subCategoryId;
  late String _printerId;
  String? _templateKey;
  late int _priority;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    _categoryId = route?.category.id ?? widget.options.categories.first.id;
    _subCategoryId = route?.subCategory?.id;
    _printerId = route?.printer.id ?? widget.options.printers.first.id;
    _templateKey = route?.template?.key;
    _priority = route?.priority ?? 0;
    _active = route?.isActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.options.categories.firstWhere(
      (item) => item.id == _categoryId,
    );
    return AlertDialog(
      title: Text(
        widget.route == null ? 'Add kitchen route' : 'Edit kitchen route',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: widget.options.categories
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _categoryId = value!;
                  _subCategoryId = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _subCategoryId,
                decoration: const InputDecoration(labelText: 'Subcategory'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All subcategories'),
                  ),
                  ...category.subCategories.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _subCategoryId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _printerId,
                decoration: const InputDecoration(labelText: 'ERP printer'),
                items: widget.options.printers
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _printerId = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _templateKey,
                decoration: const InputDecoration(labelText: 'Ticket template'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Use location default'),
                  ),
                  ...widget.options.templates.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.key,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _templateKey = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '$_priority',
                decoration: const InputDecoration(
                  labelText: 'Priority (0–1000)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    _priority = (int.tryParse(value) ?? 0).clamp(0, 1000),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Route active'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
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
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'categoryId': _categoryId,
            'subCategoryId': _subCategoryId,
            'printerId': _printerId,
            'templateKey': _templateKey,
            'priority': _priority,
            'active': _active,
          }),
          child: const Text('Save route'),
        ),
      ],
    );
  }
}

Future<void> _showRouteEditor(
  BuildContext context,
  WidgetRef ref, {
  KitchenPrinterRoute? route,
}) async {
  final state = ref.read(kitchenPrintingControllerProvider).asData?.value;
  final options = state?.options;
  if (options == null ||
      options.categories.isEmpty ||
      options.printers.isEmpty) {
    return;
  }
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _RouteEditor(options: options, route: route),
  );
  if (result == null) return;
  await ref
      .read(kitchenPrintingControllerProvider.notifier)
      .saveRoute(
        routeId: route?.id,
        categoryId: result['categoryId'] as String,
        subCategoryId: result['subCategoryId'] as String?,
        printerId: result['printerId'] as String,
        templateKey: result['templateKey'] as String?,
        priority: result['priority'] as int,
        isActive: result['active'] as bool,
      );
}

Future<void> _previewTemplate(
  BuildContext context,
  KitchenPrintingController controller,
  String template,
) async {
  try {
    final html = await controller.previewTemplate(template);
    final info = await Printing.info();
    if (info.canConvertHtml) {
      // ignore: deprecated_member_use
      final bytes = await Printing.convertHtml(
        html: html,
        format: template == 'a4'
            ? PdfPageFormat.a4
            : PdfPageFormat(80 * PdfPageFormat.mm, 260 * PdfPageFormat.mm),
      );
      await PrinterDocumentService.previewPdfBytes(
        bytes,
        name: 'Kitchen $template preview.pdf',
        format: template == 'a4'
            ? PdfPageFormat.a4
            : PdfPageFormat(80 * PdfPageFormat.mm, 260 * PdfPageFormat.mm),
      );
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kitchen template preview'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(child: SelectableText(_plainText(html))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  } catch (error) {
    if (context.mounted) _snack(context, 'Preview failed: $error');
  }
}

String _plainText(String html) => html
    .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'</(div|p|tr|li|h[1-6])>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
    .trim();

void _snack(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

class _Notice extends StatelessWidget {
  const _Notice({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(message),
  );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Text(text),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 36),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
