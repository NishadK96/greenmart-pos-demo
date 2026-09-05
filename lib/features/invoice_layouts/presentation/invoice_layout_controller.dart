import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../shared/models/entities.dart';
import '../../auth/auth_controller.dart';
import '../../printers/application/printer_document_service.dart';
import '../../printers/domain/printer_settings.dart';
import '../../store/app_store.dart';
import '../domain/invoice_layout_entities.dart';

final invoiceLayoutControllerProvider =
    AsyncNotifierProvider<InvoiceLayoutController, ErpInvoiceLayoutCatalog?>(
      InvoiceLayoutController.new,
    );

class InvoiceLayoutController extends AsyncNotifier<ErpInvoiceLayoutCatalog?> {
  String _locationId = '';
  String _documentType = 'pos';
  final Map<String, ErpInvoicePdf> _salePdfCache = {};

  @override
  Future<ErpInvoiceLayoutCatalog?> build() async {
    final locations = ref.watch(
      appStoreProvider.select((state) => state.locations),
    );
    if (locations.isEmpty) return null;
    if (_locationId.isEmpty ||
        !locations.any((location) => location.id == _locationId)) {
      _locationId = locations.first.id;
    }
    return _load();
  }

  Future<void> selectLocation(String locationId) async {
    if (locationId == _locationId) return;
    _locationId = locationId;
    await refresh();
  }

  Future<void> selectDocumentType(String documentType) async {
    if (documentType == _documentType) return;
    _documentType = documentType;
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> assign(String layoutId) async {
    final previous = state.asData?.value;
    state = const AsyncLoading();
    try {
      final catalog = await _authorized(
        (token) => ref
            .read(apiProvider)
            .assignInvoiceLayout(
              accessToken: token,
              locationId: _locationId,
              layoutId: layoutId,
              documentType: _documentType,
            ),
      );
      _salePdfCache.clear();
      state = AsyncData(catalog);
    } catch (error, stackTrace) {
      state = previous == null
          ? AsyncError(error, stackTrace)
          : AsyncData(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<ErpInvoicePdf> preview(String layoutId, {String? transactionId}) =>
      _authorized(
        (token) => ref
            .read(apiProvider)
            .previewInvoiceLayout(
              accessToken: token,
              layoutId: layoutId,
              locationId: _locationId,
              documentType: _documentType,
              transactionId: transactionId,
            ),
      );

  Future<bool> printSale({
    required Sale sale,
    required String businessName,
    required PrinterSettings settings,
    Printer? printer,
    bool arabic = false,
  }) async {
    if (sale.serverId != null) {
      final saleId = sale.serverId!;
      final cachedFile = _salePdfCache[saleId];
      late final ErpInvoicePdf file;
      if (cachedFile == null) {
        file = await _authorized<ErpInvoicePdf>(
          (token) =>
              ref.read(apiProvider).finalizedSaleInvoicePdf(token, saleId),
        );
        _salePdfCache[saleId] = file;
      } else {
        file = cachedFile;
      }
      return PrinterDocumentService.printPdfBytes(
        file.bytes,
        name: file.fileName,
        printer: printer,
        previewBeforePrinting: false,
      );
    }
    return PrinterDocumentService.printReceiptTo(
      sale,
      businessName,
      settings.copyWith(previewBeforePrinting: false),
      printer: printer,
      arabic: arabic,
    );
  }

  Future<ErpInvoiceLayoutCatalog> _load() => _authorized(
    (token) => ref
        .read(apiProvider)
        .invoiceLayouts(
          accessToken: token,
          locationId: _locationId,
          documentType: _documentType,
        ),
  );

  Future<T> _authorized<T>(Future<T> Function(String token) request) async {
    final auth = ref.read(authControllerProvider);
    final token =
        auth.asData?.value ?? await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty) {
      throw const ApiException('Your session has expired.');
    }
    try {
      return await request(token);
    } on ApiException catch (error) {
      if (!_isExpired(error)) rethrow;
      final refreshed = await ref
          .read(authControllerProvider.notifier)
          .refreshAccessToken();
      return request(refreshed);
    }
  }

  bool _isExpired(ApiException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == 401 ||
        message.contains('access token has expired') ||
        message.contains('unauthenticated');
  }
}
