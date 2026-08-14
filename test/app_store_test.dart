import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailflow_pos/features/store/app_store.dart';
import 'package:retailflow_pos/shared/models/entities.dart';

void main() {
  test('line discounts update totals and never exceed the subtotal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(appStoreProvider.notifier);
    const product = Product(
      id: '1',
      variationId: '11',
      name: 'Test product',
      sku: 'TEST-1',
      barcode: 'TEST-1',
      categoryId: '1',
      purchasePrice: 800,
      sellingPrice: 1000,
      stock: 5,
      minimumStock: 1,
    );

    store.addToCart(product);
    store.quantity(product.id, 1);
    store.discount(product.id, 250);

    expect(container.read(appStoreProvider).cartSubtotal, 2000);
    expect(container.read(appStoreProvider).cartDiscount, 250);
    expect(container.read(appStoreProvider).cartTax, 88);
    expect(container.read(appStoreProvider).cartTotal, 1838);

    store.discount(product.id, 999999);
    expect(container.read(appStoreProvider).cartDiscount, 2000);
    expect(container.read(appStoreProvider).cartTotal, 0);
  });

  test('held sales can be resumed without losing cart lines', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(appStoreProvider.notifier);
    const product = Product(
      id: 'held-1',
      variationId: 'held-v1',
      name: 'Held product',
      sku: 'HELD-1',
      barcode: 'HELD-1',
      categoryId: '1',
      purchasePrice: 500,
      sellingPrice: 750,
      stock: 5,
      minimumStock: 1,
    );

    store.addToCart(product);
    store.quantity(product.id, 1);
    store.holdCart();

    expect(container.read(appStoreProvider).cart, isEmpty);
    expect(container.read(appStoreProvider).heldCarts, hasLength(1));

    store.resumeLastHeldCart();

    expect(container.read(appStoreProvider).itemCount, 2);
    expect(container.read(appStoreProvider).heldCarts, isEmpty);
  });
}
