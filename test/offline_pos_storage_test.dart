import 'package:flutter_test/flutter_test.dart';
import 'package:retailflow_pos/features/offline_pos/data/offline_pos_storage.dart';
import 'package:retailflow_pos/features/offline_pos/domain/offline_pos_entities.dart';
import 'package:retailflow_pos/shared/models/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('offline catalog and pending sale survive a cold restart', () async {
    final storage = OfflinePosStorage();
    final expires = DateTime.now().add(const Duration(days: 2));
    final state = OfflinePosState(
      context: OfflinePosContext(
        id: 'context-1',
        locationId: '1',
        cashRegisterId: '12',
        authorizedUntil: expires,
        businessId: '7',
        userId: '3',
      ),
      catalog: OfflineCatalog(
        products: const [
          Product(
            id: '88',
            name: 'Coffee',
            sku: 'SKU-88',
            barcode: 'SKU-88',
            categoryId: '',
            purchasePrice: 0,
            sellingPrice: 1150,
            stock: 9,
            minimumStock: 0,
            variationId: '91',
            taxPercent: 15,
            taxId: '4',
          ),
        ],
        customers: const [Customer(id: '25', name: 'Walk-in Customer')],
        locations: const [BusinessLocation(id: '1', name: 'Main')],
        paymentOptions: const [PaymentOption(code: 'cash', label: 'Cash')],
        taxes: const [LookupOption(id: '4', name: 'VAT', value: 15)],
        changesCursor: 1402,
        cachedAt: DateTime(2026, 8, 27),
      ),
      queue: [
        OfflineSaleRecord(
          localSaleId: 'sale-1',
          clientTransactionId: '4d2f6b17-4e4b-4f2d-9a1d-0aa1d7a5a001',
          provisionalInvoiceRef: 'OFF-000001',
          createdAt: DateTime(2026, 8, 27),
          payload: const {'document_type': 'sale'},
        ),
      ],
    );

    await storage.save(state);
    expect(await storage.canResumeOffline(), isTrue);
    final restored = await OfflinePosStorage().load();

    expect(restored.context?.id, 'context-1');
    expect(restored.context?.active, isTrue);
    expect(restored.catalog.products.single.name, 'Coffee');
    expect(restored.catalog.products.single.sellingPrice, 1150);
    expect(restored.catalog.customers.single.id, '25');
    expect(restored.catalog.changesCursor, 1402);
    expect(restored.queue.single.provisionalInvoiceRef, 'OFF-000001');
    expect(restored.pendingCount, 1);

    await storage.disableOfflineResume();
    expect(await storage.canResumeOffline(), isFalse);
    expect((await storage.load()).queue, hasLength(1));
  });
}
