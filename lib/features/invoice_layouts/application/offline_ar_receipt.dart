import 'dart:convert';

import 'package:barcode/barcode.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/pdf_fonts.dart';
import '../../../shared/models/entities.dart';
import '../../offline_pos/domain/provisional_receipt_qr.dart';
import '../domain/invoice_layout_entities.dart';

/// The supplied 80 mm Arabic receipt is the source for HTML-capable printers.
/// The matching PDF layout keeps the same receipt printable on Windows/web.
abstract final class OfflineArabicReceipt {
  static const assetPath = 'assets/receipts/ar-receipt.html';
  static final pageFormat = PdfPageFormat(
    80 * PdfPageFormat.mm,
    260 * PdfPageFormat.mm,
  );

  static Future<Uint8List> pdf({
    required Sale sale,
    required String businessName,
    required String vatNumber,
    required String cashierName,
    OfflineInvoiceLayoutBundle? layout,
  }) async {
    final html = await renderHtml(
      sale: sale,
      businessName: businessName,
      vatNumber: vatNumber,
      cashierName: cashierName,
      layout: layout,
    );
    try {
      final info = await Printing.info();
      if (info.canConvertHtml) {
        // ignore: deprecated_member_use
        return await Printing.convertHtml(html: html, format: pageFormat);
      }
    } catch (_) {
      // Windows and web do not provide HTML-to-PDF in the printing plugin.
    }
    return _portablePdf(
      sale: sale,
      businessName: businessName,
      vatNumber: vatNumber,
      cashierName: cashierName,
      layout: layout,
    );
  }

