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
