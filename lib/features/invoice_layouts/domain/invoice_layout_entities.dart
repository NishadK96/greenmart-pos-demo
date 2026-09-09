import 'dart:typed_data';

class ErpInvoiceLayout {
  const ErpInvoiceLayout({
    required this.id,
    required this.name,
    required this.design,
    required this.designName,
    required this.isSelected,
    required this.previewUrl,
    this.offlineSupported = false,
    this.offlineConfigUrl = '',
    this.rendererProfile = '',
  });

  final String id;
  final String name;
  final String design;
  final String designName;
  final bool isSelected;
  final String previewUrl;
  final bool offlineSupported;
  final String offlineConfigUrl;
  final String rendererProfile;
}

class OfflineInvoiceLayoutBundle {
  const OfflineInvoiceLayoutBundle({
    required this.manifest,
    this.assets = const {},
  });

  final Map<String, dynamic> manifest;
  final Map<String, Uint8List> assets;

  String get revision =>
      (manifest['layout'] as Map?)?['revision']?.toString() ?? '';
  String get locationId =>
      (manifest['layout'] as Map?)?['location_id']?.toString() ?? '';
  String get documentType =>
      (manifest['layout'] as Map?)?['document_type']?.toString() ?? 'pos';
}

class ErpInvoiceLayoutCatalog {
  const ErpInvoiceLayoutCatalog({
    required this.locationId,
    required this.documentType,
    required this.currentLayoutId,
    required this.layouts,
  });

  final String locationId;
  final String documentType;
  final String? currentLayoutId;
  final List<ErpInvoiceLayout> layouts;

  ErpInvoiceLayout? get selectedLayout {
    for (final layout in layouts) {
      if (layout.id == currentLayoutId || layout.isSelected) return layout;
    }
    return null;
  }
}

class ErpInvoicePdf {
  const ErpInvoicePdf({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}
