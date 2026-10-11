import 'package:eazy_pos/features/fuel/domain/fuel_calculation.dart';
import 'package:eazy_pos/shared/models/entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = Product(
    id: '1',
    variationId: '2',
    name: 'Petrol 91',
    sku: 'P91',
    barcode: 'P91',
    categoryId: 'fuel',
    purchasePrice: 0,
    sellingPrice: 179,
    stock: 100,
    minimumStock: 0,
    sellingPriceIncludesTax: true,
  );

  test('amount entry converts to four-decimal litre quantity', () {
    final units = FuelLine.litresFromAmount(5000, 179)!;
    final line = FuelLine(product: product, quantityUnits: units);
    expect(line.quantityForApi, '27.9330');
    expect(line.totalCents, 5000);
    expect(line.unitPriceForApi, '1.79');
  });

  test('litre entry is limited to four decimal places', () {
    expect(FuelLine.parseLitres('12.3456'), 123456);
    expect(FuelLine.parseLitres('12.34567'), isNull);
    expect(FuelLine.parseLitres('-1'), isNull);
  });

  test('money entry is limited to two decimal places', () {
    expect(FuelLine.parseMoney('10.01'), 1001);
    expect(FuelLine.parseMoney('10.001'), isNull);
  });

  test('fuel metadata is serialized into a stable backend sale note', () {
    const metadata = FuelSaleMetadata(
      vehicleNumber: 'abc 1234',
      odometer: '80421',
      pumpNumber: '6',
      nozzleNumber: '2',
    );

    expect(
      metadata.saleNote,
      'Fuel sale | Vehicle: ABC 1234 | Odometer: 80421 km | Pump: 6 | Nozzle: 2',
    );
  });

  test('empty optional metadata still identifies the transaction as fuel', () {
    expect(const FuelSaleMetadata().saleNote, 'Fuel sale');
  });
}
