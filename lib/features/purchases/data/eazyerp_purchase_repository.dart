import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../../shared/models/entities.dart';
import '../domain/purchase_entities.dart';
import '../domain/purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => EazyErpPurchaseRepository(ref.watch(apiProvider)),
);

class EazyErpPurchaseRepository implements PurchaseRepository {
  const EazyErpPurchaseRepository(this._api);
  final Api _api;

  @override
  Future<List<Supplier>> suppliers(String accessToken) =>
      _api.suppliers(accessToken);

  @override
  Future<Supplier> createSupplier(
    String accessToken, {
    required String businessName,
    required String contactName,
    required String mobile,
    String email = '',
    String address = '',
    int? payTermNumber,
    String payTermType = 'days',
  }) => _api.createSupplier(
    accessToken: accessToken,
    businessName: businessName,
    contactName: contactName,
    mobile: mobile,
    email: email,
    address: address,
    payTermNumber: payTermNumber,
    payTermType: payTermType,
  );

  @override
  Future<List<LookupOption>> paymentAccounts(String accessToken) =>
      _api.paymentAccounts(accessToken);

  @override
  Future<List<PurchaseDocument>> list(
    String accessToken,
    PurchaseDocumentType type,
  ) => _api.purchaseDocuments(accessToken, type);

  @override
  Future<PurchaseDocument> get(
    String accessToken,
    PurchaseDocumentType type,
    String id,
  ) => _api.purchaseDocument(accessToken, type, id);

  @override
  Future<PurchaseDocument> create(String accessToken, PurchaseDraft draft) =>
      _api.savePurchaseDocument(accessToken: accessToken, draft: draft);

  @override
  Future<PurchaseDocument> update(
    String accessToken,
    String id,
    PurchaseDraft draft,
  ) =>
      _api.savePurchaseDocument(accessToken: accessToken, draft: draft, id: id);

  @override
  Future<void> delete(
    String accessToken,
    PurchaseDocumentType type,
    String id,
  ) => _api.deletePurchaseDocument(accessToken, type, id);

  @override
  Future<PurchaseDocument> updateOrderStatus(
    String accessToken,
    String id,
    String status,
  ) => _api.updatePurchaseOrderStatus(accessToken, id, status);
}
