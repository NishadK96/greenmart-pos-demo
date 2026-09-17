import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/invoice_layout_entities.dart';

class OfflineInvoiceLayoutRepository {
  static const _legacyPrefix = 'offline_invoice_layout_v1_';
  static const _bundlePrefix = 'offline_invoice_layout_v2_bundle_';
  static const _selectionPrefix = 'offline_invoice_layout_v2_selection_';
  static const _catalogPrefix = 'offline_invoice_layout_v2_catalog_';

  String _scope(String locationId, String documentType) =>
      '${locationId}_$documentType';

  String _legacyKey(String locationId, String documentType) =>
      '$_legacyPrefix${_scope(locationId, documentType)}';

  String _bundleKey(String locationId, String documentType, String layoutId) =>
      '$_bundlePrefix${_scope(locationId, documentType)}_$layoutId';

  String _selectionKey(String locationId, String documentType) =>
      '$_selectionPrefix${_scope(locationId, documentType)}';

  String _catalogKey(String locationId, String documentType) =>
      '$_catalogPrefix${_scope(locationId, documentType)}';

  Future<void> save(
    OfflineInvoiceLayoutBundle bundle, {
    String? layoutId,
    bool selected = true,
  }) async {
    final resolvedLayoutId =
        layoutId ??
        (bundle.manifest['layout'] as Map?)?['id']?.toString() ??
        '';
    if (resolvedLayoutId.isEmpty) return;
    final payload = {
      'manifest': bundle.manifest,
      'assets': bundle.assets.map(
        (key, value) => MapEntry(key, base64Encode(value)),
      ),
    };
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _bundleKey(bundle.locationId, bundle.documentType, resolvedLayoutId),
      jsonEncode(payload),
    );
    if (selected) {
      await preferences.setString(
        _selectionKey(bundle.locationId, bundle.documentType),
        resolvedLayoutId,
      );
    }
  }

  Future<OfflineInvoiceLayoutBundle?> load(
    String locationId,
    String documentType,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final selectedLayoutId = preferences.getString(
      _selectionKey(locationId, documentType),
    );
    if (selectedLayoutId != null && selectedLayoutId.isNotEmpty) {
      return _decode(
        preferences.getString(
          _bundleKey(locationId, documentType, selectedLayoutId),
        ),
      );
    }
    return _decode(preferences.getString(_legacyKey(locationId, documentType)));
  }

  Future<OfflineInvoiceLayoutBundle?> loadLayout(
    String locationId,
    String documentType,
    String layoutId,
  ) async => _decode(
    (await SharedPreferences.getInstance()).getString(
      _bundleKey(locationId, documentType, layoutId),
    ),
  );

  Future<void> saveCatalog(ErpInvoiceLayoutCatalog catalog) async {
    final payload = {
      'location_id': catalog.locationId,
      'document_type': catalog.documentType,
      'current_layout_id': catalog.currentLayoutId,
      'layouts': catalog.layouts
          .map(
            (layout) => {
              'id': layout.id,
              'name': layout.name,
              'design': layout.design,
              'design_name': layout.designName,
              'is_selected': layout.isSelected,
              'preview_url': layout.previewUrl,
              'offline_supported': layout.offlineSupported,
              'offline_config_url': layout.offlineConfigUrl,
              'renderer_profile': layout.rendererProfile,
            },
          )
          .toList(growable: false),
    };
    await (await SharedPreferences.getInstance()).setString(
      _catalogKey(catalog.locationId, catalog.documentType),
      jsonEncode(payload),
    );
  }

  Future<ErpInvoiceLayoutCatalog?> loadCatalog(
    String locationId,
    String documentType,
  ) async {
    final text = (await SharedPreferences.getInstance()).getString(
      _catalogKey(locationId, documentType),
    );
    if (text == null) return null;
    try {
      final payload = Map<String, dynamic>.from(jsonDecode(text) as Map);
      final layouts = (payload['layouts'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final layout = Map<String, dynamic>.from(raw);
            return ErpInvoiceLayout(
              id: layout['id']?.toString() ?? '',
              name: layout['name']?.toString() ?? 'Invoice layout',
              design: layout['design']?.toString() ?? '',
              designName: layout['design_name']?.toString() ?? '',
              isSelected: layout['is_selected'] == true,
              previewUrl: layout['preview_url']?.toString() ?? '',
              offlineSupported: layout['offline_supported'] == true,
              offlineConfigUrl: layout['offline_config_url']?.toString() ?? '',
              rendererProfile: layout['renderer_profile']?.toString() ?? '',
            );
          })
          .where((layout) => layout.id.isNotEmpty)
          .toList(growable: false);
      return ErpInvoiceLayoutCatalog(
        locationId: payload['location_id']?.toString() ?? locationId,
        documentType: payload['document_type']?.toString() ?? documentType,
        currentLayoutId: payload['current_layout_id']?.toString(),
        layouts: layouts,
      );
    } catch (_) {
      return null;
    }
  }

  OfflineInvoiceLayoutBundle? _decode(String? text) {
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
