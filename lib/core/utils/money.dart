import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
String money(int paise) => _currency.format(paise / 100);
int toPaise(num value) => (value * 100).round();
