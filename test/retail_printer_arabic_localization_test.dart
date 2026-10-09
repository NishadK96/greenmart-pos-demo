import 'package:eazy_pos/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retail payment and printer labels have Arabic translations', () {
    const arabic = AppLocalizations(Locale('ar'));
    for (final label in [
      'New Sale',
      'Shift open',
      'ZATCA Phase 2',
      'Saved Orders',
      'Amount Due',
      'Bank Transfer',
      'Cheque',
      'Keyboard: use arrow keys to select a payment method, then press Enter twice to confirm.',
      'Choose the official ERP invoice layout, local fallbacks and default printer.',
      'Set default',
      'Default (slim) (ar-receipt)',
    ]) {
      expect(arabic.tr(label), isNot(label), reason: label);
    }
  });
}
