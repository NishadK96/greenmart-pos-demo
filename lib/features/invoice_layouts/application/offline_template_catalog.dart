import '../domain/invoice_layout_entities.dart';

/// Local, network-independent invoice presets. These mirror the layouts supplied
/// by the ERP so a device can still produce a usable receipt before it has
/// downloaded a server-managed layout bundle.
class OfflineTemplateCatalog {
  static const presets = <OfflineTemplatePreset>[
    OfflineTemplatePreset(
      'slim-80mm',
      'Slim 80 mm',
      'slim',
      'thermal_80mm',
      80,
    ),
    OfflineTemplatePreset(
      'ar-receipt-80mm',
      'Arabic receipt 80 mm',
      'ar_receipt',
      'thermal_80mm',
      80,
    ),
    OfflineTemplatePreset(
      'arabic-compact-80mm',
      'Arabic compact 80 mm',
      'arabic_compact',
      'thermal_80mm',
      80,
    ),
    OfflineTemplatePreset(
      'slim2-58mm',
      'Slim 58 mm',
      'slim2',
      'thermal_58mm',
      58,
    ),
    OfflineTemplatePreset(
      'ar-receipt-58mm',
      'Arabic receipt 58 mm',
      'ar_receipt_58',
      'thermal_58mm',
      58,
    ),
    OfflineTemplatePreset(
      'ar-receipt-58-original',
      'Arabic receipt 58 mm (original)',
      'ar_receipt_58_original',
      'thermal_58mm',
      58,
    ),
  ];

  static ErpInvoiceLayoutCatalog catalog(
    String locationId,
    String documentType,
  ) {
    return ErpInvoiceLayoutCatalog(
      locationId: locationId,
      documentType: documentType,
      currentLayoutId: presets.first.id,
      layouts: [
        for (final preset in presets)
          ErpInvoiceLayout(
            id: preset.id,
            name: preset.name,
            design: preset.profile,
            designName: preset.name,
            isSelected: preset == presets.first,
            previewUrl: '',
            offlineSupported: true,
            rendererProfile: preset.profile,
            paperFormat: preset.paperFormat,
            paperWidthMm: preset.widthMm,
          ),
      ],
    );
  }

  static OfflineInvoiceLayoutBundle bundle(
    String locationId,
    String documentType, {
    String presetId = 'slim-80mm',
  }) {
    final preset = presets.firstWhere(
      (item) => item.id == presetId,
      orElse: () => presets.first,
    );
    final rtl =
        preset.profile.startsWith('ar_') || preset.profile == 'arabic_compact';
    return OfflineInvoiceLayoutBundle(
      manifest: {
        'layout': {
          'id': preset.id,
          'revision': 'local-1',
          'location_id': locationId,
          'document_type': documentType,
        },
        'page': {
          'width_mm': preset.widthMm,
          'height_mm': 297,
          'margins_mm': {'left': 2, 'top': 2, 'right': 2, 'bottom': 2},
        },
        'locale': {
          'primary_locale': rtl ? 'ar' : 'en',
          'bilingual': true,
          'direction': rtl ? 'rtl' : 'ltr',
        },
        'business': {'name_en': 'Eazy POS', 'name_ar': 'إيزي بوس'},
        'location': {'address': {}},
        'invoice_identity': {'enabled': false, 'visible_fields': {}},
        'money': {
          'currency_code': 'SAR',
          'currency_symbol': 'SAR',
          'decimal_places': 2,
        },
        'labels': {},
        'visible_fields': {'logo': false},
        'header': {},
        'footer': {},
        'provisional_document': {'enabled': true},
        'renderer_profile': preset.profile,
      },
    );
  }
}

class OfflineTemplatePreset {
  const OfflineTemplatePreset(
    this.id,
    this.name,
    this.profile,
    this.paperFormat,
    this.widthMm,
  );
  final String id;
  final String name;
  final String profile;
  final String paperFormat;
  final int widthMm;
}
