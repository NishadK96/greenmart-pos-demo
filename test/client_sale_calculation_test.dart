import 'package:eazy_pos/features/pos/domain/client_sale_calculation.dart';
import 'package:eazy_pos/shared/models/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = Product(
    id: '1',
    variationId: '1',
    name: 'Item',
    sku: 'ITEM',
    barcode: 'ITEM',
    categoryId: '1',
    purchasePrice: 0,
    sellingPrice: 1,
    stock: 10,
    minimumStock: 0,
    sellingPriceIncludesTax: true,
  );

  test('allocates a one-halala discount without losing or adding money', () {
    final result = ClientSaleCalculation.fromCart(
      lines: const [
        CartLine(product: product),
        CartLine(product: product),
        CartLine(product: product),
      ],
      orderDiscount: 2,
      finalTotal: 1,
    );

    expect(result['subtotal'], '0.03');
    expect(result['discount_total'], '0.02');
    expect(result['final_total'], '0.01');
    final lines = result['lines'] as List;
    expect(lines.map((line) => line['order_discount']).toList(), [
      '0.01',
      '0.01',
      '0.00',
    ]);
    expect(lines.map((line) => line['payable_total']).toList(), [
      '0.00',
      '0.00',
      '0.01',
    ]);
  });

  test('keeps order-level tax separate from tax-inclusive item totals', () {
    final result = ClientSaleCalculation.fromCart(
      lines: const [CartLine(product: product, quantity: 2)],
      orderDiscount: 0,
      finalTotal: 3,
    );

    expect(result['lines'], [
      {'line_total': '0.02', 'order_discount': '0.00', 'payable_total': '0.02'},
    ]);
    expect(result['order_tax_total'], '0.01');
    expect(result['final_total'], '0.03');
  });

  test('matches the backend four-line example exactly', () {
    const expensive = Product(
      id: '2',
      variationId: '2',
      name: 'Expensive item',
      sku: 'EXPENSIVE',
      barcode: 'EXPENSIVE',
      categoryId: '1',
      purchasePrice: 0,
      sellingPrice: 143750,
      stock: 10,
      minimumStock: 0,
      sellingPriceIncludesTax: true,
    );
    const small = Product(
      id: '3',
      variationId: '3',
      name: 'Small item',
      sku: 'SMALL',
      barcode: 'SMALL',
      categoryId: '1',
      purchasePrice: 0,
      sellingPrice: 1250,
      stock: 10,
      minimumStock: 0,
      sellingPriceIncludesTax: true,
    );
    final result = ClientSaleCalculation.fromCart(
      lines: const [
        CartLine(product: expensive),
        CartLine(product: expensive),
        CartLine(product: small),
        CartLine(product: expensive),
      ],
      orderDiscount: 0,
      finalTotal: 432500,
    );

    expect(result['subtotal'], '4325.00');
    expect(result['discount_total'], '0.00');
    expect(result['order_tax_total'], '0.00');
    expect(result['final_total'], '4325.00');
    expect((result['lines'] as List)[2]['line_total'], '12.50');
  });
}
