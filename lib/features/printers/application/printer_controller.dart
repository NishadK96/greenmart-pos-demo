import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
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
    return null;
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
    try {
      final info = await Printing.info();
      final printers = info.canListPrinters
          ? await Printing.listPrinters()
          : const <Printer>[];
      state = state.copyWith(
        scanning: false,
        printers: printers.where((printer) => printer.isAvailable).toList(),
        message: printers.isEmpty
            ? 'Printer discovery is not supported on this device. Test print will open the system dialog.'
            : null,
      );
    } catch (_) {
      state = state.copyWith(
        scanning: false,
        printers: const [],
        message:
            'Could not discover printers. Test print will use the system print dialog.',
      );
    }
  }

  Future<void> selectPrinter(Printer printer) async {
    await update(
      state.settings.copyWith(
        defaultPrinterUrl: printer.url,
      ),
    );
  }

  Future<void> clearDefaults() async {
    await update(
      state.settings.copyWith(
        clearDefaultPrinter: true,
      ),
    );
  }

  Future<void> reset() async {
    await _repository.clear();
    state = const PrinterState(settings: PrinterSettings(), loading: false);
    await scan();
  }
}
