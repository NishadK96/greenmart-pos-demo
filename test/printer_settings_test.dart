import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eazy_pos/features/printers/application/printer_controller.dart';
import 'package:eazy_pos/features/printers/application/printer_document_service.dart';
import 'package:eazy_pos/features/printers/data/printer_settings_repository.dart';
import 'package:eazy_pos/features/printers/domain/printer_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ERP is available for every printer document type', () {
    for (final section in PrinterSection.values) {
      expect(
        PrinterTemplate.optionsFor(section),
        contains(PrinterTemplate.erp),
      );
    }
  });

  test('selected ERP template persists as the profile default', () async {
    final repository = PrinterSettingsRepository();
    const initial = PrinterSettings();
    final templates = Map<String, String>.from(initial.templates)
      ..['billing-retail'] = PrinterTemplate.erp;

    await repository.save(initial.copyWith(templates: templates));
    final restored = await repository.load();

    expect(restored.templateFor('billing-retail'), PrinterTemplate.erp);
    expect(restored.usesErpTemplate('billing-retail'), isTrue);
    expect(
      restored.templateFor('billing-business'),
      PrinterTemplate.detailedTaxInvoice,
    );
  });

  test(
    'one default printer persists globally for every document type',
    () async {
      final repository = PrinterSettingsRepository();
      const printerUrl = r'windows-printer://office-receipt-printer';
      const printerName = 'Office receipt printer';

      await repository.save(
        const PrinterSettings().copyWith(
          defaultPrinterUrl: printerUrl,
          defaultPrinterName: printerName,
        ),
      );
      final restored = await repository.load();

      expect(restored.defaultPrinterUrl, printerUrl);
      expect(restored.defaultPrinterName, printerName);
      for (final section in PrinterSection.values) {
        expect(
          restored.copyWith(section: section).defaultPrinterUrl,
          printerUrl,
        );
      }
      for (final audience in BillingAudience.values) {
        expect(
          restored
              .copyWith(
                section: PrinterSection.billing,
                billingAudience: audience,
              )
              .defaultPrinterUrl,
          printerUrl,
        );
      }
    },
  );

  test('saved Windows printer remains usable before discovery completes', () {
    const printerUrl = r'windows-printer://office-receipt-printer';
    const printerName = 'Office receipt printer';
    final state = PrinterState(
      settings: const PrinterSettings().copyWith(
        defaultPrinterUrl: printerUrl,
        defaultPrinterName: printerName,
      ),
      printers: const <Printer>[],
      loading: false,
    );

    expect(state.selectedPrinter?.url, printerUrl);
    expect(state.selectedPrinter?.name, printerName);
  });

  test('multiple print destinations persist and remain usable', () async {
    const primaryUrl = r'windows-printer://receipt';
    const additionalUrl = r'windows-printer://office-copy';
    final repository = PrinterSettingsRepository();
    await repository.save(
      const PrinterSettings().copyWith(
        defaultPrinterUrl: primaryUrl,
        defaultPrinterName: 'Receipt printer',
        additionalPrinters: const {additionalUrl: 'Office copy'},
      ),
    );

    final restored = await repository.load();
    final state = PrinterState(settings: restored, loading: false);

    expect(restored.additionalPrinters, const {additionalUrl: 'Office copy'});
    expect(state.selectedPrinters.map((printer) => printer.url), [
      primaryUrl,
      additionalUrl,
    ]);
  });

  test('billing templates generate distinct print layouts', () async {
    Future<List<int>> build(String template) {
      const defaults = PrinterSettings();
      final templates = Map<String, String>.from(defaults.templates)
        ..['billing-retail'] = template;
      return PrinterDocumentService.sample(
        defaults.copyWith(templates: templates),
        PdfPageFormat.a4,
      );
    }

    final erp = await build(PrinterTemplate.erp);
    final bilingual = await build(PrinterTemplate.bilingualReceipt);
    final detailed = await build(PrinterTemplate.detailedTaxInvoice);

    expect(erp.length, greaterThan(500));
    expect(bilingual.length, greaterThan(500));
    expect(detailed.length, greaterThan(500));
    expect(listEquals(erp, bilingual), isFalse);
    expect(listEquals(erp, detailed), isFalse);
    expect(listEquals(bilingual, detailed), isFalse);
  });

  test('a billing template can be applied consistently to B2C and B2B', () {
    final settings = const PrinterSettings().withTemplateForCurrentSection(
      PrinterTemplate.bilingualReceipt,
    );

    expect(
      settings.templateFor('billing-retail'),
      PrinterTemplate.bilingualReceipt,
    );
    expect(
      settings.templateFor('billing-business'),
      PrinterTemplate.bilingualReceipt,
    );
  });
}
