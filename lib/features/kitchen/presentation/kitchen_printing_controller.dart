import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/auth_controller.dart';
import '../../printers/application/printer_controller.dart';
import '../../printers/application/printer_document_service.dart';
import '../../store/app_store.dart';
import '../../../shared/models/entities.dart';
import '../domain/kitchen_entities.dart';

class KitchenPrintSummary {
  const KitchenPrintSummary({
    required this.jobCount,
    required this.printedCount,
    required this.unassignedCount,
  });

  final int jobCount;
  final int printedCount;
  final int unassignedCount;
}

class KitchenPrintingState {
  const KitchenPrintingState({
    this.locationId = '',
    this.settings,
    this.options,
    this.routes = const [],
    this.jobs = const [],
    this.jobsAccessDenied = false,
    this.canManageSettings = false,
    this.unassignedItems = const [],
    this.busy = false,
    this.message,
  });

  final String locationId;
  final RestaurantSettings? settings;
  final KitchenPrinterOptions? options;
  final List<KitchenPrinterRoute> routes;
  final List<KitchenPrintJob> jobs;
  final bool jobsAccessDenied;
  final bool canManageSettings;
  final List<KitchenJobItem> unassignedItems;
  final bool busy;
  final String? message;

  bool get hasActiveRoutes => routes.any((route) => route.isActive);

  KitchenPrintingState copyWith({
    String? locationId,
    RestaurantSettings? settings,
    KitchenPrinterOptions? options,
    List<KitchenPrinterRoute>? routes,
    List<KitchenPrintJob>? jobs,
    bool? jobsAccessDenied,
    bool? canManageSettings,
    List<KitchenJobItem>? unassignedItems,
    bool? busy,
    String? message,
    bool clearMessage = false,
  }) => KitchenPrintingState(
    locationId: locationId ?? this.locationId,
    settings: settings ?? this.settings,
    options: options ?? this.options,
    routes: routes ?? this.routes,
    jobs: jobs ?? this.jobs,
    jobsAccessDenied: jobsAccessDenied ?? this.jobsAccessDenied,
    canManageSettings: canManageSettings ?? this.canManageSettings,
    unassignedItems: unassignedItems ?? this.unassignedItems,
    busy: busy ?? this.busy,
    message: clearMessage ? null : message ?? this.message,
  );
}

final kitchenPrintingControllerProvider =
    AsyncNotifierProvider<KitchenPrintingController, KitchenPrintingState>(
      KitchenPrintingController.new,
      retry: (_, _) => null,
    );

class KitchenPrintingController extends AsyncNotifier<KitchenPrintingState> {
  @override
  Future<KitchenPrintingState> build() async {
    final locations = ref.watch(
      appStoreProvider.select((state) => state.locations),
    );
    if (locations.isEmpty) return const KitchenPrintingState();
    return _load(locations.first.id);
  }

