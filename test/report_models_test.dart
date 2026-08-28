import 'package:flutter_test/flutter_test.dart';
import 'package:retailflow_pos/features/reports/domain/report_models.dart';

void main() {
  test('sales report maps pagination, summary and trends', () {
    final result = ReportResult.fromJson(ReportKind.sales, {
      'current_page': 2,
      'last_page': 4,
      'total': 72,
      'data': [
        {'id': 1, 'invoice_no': 'INV-1', 'final_total': 115},
      ],
      'summary': {'row_count': 72, 'final_total': 9200},
      'trends': [
        {'period': '2026-08', 'final_total': 9200},
      ],
    });

    expect(result.page, 2);
    expect(result.lastPage, 4);
    expect(result.total, 72);
    expect(result.rows.single['invoice_no'], 'INV-1');
    expect(result.summary['final_total'], 9200);
    expect(result.insights.single['period'], '2026-08');
  });

  test('inventory valuation maps data as summary without pagination', () {
    final result = ReportResult.fromJson(ReportKind.inventoryValuation, {
      'data': {
        'as_of': '2026-08-25',
        'cost_value': 1000,
        'selling_value': 1400,
        'potential_profit': 400,
        'profit_margin': 28.57,
      },
    });

    expect(result.rows, isEmpty);
    expect(result.summary['selling_value'], 1400);
    expect(result.lastPage, 1);
  });

  test('report request sends supported common filters', () {
    final request = ReportRequest(
      kind: ReportKind.returns,
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 25),
      locationId: '3',
      page: 2,
      perPage: 50,
    );

    expect(request.parameters, {
      'start_date': '2026-08-01',
      'end_date': '2026-08-25',
      'location_id': '3',
      'page': '2',
      'per_page': '50',
    });
  });
}
