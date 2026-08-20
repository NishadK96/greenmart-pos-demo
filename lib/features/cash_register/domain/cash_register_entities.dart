double _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

DateTime? _asDate(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text) ??
      DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

class CashRegisterTransaction {
  const CashRegisterTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.transactionType,
    required this.payMethod,
  });

  factory CashRegisterTransaction.fromJson(Map<String, dynamic> json) =>
      CashRegisterTransaction(
        id: '${json['id'] ?? ''}',
        amount: _asDouble(json['amount']),
        type: '${json['type'] ?? ''}',
        transactionType: '${json['transaction_type'] ?? ''}',
        payMethod: '${json['pay_method'] ?? 'cash'}',
      );

  final String id;
  final double amount;
  final String type;
  final String transactionType;
  final String payMethod;
}

class CashRegister {
  const CashRegister({
    required this.id,
    required this.locationId,
    required this.status,
    required this.createdAt,
    required this.transactions,
    this.closedAt,
  });

  factory CashRegister.fromJson(Map<String, dynamic> json) {
    final rawTransactions =
        json['cash_register_transactions'] ?? json['transactions'];
    return CashRegister(
      id: '${json['id'] ?? ''}',
      locationId: '${json['location_id'] ?? ''}',
      status: '${json['status'] ?? 'open'}',
      createdAt: _asDate(json['created_at']) ?? DateTime.now(),
      closedAt: _asDate(json['closed_at']),
      transactions: rawTransactions is List
          ? rawTransactions
                .whereType<Map>()
                .map(
                  (item) => CashRegisterTransaction.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }

  final String id;
  final String locationId;
  final String status;
  final DateTime createdAt;
  final DateTime? closedAt;
  final List<CashRegisterTransaction> transactions;

  double get openingCash => transactions
      .where((item) => item.transactionType == 'initial')
      .fold(0, (total, item) => total + item.amount);
}

class CashRegisterSummary {
  const CashRegisterSummary({
    required this.expectedTotals,
    required this.actualTotals,
    required this.variance,
    required this.expectedTotal,
    this.actualTotal,
  });

  factory CashRegisterSummary.fromJson(Map<String, dynamic> json) =>
      CashRegisterSummary(
        expectedTotals: _amountMap(json['expected_totals']),
        actualTotals: _amountMap(json['actual_totals']),
        variance: _amountMap(json['variance']),
        expectedTotal: _asDouble(json['expected_total']),
        actualTotal: json['actual_total'] == null
            ? null
            : _asDouble(json['actual_total']),
      );

  final Map<String, double> expectedTotals;
  final Map<String, double> actualTotals;
  final Map<String, double> variance;
  final double expectedTotal;
  final double? actualTotal;

  static Map<String, double> _amountMap(dynamic value) => value is Map
      ? value.map((key, amount) => MapEntry('$key', _asDouble(amount)))
      : const {};
}
