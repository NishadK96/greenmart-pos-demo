enum PrinterSection { billing, quotation, kitchen, barcode }

enum BillingAudience { retail, business }

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
      'billing-retail': 'Arabic & English 3',
      'billing-business': 'Detailed tax invoice',
      'quotation': 'Simplified quotation',
      'kitchen': 'Kitchen order ticket',
      'barcode': 'Compact price label',
    },
    this.selectedPrinters = const {},
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
  final int barcodeColumns, barcodeHeight, barcodeWidthPercent, barcodeDpi;
  final bool showStoreName, showPrice, showDate;

  String get profileKey => section == PrinterSection.billing
      ? 'billing-${billingAudience.name}'
      : section.name;

  PrinterSettings copyWith({
    PrinterSection? section,
    BillingAudience? billingAudience,
    Map<String, String>? paperSizes,
    Map<String, String>? templates,
    Map<String, String>? selectedPrinters,
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
      barcodeColumns: json['barcodeColumns'] as int? ?? 3,
      barcodeHeight: json['barcodeHeight'] as int? ?? 56,
      barcodeWidthPercent: json['barcodeWidthPercent'] as int? ?? 78,
      barcodeDpi: json['barcodeDpi'] as int? ?? 300,
      showStoreName: json['showStoreName'] as bool? ?? true,
      showPrice: json['showPrice'] as bool? ?? true,
      showDate: json['showDate'] as bool? ?? true,
    );
  }
}
