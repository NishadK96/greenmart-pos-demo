import 'package:intl/intl.dart';

String _currencySymbol = '';

void configureCurrency(String symbol) => _currencySymbol = symbol;

String money(int minorUnits) => NumberFormat.currency(
  symbol: _currencySymbol,
  decimalDigits: 2,
).format(minorUnits / 100);
int toPaise(num value) => (value * 100).round();
