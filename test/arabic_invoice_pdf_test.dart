import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:eazy_pos/core/utils/pdf_fonts.dart';
import 'package:eazy_pos/features/printers/application/printer_document_service.dart';
import 'package:eazy_pos/features/printers/domain/printer_settings.dart';
import 'package:eazy_pos/features/purchases/domain/purchase_entities.dart';
import 'package:eazy_pos/features/purchases/presentation/purchase_document_export.dart';
import 'package:eazy_pos/shared/models/entities.dart';
import 'package:eazy_pos/features/invoice_layouts/domain/invoice_layout_entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'offline labels preserve ERP Arabic and supplement bilingual defaults',
    () {
      String label(
        String key,
        String value,
        String fallback, {
        bool bilingual = true,
      }) => PrinterDocumentService.offlineInvoiceLabel(
        key,
        value,
        fallback,
        arabic: true,
        bilingual: bilingual,
      );
      expect(label('payment', '', 'Payment'), 'Payment / الدفع');
      expect(label('tax', '', 'Tax', bilingual: false), 'الضريبة');
      expect(label('product', 'الصنف', 'Product'), 'الصنف');
      expect(label('quantity', 'Hours', 'Qty'), 'Hours / الكمية');
      expect(
        PrinterDocumentService.offlineInvoiceLabel(
          'tax',
          '',
          'Tax',
          arabic: false,
          bilingual: false,
        ),
        'Tax',
      );
    },
  );

  test('Arabic purchase order and sales receipt PDFs render', () async {
    final purchase = PurchaseDocument(
      id: 'purchase-ar-1',
      type: PurchaseDocumentType.order,
      reference: 'PO-AR-0001',
      supplierId: '1',
      supplierName: 'مؤسسة النور للتجارة',
      locationId: '1',
      locationName: 'الفرع الرئيسي - الرياض',
      date: DateTime(2026, 8, 29),
      status: 'مستلم',
      total: 11500,
      notes: 'يرجى التسليم صباحاً',
      lines: const [
        PurchaseLineRecord(
          productId: '1',
          variationId: '1',
          name: 'قهوة عربية فاخرة',
          sku: 'AR-COFFEE',
          quantity: 2,
          unitCost: 5000,
        ),
      ],
    );
    final now = DateTime(2026, 8, 29, 14, 30);
    const product = Product(
      id: '1',
      name: 'قهوة عربية فاخرة',
      sku: 'AR-COFFEE',
      barcode: 'AR-COFFEE',
      categoryId: '1',
      purchasePrice: 4000,
      sellingPrice: 5750,
      stock: 10,
      minimumStock: 1,
      variationId: '1',
      taxPercent: 15,
    );
    final sale = Sale(
      localId: 'sale-ar-1',
      invoiceNo: 'INV-AR-0001',
      createdAt: now,
      updatedAt: now,
      customer: const Customer(id: '1', name: 'أحمد محمد'),
      items: const [CartLine(product: product, quantity: 2)],
      paymentMethod: 'cash',
      total: 11500,
      tax: 1500,
      discount: 0,
      syncStatus: SyncStatus.synced,
    );

    final purchaseBytes = await buildPurchaseOrderPdf(purchase);
    final receiptBytes = await PrinterDocumentService.receipt(
      sale,
      'متجر جرين مارت',
      const PrinterSettings(),
      PrinterDocumentService.formatFor('80mm'),
      arabic: true,
    );
    final bilingualSampleBytes = await PrinterDocumentService.sample(
      const PrinterSettings(
        templates: {'billing-retail': PrinterTemplate.bilingualReceipt},
      ),
      PrinterDocumentService.formatFor('80mm'),
    );
    final offlineBytes = await PrinterDocumentService.offlineLayoutReceipt(
      sale,
      const OfflineInvoiceLayoutBundle(
        manifest: {
          'locale': {
            'bilingual': true,
            'primary_locale': 'ar-SA',
            'direction': 'rtl',
          },
          'page': {'width_mm': 58, 'height_mm': 297},
          'business': {'name_ar': 'متجر إيزي', 'name_en': 'Eazy Store'},
          'labels': {'invoice_heading': 'Invoice', 'quantity': 'Hours'},
          'money': {'currency_code': 'SAR'},
        },
      ),
      // A bilingual ERP layout must remain bilingual in an English UI.
      arabic: false,
    );
    expect(offlineBytes.length, greaterThan(10000));

    expect(purchaseBytes.length, greaterThan(10000));
    expect(receiptBytes.length, greaterThan(10000));
    expect(bilingualSampleBytes.length, greaterThan(10000));
    expect(PdfFonts.containsArabic('فاتورة ضريبية'), isTrue);

    final outputDirectory = Platform.environment['PDF_QA_OUTPUT_DIR'];
    if (outputDirectory != null && outputDirectory.isNotEmpty) {
      final directory = Directory(outputDirectory)..createSync(recursive: true);
      File(
        '${directory.path}/arabic-purchase-order-sample.pdf',
      ).writeAsBytesSync(purchaseBytes);
      File(
        '${directory.path}/arabic-sales-receipt-sample.pdf',
      ).writeAsBytesSync(receiptBytes);
      File(
        '${directory.path}/bilingual-printer-sample.pdf',
      ).writeAsBytesSync(bilingualSampleBytes);
      File(
        '${directory.path}/offline-bilingual-receipt.pdf',
      ).writeAsBytesSync(offlineBytes);
    }
  });
}
