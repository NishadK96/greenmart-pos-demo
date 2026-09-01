import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/desktop_pdf_preview.dart';
import '../../../shared/models/entities.dart';
import '../domain/printer_settings.dart';
import '../../offline_pos/domain/provisional_receipt_qr.dart';
import '../../../core/utils/pdf_fonts.dart';

class PrinterDocumentService {
  static Future<bool> printPdfBytes(
    Uint8List bytes, {
    required String name,
    Printer? printer,
    PdfPageFormat format = PdfPageFormat.a4,
    bool previewBeforePrinting = false,
  }) async {
    if (_usesExternalWindowsPreview && previewBeforePrinting) {
      return openDesktopPdfPreview(bytes, fileName: name);
    }
    if (!previewBeforePrinting &&
        printer != null &&
        printer.url != 'system-print-dialog') {
      try {
        final printed = await Printing.directPrintPdf(
          printer: printer,
          name: name,
          format: format,
          onLayout: (_) async => bytes,
        );
        if (printed) return true;
      } catch (_) {
        // Fall through to the system dialog when direct printing is unavailable.
      }
    }
    if (_usesExternalWindowsPreview) {
      return openDesktopPdfPreview(bytes, fileName: name);
    }
    return Printing.layoutPdf(
      name: name,
      format: format,
      onLayout: (_) async => bytes,
    );
  }

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
    final template = settings.templateFor(profile);
    final erpTemplate = template == PrinterTemplate.erp;
    final paper = settings.paperSizes[profile] ?? '80mm';
    final format = formatFor(paper);
    final doc = pw.Document();
    final theme = await PdfFonts.arabicTheme();
    if (settings.section == PrinterSection.barcode) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          theme: theme,
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
    if (settings.section == PrinterSection.billing && !erpTemplate) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          theme: theme,
          margin: pw.EdgeInsets.all(
            format.width < PdfPageFormat.a4.width ? 10 : 32,
          ),
          build: (_) => template == PrinterTemplate.detailedTaxInvoice
              ? _detailedTaxSample(settings.billingAudience)
              : _bilingualReceiptSample(settings.billingAudience),
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
        theme: theme,
        margin: pw.EdgeInsets.all(
          format.width < PdfPageFormat.a4.width ? 12 : 36,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (erpTemplate)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: .6),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    'ERP',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
            if (template == PrinterTemplate.bilingualReceipt) ...[
              pw.Text(
                'ARABIC & ENGLISH 3',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              PdfFonts.text(
                'نموذج الفاتورة العربية والإنجليزية',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 5),
            ],
            if (template == PrinterTemplate.detailedTaxInvoice) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DETAILED TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text('Supplier: GREENMART'),
                    pw.Text('VAT number: 300000000000003'),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
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
            if (settings.section == PrinterSection.billing)
              PdfFonts.text(
                settings.billingAudience == BillingAudience.business
                    ? 'فاتورة ضريبية'
                    : 'فاتورة ضريبية مبسطة',
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

  static pw.Widget _bilingualReceiptSample(BillingAudience audience) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'GREENMART',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
          PdfFonts.text(
            'جرين مارت',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'ARABIC & ENGLISH 3 · THERMAL RECEIPT',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7),
          ),
          pw.SizedBox(height: 7),
          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          PdfFonts.bilingual(
            audience == BillingAudience.business
                ? 'TAX INVOICE | فاتورة ضريبية'
                : 'SIMPLIFIED TAX INVOICE | فاتورة ضريبية مبسطة',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          _documentFact('Invoice | الفاتورة', 'TEST-0001'),
          _documentFact('Customer | العميل', 'Walk-in Customer'),
          _documentFact('Payment | الدفع', 'CASH | نقدي'),
          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          _line('Sample Product × 2', '98.00'),
          _line('Service item × 1', '25.00'),
          pw.Divider(borderStyle: pw.BorderStyle.dashed),
          _line('Subtotal | المجموع', '123.00'),
          _line('VAT | الضريبة', '6.15'),
          _line('TOTAL | الإجمالي', '129.15', bold: true),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: 'GREENMART|TEST-0001|129.15|6.15',
              width: 66,
              height: 66,
            ),
          ),
          pw.SizedBox(height: 6),
          PdfFonts.bilingual(
            'Thank you | شكراً لزيارتكم',
            textAlign: pw.TextAlign.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      );

