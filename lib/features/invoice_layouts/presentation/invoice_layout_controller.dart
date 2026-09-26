import 'dart:typed_data';

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
import '../data/offline_invoice_layout_repository.dart';

final offlineInvoiceLayoutRepositoryProvider = Provider(
  (_) => OfflineInvoiceLayoutRepository(),
);

final invoiceLayoutControllerProvider =
    AsyncNotifierProvider<InvoiceLayoutController, ErpInvoiceLayoutCatalog?>(
      InvoiceLayoutController.new,
    );

final invoiceDesignsProvider = FutureProvider<List<ErpInvoiceDesign>>(
  (ref) => ref.read(invoiceLayoutControllerProvider.notifier).designs(),
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

  Future<List<ErpInvoiceDesign>> designs() => _authorized(
    (token) => ref.read(apiProvider).invoiceTemplateDesigns(token),
  );

  Future<ErpInvoicePdf> previewDesign(String design) => _authorized(
    (token) => ref.read(apiProvider).previewInvoiceDesign(token, design),
  );

  Future<void> assign(String? layoutId, {String? design}) async {
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
              design: design,
              documentType: _documentType,
            ),
      );
      _salePdfCache.clear();
      state = AsyncData(catalog);
      await _cacheOfflineLayouts(catalog);
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
    Iterable<Printer>? printers,
    bool arabic = false,
  }) async {
    final file = await salePdf(
      sale: sale,
      businessName: businessName,
      settings: settings,
      arabic: arabic,
    );
    final profile = sale.customer.isBusiness
        ? 'billing-business'
        : 'billing-retail';
    final format = PrinterDocumentService.formatFor(
      settings.paperSizes[profile] ?? '80mm',
    );
    return PrinterDocumentService.printPdfBytes(
      file.bytes,
      name: file.fileName,
      printer: printer,
      printers: printers,
      format: format,
      fitThermalPrintableWidth: true,
    );
  }

  Future<bool> previewSale({
    required Sale sale,
    required String businessName,
    required PrinterSettings settings,
    bool arabic = false,
  }) async {
    if (sale.serverId != null) {
      final saleId = sale.serverId!;
      final cachedFile = _salePdfCache[saleId];
      final file =
          cachedFile ??
          await _authorized<ErpInvoicePdf>(
            (token) =>
                ref.read(apiProvider).finalizedSaleInvoicePdf(token, saleId),
          );
      _salePdfCache[saleId] = file;
      return PrinterDocumentService.previewPdfBytes(
        file.bytes,
        name: file.fileName,
      );
    }
    return PrinterDocumentService.previewReceipt(
      sale,
      businessName,
      settings,
      arabic: arabic,
    );
  }

  Future<ErpInvoicePdf> salePdf({
    required Sale sale,
    required String businessName,
    required PrinterSettings settings,
    bool arabic = false,
  }) async {
    if (sale.serverId != null) {
      final saleId = sale.serverId!;
      final cachedFile = _salePdfCache[saleId];
      if (cachedFile != null) return cachedFile;
      final file = await _authorized<ErpInvoicePdf>(
        (token) => ref.read(apiProvider).finalizedSaleInvoicePdf(token, saleId),
      );
      _salePdfCache[saleId] = file;
      return file;
    }
    final profile = sale.customer.isBusiness
        ? 'billing-business'
        : 'billing-retail';
    final format = PrinterDocumentService.formatFor(
      settings.paperSizes[profile] ?? '80mm',
    );
    final offlineLayout = await ref
        .read(offlineInvoiceLayoutRepositoryProvider)
        .load(_locationId, _documentType);
    return ErpInvoicePdf(
      bytes: offlineLayout == null
          ? await PrinterDocumentService.receipt(
              sale,
              businessName,
              settings,
              format,
              arabic: arabic,
            )
          : await PrinterDocumentService.offlineLayoutReceipt(
              sale,
              offlineLayout,
              arabic: arabic,
            ),
      fileName: 'Invoice ${sale.invoiceNo}.pdf',
    );
  }

  Future<ErpInvoiceLayoutCatalog> _load() async {
    try {
      final catalog = await _authorized(
        (token) => ref
            .read(apiProvider)
            .invoiceLayouts(
              accessToken: token,
              locationId: _locationId,
              documentType: _documentType,
            ),
      );
      await _cacheOfflineLayouts(catalog);
      return catalog;
    } catch (_) {
      final cached = await ref
          .read(offlineInvoiceLayoutRepositoryProvider)
          .loadCatalog(_locationId, _documentType);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> _cacheOfflineLayouts(ErpInvoiceLayoutCatalog catalog) async {
    final repository = ref.read(offlineInvoiceLayoutRepositoryProvider);
    await repository.saveCatalog(catalog);
    final supported = catalog.layouts
        .where((layout) => layout.offlineSupported)
        .toList(growable: false);
    if (supported.isEmpty) return;
    try {
      final bundles = await _authorized((token) async {
        final api = ref.read(apiProvider);
        return Future.wait(
          supported.map((layout) async {
            try {
              final manifest = await api.offlineInvoiceLayoutConfig(
                accessToken: token,
                layoutId: layout.id,
                locationId: catalog.locationId,
                documentType: catalog.documentType,
              );
              final cached = await repository.loadLayout(
                catalog.locationId,
                catalog.documentType,
                layout.id,
              );
              final revision =
                  (manifest['layout'] as Map?)?['revision']?.toString() ?? '';
              if (cached != null &&
                  revision.isNotEmpty &&
                  cached.revision == revision) {
                return MapEntry(layout, cached);
              }
              final descriptors = <Map<String, dynamic>>[
                ..._descriptorList(manifest['assets']),
                ..._descriptorList((manifest['typography'] as Map?)?['assets']),
              ];
              final entries = await Future.wait(
                descriptors.map((descriptor) async {
                  final id = descriptor['id']?.toString() ?? '';
                  final url = descriptor['url']?.toString() ?? '';
                  if (id.isEmpty || url.isEmpty) return null;
                  try {
                    return MapEntry(
                      id,
                      await api.authenticatedAsset(token, url),
                    );
                  } catch (_) {
                    return null;
                  }
                }),
              );
              final assets = <String, Uint8List>{
                for (final entry in entries)
                  if (entry != null) entry.key: entry.value,
              };
              return MapEntry(
                layout,
                OfflineInvoiceLayoutBundle(manifest: manifest, assets: assets),
              );
            } catch (_) {
              return null;
            }
          }),
        );
      });
      for (final entry
          in bundles
              .whereType<
                MapEntry<ErpInvoiceLayout, OfflineInvoiceLayoutBundle>
              >()) {
        await repository.save(
          entry.value,
          layoutId: entry.key.id,
          selected:
              entry.key.id == catalog.currentLayoutId || entry.key.isSelected,
        );
      }
    } catch (_) {
      // Refreshing offline caches is best effort and must never block normal
      // online layout or printing flows.
    }
  }

  List<Map<String, dynamic>> _descriptorList(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
      : const [];

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
