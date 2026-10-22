enum PrinterSection { billing, quotation, kitchen, barcode }

enum BillingAudience { retail, business }

class InvoicePrintRoute {
  const InvoicePrintRoute({
    required this.locationId,
    required this.documentType,
    required this.paperFormat,
    this.enabled = true,
    this.layoutId = '',
    this.layoutName = '',
    this.paperWidthMm = 210,
    this.printerUrl = '',
    this.printerName = '',
    this.copies = 1,
  });

  final String locationId;
  final String documentType;
  final String paperFormat;
  final bool enabled;
  final String layoutId;
  final String layoutName;
  final int paperWidthMm;
  final String printerUrl;
  final String printerName;
  final int copies;

  String get key => routeKey(locationId, documentType, paperFormat);
  bool get isConfigured =>
      enabled && layoutId.isNotEmpty && printerUrl.isNotEmpty;

  static String routeKey(
    String locationId,
    String documentType,
    String paperFormat,
  ) => '$locationId|$documentType|$paperFormat';

  InvoicePrintRoute copyWith({
    bool? enabled,
    String? layoutId,
    String? layoutName,
    int? paperWidthMm,
    String? printerUrl,
    String? printerName,
    int? copies,
  }) => InvoicePrintRoute(
    locationId: locationId,
    documentType: documentType,
    paperFormat: paperFormat,
    enabled: enabled ?? this.enabled,
    layoutId: layoutId ?? this.layoutId,
    layoutName: layoutName ?? this.layoutName,
    paperWidthMm: paperWidthMm ?? this.paperWidthMm,
    printerUrl: printerUrl ?? this.printerUrl,
    printerName: printerName ?? this.printerName,
    copies: copies ?? this.copies,
  );

  Map<String, Object?> toJson() => {
    'locationId': locationId,
    'documentType': documentType,
    'paperFormat': paperFormat,
    'enabled': enabled,
    'layoutId': layoutId,
    'layoutName': layoutName,
    'paperWidthMm': paperWidthMm,
    'printerUrl': printerUrl,
    'printerName': printerName,
    'copies': copies,
  };

  factory InvoicePrintRoute.fromJson(
    Map<String, dynamic> json,
  ) => InvoicePrintRoute(
    locationId: json['locationId']?.toString() ?? '',
    documentType: json['documentType']?.toString() ?? 'pos',
    paperFormat: json['paperFormat']?.toString() ?? 'a4',
    enabled: json['enabled'] as bool? ?? true,
    layoutId: json['layoutId']?.toString() ?? '',
    layoutName: json['layoutName']?.toString() ?? '',
    paperWidthMm: int.tryParse(json['paperWidthMm']?.toString() ?? '') ?? 210,
    printerUrl: json['printerUrl']?.toString() ?? '',
    printerName: json['printerName']?.toString() ?? '',
    copies: (int.tryParse(json['copies']?.toString() ?? '') ?? 1).clamp(1, 9),
  );
}

abstract final class PrinterTemplate {
  static const erp = 'ERP';
  static const bilingualReceipt = 'Arabic & English 3';
  static const detailedTaxInvoice = 'Detailed tax invoice';
  static const simplifiedQuotation = 'Simplified quotation';
  static const kitchenTicket = 'Kitchen order ticket';
  static const compactPriceLabel = 'Compact price label';

  static List<String> optionsFor(PrinterSection section) => switch (section) {
    PrinterSection.billing => const [erp, bilingualReceipt, detailedTaxInvoice],
    PrinterSection.quotation => const [erp, simplifiedQuotation],
    PrinterSection.kitchen => const [erp, kitchenTicket],
    PrinterSection.barcode => const [erp, compactPriceLabel],
  };
}

