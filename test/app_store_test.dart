import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailflow_pos/features/store/app_store.dart';
import 'package:retailflow_pos/shared/models/entities.dart';

void main() {
  test('checkout payment options exclude custom payment slots', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(appStoreProvider.notifier)
        .restoreOfflineCatalog(
          products: const [],
          categories: const [],
          customers: const [],
          locations: const [],
          paymentOptions: const [
            PaymentOption(code: 'cash', label: 'Cash'),
            PaymentOption(code: 'card', label: 'Card'),
            PaymentOption(code: 'custom_pay_1', label: 'Custom Payment 1'),
            PaymentOption(code: 'custom_pay_2', label: 'Voucher'),
          ],
          taxes: const [],
        );

    expect(
      container
          .read(appStoreProvider)
          .checkoutPaymentOptions
          .map((option) => option.code),
      ['cash', 'card'],
    );
    expect(
      container
          .read(appStoreProvider)
          .posPaymentOptions
          .map((option) => option.code),
      ['cash', 'card', 'credit'],
    );
  });

  test('walk-in customer detection does not block named customers', () {
    expect(const Customer(id: '1', name: 'Walk-In Customer').isWalkIn, isTrue);
    expect(const Customer(id: '2', name: 'Walk in').isWalkIn, isTrue);
    expect(const Customer(id: '3', name: 'Riyadh Retail').isWalkIn, isFalse);
  });

  test('overselling follows the business setting', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(appStoreProvider.notifier);
    const product = Product(
      id: 'sold-out',
      variationId: 'sold-out-v1',
      name: 'Sold out product',
      sku: 'SOLD-OUT',
      barcode: 'SOLD-OUT',
      categoryId: '1',
      purchasePrice: 500,
      sellingPrice: 1000,
      stock: 0,
      minimumStock: 1,
    );

    store.addToCart(product);
    expect(container.read(appStoreProvider).cart, isEmpty);

    store.restoreOfflineCatalog(
      products: const [product],
      categories: const [],
      customers: const [],
      locations: const [],
      paymentOptions: const [],
      taxes: const [],
      allowOverselling: true,
    );
    store.addToCart(product);
    store.quantity(product.id, 2);

    expect(container.read(appStoreProvider).cart.single.quantity, 3);
  });

  test('cart total matches the two checkout prices shown in the POS', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(appStoreProvider.notifier);

    const flour = Product(
      id: 'flour',
      variationId: 'flour-v1',
      name: 'Whole Wheat Flour',
      sku: 'SKU-1001',
      barcode: 'SKU-1001',
      categoryId: '1',
      purchasePrice: 4000,
      sellingPrice: 5125,
      stock: 11,
      minimumStock: 1,
      taxPercent: 0,
    );
    const sugar = Product(
      id: 'sugar',
      variationId: 'sugar-v1',
      name: 'Organic Sugar',
      sku: 'SKU-1003',
      barcode: 'SKU-1003',
      categoryId: '1',
      purchasePrice: 4500,
      sellingPrice: 5575,
      stock: 26,
      minimumStock: 1,
      taxPercent: 0,
    );

    store.addToCart(flour);
    store.addToCart(sugar);

    final state = container.read(appStoreProvider);
    expect(state.cartSubtotal, 10700);
    expect(state.cartLineDiscount, 0);
    expect(state.cartGrossDiscount, 0);
    expect(state.cartTax, 0);
    expect(state.cartTotal, 10700);
  });

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

    expect(container.read(appStoreProvider).cartSubtotal, 2000);
    expect(container.read(appStoreProvider).cartGrossDiscount, 0);
    expect(container.read(appStoreProvider).cartTotal, 2100);

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

  test('edited unit price and gross discount update and survive held sale', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(appStoreProvider.notifier);
    const product = Product(
      id: 'priced-1',
      variationId: 'priced-v1',
      name: 'Priced product',
      sku: 'PRICE-1',
      barcode: 'PRICE-1',
      categoryId: '1',
      purchasePrice: 700,
      sellingPrice: 1000,
      stock: 5,
      minimumStock: 1,
    );

    store.addToCart(product);
    store.quantity(product.id, 1);
    store.unitPrice(product.id, 1200);
    store.discount(product.id, 200);
    store.setGrossDiscount(300);

    var state = container.read(appStoreProvider);
    expect(state.cart.single.unitPrice, 1200);
    expect(state.cartSubtotal, 2400);
    expect(state.cartLineDiscount, 200);
    expect(state.cartTax, 110);
    expect(state.cartGrossDiscount, 300);
    expect(state.cartTotal, 2010);

    store.holdCart();
    store.resumeLastHeldCart();
    state = container.read(appStoreProvider);

    expect(state.cart.single.unitPrice, 1200);
    expect(state.cartGrossDiscount, 300);
    expect(state.cartTotal, 2010);
  });

  test('percentage gross discount updates totals and survives held sale', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(appStoreProvider.notifier);
    const product = Product(
      id: 'percentage-1',
      variationId: 'percentage-v1',
      name: 'Percentage product',
      sku: 'PERCENT-1',
      barcode: 'PERCENT-1',
      categoryId: '1',
      purchasePrice: 500,
      sellingPrice: 1000,
      stock: 5,
      minimumStock: 1,
      taxPercent: 0,
    );

    store.addToCart(product);
    store.quantity(product.id, 1);
    store.setGrossDiscountPercentage(10);

    var state = container.read(appStoreProvider);
    expect(state.grossDiscountType, 'percentage');
    expect(state.grossDiscountRate, 10);
    expect(state.cartGrossDiscount, 200);
    expect(state.cartTotal, 1800);

    store.holdCart();
    store.resumeLastHeldCart();
    state = container.read(appStoreProvider);

    expect(state.grossDiscountType, 'percentage');
    expect(state.grossDiscountRate, 10);
    expect(state.cartGrossDiscount, 200);
    expect(state.cartTotal, 1800);
  });
}
