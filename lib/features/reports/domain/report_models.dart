enum ReportKind {
  sales('sales', 'Sales', 'Sales totals, trends and invoice performance'),
  productSales(
    'product-sales',
    'Product sales',
    'Product, category and variation performance',
  ),
  purchases('purchases', 'Purchases', 'Purchase totals, dues and suppliers'),
  taxes('taxes', 'Taxes', 'Input and output tax summary'),
  payments('payments', 'Payments', 'Payment methods and due collections'),
  registers('registers', 'Registers', 'Register session performance'),
  inventoryValuation(
    'inventory-valuation',
    'Inventory value',
    'Current cost and selling valuation',
  ),
  stockMovements(
    'stock-movements',
    'Stock movements',
    'Inventory movements and adjustments',
  ),
  returns('returns', 'Returns', 'Sales and purchase returns');

  const ReportKind(this.path, this.label, this.description);
  final String path, label, description;
}

class ReportRequest {
  const ReportRequest({
    required this.kind,
    required this.startDate,
    required this.endDate,
    this.locationId = '',
    this.page = 1,
    this.perPage = 20,
  });

  final ReportKind kind;
  final DateTime startDate, endDate;
  final String locationId;
  final int page, perPage;

  Map<String, String> get parameters => {
    if (kind != ReportKind.inventoryValuation) 'start_date': _date(startDate),
    'end_date': _date(endDate),
    if (locationId.isNotEmpty) 'location_id': locationId,
    if (kind != ReportKind.inventoryValuation) ...{
      'page': '$page',
      'per_page': '$perPage',
    },
  };

  ReportRequest copyWith({
    ReportKind? kind,
    DateTime? startDate,
    DateTime? endDate,
    String? locationId,
    int? page,
    int? perPage,
  }) => ReportRequest(
    kind: kind ?? this.kind,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    locationId: locationId ?? this.locationId,
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
  );

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ReportRequest &&
      other.kind == kind &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.locationId == locationId &&
      other.page == page &&
      other.perPage == perPage;

  @override
  int get hashCode =>
      Object.hash(kind, startDate, endDate, locationId, page, perPage);
}

class ReportResult {
  const ReportResult({
    required this.rows,
    required this.summary,
    required this.insights,
    required this.page,
    required this.lastPage,
    required this.total,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> insights;
  final int page, lastPage, total;

  factory ReportResult.fromJson(ReportKind kind, Map<String, dynamic> json) {
    final rawData = json['data'];
    if (kind == ReportKind.inventoryValuation) {
      final values = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      return ReportResult(
        rows: const [],
        summary: values,
        insights: const [],
        page: 1,
        lastPage: 1,
        total: 0,
      );
    }
    final insightKey = switch (kind) {
      ReportKind.sales || ReportKind.purchases => 'trends',
      ReportKind.productSales => 'performance',
      ReportKind.payments => 'method_breakdown',
      ReportKind.taxes => '',
      _ => '',
    };
    final rawInsights = insightKey.isEmpty ? null : json[insightKey];
    return ReportResult(
      rows: rawData is List
          ? rawData
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
          : const [],
      summary: json['summary'] is Map
          ? Map<String, dynamic>.from(json['summary'] as Map)
          : const {},
      insights: rawInsights is List
          ? rawInsights
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
          : const [],
      page: _integer(json['current_page'], 1),
      lastPage: _integer(json['last_page'], 1),
      total: _integer(json['total'], 0),
    );
  }

  static int _integer(dynamic value, int fallback) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;
}