  Future<void> selectLocation(String locationId) async {
    if (locationId == state.asData?.value.locationId) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(locationId));
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    final locations = ref.read(appStoreProvider).locations;
    final locationId = current?.locationId.isNotEmpty == true
        ? current!.locationId
        : locations.firstOrNull?.id;
    if (locationId == null || locationId.isEmpty) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(locationId));
  }

  Future<void> updateSettings(Map<String, dynamic> changes) async {
    final current = _current;
    _set(current.copyWith(busy: true, clearMessage: true));
    try {
      final settings = await _authorized(
        (token) => ref
            .read(apiProvider)
            .updateRestaurantSettings(
              accessToken: token,
              locationId: current.locationId,
              changes: changes,
            ),
      );
      _set(current.copyWith(settings: settings, busy: false));
    } catch (error) {
      _set(current.copyWith(busy: false, message: error.toString()));
      rethrow;
    }
  }

  Future<void> saveRoute({
    String? routeId,
    required String categoryId,
    String? subCategoryId,
    required String printerId,
    String? templateKey,
    int priority = 0,
    bool isActive = true,
  }) async {
    final current = _current;
    _set(current.copyWith(busy: true, clearMessage: true));
    try {
      await _authorized(
        (token) => ref
            .read(apiProvider)
            .saveKitchenPrinterRoute(
              accessToken: token,
              locationId: current.locationId,
              routeId: routeId,
              values: {
                'category_id': int.tryParse(categoryId) ?? categoryId,
                'sub_category_id': subCategoryId == null
                    ? null
                    : int.tryParse(subCategoryId) ?? subCategoryId,
                'printer_id': int.tryParse(printerId) ?? printerId,
                'template_key': templateKey,
                'priority': priority,
                'is_active': isActive,
              },
            ),
      );
      final routes = await _routes(current.locationId);
      _set(current.copyWith(routes: routes, busy: false));
    } catch (error) {
      _set(current.copyWith(busy: false, message: error.toString()));
      rethrow;
    }
  }

  Future<void> deleteRoute(String routeId) async {
    final current = _current;
    _set(current.copyWith(busy: true, clearMessage: true));
    try {
      await _authorized(
        (token) => ref
            .read(apiProvider)
            .deleteKitchenPrinterRoute(
              accessToken: token,
              locationId: current.locationId,
              routeId: routeId,
            ),
      );
      _set(
        current.copyWith(
          routes: current.routes.where((route) => route.id != routeId).toList(),
          busy: false,
        ),
      );
    } catch (error) {
      _set(current.copyWith(busy: false, message: error.toString()));
      rethrow;
    }
  }

  Future<String> previewTemplate(String template) => _authorized(
    (token) => ref
        .read(apiProvider)
        .kitchenTemplatePreview(
          accessToken: token,
          locationId: _current.locationId,
          template: template,
        ),
  );

  Future<void> refreshJobs({String? status}) async {
    final current = _current;
    try {
      final result = await _authorized(
        (token) => ref
            .read(apiProvider)
            .kitchenPrintJobs(
              accessToken: token,
              locationId: current.locationId,
              status: status,
            ),
      );
      _set(
        current.copyWith(
          jobs: result.jobs,
          jobsAccessDenied: false,
          clearMessage: true,
        ),
      );
    } on ApiException catch (error) {
      if (error.statusCode != 403) rethrow;
      _set(current.copyWith(jobs: const [], jobsAccessDenied: true));
    }
  }

  Future<String> createKitchenOrder({
    required String locationId,
    required Customer customer,
    required List<CartLine> lines,
    required String clientTransactionId,
    String? saleNote,
  }) async {
    final response = await _authorized(
      (token) => ref
          .read(apiProvider)
          .createSale(
            accessToken: token,
            locationId: locationId,
            customer: customer,
            lines: lines,
            total: lines.fold<int>(0, (total, line) => total + line.subtotal),
            grossDiscount: 0,
            clientTransactionId: clientTransactionId,
            isKitchenOrder: true,
            saleNote: saleNote,
          ),
    );
    final transactionId =
        (response['transaction_id'] ??
                response['server_transaction_id'] ??
                response['id'])
            ?.toString() ??
        '';
    if (transactionId.isEmpty) {
      throw const ApiException(
        'The kitchen sale response did not include a transaction ID. Retry with the same order.',
      );
    }
    return transactionId;
  }

  Future<KitchenPrintSummary> processTransaction(
    String transactionId, {
    String? locationId,
  }) async {
    if (transactionId.isEmpty) {
      throw const ApiException('Kitchen transaction ID is missing.');
    }
    final current = _current;
    late final KitchenJobsResult result;
    try {
      result = await _authorized(
        (token) => ref
            .read(apiProvider)
            .generateKitchenPrintJobs(
              accessToken: token,
              transactionId: transactionId,
              locationId: locationId ?? current.locationId,
            ),
      );
    } catch (error) {
      _set(
        current.copyWith(
          message:
              'Kitchen order saved, but jobs could not be generated: $error',
        ),
      );
      rethrow;
    }
    _set(
      current.copyWith(
        jobs: _mergeJobs(current.jobs, result.jobs),
        unassignedItems: result.unassignedItems,
        message: result.unassignedItems.isEmpty
            ? null
            : '${result.unassignedItems.length} kitchen item(s) have no printer route.',
        clearMessage: result.unassignedItems.isEmpty,
      ),
    );
    final failures = <String>[];
    var printedCount = result.jobs
        .where((job) => job.status == 'printed')
        .length;
    for (final job in result.jobs.where(
      (job) => job.status == 'pending' || job.status == 'failed',
    )) {
      try {
        await printJob(job);
        printedCount++;
      } catch (error) {
        failures.add('${job.printer.name}: $error');
      }
    }
    if (failures.isNotEmpty) {
      _set(
        _current.copyWith(
          message:
              'Kitchen order saved, but ${failures.length} print job(s) failed. Retry printing or open Printer settings.',
        ),
      );
      throw StateError('Printing failed for ${failures.join(', ')}');
    }
    if (result.jobs.isEmpty || result.unassignedItems.isNotEmpty) {
      final message = result.jobs.isEmpty
          ? 'Kitchen order saved, but no printer jobs were generated.'
          : 'Kitchen order saved, but ${result.unassignedItems.length} item(s) have no printer route.';
      _set(_current.copyWith(message: message));
      throw StateError(message);
    }
    if (printedCount != result.jobs.length) {
      const message =
          'Some kitchen jobs are still marked as printing. Check their printer status before retrying to avoid duplicate tickets.';
      _set(_current.copyWith(message: message));
      throw StateError(message);
    }
    return KitchenPrintSummary(
      jobCount: result.jobs.length,
      printedCount: printedCount,
      unassignedCount: result.unassignedItems.length,
    );
  }

  Future<void> printJob(KitchenPrintJob job) async {
    final localPrinter = ref
        .read(printerControllerProvider)
        .kitchenPrinter(job.printer.id);
    if (localPrinter == null) {
      final message =
          'Pair ERP printer "${job.printer.name}" with a local printer first.';
      await _reportFailure(job, _attemptId(job), message);
      throw StateError(message);
    }
    final attemptId = _attemptId(job);
    try {
      await _status(job.id, 'printing', attemptId);
      final bytes = await PrinterDocumentService.kitchenTicket(job);
      await PrinterDocumentService.printPdfBytes(
        bytes,
        name: 'Kitchen order ${job.transactionId} - ${job.printer.name}',
        printer: localPrinter,
        format: PrinterDocumentService.kitchenFormat(job.template),
      );
      await _status(job.id, 'printed', attemptId);
      await refreshJobs();
    } catch (error) {
      await _reportFailure(job, attemptId, error.toString());
      rethrow;
    }
  }

  Future<KitchenPrintingState> _load(String locationId) async {
    final values = await Future.wait([
      _authorized(
        (token) => ref
            .read(apiProvider)
            .restaurantSettings(accessToken: token, locationId: locationId),
      ),
      _authorized(
        (token) => ref
            .read(apiProvider)
            .kitchenPrinterOptions(accessToken: token, locationId: locationId),
      ),
      _routes(locationId),
    ]);
    var jobs = const <KitchenPrintJob>[];
    var jobsAccessDenied = false;
    var canManageSettings = false;
    try {
      final access = await _authorized(
        (token) => ref.read(apiProvider).connectorAccess(token),
      );
      canManageSettings = access.allows('business_settings.access');
    } on ApiException {
      // Reading settings remains useful when the permission feed is unavailable.
    }
    try {
      final result = await _authorized(
        (token) => ref
            .read(apiProvider)
            .kitchenPrintJobs(accessToken: token, locationId: locationId),
      );
      jobs = result.jobs;
    } on ApiException catch (error) {
      if (error.statusCode != 403) rethrow;
      jobsAccessDenied = true;
    }
    return KitchenPrintingState(
      locationId: locationId,
      settings: values[0] as RestaurantSettings,
      options: values[1] as KitchenPrinterOptions,
      routes: values[2] as List<KitchenPrinterRoute>,
      jobs: jobs,
      jobsAccessDenied: jobsAccessDenied,
      canManageSettings: canManageSettings,
    );
  }

  Future<List<KitchenPrinterRoute>> _routes(String locationId) => _authorized(
    (token) => ref
        .read(apiProvider)
        .kitchenPrinterRoutes(accessToken: token, locationId: locationId),
  );

  Future<void> _status(
    String jobId,
    String status,
    String attemptId, {
    String? error,
  }) => _authorized(
    (token) => ref
        .read(apiProvider)
        .updateKitchenPrintJobStatus(
          accessToken: token,
          jobId: jobId,
          status: status,
          clientPrintId: attemptId,
          error: error,
        ),
  );

  Future<void> _reportFailure(
    KitchenPrintJob job,
    String attemptId,
    String error,
  ) async {
    try {
      await _status(job.id, 'failed', attemptId, error: error);
      await refreshJobs();
    } catch (_) {
      // The original printer error remains the useful failure to surface.
    }
  }

  String _attemptId(KitchenPrintJob job) =>
      'eazy-pos-${job.id}-${DateTime.now().microsecondsSinceEpoch}';

  List<KitchenPrintJob> _mergeJobs(
    List<KitchenPrintJob> existing,
    List<KitchenPrintJob> incoming,
  ) {
    final values = {for (final job in existing) job.id: job};
    for (final job in incoming) values[job.id] = job;
    return values.values.toList(growable: false);
  }

  KitchenPrintingState get _current =>
      state.asData?.value ?? const KitchenPrintingState();

  void _set(KitchenPrintingState value) => state = AsyncData(value);

  Future<T> _authorized<T>(Future<T> Function(String token) request) async {
    final auth = ref.read(authControllerProvider);
    final token =
        auth.asData?.value ?? await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty || token == 'offline-local-session') {
      throw const ApiException('Kitchen settings require an online session.');
    }
    try {
      return await request(token);
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      final refreshed = await ref
          .read(authControllerProvider.notifier)
          .refreshAccessToken();
      return request(refreshed);
    }
  }
}
