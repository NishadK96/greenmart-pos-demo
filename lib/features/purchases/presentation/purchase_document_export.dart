import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/money.dart';
import '../../../core/utils/pdf_fonts.dart';
import '../domain/purchase_entities.dart';
import '../../printers/application/printer_document_service.dart';
import '../../printers/application/printer_controller.dart';
import 'purchase_pdf_download.dart';

Future<Uint8List> buildPurchaseOrderPdf(PurchaseDocument document) async {
  final pdf = pw.Document(title: document.reference);
  final theme = await PdfFonts.arabicTheme();
  final subtotal = document.lines.fold<double>(
    0,
    (sum, line) => sum + line.lineTotal,
  );
  final expenses = document.expenses.fold<double>(
    0,
    (sum, item) => sum + item.amount * 100,
  );
  final shipping = document.shippingCharges * 100;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'GreenMart',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Purchase Order',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
              PdfFonts.text(
                'أمر شراء',
                style: const pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          pw.Text(
            document.reference,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
      build: (_) => [
        pw.SizedBox(height: 24),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfFact('Supplier / المورد', document.supplierName),
                  pw.SizedBox(width: 20),
                  _pdfFact('Location / الموقع', document.locationName),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfFact(
                    'Date / التاريخ',
                    document.date.toIso8601String().split('T').first,
                  ),
                  pw.SizedBox(width: 20),
                  _pdfFact('Status / الحالة', document.status),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        PdfFonts.bilingual(
          'Products / المنتجات',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: [
            _pdfTableHeader('Product / المنتج'),
            _pdfTableHeader('SKU'),
            _pdfTableHeader('Quantity / الكمية'),
            _pdfTableHeader('Unit Price / سعر الوحدة'),
            _pdfTableHeader('Total / الإجمالي'),
          ],
          data: document.lines
              .map(
                (line) => [
                  line.name,
                  line.sku,
                  line.quantity.toStringAsFixed(
                    line.quantity == line.quantity.roundToDouble() ? 0 : 2,
                  ),
                  money(line.unitCost.round()),
                  money(line.lineTotal.round()),
                ],
              )
              .toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.green50),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellPadding: const pw.EdgeInsets.all(8),
          cellBuilder: (_, value, __) => PdfFonts.text(value.toString()),
        ),
        pw.SizedBox(height: 20),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 250,
            child: pw.Column(
              children: [
                _pdfTotal('Subtotal / المجموع الفرعي', subtotal.round()),
                _pdfTotal('Shipping / الشحن', shipping.round()),
                _pdfTotal('Other charges / رسوم أخرى', expenses.round()),
                pw.Divider(),
                _pdfTotal('Total / الإجمالي', document.total, strong: true),
              ],
            ),
          ),
        ),
        if (document.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 24),
          PdfFonts.bilingual(
            'Notes / ملاحظات',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          PdfFonts.text(document.notes),
        ],
      ],
    ),
  );
  return pdf.save();
}

pw.Widget _pdfFact(String label, String value) => pw.Expanded(
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      PdfFonts.bilingual(
        label,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 3),
      PdfFonts.text(
        value.isEmpty ? '-' : value,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
    ],
  ),
);

pw.Widget _pdfTableHeader(String label) => PdfFonts.bilingual(
  label,
  textAlign: pw.TextAlign.center,
  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
);

pw.Widget _pdfTotal(String label, int value, {bool strong = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          PdfFonts.bilingual(
            label,
            style: pw.TextStyle(
              fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            money(value),
            style: pw.TextStyle(
              fontSize: strong ? 16 : 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );

Future<void> printPurchaseOrder(
  PurchaseDocument document,
  PrinterState printerState,
) async {
  final bytes = await buildPurchaseOrderPdf(document);
  await PrinterDocumentService.printPdfBytes(
    bytes,
    name: '${document.reference}.pdf',
    printer: printerState.selectedPrinter,
    format: PdfPageFormat.a4,
  );
}

Future<bool> savePurchaseOrderPdf(PurchaseDocument document) async {
  final bytes = await buildPurchaseOrderPdf(document);
  final safeName = document.reference.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '-',
  );
  return downloadPurchasePdf(bytes, 'purchase-order-$safeName.pdf');
}
