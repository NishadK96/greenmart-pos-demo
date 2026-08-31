import 'dart:typed_data';

class ErpInvoiceLayout {
  const ErpInvoiceLayout({
    required this.id,
    required this.name,
    required this.design,
    required this.designName,
    required this.isSelected,
    required this.previewUrl,
  });

  final String id;
  final String name;
  final String design;
  final String designName;
  final bool isSelected;
  final String previewUrl;
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
