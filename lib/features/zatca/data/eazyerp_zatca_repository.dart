import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../domain/zatca_entities.dart';
import '../domain/zatca_repository.dart';

final zatcaRepositoryProvider = Provider<ZatcaRepository>(
  (ref) => EazyErpZatcaRepository(ref.watch(apiProvider)),
);

class EazyErpZatcaRepository implements ZatcaRepository {
  const EazyErpZatcaRepository(this._api);
  final Api _api;
  @override
  Future<ZatcaIntegrationStatus> status(String accessToken) =>
      _api.zatcaStatus(accessToken);
  @override
  Future<ZatcaLocationStatus> onboard(
    String accessToken,
    String locationId,
    ZatcaOnboardingDraft draft,
  ) => _api.onboardZatca(
    accessToken: accessToken,
    locationId: locationId,
    draft: draft,
  );
  @override
  Future<ZatcaInvoiceStatus> invoiceStatus(String accessToken, String saleId) =>
      _api.zatcaInvoiceStatus(accessToken, saleId);
  @override
  Future<ZatcaOperationResult> syncInvoice(String accessToken, String saleId) =>
      _api.syncZatcaInvoice(accessToken, saleId);
  @override
  Future<ZatcaOperationResult> syncReturn(
    String accessToken,
    String returnId,
  ) => _api.syncZatcaReturn(accessToken, returnId);
  @override
  Future<ZatcaQrPayload> qr(String accessToken, String saleId) =>
      _api.zatcaQr(accessToken, saleId);
  @override
  Future<ZatcaDownload> downloadXml(String accessToken, String saleId) =>
      _api.downloadZatcaXml(accessToken, saleId);
  @override
  Future<ZatcaDownload> downloadPdf(String accessToken, String saleId) =>
      _api.downloadZatcaPdf(accessToken, saleId);
}
