import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/desktop_pdf_preview.dart';
import '../../../shared/models/entities.dart';
import '../domain/printer_settings.dart';
import '../../offline_pos/domain/provisional_receipt_qr.dart';
import '../../../core/utils/pdf_fonts.dart';
import '../../invoice_layouts/domain/invoice_layout_entities.dart';

class PrinterDocumentService {
  static Future<bool> previewPdfBytes(
    Uint8List bytes, {
    required String name,
    PdfPageFormat format = PdfPageFormat.a4,
  }) {
    if (_usesExternalWindowsPreview) {
      return openDesktopPdfPreview(bytes, fileName: name);
    }
    return Printing.layoutPdf(
      name: name,
      format: format,
      onLayout: (_) async => bytes,
    );
  }

  static Future<bool> printPdfBytes(
    Uint8List bytes, {
    required String name,
    Printer? printer,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    if (printer != null && printer.url != 'system-print-dialog') {
      try {
        final printed = await Printing.directPrintPdf(
          printer: printer,
          name: name,
          format: format,
          usePrinterSettings: _usesExternalWindowsPreview,
          onLayout: (_) async => bytes,
        );
        if (printed) return true;
        throw StateError(
          'The selected printer did not accept the print job. Check that it is online and selected as the default printer.',
        );
      } catch (error) {
        if (error is StateError) rethrow;
        throw StateError(
          'Unable to print to ${printer.name}. Check the printer connection and try again.',
        );
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      throw StateError(
        'No physical default printer is selected. Open Printer settings, scan for printers, and set one as default.',
      );
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
                  'EAZY POS',
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
                    pw.Text('Supplier: EAZY POS'),
                    pw.Text('VAT number: 300000000000003'),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
            pw.Text(
              'EAZY POS',
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
            'EAZY POS',
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
              data: 'EAZY POS|TEST-0001|129.15|6.15',
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
                  pw.Text('EAZY POS'),
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

  static Future<Uint8List> offlineLayoutReceipt(
    Sale sale,
    OfflineInvoiceLayoutBundle bundle, {
    bool arabic = false,
  }) async {
    final manifest = bundle.manifest;
    final page = _map(manifest['page']);
    final labels = _map(manifest['labels']);
    final business = _map(manifest['business']);
    final location = _map(manifest['location']);
    final visible = _map(manifest['visible_fields']);
    final money = _map(manifest['money']);
    final header = _map(manifest['header']);
    final footer = _map(manifest['footer']);
    final provisional = _map(manifest['provisional_document']);
    final width = _number(page['width_mm'], 80) * PdfPageFormat.mm;
    final height = _number(page['height_mm'], 297) * PdfPageFormat.mm;
    final margins = _map(page['margins_mm']);
    final format = PdfPageFormat(width, height);
    final symbol = money['currency_symbol']?.toString().trim();
    final currency = symbol?.isNotEmpty == true
        ? symbol!
        : money['currency_code']?.toString() ?? 'SAR';
    final decimals = (_number(money['decimal_places'], 2)).round();
    String amount(int value) =>
        '$currency ${(value / 100).toStringAsFixed(decimals)}';
    String label(String key, String fallback) {
      final value = labels[key]?.toString().trim() ?? '';
      return value.isEmpty ? fallback : value;
    }

    final nameAr = business['name_ar']?.toString().trim() ?? '';
    final nameEn = business['name_en']?.toString().trim() ?? '';
    final businessName = arabic && nameAr.isNotEmpty
        ? nameAr
        : nameEn.isNotEmpty
        ? nameEn
        : business['name']?.toString() ?? '';
    final address = _map(location['address']);
    final addressText = arabic
        ? address['override_ar']?.toString() ?? ''
        : address['override_en']?.toString() ?? '';
    final fallbackAddress = [
      address['landmark'],
      address['city'],
      address['state'],
      address['zip_code'],
      address['country'],
    ].where((value) => value?.toString().trim().isNotEmpty == true).join(', ');
    final logo = bundle.assets['logo'];
    final document = pw.Document();
    final theme = await PdfFonts.arabicTheme();
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: theme,
        margin: pw.EdgeInsets.fromLTRB(
          _number(margins['left'], 2) * PdfPageFormat.mm,
          _number(margins['top'], 2) * PdfPageFormat.mm,
          _number(margins['right'], 2) * PdfPageFormat.mm,
          _number(margins['bottom'], 2) * PdfPageFormat.mm,
        ),
        build: (_) => [
          if (logo != null && visible['logo'] == true)
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(logo),
                width: format.width < PdfPageFormat.a4.width ? 70 : 120,
                height: 70,
                fit: pw.BoxFit.contain,
              ),
            ),
          if (visible['business_name'] != false)
            PdfFonts.text(
              businessName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          if (visible['location_name'] == true)
            PdfFonts.text(
              location['name']?.toString() ?? '',
              textAlign: pw.TextAlign.center,
            ),
          if ((addressText.isNotEmpty || fallbackAddress.isNotEmpty))
            PdfFonts.text(
              addressText.isNotEmpty ? addressText : fallbackAddress,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 9),
            ),
          if (header['text']?.toString().trim().isNotEmpty == true)
            PdfFonts.text(
              header['text'].toString(),
              textAlign: pw.TextAlign.center,
            ),
          pw.SizedBox(height: 8),
          PdfFonts.text(
            label('invoice_heading', 'PROVISIONAL INVOICE'),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          _documentFact(label('invoice_number', 'Invoice'), sale.invoiceNo),
          _documentFact(label('date', 'Date'), sale.createdAt.toString()),
          if (visible['customer'] != false)
            _documentFact(label('customer', 'Customer'), sale.customer.name),
          if (sale.customer.taxNumber?.isNotEmpty == true)
            _documentFact(
              label('client_tax', 'Customer VAT'),
              sale.customer.taxNumber!,
            ),
          _documentFact('Payment', _paymentLabel(sale.paymentMethod, arabic)),
          pw.Divider(),
          pw.TableHelper.fromTextArray(
            headers: [
              label('product', 'Product'),
              label('quantity', 'Qty'),
              label('unit_price', 'Unit price'),
              label('line_subtotal', 'Total'),
            ],
            data: sale.items
                .map(
                  (item) => [
                    item.product.displayName(arabic),
                    item.quantity.toString(),
                    amount(item.unitPrice),
                    amount(item.total),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(width: .4),
            cellPadding: const pw.EdgeInsets.all(4),
          ),
          pw.SizedBox(height: 8),
          _line(
            label('subtotal', 'Subtotal'),
            amount(sale.total - sale.tax + sale.discount),
          ),
          if (sale.discount != 0)
            _line(label('discount', 'Discount'), amount(sale.discount)),
          if (sale.tax != 0) _line(label('tax', 'Tax'), amount(sale.tax)),
          _line(label('total', 'Total'), amount(sale.total), bold: true),
          if (_map(manifest['payments'])['visible'] == true)
            _line(label('paid', 'Paid'), amount(sale.total)),
          pw.SizedBox(height: 12),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: provisionalReceiptQrData(sale, businessName),
              width: 72,
              height: 72,
            ),
          ),
          pw.SizedBox(height: 8),
          PdfFonts.text(
            _map(provisional['watermark'])[arabic ? 'ar' : 'en']?.toString() ??
                'PROVISIONAL - PENDING SYNCHRONIZATION',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          if (footer['text']?.toString().trim().isNotEmpty == true) ...[
            pw.Divider(),
            PdfFonts.text(
              footer['text'].toString(),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ],
      ),
    );
    return document.save();
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static double _number(dynamic value, double fallback) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

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
        name: 'Eazy POS ${settings.profileKey} test',
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
      try {
        final printed = await Printing.directPrintPdf(
          printer: printer,
          name: 'Eazy POS ${settings.profileKey} test',
          format: format,
          usePrinterSettings: _usesExternalWindowsPreview,
          onLayout: (requested) => sample(settings, requested),
        );
        if (printed) return true;
        throw StateError(
          'The selected printer did not accept the print job. Check that it is online and selected as the default printer.',
        );
      } catch (error) {
        if (error is StateError) rethrow;
        throw StateError(
          'Unable to print to ${printer.name}. Check the printer connection and try again.',
        );
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      throw StateError(
        'No physical default printer is selected. Open Printer settings, scan for printers, and set one as default.',
      );
    }
    return await printSample(settings);
  }

  static Future<bool> previewSample(PrinterSettings settings) async {
    final format = formatFor(
      settings.paperSizes[settings.profileKey] ?? '80mm',
    );
    final bytes = await sample(settings, format);
    return previewPdfBytes(
      bytes,
      name: 'Eazy POS ${settings.profileKey} test.pdf',
      format: format,
    );
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
    if (printer != null && printer.url != 'system-print-dialog') {
      try {
        final printed = await Printing.directPrintPdf(
          printer: printer,
          name: 'Invoice ${sale.invoiceNo}',
          format: format,
          usePrinterSettings: _usesExternalWindowsPreview,
          onLayout: (format) =>
              receipt(sale, businessName, settings, format, arabic: arabic),
        );
        if (printed) return true;
        throw StateError(
          'The selected printer did not accept the print job. Check that it is online and selected as the default printer.',
        );
      } catch (error) {
        if (error is StateError) rethrow;
        throw StateError(
          'Unable to print to ${printer.name}. Check the printer connection and try again.',
        );
      }
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      throw StateError(
        'No physical default printer is selected. Open Printer settings, scan for printers, and set one as default.',
      );
    }
    return await printReceipt(sale, businessName, settings, arabic: arabic);
  }

  static Future<bool> previewReceipt(
    Sale sale,
    String businessName,
    PrinterSettings settings, {
    bool arabic = false,
  }) async {
    final profile = sale.customer.isBusiness
        ? 'billing-business'
        : 'billing-retail';
    final format = formatFor(settings.paperSizes[profile] ?? '80mm');
    final bytes = await receipt(
      sale,
      businessName,
      settings,
      format,
      arabic: arabic,
    );
    return previewPdfBytes(
      bytes,
      name: 'Invoice ${sale.invoiceNo}.pdf',
      format: format,
    );
  }

  static bool get _usesExternalWindowsPreview =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
}
