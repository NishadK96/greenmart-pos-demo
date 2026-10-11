import '../../../shared/models/entities.dart';

class FuelSaleMetadata {
  const FuelSaleMetadata({
    this.vehicleNumber = '',
    this.odometer = '',
    this.pumpNumber = '',
    this.nozzleNumber = '',
  });

  final String vehicleNumber, odometer, pumpNumber, nozzleNumber;

  String get saleNote => [
    'Fuel sale',
    if (vehicleNumber.trim().isNotEmpty)
      'Vehicle: ${vehicleNumber.trim().toUpperCase()}',
    if (odometer.trim().isNotEmpty) 'Odometer: ${odometer.trim()} km',
    if (pumpNumber.trim().isNotEmpty) 'Pump: ${pumpNumber.trim()}',
    if (nozzleNumber.trim().isNotEmpty) 'Nozzle: ${nozzleNumber.trim()}',
  ].join(' | ');
}

/// Fuel quantities are stored as ten-thousandths of a litre. Money stays in
/// cents so the display and connector payload use the same rounded values.
class FuelLine {
  const FuelLine({required this.product, required this.quantityUnits});

  final Product product;
  final int quantityUnits;

  int get priceCentsIncludingTax => product.sellingPriceIncludesTax
      ? product.sellingPrice
      : (product.sellingPrice * (1 + product.taxPercent / 100)).round();

  int get totalCents =>
      (quantityUnits * priceCentsIncludingTax / 10000).round();

  int get taxCents => product.taxPercent <= 0
      ? 0
      : (totalCents - totalCents / (1 + product.taxPercent / 100)).round();

  String get quantityForApi => (quantityUnits / 10000).toStringAsFixed(4);
  String get unitPriceForApi =>
      (priceCentsIncludingTax / 100).toStringAsFixed(2);

  static int? parseLitres(String text) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,4}))?$').firstMatch(text.trim());
    if (match == null) return null;
    final whole = int.tryParse(match.group(1)!);
    if (whole == null) return null;
    final fraction = (match.group(2) ?? '').padRight(4, '0');
    return whole * 10000 + (int.tryParse(fraction) ?? 0);
  }

  static int? parseMoney(String text) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text.trim());
    if (match == null) return null;
    final whole = int.tryParse(match.group(1)!);
    if (whole == null) return null;
    return whole * 100 + int.parse((match.group(2) ?? '').padRight(2, '0'));
  }

  static int? litresFromAmount(int amountCents, int priceCents) {
    if (amountCents <= 0 || priceCents <= 0) return null;
    return (amountCents * 10000 / priceCents).round();
  }
}
