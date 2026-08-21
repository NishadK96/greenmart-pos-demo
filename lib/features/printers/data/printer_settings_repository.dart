import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/printer_settings.dart';

class PrinterSettingsRepository {
  static const _key = 'greenmart_printer_settings_v1';

  Future<PrinterSettings> load() async {
    final value = (await SharedPreferences.getInstance()).getString(_key);
    if (value == null) return const PrinterSettings();
    try {
      return PrinterSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      return const PrinterSettings();
    }
  }

  Future<void> save(PrinterSettings settings) async =>
      (await SharedPreferences.getInstance()).setString(
        _key,
        jsonEncode(settings.toJson()),
      );

  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}
