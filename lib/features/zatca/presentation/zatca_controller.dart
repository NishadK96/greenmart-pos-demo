import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_controller.dart';
import '../data/eazyerp_zatca_repository.dart';
import '../domain/zatca_entities.dart';

final zatcaControllerProvider =
    AsyncNotifierProvider<ZatcaController, ZatcaIntegrationStatus>(
      ZatcaController.new,
    );

class ZatcaController extends AsyncNotifier<ZatcaIntegrationStatus> {
  @override
  Future<ZatcaIntegrationStatus> build() async =>
      ref.read(zatcaRepositoryProvider).status(await _token());

  Future<void> refreshStatus() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> onboard(String locationId, ZatcaOnboardingDraft draft) async {
    await ref
        .read(zatcaRepositoryProvider)
        .onboard(await _token(), locationId, draft);
    await refreshStatus();
  }

  Future<ZatcaInvoiceStatus> invoiceStatus(String saleId) async =>
      ref.read(zatcaRepositoryProvider).invoiceStatus(await _token(), saleId);

  Future<ZatcaOperationResult> syncInvoice(String saleId) async {
    final result = await ref
        .read(zatcaRepositoryProvider)
        .syncInvoice(await _token(), saleId);
    ref.invalidateSelf();
    return result;
  }

  Future<ZatcaOperationResult> syncReturn(String returnId) async {
    final result = await ref
        .read(zatcaRepositoryProvider)
        .syncReturn(await _token(), returnId);
    ref.invalidateSelf();
    return result;
  }

  Future<ZatcaQrPayload> qr(String saleId) async =>
      ref.read(zatcaRepositoryProvider).qr(await _token(), saleId);

  Future<ZatcaDownload> downloadXml(String saleId) async =>
      ref.read(zatcaRepositoryProvider).downloadXml(await _token(), saleId);

  Future<ZatcaDownload> downloadPdf(String saleId) async =>
      ref.read(zatcaRepositoryProvider).downloadPdf(await _token(), saleId);

  Future<ZatcaPage> invoices(ZatcaListFilter filter) async =>
      ref.read(zatcaRepositoryProvider).invoices(await _token(), filter);

  Future<ZatcaPage> returns(ZatcaListFilter filter) async =>
      ref.read(zatcaRepositoryProvider).returns(await _token(), filter);

  Future<ZatcaInvoiceStatus> returnStatus(String returnId) async =>
      ref.read(zatcaRepositoryProvider).returnStatus(await _token(), returnId);

  Future<ZatcaBulkResult> syncInvoicesBulk(List<String> ids) async {
    final result = await ref
        .read(zatcaRepositoryProvider)
        .syncInvoicesBulk(await _token(), ids);
    ref.invalidateSelf();
    return result;
  }

  Future<ZatcaBulkResult> syncReturnsBulk(List<String> ids) async {
    final result = await ref
        .read(zatcaRepositoryProvider)
        .syncReturnsBulk(await _token(), ids);
    ref.invalidateSelf();
    return result;
  }

  Future<ZatcaQrPayload> returnQr(String returnId) async =>
      ref.read(zatcaRepositoryProvider).returnQr(await _token(), returnId);

  Future<ZatcaDownload> downloadReturnXml(String returnId) async => ref
      .read(zatcaRepositoryProvider)
      .downloadReturnXml(await _token(), returnId);

  Future<ZatcaDownload> downloadReturnPdf(String returnId) async => ref
      .read(zatcaRepositoryProvider)
      .downloadReturnPdf(await _token(), returnId);

  Future<ZatcaSettings> settings() async =>
      ref.read(zatcaRepositoryProvider).settings(await _token());

  Future<ZatcaSettings> updateSettings(Map<String, dynamic> changes) async =>
      ref.read(zatcaRepositoryProvider).updateSettings(await _token(), changes);

  Future<ZatcaSyncSummary> syncSummary() async =>
      ref.read(zatcaRepositoryProvider).syncSummary(await _token());

  Future<String> _token() async {
    final token = await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty)
      throw StateError('Your session has expired.');
    return token;
  }
}
