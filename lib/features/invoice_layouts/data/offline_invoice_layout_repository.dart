import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/invoice_layout_entities.dart';

class OfflineInvoiceLayoutRepository {
  static const _prefix = 'offline_invoice_layout_v1_';

  String _key(String locationId, String documentType) =>
      '$_prefix${locationId}_$documentType';

  Future<void> save(OfflineInvoiceLayoutBundle bundle) async {
    final payload = {
      'manifest': bundle.manifest,
      'assets': bundle.assets.map(
        (key, value) => MapEntry(key, base64Encode(value)),
      ),
    };
    await (await SharedPreferences.getInstance()).setString(
      _key(bundle.locationId, bundle.documentType),
      jsonEncode(payload),
    );
  }

  Future<OfflineInvoiceLayoutBundle?> load(
    String locationId,
    String documentType,
  ) async {
    final text = (await SharedPreferences.getInstance()).getString(
      _key(locationId, documentType),
    );
    if (text == null) return null;
    try {
      final payload = Map<String, dynamic>.from(jsonDecode(text) as Map);
      final assets = Map<String, dynamic>.from(
        payload['assets'] as Map? ?? const {},
      ).map((key, value) => MapEntry(key, base64Decode(value.toString())));
      return OfflineInvoiceLayoutBundle(
        manifest: Map<String, dynamic>.from(payload['manifest'] as Map),
        assets: assets,
      );
    } catch (_) {
      return null;
    }
  }
}