class PrinterSettings {
  const PrinterSettings({
    this.section = PrinterSection.billing,
    this.billingAudience = BillingAudience.retail,
    this.paperSizes = const {
      'billing-retail': '80mm',
      'billing-business': 'A4',
      'quotation': 'A4',
      'kitchen': '80mm',
      'barcode': '50 × 25 mm',
    },
    this.templates = const {
      'billing-retail': PrinterTemplate.bilingualReceipt,
      'billing-business': PrinterTemplate.detailedTaxInvoice,
      'quotation': PrinterTemplate.simplifiedQuotation,
      'kitchen': PrinterTemplate.kitchenTicket,
      'barcode': PrinterTemplate.compactPriceLabel,
    },
    this.selectedPrinters = const {},
    this.additionalPrinters = const {},
    this.invoicePrintRoutes = const {},
    this.kitchenPrinterBindings = const {},
    this.kitchenPrinterBindingNames = const {},
    this.defaultPrinterUrl,
    this.defaultPrinterName,
    this.barcodeColumns = 3,
    this.barcodeHeight = 56,
    this.barcodeWidthPercent = 78,
    this.barcodeDpi = 300,
    this.showStoreName = true,
    this.showPrice = true,
    this.showDate = true,
    this.posPrintingEnabled = true,
  });

  final PrinterSection section;
  final BillingAudience billingAudience;
  final Map<String, String> paperSizes;
  final Map<String, String> templates;
  final Map<String, String> selectedPrinters;

  /// Additional print destinations keyed by the platform printer URL.
  /// The primary/default destination remains in [defaultPrinterUrl].
  final Map<String, String> additionalPrinters;

  /// Location-scoped mappings between ERP layouts and physical printers.
  /// A4 and thermal routes deliberately remain separate because each route
  /// downloads a PDF rendered with its own authoritative ERP page format.
  final Map<String, InvoicePrintRoute> invoicePrintRoutes;

  /// ERP kitchen printer id -> locally installed printer URL/name. The ERP
  /// decides which items belong to each printer; these bindings decide which
  /// physical device receives that printer's durable job on this workstation.
  final Map<String, String> kitchenPrinterBindings;
  final Map<String, String> kitchenPrinterBindingNames;
  final String? defaultPrinterUrl;
  final String? defaultPrinterName;
  final int barcodeColumns, barcodeHeight, barcodeWidthPercent, barcodeDpi;
  final bool showStoreName, showPrice, showDate, posPrintingEnabled;

  String get profileKey => section == PrinterSection.billing
      ? 'billing-${billingAudience.name}'
      : section.name;

  String templateFor(String profile) =>
      templates[profile] ?? PrinterTemplate.erp;

  bool usesErpTemplate(String profile) =>
      templateFor(profile) == PrinterTemplate.erp;

  PrinterSettings withTemplateForCurrentSection(String template) {
    final updated = Map<String, String>.from(templates);
    if (section == PrinterSection.billing) {
      updated['billing-retail'] = template;
      updated['billing-business'] = template;
    } else {
      updated[profileKey] = template;
    }
    return copyWith(templates: updated);
  }

  PrinterSettings copyWith({
    PrinterSection? section,
    BillingAudience? billingAudience,
    Map<String, String>? paperSizes,
    Map<String, String>? templates,
    Map<String, String>? selectedPrinters,
    Map<String, String>? additionalPrinters,
    Map<String, InvoicePrintRoute>? invoicePrintRoutes,
    Map<String, String>? kitchenPrinterBindings,
    Map<String, String>? kitchenPrinterBindingNames,
    String? defaultPrinterUrl,
    String? defaultPrinterName,
    bool clearDefaultPrinter = false,
    int? barcodeColumns,
    int? barcodeHeight,
    int? barcodeWidthPercent,
    int? barcodeDpi,
    bool? showStoreName,
    bool? showPrice,
    bool? showDate,
    bool? posPrintingEnabled,
  }) => PrinterSettings(
    section: section ?? this.section,
    billingAudience: billingAudience ?? this.billingAudience,
    paperSizes: paperSizes ?? this.paperSizes,
    templates: templates ?? this.templates,
    selectedPrinters: selectedPrinters ?? this.selectedPrinters,
    additionalPrinters: additionalPrinters ?? this.additionalPrinters,
    invoicePrintRoutes: invoicePrintRoutes ?? this.invoicePrintRoutes,
    kitchenPrinterBindings:
        kitchenPrinterBindings ?? this.kitchenPrinterBindings,
    kitchenPrinterBindingNames:
        kitchenPrinterBindingNames ?? this.kitchenPrinterBindingNames,
    defaultPrinterUrl: clearDefaultPrinter
        ? null
        : defaultPrinterUrl ?? this.defaultPrinterUrl,
    defaultPrinterName: clearDefaultPrinter
        ? null
        : defaultPrinterName ?? this.defaultPrinterName,
    barcodeColumns: barcodeColumns ?? this.barcodeColumns,
    barcodeHeight: barcodeHeight ?? this.barcodeHeight,
    barcodeWidthPercent: barcodeWidthPercent ?? this.barcodeWidthPercent,
    barcodeDpi: barcodeDpi ?? this.barcodeDpi,
    showStoreName: showStoreName ?? this.showStoreName,
    showPrice: showPrice ?? this.showPrice,
    showDate: showDate ?? this.showDate,
    posPrintingEnabled: posPrintingEnabled ?? this.posPrintingEnabled,
  );

