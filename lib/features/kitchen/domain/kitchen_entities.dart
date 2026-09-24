class KitchenTemplate {
  const KitchenTemplate({
    required this.key,
    required this.name,
    this.previewUrl,
  });

  final String key;
  final String name;
  final String? previewUrl;

  factory KitchenTemplate.fromJson(Map<String, dynamic> json) =>
      KitchenTemplate(
        key: json['key']?.toString() ?? 'thermal',
        name: json['name']?.toString() ?? json['key']?.toString() ?? 'Thermal',
        previewUrl: json['preview_url']?.toString(),
      );
}

class KitchenErpPrinter {
  const KitchenErpPrinter({
    required this.id,
    required this.name,
    this.locationId,
    this.connectionType,
    this.capabilityProfile,
    this.charPerLine,
    this.ipAddress,
    this.port,
    this.path,
    this.serverUrl,
  });

  final String id;
  final String name;
  final String? locationId;
  final String? connectionType;
  final String? capabilityProfile;
  final String? charPerLine;
  final String? ipAddress;
  final String? port;
  final String? path;
  final String? serverUrl;

  factory KitchenErpPrinter.fromJson(Map<String, dynamic> json) =>
      KitchenErpPrinter(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Kitchen printer',
        locationId: json['location_id']?.toString(),
        connectionType: json['connection_type']?.toString(),
        capabilityProfile: json['capability_profile']?.toString(),
        charPerLine: json['char_per_line']?.toString(),
        ipAddress: json['ip_address']?.toString(),
        port: json['port']?.toString(),
        path: json['path']?.toString(),
        serverUrl: json['server_url']?.toString(),
      );
}

class KitchenCategoryOption {
  const KitchenCategoryOption({
    required this.id,
    required this.name,
    this.subCategories = const [],
  });

  final String id;
  final String name;
  final List<KitchenCategoryOption> subCategories;

  factory KitchenCategoryOption.fromJson(Map<String, dynamic> json) =>
      KitchenCategoryOption(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Category',
        subCategories: _objectList(
          json['sub_categories'],
        ).map(KitchenCategoryOption.fromJson).toList(growable: false),
      );
}

class RestaurantSettings {
  const RestaurantSettings({
    required this.locationId,
    required this.selectedTemplate,
    required this.templates,
    required this.printReceiptOnInvoice,
    required this.receiptPrinterType,
    this.receiptPrinterId,
    this.invoiceLayoutId,
    this.invoiceSchemeId,
  });

  final String locationId;
  final String selectedTemplate;
  final List<KitchenTemplate> templates;
  final bool printReceiptOnInvoice;
  final String receiptPrinterType;
  final String? receiptPrinterId;
  final String? invoiceLayoutId;
  final String? invoiceSchemeId;

  factory RestaurantSettings.fromJson(Map<String, dynamic> json) {
    final receipt = _object(json['receipt']);
    final kitchen = _object(json['kitchen']);
    final invoice = _object(json['invoice']);
    return RestaurantSettings(
      locationId: json['location_id']?.toString() ?? '',
      selectedTemplate: kitchen['selected_template']?.toString() ?? 'thermal',
      templates: _objectList(
        kitchen['templates'],
      ).map(KitchenTemplate.fromJson).toList(growable: false),
      printReceiptOnInvoice: _bool(receipt['print_receipt_on_invoice']),
      receiptPrinterType:
          receipt['receipt_printer_type']?.toString() ?? 'browser',
      receiptPrinterId: receipt['printer_id']?.toString(),
      invoiceLayoutId: invoice['invoice_layout_id']?.toString(),
      invoiceSchemeId: invoice['invoice_scheme_id']?.toString(),
    );
  }
}

class KitchenPrinterOptions {
  const KitchenPrinterOptions({
    required this.locationId,
    required this.printers,
    required this.categories,
    required this.templates,
  });

  final String locationId;
  final List<KitchenErpPrinter> printers;
  final List<KitchenCategoryOption> categories;
  final List<KitchenTemplate> templates;

  factory KitchenPrinterOptions.fromJson(Map<String, dynamic> json) =>
      KitchenPrinterOptions(
        locationId: json['location_id']?.toString() ?? '',
        printers: _objectList(
          json['printers'],
        ).map(KitchenErpPrinter.fromJson).toList(growable: false),
        categories: _objectList(
          json['categories'],
        ).map(KitchenCategoryOption.fromJson).toList(growable: false),
        templates: _objectList(
          json['templates'],
        ).map(KitchenTemplate.fromJson).toList(growable: false),
      );
}

