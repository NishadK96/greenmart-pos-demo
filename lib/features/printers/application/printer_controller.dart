import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'android_bluetooth_printer.dart';
import '../data/printer_settings_repository.dart';
import '../domain/printer_settings.dart';

class PrinterState {
  const PrinterState({
    this.settings = const PrinterSettings(),
    this.printers = const [],
    this.loading = true,
    this.scanning = false,
    this.message,
  });
  final PrinterSettings settings;
  final List<Printer> printers;
  final bool loading, scanning;
  final String? message;

  Printer? get selectedPrinter {
    final url = settings.defaultPrinterUrl;
    if (url == null) return null;
    for (final printer in printers) {
      if (printer.url == url) return printer;
    }
    // Printer discovery can be delayed or temporarily unavailable on Windows.
    // The platform printer URL is the stable identifier directPrintPdf needs,
    // so keep the user's persisted selection usable between scans/restarts.
    return Printer(url: url, name: settings.defaultPrinterName);
  }

  List<Printer> get selectedPrinters {
    final destinations = <String, Printer>{};
    final primary = selectedPrinter;
    if (primary != null) destinations[primary.url] = primary;
    for (final entry in settings.additionalPrinters.entries) {
      if (entry.key == primary?.url) continue;
      destinations[entry.key] = _printerFor(entry.key, entry.value);
    }
    return destinations.values.toList(growable: false);
  }

  Printer _printerFor(String url, String name) {
    for (final printer in printers) {
      if (printer.url == url) return printer;
    }
    return Printer(url: url, name: name);
  }

  Printer? kitchenPrinter(String erpPrinterId) {
    final url = settings.kitchenPrinterBindings[erpPrinterId];
    if (url == null || url.isEmpty || url == 'system-print-dialog') return null;
    return _printerFor(
      url,
      settings.kitchenPrinterBindingNames[erpPrinterId] ?? url,
    );
  }

  PrinterState copyWith({
    PrinterSettings? settings,
    List<Printer>? printers,
    bool? loading,
    bool? scanning,
    String? message,
    bool clearMessage = false,
  }) => PrinterState(
    settings: settings ?? this.settings,
    printers: printers ?? this.printers,
    loading: loading ?? this.loading,
    scanning: scanning ?? this.scanning,
    message: clearMessage ? null : message ?? this.message,
  );
}

final printerSettingsRepositoryProvider = Provider(
  (_) => PrinterSettingsRepository(),
);

final printerControllerProvider =
    NotifierProvider<PrinterController, PrinterState>(PrinterController.new);

class PrinterController extends Notifier<PrinterState> {
  late final PrinterSettingsRepository _repository;

  @override
  PrinterState build() {
    _repository = ref.read(printerSettingsRepositoryProvider);
    Future<void>.microtask(load);
    return const PrinterState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearMessage: true);
    final settings = await _repository.load();
    state = state.copyWith(settings: settings, loading: false);
    await scan();
  }

  Future<void> update(PrinterSettings settings) async {
    state = state.copyWith(settings: settings, clearMessage: true);
    await _repository.save(settings);
  }

  Future<void> scan() async {
    state = state.copyWith(scanning: true, clearMessage: true);
    if (kIsWeb) {
      state = state.copyWith(
        scanning: false,
        printers: const [
          Printer(
            url: 'system-print-dialog',
            name: 'Browser / system print dialog',
            model: 'Choose an installed printer when the dialog opens',
            isDefault: true,
          ),
        ],
        message:
            'Browsers do not allow websites to enumerate or silently select installed printers.',
      );
      return;
    }
    final printers = <Printer>[];
    String? message;
    try {
      final info = await Printing.info();
      if (info.canListPrinters) {
        printers.addAll(
          (await Printing.listPrinters()).where((p) => p.isAvailable),
        );
      }
    } catch (_) {
      message = 'Could not discover system printers.';
    }
    if (AndroidBluetoothPrinter.supported) {
      try {
        printers.insertAll(0, await AndroidBluetoothPrinter.pairedPrinters());
      } catch (error) {
        message =
            'Bluetooth printers unavailable: $error. Pair the printer in Android Settings, allow Nearby devices, then scan again.';
      }
      printers.add(
        const Printer(
          url: 'system-print-dialog',
          name: 'Android print service',
          model: 'Choose a printer in the Android print dialog',
        ),
      );
      message ??= printers.length == 1
          ? 'No paired Bluetooth printer found. Pair your printer in Android Settings, then scan again.'
          : null;
    } else if (printers.isEmpty) {
      message ??= state.settings.defaultPrinterUrl == null
          ? 'No available printer was found. Connect a printer, scan again, and set it as default.'
          : 'Printer discovery returned no devices. The saved default printer will still be used for direct printing.';
    }
    state = state.copyWith(
      scanning: false,
      printers: printers,
      message: message,
    );
  }

  Future<void> selectPrinter(Printer printer) async {
    final additional = Map<String, String>.from(
      state.settings.additionalPrinters,
    );
    final previousUrl = state.settings.defaultPrinterUrl;
    final previousName = state.settings.defaultPrinterName;
    final wasAdditional = additional.remove(printer.url) != null;
    if (previousUrl != null && previousUrl != printer.url && wasAdditional) {
      additional[previousUrl] = previousName ?? previousUrl;
    }
    await update(
      state.settings.copyWith(
        defaultPrinterUrl: printer.url,
        defaultPrinterName: printer.name,
        additionalPrinters: additional,
      ),
    );
  }

  Future<void> toggleAdditionalPrinter(Printer printer) async {
    if (state.settings.defaultPrinterUrl == null) {
      await selectPrinter(printer);
      return;
    }
    final additional = Map<String, String>.from(
      state.settings.additionalPrinters,
    );
    if (printer.url == state.settings.defaultPrinterUrl) {
      if (additional.isEmpty) {
        await update(
          state.settings.copyWith(
            clearDefaultPrinter: true,
            additionalPrinters: const {},
          ),
        );
        return;
      }
      final replacement = additional.entries.first;
      additional.remove(replacement.key);
      await update(
        state.settings.copyWith(
          defaultPrinterUrl: replacement.key,
          defaultPrinterName: replacement.value,
          additionalPrinters: additional,
        ),
      );
      return;
    }
    if (additional.containsKey(printer.url)) {
      additional.remove(printer.url);
    } else {
      additional[printer.url] = printer.name;
    }
    await update(state.settings.copyWith(additionalPrinters: additional));
  }

  Future<void> bindKitchenPrinter(String erpPrinterId, Printer? printer) async {
    final bindings = Map<String, String>.from(
      state.settings.kitchenPrinterBindings,
    );
    final names = Map<String, String>.from(
      state.settings.kitchenPrinterBindingNames,
    );
    if (printer == null || printer.url == 'system-print-dialog') {
      bindings.remove(erpPrinterId);
      names.remove(erpPrinterId);
    } else {
      bindings[erpPrinterId] = printer.url;
      names[erpPrinterId] = printer.name;
    }
    await update(
      state.settings.copyWith(
        kitchenPrinterBindings: bindings,
        kitchenPrinterBindingNames: names,
      ),
    );
  }

  Future<void> clearDefaults() async {
    await update(
      state.settings.copyWith(
        clearDefaultPrinter: true,
        additionalPrinters: const {},
      ),
    );
  }

  Future<void> reset() async {
    await _repository.clear();
    state = const PrinterState(settings: PrinterSettings(), loading: false);
    await scan();
  }
}
