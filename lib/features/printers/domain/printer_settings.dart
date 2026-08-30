enum PrinterSection { billing, quotation, kitchen, barcode }

enum BillingAudience { retail, business }

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
    this.defaultPrinterUrl,
    this.barcodeColumns = 3,
    this.barcodeHeight = 56,
    this.barcodeWidthPercent = 78,
    this.barcodeDpi = 300,
    this.showStoreName = true,
    this.showPrice = true,
    this.showDate = true,
  });

  final PrinterSection section;
  final BillingAudience billingAudience;
  final Map<String, String> paperSizes;
  final Map<String, String> templates;
  final Map<String, String> selectedPrinters;
  final String? defaultPrinterUrl;
  final int barcodeColumns, barcodeHeight, barcodeWidthPercent, barcodeDpi;
  final bool showStoreName, showPrice, showDate;

  String get profileKey => section == PrinterSection.billing
      ? 'billing-${billingAudience.name}'
      : section.name;

  String templateFor(String profile) =>
      templates[profile] ?? PrinterTemplate.erp;

  bool usesErpTemplate(String profile) =>
      templateFor(profile) == PrinterTemplate.erp;

  PrinterSettings copyWith({
    PrinterSection? section,
    BillingAudience? billingAudience,
    Map<String, String>? paperSizes,
    Map<String, String>? templates,
    Map<String, String>? selectedPrinters,
    String? defaultPrinterUrl,
    bool clearDefaultPrinter = false,
    int? barcodeColumns,
    int? barcodeHeight,
    int? barcodeWidthPercent,
    int? barcodeDpi,
    bool? showStoreName,
    bool? showPrice,
    bool? showDate,
  }) => PrinterSettings(
    section: section ?? this.section,
    billingAudience: billingAudience ?? this.billingAudience,
    paperSizes: paperSizes ?? this.paperSizes,
    templates: templates ?? this.templates,
    selectedPrinters: selectedPrinters ?? this.selectedPrinters,
    defaultPrinterUrl: clearDefaultPrinter
        ? null
        : defaultPrinterUrl ?? this.defaultPrinterUrl,
    barcodeColumns: barcodeColumns ?? this.barcodeColumns,
    barcodeHeight: barcodeHeight ?? this.barcodeHeight,
    barcodeWidthPercent: barcodeWidthPercent ?? this.barcodeWidthPercent,
    barcodeDpi: barcodeDpi ?? this.barcodeDpi,
    showStoreName: showStoreName ?? this.showStoreName,
    showPrice: showPrice ?? this.showPrice,
    showDate: showDate ?? this.showDate,
  );

  Map<String, Object?> toJson() => {
    'paperSizes': paperSizes,
    'templates': templates,
    'selectedPrinters': selectedPrinters,
    'defaultPrinterUrl': defaultPrinterUrl,
    'barcodeColumns': barcodeColumns,
    'barcodeHeight': barcodeHeight,
    'barcodeWidthPercent': barcodeWidthPercent,
    'barcodeDpi': barcodeDpi,
    'showStoreName': showStoreName,
    'showPrice': showPrice,
    'showDate': showDate,
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
      defaultPrinterUrl:
          json['defaultPrinterUrl']?.toString() ??
          _firstSelectedPrinter(json['selectedPrinters']),
      barcodeColumns: json['barcodeColumns'] as int? ?? 3,
      barcodeHeight: json['barcodeHeight'] as int? ?? 56,
      barcodeWidthPercent: json['barcodeWidthPercent'] as int? ?? 78,
      barcodeDpi: json['barcodeDpi'] as int? ?? 300,
      showStoreName: json['showStoreName'] as bool? ?? true,
      showPrice: json['showPrice'] as bool? ?? true,
      showDate: json['showDate'] as bool? ?? true,
    );
  }

  static String? _firstSelectedPrinter(dynamic raw) {
    final selected = Map<String, String>.from(raw as Map? ?? const {});
    return selected.isEmpty ? null : selected.values.first;
  }
}
