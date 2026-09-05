import 'package:flutter/material.dart' hide Text;
import 'package:retailflow_pos/shared/widgets/localized_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../apis/api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/desktop_pdf_preview.dart';
import '../../../shared/models/entities.dart';
import '../../../shared/widgets/ui.dart';
import '../../invoice_layouts/domain/invoice_layout_entities.dart';
import '../../invoice_layouts/presentation/invoice_layout_controller.dart';
import '../../store/app_store.dart';
import '../application/printer_controller.dart';
import '../application/printer_document_service.dart';
import '../domain/printer_settings.dart';

class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(printerControllerProvider);
    final layoutState = ref.watch(invoiceLayoutControllerProvider);
    final controller = ref.read(printerControllerProvider.notifier);
    final layoutController = ref.read(invoiceLayoutControllerProvider.notifier);
    final appState = ref.watch(appStoreProvider);
    final locations = appState.locations;
    final previewTransactionId = _latestFinalizedTransactionId(appState.sales);
    final settings = state.settings;
    return Scaffold(
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) => ListView(
                  padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
                  children: [
                    _Header(
                      onTest: () async {
                        try {
                          if (settings.section == PrinterSection.billing) {
                            final catalog = layoutState.asData?.value;
                            final selected = catalog?.selectedLayout;
                            if (selected == null) {
                              throw const ApiException(
                                'Select an ERP invoice layout before previewing.',
                              );
                            }
                            if (previewTransactionId == null) {
                              throw const ApiException(
                                'Complete and synchronize at least one sale before testing an ERP invoice layout.',
                              );
                            }
                            final file = await layoutController.preview(
                              selected.id,
                              transactionId: previewTransactionId,
                            );
                            await PrinterDocumentService.printPdfBytes(
                              file.bytes,
                              name: file.fileName,
                              printer: state.selectedPrinter,
                              previewBeforePrinting:
                                  settings.previewBeforePrinting,
                            );
                            return;
                          }
                          await PrinterDocumentService.printSampleTo(
                            settings,
                            printer: state.selectedPrinter,
                          );
                        } catch (error) {
                          if (context.mounted)
                            _message(context, 'Print failed: $error');
                        }
                      },
                      onReload: controller.load,
                      onClear: controller.clearDefaults,
                    ),
                    const SizedBox(height: 18),
                    _SectionTabs(
                      settings: settings,
                      onChanged: controller.update,
                    ),
                    const SizedBox(height: 14),
                    if (settings.section == PrinterSection.billing)
                      _AudienceTabs(
                        settings: settings,
                        onChanged: controller.update,
                      ),
                    if (settings.section == PrinterSection.billing)
                      const SizedBox(height: 14),
                    if (settings.section == PrinterSection.billing) ...[
                      _ErpInvoiceLayoutsPanel(
                        state: layoutState,
                        locations: locations,
                        onLocationChanged: layoutController.selectLocation,
                        onDocumentTypeChanged:
                            layoutController.selectDocumentType,
                        onRefresh: layoutController.refresh,
                        onPreview: (layout) => _showErpInvoicePreview(
                          context,
                          layout: layout,
                          load: () {
                            if (previewTransactionId == null) {
                              throw const ApiException(
                                'Complete and synchronize at least one sale before previewing an ERP invoice layout.',
                              );
                            }
                            return layoutController.preview(
                              layout.id,
                              transactionId: previewTransactionId,
                            );
                          },
                        ),
                        onAssign: (layout) async {
                          try {
                            await layoutController.assign(layout.id);
                            final templates =
                                Map<String, String>.from(settings.templates)
                                  ..['billing-retail'] = PrinterTemplate.erp
                                  ..['billing-business'] = PrinterTemplate.erp;
                            await controller.update(
                              settings.copyWith(templates: templates),
                            );
                            if (context.mounted) {
                              _message(
                                context,
                                '${layout.name} is now the default ERP invoice layout.',
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              _message(context, error.toString());
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      _PrintBehaviorSettings(
                        settings: settings,
                        onChanged: controller.update,
                      ),
                      const SizedBox(height: 14),
                      _DocumentSettings(
                        settings: settings,
                        onChanged: controller.update,
                        billingFallback: true,
                      ),
                    ] else
                      _DocumentSettings(
                        settings: settings,
                        onChanged: controller.update,
                      ),
                    if (settings.section == PrinterSection.barcode) ...[
                      const SizedBox(height: 14),
                      _BarcodeSettings(
                        settings: settings,
                        onChanged: controller.update,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _PrinterList(
                      printers: state.printers,
                      settings: settings,
                      scanning: state.scanning,
                      message: state.message,
                      onScan: controller.scan,
                      onSelect: controller.selectPrinter,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  static void _message(BuildContext context, String message) =>
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

  static String? _latestFinalizedTransactionId(List<Sale> sales) {
    Sale? latest;
    for (final sale in sales) {
      if (sale.serverId == null || sale.serverId!.trim().isEmpty) continue;
      if (latest == null || sale.createdAt.isAfter(latest.createdAt)) {
        latest = sale;
      }
    }
    return latest?.serverId;
  }
}

class _ErpInvoiceLayoutsPanel extends StatelessWidget {
  const _ErpInvoiceLayoutsPanel({
    required this.state,
    required this.locations,
    required this.onLocationChanged,
    required this.onDocumentTypeChanged,
    required this.onRefresh,
    required this.onPreview,
    required this.onAssign,
  });

  final AsyncValue<ErpInvoiceLayoutCatalog?> state;
  final List<BusinessLocation> locations;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<String> onDocumentTypeChanged;
  final VoidCallback onRefresh;
  final Future<void> Function(ErpInvoiceLayout) onPreview;
  final ValueChanged<ErpInvoiceLayout> onAssign;

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEAF6F2),
              child: Icon(Icons.cloud_done_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Official invoice layout',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Managed in EazyERP. This layout and its paper format are used for synchronized sales and reprints at this location.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: context.tr('Reload ERP layouts'),
              onPressed: state.isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (locations.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(state.asData?.value?.locationId),
                  initialValue:
                      state.asData?.value?.locationId ?? locations.first.id,
                  decoration: InputDecoration(
                    labelText: context.tr('Business location'),
                  ),
                  items: locations
                      .map(
                        (location) => DropdownMenuItem(
                          value: location.id,
                          child: Text(location.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: state.isLoading
                      ? null
                      : (value) {
                          if (value != null) onLocationChanged(value);
                        },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(state.asData?.value?.documentType),
                  initialValue: state.asData?.value?.documentType ?? 'pos',
                  decoration: InputDecoration(
                    labelText: context.tr('Document type'),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pos', child: Text('POS sale')),
                    DropdownMenuItem(
                      value: 'direct_sale',
                      child: Text('Direct sale'),
                    ),
                  ],
                  onChanged: state.isLoading
                      ? null
                      : (value) {
                          if (value != null) onDocumentTypeChanged(value);
                        },
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        state.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1C7C7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined, color: Color(0xFFC94B4B)),
                const SizedBox(width: 10),
                Expanded(child: Text(error.toString())),
                TextButton(onPressed: onRefresh, child: const Text('Retry')),
              ],
            ),
          ),
          data: (catalog) {
            if (catalog == null || catalog.layouts.isEmpty) {
              return const EmptyState(
                'No ERP invoice layouts are available for this location.',
              );
            }
            return LayoutBuilder(
              builder: (_, constraints) {
                final columns = constraints.maxWidth >= 980
                    ? 3
                    : constraints.maxWidth >= 640
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: catalog.layouts
                      .map(
                        (layout) => SizedBox(
                          width: width,
                          child: _ErpLayoutCard(
                            layout: layout,
                            selected: layout.id == catalog.currentLayoutId,
                            onPreview: () => onPreview(layout),
                            onAssign: () => onAssign(layout),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

class _ErpLayoutCard extends StatelessWidget {
  const _ErpLayoutCard({
    required this.layout,
    required this.selected,
    required this.onPreview,
    required this.onAssign,
  });

  final ErpInvoiceLayout layout;
  final bool selected;
  final VoidCallback onPreview;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: selected ? const Color(0xFFF0F8F5) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: selected ? AppColors.primary : const Color(0xFFDDE5E1),
        width: selected ? 1.5 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.description_outlined,
              color: selected ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                layout.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          layout.designName.isEmpty ? layout.design : layout.designName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Preview'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: selected ? null : onAssign,
                child: Text(selected ? 'Default' : 'Set default'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _showErpInvoicePreview(
  BuildContext context, {
  required ErpInvoiceLayout layout,
  required Future<ErpInvoicePdf> Function() load,
}) => showDialog<void>(
  context: context,
  barrierColor: const Color(0xCC17201D),
  builder: (_) => _ErpInvoicePreviewDialog(layout: layout, load: load),
);

class _ErpInvoicePreviewDialog extends StatefulWidget {
  const _ErpInvoicePreviewDialog({required this.layout, required this.load});

  final ErpInvoiceLayout layout;
  final Future<ErpInvoicePdf> Function() load;

  @override
  State<_ErpInvoicePreviewDialog> createState() =>
      _ErpInvoicePreviewDialogState();
}

class _ErpInvoicePreviewDialogState extends State<_ErpInvoicePreviewDialog> {
  late Future<ErpInvoicePdf> _preview;

  @override
  void initState() {
    super.initState();
    _preview = widget.load();
  }

  void _retry() => setState(() => _preview = widget.load());

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.width < 720;
    final designName = widget.layout.designName.isEmpty
        ? widget.layout.design
        : widget.layout.designName;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 32,
        vertical: compact ? 12 : 24,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1180,
          maxHeight: screen.height - (compact ? 24 : 48),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 22,
                15,
                compact ? 8 : 12,
                14,
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFFE5F4EF),
                    child: Icon(
                      Icons.preview_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.layout.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          designName.isEmpty
                              ? 'EazyERP invoice preview'
                              : '$designName • EazyERP preview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F8F5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Preview only • Nothing will print',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.tr('Close preview'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF555B59),
                child: FutureBuilder<ErpInvoicePdf>(
                  future: _preview,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _InvoicePreviewLoading();
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return _InvoicePreviewError(
                        message:
                            snapshot.error?.toString() ??
                            'The invoice preview could not be generated.',
                        onRetry: _retry,
                      );
                    }
                    final file = snapshot.requireData;
                    if (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.windows) {
                      return _WindowsErpPreview(file: file);
                    }
                    return PdfPreview(
                      build: (_) async => file.bytes,
                      pdfFileName: file.fileName,
                      allowPrinting: false,
                      allowSharing: false,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      useActions: false,
                      dynamicLayout: false,
                      maxPageWidth: 940,
                      padding: EdgeInsets.all(compact ? 12 : 24),
                      previewPageMargin: EdgeInsets.symmetric(
                        horizontal: compact ? 4 : 14,
                        vertical: 10,
                      ),
                      scrollViewDecoration: const BoxDecoration(
                        color: Color(0xFF555B59),
                      ),
                      pdfPreviewPageDecoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x59000000),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(2),
                      ),
                      loadingWidget: const _InvoicePreviewLoading(),
                      onError: (_, error) => _InvoicePreviewError(
                        message: error.toString(),
                        onRetry: _retry,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowsErpPreview extends StatefulWidget {
  const _WindowsErpPreview({required this.file});

  final ErpInvoicePdf file;

  @override
  State<_WindowsErpPreview> createState() => _WindowsErpPreviewState();
}

class _WindowsErpPreviewState extends State<_WindowsErpPreview> {
  bool _opening = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (mounted)
      setState(() {
        _opening = true;
        _error = null;
      });
    try {
      final opened = await openDesktopPdfPreview(
        widget.file.bytes,
        fileName: widget.file.fileName,
      );
      if (!opened) throw StateError('Windows PDF viewer is unavailable.');
      if (mounted) setState(() => _opening = false);
    } catch (error) {
      if (mounted)
        setState(() {
          _opening = false;
          _error = error.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      margin: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_opening)
                const CircularProgressIndicator()
              else
                Icon(
                  _error == null
                      ? Icons.open_in_new_rounded
                      : Icons.error_outline_rounded,
                  size: 42,
                  color: _error == null ? AppColors.primary : AppColors.danger,
                ),
              const SizedBox(height: 16),
              Text(
                _opening
                    ? 'Opening invoice preview…'
                    : _error == null
                    ? 'Preview opened in your Windows PDF viewer'
                    : 'Unable to open the Windows PDF viewer',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ??
                    'This uses the native Windows viewer to reliably display the ERP invoice. Nothing is printed automatically.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              if (!_opening) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _open,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open preview again'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _InvoicePreviewLoading extends StatelessWidget {
  const _InvoicePreviewLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Card(
      margin: EdgeInsets.all(24),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Generating EazyERP preview…',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              'Loading the selected layout, labels and invoice fields.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InvoicePreviewError extends StatelessWidget {
  const _InvoicePreviewError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      margin: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: AppColors.danger,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load preview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry preview'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onTest,
    required this.onReload,
    required this.onClear,
  });
  final VoidCallback onTest, onReload, onClear;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 12,
      spacing: 16,
      children: [
        SizedBox(
          width: constraints.maxWidth < 760 ? constraints.maxWidth : 520,
          child: const PageTitle(
            'Printer settings',
            subtitle:
                'Choose the official ERP invoice layout, local fallbacks and default printer.',
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onTest,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Test print'),
            ),
            OutlinedButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.sync),
              label: const Text('Reload config'),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.layers_clear_outlined),
              label: const Text('Clear defaults'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.settings, required this.onChanged});
  final PrinterSettings settings;
  final ValueChanged<PrinterSettings> onChanged;
  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.all(6),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<PrinterSection>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: PrinterSection.billing,
            icon: Icon(Icons.receipt_long_outlined),
            label: Text('Billing printer'),
          ),
          ButtonSegment(
            value: PrinterSection.quotation,
            icon: Icon(Icons.description_outlined),
            label: Text('Quotation printer'),
          ),
          ButtonSegment(
            value: PrinterSection.kitchen,
            icon: Icon(Icons.restaurant_outlined),
            label: Text('Kitchen printer'),
          ),
          ButtonSegment(
            value: PrinterSection.barcode,
            icon: Icon(Icons.qr_code_2),
            label: Text('Barcode printer'),
          ),
        ],
        selected: {settings.section},
        onSelectionChanged: (value) =>
            onChanged(settings.copyWith(section: value.first)),
      ),
    ),
  );
}

class _AudienceTabs extends StatelessWidget {
  const _AudienceTabs({required this.settings, required this.onChanged});
  final PrinterSettings settings;
  final ValueChanged<PrinterSettings> onChanged;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SegmentedButton<BillingAudience>(
      segments: const [
        ButtonSegment(
          value: BillingAudience.retail,
          label: Text('B2C · Retail'),
        ),
        ButtonSegment(
          value: BillingAudience.business,
          label: Text('B2B · Business'),
        ),
      ],
      selected: {settings.billingAudience},
      onSelectionChanged: (value) =>
          onChanged(settings.copyWith(billingAudience: value.first)),
    ),
  );
}

class _DocumentSettings extends StatelessWidget {
  const _DocumentSettings({
    required this.settings,
    required this.onChanged,
    this.billingFallback = false,
  });
  final PrinterSettings settings;
  final ValueChanged<PrinterSettings> onChanged;
  final bool billingFallback;
  @override
  Widget build(BuildContext context) {
    final key = settings.profileKey;
    final papers = settings.section == PrinterSection.barcode
        ? const ['50 × 25 mm', '40 × 30 mm']
        : const ['58mm', '80mm', 'A4'];
    final currentPaper = papers.contains(settings.paperSizes[key])
        ? settings.paperSizes[key]!
        : papers.first;
    final templates = PrinterTemplate.optionsFor(settings.section);
    final currentTemplate = templates.contains(settings.templates[key])
        ? settings.templates[key]!
        : templates.first;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            billingFallback ? 'Offline receipt fallback' : 'Document settings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (billingFallback) ...[
            const SizedBox(height: 4),
            const Text(
              'Used only for a provisional receipt when a sale has not yet synchronized. The official invoice is always generated by EazyERP.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 300,
                child: DropdownButtonFormField<String>(
                  initialValue: currentPaper,
                  decoration: InputDecoration(
                    labelText: context.tr('Paper / label size'),
                  ),
                  items: papers
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) {
                    final map = Map<String, String>.from(settings.paperSizes)
                      ..[key] = value!;
                    onChanged(settings.copyWith(paperSizes: map));
                  },
                ),
              ),
              SizedBox(
                width: 340,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('$key-$currentTemplate'),
                  initialValue: currentTemplate,
                  decoration: InputDecoration(
                    labelText: context.tr('Default print template'),
                    helperText: context.tr(
                      'Used automatically for this document type',
                    ),
                  ),
                  items: templates
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Row(
                            children: [
                              if (item == PrinterTemplate.erp) ...[
                                const Icon(Icons.cloud_done_outlined, size: 17),
                                const SizedBox(width: 8),
                              ],
                              Text(item),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    onChanged(settings.withTemplateForCurrentSection(value));
                  },
                ),
              ),
            ],
          ),
          if (!billingFallback) ...[
            const SizedBox(height: 12),
            _PreviewBeforePrintingToggle(
              settings: settings,
              onChanged: onChanged,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6F2),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFB8D9CF)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    billingFallback
                        ? '$currentTemplate on $currentPaper is used only for provisional offline receipts.'
                        : '$currentTemplate is the default for ${_profileLabel(settings)}.',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _profileLabel(PrinterSettings settings) => switch (settings.section) {
    PrinterSection.billing =>
      settings.billingAudience == BillingAudience.retail
          ? 'B2C billing'
          : 'B2B billing',
    PrinterSection.quotation => 'quotations',
    PrinterSection.kitchen => 'kitchen tickets',
    PrinterSection.barcode => 'barcode labels',
  };
}

class _PrintBehaviorSettings extends StatelessWidget {
  const _PrintBehaviorSettings({
    required this.settings,
    required this.onChanged,
  });

  final PrinterSettings settings;
  final ValueChanged<PrinterSettings> onChanged;

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Print behavior',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _PreviewBeforePrintingToggle(settings: settings, onChanged: onChanged),
      ],
    ),
  );
}

class _PreviewBeforePrintingToggle extends StatelessWidget {
  const _PreviewBeforePrintingToggle({
    required this.settings,
    required this.onChanged,
  });

  final PrinterSettings settings;
  final ValueChanged<PrinterSettings> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: const EdgeInsets.symmetric(horizontal: 2),
    value: settings.previewBeforePrinting,
    onChanged: (value) =>
        onChanged(settings.copyWith(previewBeforePrinting: value)),
    secondary: const Icon(Icons.preview_outlined),
    title: const Text(
      'Preview test document',
      style: TextStyle(fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      settings.previewBeforePrinting
          ? 'The Test print button opens a preview. Regular Print actions still use the saved printer directly.'
          : 'The Test print button uses the saved printer directly.',
    ),
  );
}

class _BarcodeSettings extends StatelessWidget {
  const _BarcodeSettings({required this.settings, required this.onChanged});
  final PrinterSettings settings;
  final ValueChanged<PrinterSettings> onChanged;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Barcode sticker layout',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () => onChanged(
                const PrinterSettings(section: PrinterSection.barcode),
              ),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SliderRow(
          label: 'Stickers per row',
          value: settings.barcodeColumns.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          suffix: '${settings.barcodeColumns}',
          onChanged: (value) =>
              onChanged(settings.copyWith(barcodeColumns: value.round())),
        ),
        _SliderRow(
          label: 'Barcode height',
          value: settings.barcodeHeight.toDouble(),
          min: 30,
          max: 100,
          divisions: 14,
          suffix: '${settings.barcodeHeight} px',
          onChanged: (value) =>
              onChanged(settings.copyWith(barcodeHeight: value.round())),
        ),
        _SliderRow(
          label: 'Barcode width',
          value: settings.barcodeWidthPercent.toDouble(),
          min: 40,
          max: 100,
          divisions: 12,
          suffix: '${settings.barcodeWidthPercent}%',
          onChanged: (value) =>
              onChanged(settings.copyWith(barcodeWidthPercent: value.round())),
        ),
        Wrap(
          spacing: 18,
          children: [
            FilterChip(
              label: const Text('Store name'),
              selected: settings.showStoreName,
              onSelected: (value) =>
                  onChanged(settings.copyWith(showStoreName: value)),
            ),
            FilterChip(
              label: const Text('Price'),
              selected: settings.showPrice,
              onSelected: (value) =>
                  onChanged(settings.copyWith(showPrice: value)),
            ),
            FilterChip(
              label: const Text('Print date'),
              selected: settings.showDate,
              onSelected: (value) =>
                  onChanged(settings.copyWith(showDate: value)),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });
  final String label, suffix;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final slider = Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      );
      if (constraints.maxWidth < 430) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(suffix),
              ],
            ),
            slider,
          ],
        );
      }
      return Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: slider),
          SizedBox(width: 64, child: Text(suffix, textAlign: TextAlign.end)),
        ],
      );
    },
  );
}

class _PrinterList extends StatelessWidget {
  const _PrinterList({
    required this.printers,
    required this.settings,
    required this.scanning,
    required this.message,
    required this.onScan,
    required this.onSelect,
  });
  final List<Printer> printers;
  final PrinterSettings settings;
  final bool scanning;
  final String? message;
  final VoidCallback onScan;
  final ValueChanged<Printer> onSelect;
  @override
  Widget build(BuildContext context) {
    final selectedUrl = settings.defaultPrinterUrl;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default printer for this app',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Used automatically for sales, purchases, ZATCA and all other print actions',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: scanning ? null : onScan,
                icon: scanning
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radar),
                label: const Text('Scan for printers'),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB96A00)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(message!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final printer in printers)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDDE5E2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE4F2EE),
                    child: Icon(Icons.print_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          printer.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (printer.model?.isNotEmpty == true)
                          Text(
                            printer.model!,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                      ],
                    ),
                  ),
                  if (selectedUrl == printer.url)
                    const StatusBadge('Default')
                  else
                    OutlinedButton(
                      onPressed: () => onSelect(printer),
                      child: const Text('Set as default'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