  Map<String, Object?> toJson() => {
    'paperSizes': paperSizes,
    'templates': templates,
    'selectedPrinters': selectedPrinters,
    'additionalPrinters': additionalPrinters,
    'invoicePrintRoutes': invoicePrintRoutes.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'kitchenPrinterBindings': kitchenPrinterBindings,
    'kitchenPrinterBindingNames': kitchenPrinterBindingNames,
    'defaultPrinterUrl': defaultPrinterUrl,
    'defaultPrinterName': defaultPrinterName,
    'barcodeColumns': barcodeColumns,
    'barcodeHeight': barcodeHeight,
    'barcodeWidthPercent': barcodeWidthPercent,
    'barcodeDpi': barcodeDpi,
    'showStoreName': showStoreName,
    'showPrice': showPrice,
    'showDate': showDate,
    'posPrintingEnabled': posPrintingEnabled,
  };

  factory PrinterSettings.fromJson(Map<String, dynamic> json) {
    const defaults = PrinterSettings();
    return PrinterSettings(
      paperSizes: {
        ...defaults.paperSizes,
        ...Map<String, String>.from(json['paperSizes'] as Map? ?? const {}),
      },
      templates: {
        ...defaults.templates,
        ...Map<String, String>.from(json['templates'] as Map? ?? const {}),
      },
      selectedPrinters: Map<String, String>.from(
        json['selectedPrinters'] as Map? ?? const {},
      ),
      additionalPrinters: Map<String, String>.from(
        json['additionalPrinters'] as Map? ?? const {},
      ),
      invoicePrintRoutes:
          Map<String, dynamic>.from(
            json['invoicePrintRoutes'] as Map? ?? const {},
          ).map(
            (key, value) => MapEntry(
              key,
              InvoicePrintRoute.fromJson(
                Map<String, dynamic>.from(value as Map? ?? const {}),
              ),
            ),
          ),
      kitchenPrinterBindings: Map<String, String>.from(
        json['kitchenPrinterBindings'] as Map? ?? const {},
      ),
      kitchenPrinterBindingNames: Map<String, String>.from(
        json['kitchenPrinterBindingNames'] as Map? ?? const {},
      ),
      defaultPrinterUrl:
          json['defaultPrinterUrl']?.toString() ??
          _firstSelectedPrinter(json['selectedPrinters']),
      defaultPrinterName: json['defaultPrinterName']?.toString(),
      barcodeColumns: json['barcodeColumns'] as int? ?? 3,
      barcodeHeight: json['barcodeHeight'] as int? ?? 56,
      barcodeWidthPercent: json['barcodeWidthPercent'] as int? ?? 78,
      barcodeDpi: json['barcodeDpi'] as int? ?? 300,
      showStoreName: json['showStoreName'] as bool? ?? true,
      showPrice: json['showPrice'] as bool? ?? true,
      showDate: json['showDate'] as bool? ?? true,
      posPrintingEnabled: json['posPrintingEnabled'] as bool? ?? true,
    );
  }

  static String? _firstSelectedPrinter(dynamic raw) {
    final selected = Map<String, String>.from(raw as Map? ?? const {});
    return selected.isEmpty ? null : selected.values.first;
  }
}
