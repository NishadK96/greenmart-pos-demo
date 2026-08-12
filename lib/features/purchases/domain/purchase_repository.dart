import 'purchase_entities.dart';
import '../../../shared/models/entities.dart';

abstract interface class PurchaseRepository {
  Future<List<Supplier>> suppliers(String accessToken);
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
