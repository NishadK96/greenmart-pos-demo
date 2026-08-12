import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/money.dart';
import '../domain/purchase_entities.dart';
import 'purchase_pdf_download.dart';

Future<Uint8List> buildPurchaseOrderPdf(PurchaseDocument document) async {
  final pdf = pw.Document(title: document.reference);
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
          child: pw.Row(
            children: [
              _pdfFact('Supplier', document.supplierName),
              _pdfFact('Location', document.locationName),
              _pdfFact(
                'Date',
                document.date.toIso8601String().split('T').first,
              ),
              _pdfFact('Status', document.status),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Text(
          'Products',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Product', 'SKU', 'Quantity', 'Unit Price', 'Total'],
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
        ),
        pw.SizedBox(height: 20),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 250,
            child: pw.Column(
              children: [
                _pdfTotal('Subtotal', subtotal.round()),
                _pdfTotal('Shipping', shipping.round()),
                _pdfTotal('Other charges', expenses.round()),
                pw.Divider(),
                _pdfTotal('Total', document.total, strong: true),
              ],
            ),
          ),
        ),
        if (document.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 24),
          pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(document.notes),
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
      pw.Text(
        label,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        value.isEmpty ? '-' : value,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
    ],
  ),
);

pw.Widget _pdfTotal(String label, int value, {bool strong = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
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

Future<void> printPurchaseOrder(PurchaseDocument document) async {
  final bytes = await buildPurchaseOrderPdf(document);
  await Printing.layoutPdf(
    name: '${document.reference}.pdf',
    onLayout: (_) async => bytes,
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