class KitchenPrinterRoute {
  const KitchenPrinterRoute({
    required this.id,
    required this.category,
    required this.printer,
    required this.priority,
    required this.isActive,
    this.subCategory,
    this.template,
  });

  final String id;
  final KitchenCategoryOption category;
  final KitchenCategoryOption? subCategory;
  final KitchenErpPrinter printer;
  final KitchenTemplate? template;
  final int priority;
  final bool isActive;

  factory KitchenPrinterRoute.fromJson(Map<String, dynamic> json) =>
      KitchenPrinterRoute(
        id: json['id']?.toString() ?? '',
        category: KitchenCategoryOption.fromJson(_object(json['category'])),
        subCategory: json['sub_category'] is Map
            ? KitchenCategoryOption.fromJson(_object(json['sub_category']))
            : null,
        printer: KitchenErpPrinter.fromJson(_object(json['printer'])),
        template: json['template'] is Map
            ? KitchenTemplate.fromJson(_object(json['template']))
            : null,
        priority: int.tryParse(json['priority']?.toString() ?? '') ?? 0,
        isActive: _bool(json['is_active'], fallback: true),
      );
}

class KitchenJobItem {
  const KitchenJobItem({
    required this.productName,
    required this.quantity,
    this.variation,
    this.unit,
    this.note,
    this.serviceStaff,
    this.modifiers = const [],
    this.reason,
  });

  final String productName;
  final double quantity;
  final String? variation;
  final String? unit;
  final String? note;
  final String? serviceStaff;
  final List<KitchenJobItem> modifiers;
  final String? reason;

  factory KitchenJobItem.fromJson(Map<String, dynamic> json) => KitchenJobItem(
    productName: json['product_name']?.toString() ?? 'Item',
    quantity: double.tryParse(json['quantity']?.toString() ?? '') ?? 0,
    variation: json['variation']?.toString(),
    unit: json['unit']?.toString(),
    note: json['note']?.toString(),
    serviceStaff: json['service_staff']?.toString(),
    reason: json['reason']?.toString(),
    modifiers: _objectList(
      json['modifiers'],
    ).map(KitchenJobItem.fromJson).toList(growable: false),
  );
}

class KitchenPrintJob {
  const KitchenPrintJob({
    required this.id,
    required this.status,
    required this.transactionId,
    required this.locationId,
    required this.template,
    required this.printer,
    required this.items,
    required this.attempts,
    this.jobKey,
    this.htmlContent = '',
    this.pdfUrl = '',
    this.lastError,
    this.createdAt,
    this.printedAt,
  });

  final String id;
  final String status;
  final String transactionId;
  final String locationId;
  final String template;
  final KitchenErpPrinter printer;
  final List<KitchenJobItem> items;
  final int attempts;
  final String? jobKey;
  final String htmlContent;
  final String pdfUrl;
  final String? lastError;
  final DateTime? createdAt;
  final DateTime? printedAt;

  factory KitchenPrintJob.fromJson(Map<String, dynamic> json) =>
      KitchenPrintJob(
        id: (json['job_id'] ?? json['id'])?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        transactionId: json['transaction_id']?.toString() ?? '',
        locationId: json['location_id']?.toString() ?? '',
        template: json['template']?.toString() ?? 'thermal',
        printer: KitchenErpPrinter.fromJson(_object(json['printer'])),
        items: _objectList(
          json['items'],
        ).map(KitchenJobItem.fromJson).toList(growable: false),
        attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
        jobKey: json['job_key']?.toString(),
        htmlContent: json['html_content']?.toString() ?? '',
        pdfUrl: json['pdf_url']?.toString() ?? '',
        lastError: json['last_error']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        printedAt: DateTime.tryParse(json['printed_at']?.toString() ?? ''),
      );
}

class KitchenJobsResult {
  const KitchenJobsResult({
    required this.jobs,
    this.unassignedItems = const [],
  });

  final List<KitchenPrintJob> jobs;
  final List<KitchenJobItem> unassignedItems;

  factory KitchenJobsResult.fromJson(Map<String, dynamic> json) =>
      KitchenJobsResult(
        jobs: _objectList(
          json['jobs'],
        ).map(KitchenPrintJob.fromJson).toList(growable: false),
        unassignedItems: _objectList(
          json['unassigned_items'],
        ).map(KitchenJobItem.fromJson).toList(growable: false),
      );
}

Map<String, dynamic> _object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _objectList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];

bool _bool(dynamic value, {bool fallback = false}) => value == null
    ? fallback
    : value == true || value == 1 || value.toString() == '1';
