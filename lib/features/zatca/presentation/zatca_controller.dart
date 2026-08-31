import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../auth/auth_controller.dart';
import '../data/eazyerp_zatca_repository.dart';
import '../domain/zatca_entities.dart';

final zatcaControllerProvider =
    AsyncNotifierProvider<ZatcaController, ZatcaIntegrationStatus>(
      ZatcaController.new,
    );

class ZatcaController extends AsyncNotifier<ZatcaIntegrationStatus> {
  static const _tokenTimeout = Duration(seconds: 8);
  static const _statusTimeout = Duration(seconds: 12);

  @override
  Future<ZatcaIntegrationStatus> build() => _loadStatus();

  Future<ZatcaIntegrationStatus> _loadStatus() async {
    try {
      return await _authorized(
        (token) => ref.read(zatcaRepositoryProvider).status(token),
        timeout: _statusTimeout,
      );
    } on TimeoutException {
      throw const ApiException(
        'The ZATCA service did not respond in time. Check the backend connection and try again.',
      );
    }
  }

  Future<void> refreshStatus() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadStatus);
  }

  Future<void> onboard(String locationId, ZatcaOnboardingDraft draft) async {
    await _authorized(
      (token) =>
          ref.read(zatcaRepositoryProvider).onboard(token, locationId, draft),
    );
    await refreshStatus();
  }

  Future<ZatcaInvoiceStatus> invoiceStatus(String saleId) async => _authorized(
    (token) => ref.read(zatcaRepositoryProvider).invoiceStatus(token, saleId),
  );

  Future<ZatcaOperationResult> syncInvoice(String saleId) async {
    final result = await _authorized(
      (token) => ref.read(zatcaRepositoryProvider).syncInvoice(token, saleId),
    );
    ref.invalidateSelf();
    return result;
  }

  Future<ZatcaOperationResult> syncReturn(String returnId) async {
    final result = await _authorized(
      (token) => ref.read(zatcaRepositoryProvider).syncReturn(token, returnId),
    );
    ref.invalidateSelf();
    return result;
  }

  Future<ZatcaQrPayload> qr(String saleId) async => _authorized(
    (token) => ref.read(zatcaRepositoryProvider).qr(token, saleId),
  );

  Future<ZatcaDownload> downloadXml(String saleId) async => _authorized(
    (token) => ref.read(zatcaRepositoryProvider).downloadXml(token, saleId),
  );

  Future<ZatcaDownload> downloadPdf(String saleId) async => _authorized(
    (token) => ref.read(zatcaRepositoryProvider).downloadPdf(token, saleId),
  );

  Future<ZatcaPage> invoices(ZatcaListFilter filter) async => _authorized(
    (token) => ref.read(zatcaRepositoryProvider).invoices(token, filter),
  );

  Future<ZatcaPage> returns(ZatcaListFilter filter) async => _authorized(
    (token) => ref.read(zatcaRepositoryProvider).returns(token, filter),
  );

  Future<ZatcaInvoiceStatus> returnStatus(String returnId) async => _authorized(
    (token) => ref.read(zatcaRepositoryProvider).returnStatus(token, returnId),
  );

  Future<ZatcaBulkResult> syncInvoicesBulk(List<String> ids) async {
    final result = await _authorized(
      (token) => ref.read(zatcaRepositoryProvider).syncInvoicesBulk(token, ids),
    );
    ref.invalidateSelf();
    return result;
  }

  Future<ZatcaBulkResult> syncReturnsBulk(List<String> ids) async {
    final result = await _authorized(
      (token) => ref.read(zatcaRepositoryProvider).syncReturnsBulk(token, ids),
    );
    ref.invalidateSelf();
    return result;
  }

  Future<ZatcaQrPayload> returnQr(String returnId) async => _authorized(
    (token) => ref.read(zatcaRepositoryProvider).returnQr(token, returnId),
  );

  Future<ZatcaDownload> downloadReturnXml(String returnId) async => _authorized(
    (token) =>
        ref.read(zatcaRepositoryProvider).downloadReturnXml(token, returnId),
  );

  Future<ZatcaDownload> downloadReturnPdf(String returnId) async => _authorized(
    (token) =>
        ref.read(zatcaRepositoryProvider).downloadReturnPdf(token, returnId),
  );

  Future<ZatcaSettings> settings() async =>
      _authorized((token) => ref.read(zatcaRepositoryProvider).settings(token));

  Future<ZatcaSettings> updateSettings(Map<String, dynamic> changes) async =>
      _authorized(
        (token) =>
            ref.read(zatcaRepositoryProvider).updateSettings(token, changes),
      );

  Future<ZatcaSyncSummary> syncSummary() async => _authorized(
    (token) => ref.read(zatcaRepositoryProvider).syncSummary(token),
  );

  Future<T> _authorized<T>(
    Future<T> Function(String token) request, {
    Duration? timeout,
  }) async {
    Future<T> send(String token) {
      final future = request(token);
      return timeout == null ? future : future.timeout(timeout);
    }

    final token = await _token();
    try {
      return await send(token);
    } on ApiException catch (error) {
      if (!_isExpiredToken(error)) rethrow;
      final refreshed = await ref
          .read(authControllerProvider.notifier)
          .refreshAccessToken();
      return send(refreshed);
    }
  }

  bool _isExpiredToken(ApiException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == 401 ||
        message.contains('access token has expired') ||
        message.contains('unauthenticated');
  }

  Future<String> _token() async {
    final auth = ref.read(authControllerProvider);
    final token =
        auth.asData?.value ??
        await ref
            .read(authControllerProvider.future)
            .timeout(_tokenTimeout, onTimeout: () => null);
    if (token == null || token.isEmpty)
      throw StateError('Your session has expired.');
    return token;
  }
}
