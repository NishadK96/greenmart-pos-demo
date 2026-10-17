import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eazy_pos/features/van/presentation/van_pos_preview_screen.dart';

void main() {
  testWidgets('Van POS preview fits a phone width and updates order totals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: VanPosPreviewScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('New van sale'), findsOneWidget);
    expect(find.text('SAR 19.00'), findsWidgets);

    await tester.ensureVisible(find.byTooltip('Add Potato Chips'));
    await tester.tap(find.byTooltip('Add Potato Chips'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SAR 22.00'), findsWidgets);
    expect(find.textContaining('No sale or stock movement'), findsOneWidget);
  });
}
