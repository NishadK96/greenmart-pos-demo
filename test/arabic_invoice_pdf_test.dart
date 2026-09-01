import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retailflow_pos/core/utils/pdf_fonts.dart';
import 'package:retailflow_pos/features/printers/application/printer_document_service.dart';
import 'package:retailflow_pos/features/printers/domain/printer_settings.dart';
import 'package:retailflow_pos/features/purchases/domain/purchase_entities.dart';
import 'package:retailflow_pos/features/purchases/presentation/purchase_document_export.dart';
import 'package:retailflow_pos/shared/models/entities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    }
  });
}
