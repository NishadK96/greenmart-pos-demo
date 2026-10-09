import '../../../shared/models/entities.dart';

/// The Retail POS totals sent with a sell request. All arithmetic stays in
/// integer halalas; only the final JSON values are formatted as SAR strings.
class ClientSaleCalculation {
  const ClientSaleCalculation._();

  static Map<String, dynamic> fromCart({
    required List<CartLine> lines,
    required int orderDiscount,
    required int finalTotal,
  }) {
    final lineTotals = [for (final line in lines) line.total];
    final subtotal = lineTotals.fold<int>(0, (sum, value) => sum + value);
    final discount = orderDiscount.clamp(0, subtotal);
    final allocations = List<int>.filled(lineTotals.length, 0);
    if (subtotal > 0 && discount > 0) {
      final remainders = <({int index, int remainder})>[];
      var allocated = 0;
      for (var index = 0; index < lineTotals.length; index++) {
        final numerator = discount * lineTotals[index];
        allocations[index] = numerator ~/ subtotal;
        allocated += allocations[index];
        remainders.add((index: index, remainder: numerator % subtotal));
      }
      remainders.sort((a, b) {
        final compared = b.remainder.compareTo(a.remainder);
        return compared != 0 ? compared : a.index.compareTo(b.index);
      });
      for (var index = 0; index < discount - allocated; index++) {
        allocations[remainders[index].index]++;
      }
    }
    final payable = subtotal - discount;
    // This is the order-level tax already included in AppState.cartTotal.
    // Item VAT is included in each line total and must not be added again.
    final orderTax = finalTotal - payable;
    if (orderTax < 0) {
      throw StateError('Retail sale totals do not reconcile.');
    }
    return {
      'lines': [
        for (var index = 0; index < lineTotals.length; index++)
          {
            'line_total': _money(lineTotals[index]),
            'order_discount': _money(allocations[index]),
            'payable_total': _money(lineTotals[index] - allocations[index]),
          },
      ],
      'subtotal': _money(subtotal),
      'discount_total': _money(discount),
      'order_tax_total': _money(orderTax),
      'final_total': _money(finalTotal),
    };
  }

  static String _money(int halalas) => (halalas / 100).toStringAsFixed(2);
}