  static Future<String> renderHtml({
    required Sale sale,
    required String businessName,
    required String vatNumber,
    required String cashierName,
    OfflineInvoiceLayoutBundle? layout,
  }) async {
    var html = await rootBundle.loadString(assetPath);
    final identity = _map(layout?.manifest['invoice_identity']);
    final location = _map(layout?.manifest['location']);
    final address = _map(location['address']);
    final crn = '${identity['crn'] ?? ''}'.trim();
    final phone = '${identity['phone'] ?? ''}'.trim();
    final locationAddress =
        [
              identity['address_ar'],
              address['override_ar'],
              identity['address_en'],
              address['override_en'],
            ]
            .map((value) => '${value ?? ''}'.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final date = sale.createdAt.toLocal();
    final replacements = <String, String>{
      '[Business Name]': _escape(businessName),
      '[VAT Number]': _escape(vatNumber),
      '[Commercial Registration Number]': _escape(crn),
      '[Phone Number]': _escape(phone),
      '[Business Address]': _escape(locationAddress),
      '[Invoice Number]': _escape(sale.invoiceNo),
      '[YYYY/MM/DD]': '${date.year}/${_two(date.month)}/${_two(date.day)}',
      '[HH:MM:SS]':
          '${_two(date.hour)}:${_two(date.minute)}:${_two(date.second)}',
      '[Cashier Name]': _escape(cashierName),
      '[Customer Name or Cash Customer]': _escape(sale.customer.name),
      '[Mobile Number]': _escape(sale.customer.phone),
      '[Customer VAT Number]': _escape(sale.customer.taxNumber ?? ''),
      '[Total Quantity]':
          '${sale.items.fold<int>(0, (sum, item) => sum + item.quantity)}',
      '[Item Count]': '${sale.items.length}',
      '[Subtotal Before Tax]': _amount(sale.total - sale.tax + sale.discount),
      '[Discount]': _amount(sale.discount),
      '[Total VAT]': _amount(sale.tax),
      '[Total Due]': _amount(sale.total),
    };
    for (final entry in replacements.entries) {
      html = html.replaceAll(entry.key, entry.value);
    }
    final rows = sale.items.map((item) {
      final modifiers = item.modifiers.isEmpty
          ? ''
          : '<div class="ar-item-modifiers">${_escape(item.modifiers.map((modifier) => modifier.name).join(' · '))}</div>';
      return '<tr>'
          '<td class="ar-col-item"><div class="ar-strong">${_escape(item.product.name)}</div>$modifiers</td>'
          '<td class="ar-col-qty ar-num">${item.quantity}</td>'
          '<td class="ar-col-piece ar-num">${_amount(item.unitPriceExcludingTax)}</td>'
          '<td class="ar-col-total ar-num ar-strong">${_amount(item.total)}</td>'
          '<td class="ar-col-vat ar-num">${_amount(item.tax)}</td>'
          '</tr>';
    }).join();
    html = html.replaceFirst(
      RegExp(r'(<tbody>).*?(</tbody>)', dotAll: true),
      '<tbody>$rows</tbody>',
    );
    html = html.replaceFirst(
      RegExp(
        r'<div class="ar-kv">\s*<span class="k">رقم الفاتورة الأصلية.*?</div>',
        dotAll: true,
      ),
      '',
    );
    html = _removeEmptyFact(html, '[Optional]');
    if (crn.isEmpty) {
      html = html.replaceFirst(
        RegExp(
          r'<div class="ar-center ar-muted ar-xs">\s*السجل التجاري.*?</div>',
          dotAll: true,
        ),
        '',
      );
    }
    if (phone.isEmpty) {
      html = html.replaceFirst(
        RegExp(
          r'<div class="ar-center ar-muted ar-xs">\s*الهاتف.*?</div>',
          dotAll: true,
        ),
        '',
      );
    }
    if (vatNumber.isEmpty) {
      html = html.replaceFirst(
        RegExp(
          r'<div class="ar-center ar-muted">\s*الرقم الضريبي.*?</div>',
          dotAll: true,
        ),
        '',
      );
    }
    if (locationAddress.isEmpty) {
      html = html.replaceFirst(
        '<div class="ar-center ar-muted ar-xs"></div>',
        '',
      );
    }
    if (sale.customer.phone.isEmpty) html = _removeFact(html, 'الجوال');
    if (sale.customer.taxNumber?.trim().isNotEmpty != true) {
      html = _removeFact(html, 'رقم ضريبة العميل');
    }
    html = html.replaceAll('فاتورة ضريبية مبسطة', 'فاتورة مؤقتة');
    html = html.replaceAll('SIMPLIFIED TAX INVOICE', 'PROVISIONAL RECEIPT');
    final qrSvg = Barcode.qrCode().toSvg(
      provisionalReceiptQrData(sale, businessName),
      width: 160,
      height: 160,
      drawText: false,
    );
    final qrUri =
        'data:image/svg+xml;base64,${base64Encode(utf8.encode(qrSvg))}';
    html = html.replaceFirst(
      '<!-- Optional QR code: <section class="ar-section avoid-page-break ar-center"><img class="ar-qr" src="qr-code.png" alt="QR Code"></section> -->',
      '<section class="ar-section avoid-page-break ar-center">'
          '<img class="ar-qr" src="$qrUri" alt="Offline provisional QR">'
          '<div class="ar-xs ar-strong">فاتورة مؤقتة - بانتظار المزامنة</div>'
          '<div class="ar-xs">PROVISIONAL - PENDING SYNCHRONIZATION</div>'
          '</section>',
    );
    final logo = layout?.assets['logo'];
    if (logo != null && logo.isNotEmpty) {
      html = html.replaceFirst(
        '<!-- Optional logo: <div class="ar-center ar-logo"><img src="logo.png" alt="Logo"></div> -->',
        '<div class="ar-center ar-logo"><img src="data:image/png;base64,${base64Encode(logo)}" alt="Logo"></div>',
      );
    }
    return html;
  }

  static Future<Uint8List> _portablePdf({
    required Sale sale,
    required String businessName,
    required String vatNumber,
    required String cashierName,
    OfflineInvoiceLayoutBundle? layout,
  }) async {
    final identity = _map(layout?.manifest['invoice_identity']);
    final location = _map(layout?.manifest['location']);
    final address = _map(location['address']);
    final locationAddress =
        [
              identity['address_ar'],
              address['override_ar'],
              identity['address_en'],
              address['override_en'],
            ]
            .map((value) => '${value ?? ''}'.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final date = sale.createdAt.toLocal();
    final doc = pw.Document();
    final theme = await PdfFonts.arabicTheme();
    pw.Widget text(
      String value, {
      double size = 8,
      bool bold = false,
      pw.TextAlign? align,
    }) => PdfFonts.text(
      value,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
    pw.Widget bilingualLabel(
      String ar,
      String en, {
      pw.TextAlign? align,
      bool compact = false,
    }) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        text(
          ar,
          size: compact ? 5.5 : 8,
          bold: true,
          align: align ?? pw.TextAlign.right,
        ),
        text(
          en,
          size: compact ? 5 : 6,
          bold: true,
          align: align ?? pw.TextAlign.right,
        ),
      ],
    );
    pw.Widget fact(String ar, String en, String value, {bool large = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: text(
                  value,
                  size: large ? 15 : 8,
                  bold: true,
                  align: pw.TextAlign.left,
                ),
              ),
              bilingualLabel(ar, en),
            ],
          ),
        );
    pw.Widget section() => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 5, bottom: 4),
      child: pw.Divider(thickness: .5, color: PdfColors.grey600),
    );
    final logo = layout?.assets['logo'];
    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.symmetric(
          horizontal: 3 * PdfPageFormat.mm,
          vertical: 2 * PdfPageFormat.mm,
        ),
        theme: theme,
        build: (_) => [
          if (logo != null && logo.isNotEmpty)
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(logo),
                width: 60,
                height: 45,
                fit: pw.BoxFit.contain,
              ),
            ),
          pw.Center(
            child: text(
              businessName,
              size: 12,
              bold: true,
              align: pw.TextAlign.center,
            ),
          ),
          pw.Center(
            child: text(
              'فاتورة مؤقتة',
              size: 15,
              bold: true,
              align: pw.TextAlign.center,
            ),
          ),
          pw.Center(
            child: text(
              'PROVISIONAL RECEIPT',
              size: 8,
              bold: true,
              align: pw.TextAlign.center,
            ),
          ),
          if (vatNumber.isNotEmpty)
            pw.Center(
              child: pw.Column(
                children: [
                  text('الرقم الضريبي', align: pw.TextAlign.center),
                  text('VAT', size: 6, align: pw.TextAlign.center),
                  text(vatNumber, bold: true, align: pw.TextAlign.center),
                ],
              ),
            ),
          if ('${identity['crn'] ?? ''}'.trim().isNotEmpty)
            pw.Center(
              child: pw.Column(
                children: [
                  text('السجل التجاري', align: pw.TextAlign.center),
                  text('CRN', size: 6, align: pw.TextAlign.center),
                  text(
                    '${identity['crn']}',
                    bold: true,
                    align: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          if ('${identity['phone'] ?? ''}'.trim().isNotEmpty)
            pw.Center(
              child: pw.Column(
                children: [
                  text('الهاتف', align: pw.TextAlign.center),
                  text('Tel', size: 6, align: pw.TextAlign.center),
                  text(
                    '${identity['phone']}',
                    bold: true,
                    align: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          if (locationAddress.isNotEmpty)
            pw.Center(child: text(locationAddress, align: pw.TextAlign.center)),
          section(),
          fact('رقم الفاتورة', 'Inv#', sale.invoiceNo, large: true),
          fact(
            'تاريخ الفاتورة',
            'Date',
            '${date.year}/${_two(date.month)}/${_two(date.day)}',
          ),
          fact(
            'وقت البيع',
            'Time',
            '${_two(date.hour)}:${_two(date.minute)}:${_two(date.second)}',
          ),
          if (cashierName.isNotEmpty) fact('الكاشير', 'Cashier', cashierName),
          section(),
          fact('العميل', 'Cust', sale.customer.name),
          if (sale.customer.phone.isNotEmpty)
            fact('الجوال', 'Mob', sale.customer.phone),
          if (sale.customer.taxNumber?.trim().isNotEmpty == true)
            fact('رقم ضريبة العميل', 'VAT', sale.customer.taxNumber!),
          section(),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(1.8),
              1: pw.FlexColumnWidth(1.9),
              2: pw.FlexColumnWidth(1.9),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(3.2),
            },
            border: pw.TableBorder(
              horizontalInside: const pw.BorderSide(
                width: .3,
                color: PdfColors.grey400,
              ),
            ),
            children: [
              pw.TableRow(
                children: [
                  bilingualLabel(
                    'الضريبة',
                    'VAT',
                    align: pw.TextAlign.left,
                    compact: true,
                  ),
                  bilingualLabel(
                    'الإجمالي',
                    'Total',
                    align: pw.TextAlign.left,
                    compact: true,
                  ),
                  bilingualLabel(
                    'سعر القطعة',
                    'Piece',
                    align: pw.TextAlign.left,
                    compact: true,
                  ),
                  bilingualLabel(
                    'الكمية',
                    'Qty',
                    align: pw.TextAlign.left,
                    compact: true,
                  ),
                  bilingualLabel('المنتج', 'Item', compact: true),
                ],
              ),
              for (final item in sale.items)
                pw.TableRow(
                  children: [
                    text(_amount(item.tax), size: 7),
                    text(_amount(item.total), size: 7, bold: true),
                    text(_amount(item.unitPriceExcludingTax), size: 7),
                    text('${item.quantity}', size: 7),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        text(
                          item.product.name,
                          size: 8,
                          bold: true,
                          align: pw.TextAlign.right,
                        ),
                        if (item.modifiers.isNotEmpty)
                          text(
                            item.modifiers
                                .map((modifier) => modifier.name)
                                .join(' · '),
                            size: 6,
                            align: pw.TextAlign.right,
                          ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Center(
            child: text(
              'إجمالي الكمية: ${sale.items.fold<int>(0, (sum, item) => sum + item.quantity)}  |  عدد الأصناف: ${sale.items.length}',
              size: 7,
              align: pw.TextAlign.center,
            ),
          ),
          section(),
          fact('السعر', 'Sub', _amount(sale.total - sale.tax + sale.discount)),
          fact('الخصم', 'Disc', _amount(sale.discount)),
          fact('الضريبة', 'VAT', _amount(sale.tax)),
          section(),
          fact('الإجمالي', 'Total', _amount(sale.total), large: true),
          pw.SizedBox(height: 7),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: provisionalReceiptQrData(sale, businessName),
              width: 78,
              height: 78,
            ),
          ),
          pw.Center(
            child: text(
              'فاتورة مؤقتة - بانتظار المزامنة',
              size: 7,
              bold: true,
              align: pw.TextAlign.center,
            ),
          ),
          pw.Center(
            child: text(
              'PROVISIONAL - PENDING SYNCHRONIZATION',
              size: 6,
              bold: true,
              align: pw.TextAlign.center,
            ),
          ),
          section(),
          pw.Center(
            child: text(
              'شكراً لتعاملكم معنا',
              size: 8,
              align: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _amount(int value) => (value / 100).toStringAsFixed(2);
  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  static String _removeFact(String html, String label) => html.replaceFirst(
    RegExp(
      '<div class="ar-kv">\\s*<span class="k">$label.*?</div>',
      dotAll: true,
    ),
    '',
  );

  static String _removeEmptyFact(String html, String placeholder) =>
      html.replaceAll(placeholder, '');
}
