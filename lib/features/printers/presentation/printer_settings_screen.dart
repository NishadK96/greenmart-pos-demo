import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ui.dart';
import '../application/printer_controller.dart';
import '../application/printer_document_service.dart';
import '../domain/printer_settings.dart';

class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(printerControllerProvider);
    final controller = ref.read(printerControllerProvider.notifier);
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
                          final selectedUrl =
                              settings.selectedPrinters[settings.profileKey];
                          final selected = state.printers
                              .where((item) => item.url == selectedUrl)
                              .firstOrNull;
                          await PrinterDocumentService.printSampleTo(
                            settings,
                            printer: selected,
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
                'Configure document profiles, paper sizes and installed printers.',
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
  const _DocumentSettings({required this.settings, required this.onChanged});
  final PrinterSettings settings;
  final ValueChanged<PrinterSettings> onChanged;
  @override
  Widget build(BuildContext context) {
    final key = settings.profileKey;
    final papers = settings.section == PrinterSection.barcode
        ? const ['50 × 25 mm', '40 × 30 mm']
        : const ['58mm', '80mm', 'A4'];
    final currentPaper = papers.contains(settings.paperSizes[key])
        ? settings.paperSizes[key]!
        : papers.first;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document settings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 300,
                child: DropdownButtonFormField<String>(
                  initialValue: currentPaper,
                  decoration: const InputDecoration(
                    labelText: 'Paper / label size',
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
                  initialValue: settings.templates[key],
                  decoration: const InputDecoration(
                    labelText: 'Document theme',
                  ),
                  items: [settings.templates[key] ?? 'Default']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
    final selectedUrl = settings.selectedPrinters[settings.profileKey];
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
                      'Available printers',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${printers.length} device${printers.length == 1 ? '' : 's'} available',
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
                    const StatusBadge('Selected')
                  else
                    OutlinedButton(
                      onPressed: () => onSelect(printer),
                      child: const Text('Select'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
