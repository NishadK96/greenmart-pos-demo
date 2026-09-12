import 'purchase_entities.dart';
import '../../../shared/models/entities.dart';

abstract interface class PurchaseRepository {
  Future<List<Supplier>> suppliers(String accessToken);
  Future<Supplier> createSupplier(
    String accessToken, {
    required String businessName,
    required String contactName,
    required String mobile,
    String email,
    String taxNumber,
    String addressLine1,
    String addressLine2,
    String city,
    String state,
    String country,
    String zipCode,
    String landmark,
    String streetName,
    String buildingNumber,
    String additionalNumber,
    int? payTermNumber,
    String payTermType,
  });
  Future<List<LookupOption>> paymentAccounts(String accessToken);
  Future<List<PurchaseDocument>> list(
    String accessToken,
    PurchaseDocumentType type,
  );
  Future<PurchaseDocument> get(
    String accessToken,
    PurchaseDocumentType type,
    String id,
  );
  Future<PurchaseDocument> create(String accessToken, PurchaseDraft draft);
  Future<PurchaseDocument> update(
    String accessToken,
    String id,
    PurchaseDraft draft,
  );
  Future<void> delete(String accessToken, PurchaseDocumentType type, String id);
  Future<PurchaseDocument> updateOrderStatus(
    String accessToken,
    String id,
    String status,
  );
}