  static pw.Widget _detailedTaxSample(BillingAudience audience) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DETAILED TAX INVOICE',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  PdfFonts.text('فاتورة ضريبية تفصيلية'),
                  pw.SizedBox(height: 5),
                  pw.Text('GREENMART'),
                  pw.Text('VAT: 300000000000003'),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Invoice: TEST-0001'),
                pw.Text('Customer: Walk-in Customer'),
                pw.Text(audience == BillingAudience.business ? 'B2B' : 'B2C'),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
      pw.TableHelper.fromTextArray(
        headers: const ['#', 'Product', 'Qty', 'Unit price', 'VAT', 'Total'],
        data: const [
          ['1', 'Sample Product', '2', '49.00', '4.90', '102.90'],
          ['2', 'Service item', '1', '25.00', '1.25', '26.25'],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        border: pw.TableBorder.all(width: .5),
        cellPadding: const pw.EdgeInsets.all(5),
      ),
      pw.SizedBox(height: 14),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 240,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)),
            child: pw.Column(
              children: [
                _line('Subtotal', '123.00'),
                _line('VAT', '6.15'),
                pw.Divider(),
                _line('Grand total', '129.15', bold: true),
              ],
            ),
          ),
        ),
      ),
      pw.Spacer(),
      pw.Row(
        children: [
          pw.Expanded(child: pw.Text('Receiver signature: ____________')),
          pw.Expanded(child: pw.Text('Salesperson signature: __________')),
        ],
      ),
    ],
  );

  static Future<Uint8List> receipt(
    Sale sale,
    String businessName,
    PrinterSettings settings,
    PdfPageFormat requested, {
    bool arabic = false,
  }) async {
    final profile = sale.customer.isBusiness
        ? 'billing-business'
        : 'billing-retail';
    final template = settings.templateFor(profile);
    final erpTemplate = template == PrinterTemplate.erp;
    final format = formatFor(settings.paperSizes[profile] ?? '80mm');
    final doc = pw.Document();
    final theme = await PdfFonts.arabicTheme();
    doc.addPage(
      pw.Page(
        pageFormat: format,
        theme: theme,
        margin: pw.EdgeInsets.all(
          format.width < PdfPageFormat.a4.width ? 12 : 36,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (template == PrinterTemplate.detailedTaxInvoice)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: .8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DETAILED TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    PdfFonts.text('فاتورة ضريبية تفصيلية'),
                    pw.SizedBox(height: 6),
                    PdfFonts.text(
                      businessName.toUpperCase(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('Invoice: ${sale.invoiceNo}'),
                    PdfFonts.text('Customer: ${sale.customer.name}'),
                    if (sale.customer.taxNumber?.isNotEmpty == true)
                      pw.Text('Customer VAT: ${sale.customer.taxNumber}'),
                  ],
                ),
              )
            else if (erpTemplate)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: .7),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: PdfFonts.text(
                        businessName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 17,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Text(
                      'ERP',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              PdfFonts.text(
                businessName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            if (erpTemplate || template == PrinterTemplate.detailedTaxInvoice)
              pw.SizedBox(height: 8),
            if (template == PrinterTemplate.bilingualReceipt) ...[
              pw.Text(
                'ARABIC & ENGLISH 3',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              PdfFonts.text(
                'فاتورة ثنائية اللغة',
                textAlign: pw.TextAlign.center,
              ),
            ],
            PdfFonts.text(
              sale.syncStatus == SyncStatus.pending
                  ? arabic
                        ? 'إيصال مؤقت غير متصل'
                        : 'PROVISIONAL OFFLINE RECEIPT'
                  : sale.customer.isBusiness
                  ? arabic
                        ? 'فاتورة ضريبية'
                        : 'TAX INVOICE'
                  : arabic
                  ? 'فاتورة ضريبية مبسطة'
                  : 'SIMPLIFIED TAX INVOICE',
              textAlign: pw.TextAlign.center,
            ),
            if (!arabic && sale.syncStatus != SyncStatus.pending)
              PdfFonts.text(
                sale.customer.isBusiness
                    ? 'فاتورة ضريبية'
                    : 'فاتورة ضريبية مبسطة',
                textAlign: pw.TextAlign.center,
              ),
            pw.Divider(),
            _documentFact(arabic ? 'الفاتورة' : 'Invoice', sale.invoiceNo),
            _documentFact(arabic ? 'العميل' : 'Customer', sale.customer.name),
            if (sale.customer.taxNumber?.isNotEmpty == true)
              _documentFact(
                arabic ? 'الرقم الضريبي' : 'VAT',
                sale.customer.taxNumber!,
              ),
            _documentFact(
              arabic ? 'الدفع' : 'Payment',
              _paymentLabel(sale.paymentMethod, arabic),
            ),
            pw.Divider(),
            if (template == PrinterTemplate.detailedTaxInvoice) ...[
              _detailedTableHeader(arabic),
              pw.Divider(height: 8),
              for (final item in sale.items) _detailedReceiptItem(item, arabic),
            ] else
              for (final item in sale.items) _receiptItem(item, arabic),
            pw.Divider(),
            _line(arabic ? 'الضريبة' : 'Tax', _money(sale.tax)),
            _line(arabic ? 'الخصم' : 'Discount', _money(sale.discount)),
            _line(
              arabic ? 'الإجمالي' : 'TOTAL',
              _money(sale.total),
              bold: true,
            ),
            if (sale.syncStatus == SyncStatus.pending) ...[
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: provisionalReceiptQrData(sale, businessName),
                  width: 92,
                  height: 92,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'PROVISIONAL — NOT A FINAL ZATCA INVOICE',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'The official invoice number and ZATCA status are issued after synchronization.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
            pw.SizedBox(height: 14),
            if (!arabic) pw.Text('Thank you', textAlign: pw.TextAlign.center),
            if (arabic)
              PdfFonts.text('شكراً لكم', textAlign: pw.TextAlign.center),
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
              child: PdfFonts.bilingual(
                label,
                style: bold
                    ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                    : null,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              value,
              style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
            ),
          ],
        ),
      );

  static pw.Widget _receiptItem(CartLine item, bool arabic) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.Expanded(child: PdfFonts.text(item.product.displayName(arabic))),
        pw.SizedBox(width: 8),
        pw.Text('${item.quantity} x ${_money(item.unitPrice)}'),
      ],
    ),
  );

  static pw.Widget _detailedTableHeader(bool arabic) => pw.Container(
    color: PdfColors.grey200,
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    child: pw.Row(
      children: [
        pw.Expanded(
          flex: 4,
          child: PdfFonts.text(
            arabic ? 'المنتج' : 'Product',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: PdfFonts.text(
            arabic ? 'الكمية' : 'Qty',
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: PdfFonts.text(
            arabic ? 'السعر' : 'Unit price',
            textAlign: pw.TextAlign.right,
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: PdfFonts.text(
            arabic ? 'الإجمالي' : 'Line total',
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    ),
  );

  static pw.Widget _detailedReceiptItem(
    CartLine item,
    bool arabic,
  ) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(width: .35)),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          flex: 4,
          child: PdfFonts.text(item.product.displayName(arabic)),
        ),
        pw.Expanded(
          child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(_money(item.unitPrice), textAlign: pw.TextAlign.right),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(_money(item.total), textAlign: pw.TextAlign.right),
        ),
      ],
    ),
  );

  static String _money(int minorUnits) =>
      'SAR ${(minorUnits / 100).toStringAsFixed(2)}';

  static String _paymentLabel(String method, bool arabic) {
    if (!arabic) return method.toUpperCase();
    return switch (method.toLowerCase()) {
      'cash' => 'نقدي',
      'card' => 'بطاقة',
      'credit' => 'آجل',
      'bank' || 'bank transfer' => 'تحويل بنكي',
      _ => method,
    };
  }

  static pw.Widget _documentFact(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      children: [
        PdfFonts.bilingual(label),
        pw.SizedBox(width: 5),
        pw.Expanded(
          child: PdfFonts.bilingual(
            value,
            textAlign: pw.TextAlign.right,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
          ),
        ),
      ],
    ),
  );

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
    if (_usesExternalWindowsPreview && settings.previewBeforePrinting) {
      final bytes = await sample(settings, format);
      return openDesktopPdfPreview(
        bytes,
        fileName: 'GreenMart ${settings.profileKey} test.pdf',
      );
    }
    if (!settings.previewBeforePrinting &&
        printer != null &&
        printer.url != 'system-print-dialog') {
      try {
        final printed = await Printing.directPrintPdf(
          printer: printer,
          name: 'GreenMart ${settings.profileKey} test',
          format: format,
          onLayout: (requested) => sample(settings, requested),
        );
        if (printed) return true;
      } catch (_) {
        // Fall through to the system dialog when direct printing is unavailable.
      }
    }
    if (_usesExternalWindowsPreview) {
      final bytes = await sample(settings, format);
      return openDesktopPdfPreview(
        bytes,
        fileName: 'GreenMart ${settings.profileKey} test.pdf',
      );
    }
    return await printSample(settings);
  }

  static Future<bool> printReceipt(
    Sale sale,
    String businessName,
    PrinterSettings settings, {
    bool arabic = false,
  }) async {
    final format = formatFor(
      settings.paperSizes[sale.customer.isBusiness
              ? 'billing-business'
              : 'billing-retail'] ??
          '80mm',
    );
    return Printing.layoutPdf(
      name: 'Invoice ${sale.invoiceNo}',
      format: format,
      onLayout: (requested) =>
          receipt(sale, businessName, settings, requested, arabic: arabic),
    );
  }

  static Future<bool> printReceiptTo(
    Sale sale,
    String businessName,
    PrinterSettings settings, {
    Printer? printer,
    bool arabic = false,
  }) async {
    final profile = sale.customer.isBusiness
        ? 'billing-business'
        : 'billing-retail';
    final format = formatFor(settings.paperSizes[profile] ?? '80mm');
    if (_usesExternalWindowsPreview && settings.previewBeforePrinting) {
      final bytes = await receipt(
        sale,
        businessName,
        settings,
        format,
        arabic: arabic,
      );
      return openDesktopPdfPreview(
        bytes,
        fileName: 'Invoice ${sale.invoiceNo}.pdf',
      );
    }
    if (!settings.previewBeforePrinting &&
        printer != null &&
        printer.url != 'system-print-dialog') {
      try {
        final printed = await Printing.directPrintPdf(
          printer: printer,
          name: 'Invoice ${sale.invoiceNo}',
          format: format,
          onLayout: (format) =>
              receipt(sale, businessName, settings, format, arabic: arabic),
        );
        if (printed) return true;
      } catch (_) {
        // Fall through to the system dialog when direct printing is unavailable.
      }
    }
    if (_usesExternalWindowsPreview) {
      final bytes = await receipt(
        sale,
        businessName,
        settings,
        format,
        arabic: arabic,
      );
      return openDesktopPdfPreview(
        bytes,
        fileName: 'Invoice ${sale.invoiceNo}.pdf',
      );
    }
    return await printReceipt(sale, businessName, settings, arabic: arabic);
  }

  static bool get _usesExternalWindowsPreview =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
}
