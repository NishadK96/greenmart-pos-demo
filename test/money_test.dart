import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailflow_pos/core/utils/money.dart';

void main() {
  test('text-only money output uses SAR instead of a legacy glyph', () {
    expect(money(123450), contains('SAR'));
    expect(money(123450), contains('1,234.50'));
  });

  testWidgets('RiyalAmount renders the official SVG before the amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RiyalAmount(123450))),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.textContaining('1,234.50', findRichText: true), findsOneWidget);

    final richText = tester.widget<RichText>(find.byType(RichText).last);
    expect(richText.textDirection, TextDirection.ltr);
  });
}
