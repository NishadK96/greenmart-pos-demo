import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:retailflow_pos/features/printers/application/printer_controller.dart';
import 'package:retailflow_pos/features/printers/data/printer_settings_repository.dart';
import 'package:retailflow_pos/features/printers/domain/printer_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('selecting a printer saves it as the device-wide default', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(printerControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    const printer = Printer(
      url: 'printer://receipt-1',
      name: 'Receipt printer',
    );
    await controller.selectPrinter(printer);

    expect(
      container.read(printerControllerProvider).settings.defaultPrinterUrl,
      printer.url,
    );
    expect(
      (await PrinterSettingsRepository().load()).defaultPrinterUrl,
      printer.url,
    );
  });

  test('existing profile selection migrates to the global default', () {
    final settings = PrinterSettings.fromJson({
      'selectedPrinters': {'billing-retail': 'printer://legacy'},
    });

    expect(settings.defaultPrinterUrl, 'printer://legacy');
  });
}
