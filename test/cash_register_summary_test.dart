import 'package:eazy_pos/features/cash_register/domain/cash_register_entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cash register summary maps reconciliation response', () {
    final summary = CashRegisterSummary.fromJson(const {
      'register_id': 27,
      'status': 'close',
      'expected_totals': {'cash': 125.0, 'card': 80.0, 'custom_pay_1': 0.0},
      'actual_totals': {'cash': 120.0, 'card': 80.0},
      'variance': {'cash': -5.0, 'card': 0.0, 'custom_pay_1': null},
      'expected_total': 205.0,
      'actual_total': 200.0,
    });

    expect(summary.registerId, '27');
    expect(summary.status, 'close');
    expect(summary.expectedTotals['cash'], 125);
    expect(summary.actualTotals['cash'], 120);
    expect(summary.variance['cash'], -5);
    expect(summary.variance['custom_pay_1'], 0);
    expect(summary.expectedTotal, 205);
    expect(summary.actualTotal, 200);
  });
}
