import 'dart:typed_data';

class ZatcaTotals {
  const ZatcaTotals({
    required this.pending,
    required this.success,
    required this.failed,
  });
  final int pending, success, failed;
}

class ZatcaLocationStatus {
  const ZatcaLocationStatus({
    required this.id,
    required this.name,
    required this.configured,
    this.portalMode,
    this.syncFrom,
  });
  final String id, name;
  final bool configured;
  final String? portalMode, syncFrom;
}

class ZatcaIntegrationStatus {
  const ZatcaIntegrationStatus({
    required this.installed,
    required this.subscriptionEnabled,
    required this.syncFrequency,
    required this.locations,
    required this.totals,
    this.version,
  });
  final bool installed, subscriptionEnabled;
  final String syncFrequency;
  final String? version;
  final List<ZatcaLocationStatus> locations;
  final ZatcaTotals totals;
}

class ZatcaOnboardingDraft {
  const ZatcaOnboardingDraft({
    required this.portalMode,
    required this.otp,
    required this.email,
    required this.commonName,
    required this.organizationUnitName,
    required this.organizationName,
    required this.vatNumber,
    required this.invoiceType,
    required this.registeredAddress,
    required this.businessCategory,
    this.vatName = '',
    this.crn = '',
    this.streetName = '',
    this.buildingNumber = '',
    this.plotIdentification = '',
    this.subDivisionName = '',
    this.cityName = '',
    this.postalNumber = '',
    this.countryName = 'Saudi Arabia',
  });
  final String portalMode, otp, email, commonName, organizationUnitName;
  final String organizationName, vatNumber, invoiceType, registeredAddress;
  final String businessCategory, vatName, crn, streetName, buildingNumber;
  final String plotIdentification, subDivisionName, cityName, postalNumber;
  final String countryName;

  Map<String, dynamic> toJson() => {
    'portal_mode': portalMode,
    'otp': otp,
    'email': email,
    'common_name': commonName,
    'country_code': 'SA',
    'organization_unit_name': organizationUnitName,
    'organization_name': organizationName,
    'vat_number': vatNumber,
    if (vatName.isNotEmpty) 'vat_name': vatName,
    'invoice_type': invoiceType,
    'registered_address': registeredAddress,
    'business_category': businessCategory,
    if (crn.isNotEmpty) 'crn': crn,
    if (streetName.isNotEmpty) 'street_name': streetName,
    if (buildingNumber.isNotEmpty) 'building_number': buildingNumber,
    if (plotIdentification.isNotEmpty)
      'plot_identification': plotIdentification,
    if (subDivisionName.isNotEmpty) 'sub_division_name': subDivisionName,
    if (cityName.isNotEmpty) 'city_name': cityName,
    if (postalNumber.isNotEmpty) 'postal_number': postalNumber,
    if (countryName.isNotEmpty) 'country_name': countryName,
  };
}

class ZatcaDocumentInfo {
  const ZatcaDocumentInfo({
    required this.id,
    required this.status,
    required this.sentToZatca,
    this.icv,
    this.uuid,
    this.portalMode,
    this.signingTime,
  });
  final String id, status;
  final bool sentToZatca;
  final String? icv, uuid, portalMode, signingTime;
}

class ZatcaInvoiceStatus {
  const ZatcaInvoiceStatus({
    required this.saleId,
    required this.invoiceNo,
    required this.status,
    this.document,
  });
  final String saleId, invoiceNo, status;
  final ZatcaDocumentInfo? document;
}

class ZatcaOperationResult {
  const ZatcaOperationResult({
    required this.success,
    required this.message,
    required this.status,
  });
  final bool success;
  final String message, status;
}

class ZatcaQrPayload {
  const ZatcaQrPayload({
    required this.saleId,
    required this.value,
    required this.format,
  });
  final String saleId, value, format;
}

class ZatcaDownload {
  const ZatcaDownload({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

class ZatcaTransaction {
  const ZatcaTransaction({
    required this.id,
    required this.invoiceNo,
    required this.status,
    required this.transactionDate,
    required this.total,
    this.locationId,
    this.locationName,
    this.customerName,
    this.customerMobile,
    this.parentSaleId,
    this.parentInvoiceNo,
    this.document,
  });
  final String id, invoiceNo, status, transactionDate;
  final double total;
  final String? locationId, locationName, customerName, customerMobile;
  final String? parentSaleId, parentInvoiceNo;
  final ZatcaDocumentInfo? document;
}

class ZatcaPage {
  const ZatcaPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });
  final List<ZatcaTransaction> items;
  final int currentPage, lastPage, perPage, total;
}

class ZatcaListFilter {
  const ZatcaListFilter({
    this.status,
    this.locationId,
    this.dateFrom,
    this.dateTo,
    this.search,
    this.page = 1,
    this.perPage = 20,
  });
  final String? status, locationId, dateFrom, dateTo, search;
  final int page, perPage;
  Map<String, String> toQuery() => {
    if (status != null && status!.isNotEmpty) 'status': status!,
    if (locationId != null && locationId!.isNotEmpty)
      'location_id': locationId!,
    if (dateFrom != null && dateFrom!.isNotEmpty) 'date_from': dateFrom!,
    if (dateTo != null && dateTo!.isNotEmpty) 'date_to': dateTo!,
    if (search != null && search!.isNotEmpty) 'search': search!,
    'page': '$page',
    'per_page': '$perPage',
  };
}

class ZatcaBulkResult {
  const ZatcaBulkResult({
    required this.requested,
    required this.successful,
    required this.failed,
    required this.results,
  });
  final int requested, successful, failed;
  final List<ZatcaOperationResult> results;
}

class ZatcaSettingLocation {
  const ZatcaSettingLocation({
    required this.id,
    required this.name,
    this.syncFrom,
  });
  final String id, name;
  final String? syncFrom;
}

class ZatcaSettings {
  const ZatcaSettings({
    required this.syncFrequency,
    required this.disableDiscount,
    required this.disableOrderTax,
    required this.defaultSalesDiscount,
    required this.locations,
  });
  final String syncFrequency;
  final bool disableDiscount, disableOrderTax;
  final double defaultSalesDiscount;
  final List<ZatcaSettingLocation> locations;
}

class ZatcaSyncSummary {
  const ZatcaSyncSummary({
    required this.totalInvoices,
    required this.pending,
    required this.successful,
    required this.failed,
    required this.developerSynced,
    required this.simulationSynced,
  });
  final int totalInvoices, pending, successful, failed;
  final int developerSynced, simulationSynced;
}
