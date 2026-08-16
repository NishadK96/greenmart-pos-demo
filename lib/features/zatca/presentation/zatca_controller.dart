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

  Future<String> _token() async {
    final token = await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty)
      throw StateError('Your session has expired.');
    return token;
  }
}
