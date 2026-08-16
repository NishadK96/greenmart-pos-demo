import 'zatca_entities.dart';

abstract interface class ZatcaRepository {
  Future<ZatcaIntegrationStatus> status(String accessToken);
  Future<ZatcaLocationStatus> onboard(
    String accessToken,
    String locationId,
    ZatcaOnboardingDraft draft,
  );
  Future<ZatcaInvoiceStatus> invoiceStatus(String accessToken, String saleId);
  Future<ZatcaOperationResult> syncInvoice(String accessToken, String saleId);
  Future<ZatcaOperationResult> syncReturn(String accessToken, String returnId);
  Future<ZatcaQrPayload> qr(String accessToken, String saleId);
  Future<ZatcaDownload> downloadXml(String accessToken, String saleId);
  Future<ZatcaDownload> downloadPdf(String accessToken, String saleId);
}
