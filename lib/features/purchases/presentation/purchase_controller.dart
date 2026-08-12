import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../shared/models/entities.dart';
import '../../auth/auth_controller.dart';
import '../data/eazyerp_purchase_repository.dart';
import '../domain/purchase_entities.dart';

class PurchaseWorkspaceState {
  const PurchaseWorkspaceState({
    this.orders = const [],
    this.invoices = const [],
    this.returns = const [],
    this.suppliers = const [],
  });
  final List<PurchaseDocument> orders, invoices, returns;
  final List<Supplier> suppliers;
  List<PurchaseDocument> forType(PurchaseDocumentType type) => switch (type) {
    PurchaseDocumentType.order => orders,
    PurchaseDocumentType.invoice => invoices,
    PurchaseDocumentType.purchaseReturn => returns,
  };
}

final purchaseControllerProvider =
    AsyncNotifierProvider<PurchaseController, PurchaseWorkspaceState>(
      PurchaseController.new,
    );

class PurchaseController extends AsyncNotifier<PurchaseWorkspaceState> {
  @override
  Future<PurchaseWorkspaceState> build() async {
    final token = await _token();
    final repository = ref.read(purchaseRepositoryProvider);
    final result = await Future.wait<Object>([
      repository.list(token, PurchaseDocumentType.order),
      repository.list(token, PurchaseDocumentType.invoice),
      repository.list(token, PurchaseDocumentType.purchaseReturn),
      repository.suppliers(token),
    ]);
    return PurchaseWorkspaceState(
      orders: result[0] as List<PurchaseDocument>,
      invoices: result[1] as List<PurchaseDocument>,
      returns: result[2] as List<PurchaseDocument>,
      suppliers: result[3] as List<Supplier>,
    );
  }

  Future<PurchaseDocument> detail(PurchaseDocumentType type, String id) async =>
      ref.read(purchaseRepositoryProvider).get(await _token(), type, id);

  Future<void> save(PurchaseDraft draft, {String? id}) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(purchaseRepositoryProvider);
      if (id == null) {
        await repository.create(await _token(), draft);
      } else {
        await repository.update(await _token(), id, draft);
      }
      state = AsyncData(await build());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> remove(PurchaseDocument document) async {
    await ref
        .read(purchaseRepositoryProvider)
        .delete(await _token(), document.type, document.id);
    ref.invalidateSelf();
  }

  Future<void> changeOrderStatus(String id, String status) async {
    await ref
        .read(purchaseRepositoryProvider)
        .updateOrderStatus(await _token(), id, status);
    ref.invalidateSelf();
  }

  Future<String> _token() async {
    final token = await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty) {
      throw const ApiException('Your session has expired. Please sign in.');
    }
    return token;
  }
}
