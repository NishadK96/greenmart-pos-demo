import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../shared/models/entities.dart';
import '../domain/printer_settings.dart';

class PrinterDocumentService {
  static PdfPageFormat formatFor(String paper) {
    if (paper == '58mm') {
      return PdfPageFormat(58 * PdfPageFormat.mm, 220 * PdfPageFormat.mm);
    }
    if (paper == '80mm') {
      return PdfPageFormat(80 * PdfPageFormat.mm, 260 * PdfPageFormat.mm);
    }
    if (paper == '50 × 25 mm') {
      return PdfPageFormat(50 * PdfPageFormat.mm, 25 * PdfPageFormat.mm);
    }
    return PdfPageFormat.a4;
  }

  static Future<Uint8List> sample(
    PrinterSettings settings,
    PdfPageFormat requested,
  ) async {
    final profile = settings.profileKey;
    final paper = settings.paperSizes[profile] ?? '80mm';
    final format = formatFor(paper);
    final doc = pw.Document();
    if (settings.section == PrinterSection.barcode) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(8),
          build: (_) => pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (settings.showStoreName)
                pw.Text(
                  'GREENMART',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              pw.Text('Sample Product', maxLines: 1),
              if (settings.showPrice)
                pw.Text(
                  'SAR 49.00',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: 'SKU-1000',
                height: settings.barcodeHeight.toDouble(),
                drawText: true,
              ),
            ],
          ),
        ),
      );
      return doc.save();
    }
    final title = switch (settings.section) {
      PrinterSection.billing =>
        settings.billingAudience == BillingAudience.business
            ? 'TAX INVOICE - B2B'
            : 'SIMPLIFIED TAX INVOICE - B2C',
      PrinterSection.quotation => 'QUOTATION',
      PrinterSection.kitchen => 'KITCHEN ORDER TICKET',
      PrinterSection.barcode => '',
    };
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(
          format.width < PdfPageFormat.a4.width ? 12 : 36,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              'GREENMART',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              title,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text('Document: TEST-0001'),
            pw.Text(
              'Date: ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
            ),
            pw.Divider(),
            _line('Sample Product', '2 x 49.00'),
            _line('Service item', '1 x 25.00'),
            pw.Divider(),
            _line('Subtotal', '123.00'),
            if (settings.section != PrinterSection.kitchen) ...[
              _line('VAT', '6.15'),
              pw.SizedBox(height: 4),
              _line('TOTAL', '129.15', bold: true),
            ],
            pw.Spacer(),
            pw.Text(
              'Printer configuration test',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> receipt(
    Sale sale,
    String businessName,
    PrinterSettings settings,
    PdfPageFormat requested,
  ) async {
    final profile = sale.customer.isBusiness
        ? 'billing-business'
        : 'billing-retail';
    final format = formatFor(settings.paperSizes[profile] ?? '80mm');
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(
          format.width < PdfPageFormat.a4.width ? 12 : 36,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              businessName.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              sale.customer.isBusiness
                  ? 'TAX INVOICE'
                  : 'SIMPLIFIED TAX INVOICE',
              textAlign: pw.TextAlign.center,
            ),
            pw.Divider(),
            pw.Text('Invoice: ${sale.invoiceNo}'),
            pw.Text('Customer: ${sale.customer.name}'),
            if (sale.customer.taxNumber?.isNotEmpty == true)
              pw.Text('VAT: ${sale.customer.taxNumber}'),
            pw.Text('Payment: ${sale.paymentMethod.toUpperCase()}'),
            pw.Divider(),
            for (final item in sale.items)
              _line(
                '${item.quantity} x ${item.product.name}',
                _money(item.total),
              ),
            pw.Divider(),
            _line('Tax', _money(sale.tax)),
            _line('Discount', _money(sale.discount)),
            _line('TOTAL', _money(sale.total), bold: true),
            pw.SizedBox(height: 14),
            pw.Text('Thank you', textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _line(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: bold
                    ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                    : null,
              ),
            ),
            pw.Text(
              value,
              style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
            ),
          ],
        ),
      );

  static String _money(int minorUnits) =>
      'SAR ${(minorUnits / 100).toStringAsFixed(2)}';

  static Future<bool> printSample(PrinterSettings settings) =>
      Printing.layoutPdf(
        name: 'GreenMart ${settings.profileKey} test',
        format: formatFor(settings.paperSizes[settings.profileKey] ?? '80mm'),
        onLayout: (format) => sample(settings, format),
      );

  static Future<bool> printSampleTo(
    PrinterSettings settings, {
    Printer? printer,
  }) async {
    final format = formatFor(
      settings.paperSizes[settings.profileKey] ?? '80mm',
    );
    if (printer != null && printer.url != 'system-print-dialog') {
      return await Printing.directPrintPdf(
        printer: printer,
        name: 'GreenMart ${settings.profileKey} test',
        format: format,
        onLayout: (requested) => sample(settings, requested),
      );
    }
    return await printSample(settings);
  }

  static Future<bool> printReceipt(
    Sale sale,
    String businessName,
    PrinterSettings settings,
  ) => Printing.layoutPdf(
    name: 'Invoice ${sale.invoiceNo}',
    format: formatFor(
      settings.paperSizes[sale.customer.isBusiness
              ? 'billing-business'
              : 'billing-retail'] ??
          '80mm',
    ),
    onLayout: (format) => receipt(sale, businessName, settings, format),
  );

  static Future<bool> printReceiptTo(
    Sale sale,
    String businessName,
    PrinterSettings settings, {
    Printer? printer,
  }) async {
    if (printer != null && printer.url != 'system-print-dialog') {
      final profile = sale.customer.isBusiness
          ? 'billing-business'
          : 'billing-retail';
      return await Printing.directPrintPdf(
        printer: printer,
        name: 'Invoice ${sale.invoiceNo}',
        format: formatFor(settings.paperSizes[profile] ?? '80mm'),
        onLayout: (format) => receipt(sale, businessName, settings, format),
      );
    }
    return await printReceipt(sale, businessName, settings);
  }
}
