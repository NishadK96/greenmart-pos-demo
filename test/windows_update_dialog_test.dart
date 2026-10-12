import 'package:eazy_pos/features/app_update/domain/app_update_info.dart';
import 'package:eazy_pos/features/app_update/presentation/windows_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const update = AppUpdateInfo(
    updateAvailable: true,
    version: '1.0.0.80',
    minimumVersion: '1.0.0.79',
    mandatory: true,
    filename: 'Eazy-POS-Setup-1.0.0.80.exe',
    downloadUrl: 'https://example.com/update.exe',
    sha256: 'test-sha',
    size: 1024,
    channel: 'stable',
    releaseNotes: [],
  );

  testWidgets('manual check can close a mandatory update dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showWindowsUpdateDialog(context, update, allowDismiss: true),
              child: const Text('Check for updates'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('Update Required'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Update Required'), findsNothing);
  });

  testWidgets('automatic mandatory update remains non-dismissible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showWindowsUpdateDialog(context, update),
              child: const Text('Check automatically'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check automatically'));
    await tester.pumpAndSettle();
    expect(find.text('Update Required'), findsOneWidget);
    expect(find.byTooltip('Close'), findsNothing);
    expect(find.text('Later'), findsNothing);
  });
}
