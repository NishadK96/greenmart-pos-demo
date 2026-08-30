import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailflow_pos/apis/api.dart';
import 'package:retailflow_pos/core/network/api_provider.dart';
import 'package:retailflow_pos/features/auth/auth_controller.dart';
import 'package:retailflow_pos/features/offline_pos/presentation/offline_pos_controller.dart';
import 'package:retailflow_pos/features/store/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<String?> build() async => 'test-access-token';
}

class _OfflineApi extends Api {
  _OfflineApi();

  int syncCalls = 0;

  @override
  Future<Map<String, dynamic>> offlineBootstrap({
    required String accessToken,
    required String locationId,
    required String cashRegisterId,
    String? contextId,
    int productCursor = 0,
    int customerCursor = 0,
  }) async => {
    'context': {
      'id': 'context-1',
      'location_id': 1,
      'cash_register_id': 12,
      'business_id': 7,
      'user_id': 3,
      'authorized_until': DateTime.now()
          .add(const Duration(days: 2))
          .toIso8601String(),
    },
    'bootstrap': {
      'products': {
        'items': [
          {
            'id': 88,
            'name': 'Coffee',
            'sku': 'SKU-88',
            'unit_id': 1,
            'tax_id': 4,
            'variations': [
              {
                'id': 91,
                'sub_sku': 'SKU-88',
                'sell_price_inc_tax': 11.50,
                'stock': 9,
              },
            ],
          },
        ],
        'next_cursor': 88,
        'has_more': false,
      },
      'customers': {
        'items': [
          {'id': 25, 'name': 'Walk-in Customer'},
        ],
        'next_cursor': 25,
        'has_more': false,
      },
      'locations': [
        {'id': 1, 'name': 'Main'},
      ],
      'payment_methods': {'cash': 'Cash'},
      'taxes': [
        {'id': 4, 'name': 'VAT', 'amount': 15},
      ],
      'changes_cursor': 1402,
    },
  };

  @override
  Future<Map<String, dynamic>> syncOfflineSales({
    required String accessToken,
    required String contextId,
    required List<Map<String, dynamic>> batch,
  }) async {
    syncCalls++;
    return {
      'data': [
        {
          'client_transaction_id': batch.single['client_transaction_id'],
          'status': 'synchronized',
          'server_transaction_id': 501,
          'official_invoice_no': 'INV-00501',
          'zatca_status': 'ACCEPTED',
        },
      ],
    };
  }
}

ProviderContainer _container(_OfflineApi api) => ProviderContainer(
  overrides: [
    apiProvider.overrideWithValue(api),
    authControllerProvider.overrideWith(_FakeAuthController.new),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('prepare, offline checkout, cold restart, and reconnect sync', () async {
    final api = _OfflineApi();
    final firstRun = _container(api);
    addTearDown(firstRun.dispose);

    await firstRun.read(offlinePosControllerProvider.future);
    await firstRun
        .read(offlinePosControllerProvider.notifier)
        .prepare(locationId: '1', cashRegisterId: '12');

    final prepared = firstRun.read(offlinePosControllerProvider).requireValue;
    expect(prepared.ready, isTrue);
    expect(prepared.catalog.products.single.name, 'Coffee');
    expect(prepared.catalog.changesCursor, 1402);

    final store = firstRun.read(appStoreProvider.notifier);
    store.addToCart(firstRun.read(appStoreProvider).products.single);
    final provisional = await firstRun
        .read(offlinePosControllerProvider.notifier)
        .queueCurrentSale();

    expect(provisional.invoiceNo, startsWith('OFF-'));
    expect(provisional.syncStatus.name, 'pending');
    expect(
      firstRun.read(offlinePosControllerProvider).requireValue.pendingCount,
      1,
    );

    firstRun.dispose();

    final restarted = _container(api);
    addTearDown(restarted.dispose);
    final restored = await restarted.read(offlinePosControllerProvider.future);
    expect(restored.ready, isTrue);
    expect(restored.catalog.products.single.id, '88');
    expect(restored.pendingCount, 1);

    await restarted.read(offlinePosControllerProvider.notifier).syncNow();
    final synchronized = restarted
        .read(offlinePosControllerProvider)
        .requireValue;
    expect(api.syncCalls, 1);
    expect(synchronized.pendingCount, 0);
    expect(synchronized.queue.single.status, 'synchronized');
  });
}
