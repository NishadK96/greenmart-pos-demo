import 'cash_register_entities.dart';

abstract interface class CashRegisterRepository {
  Future<CashRegister?> current(String token);
  Future<CashRegister> open(
    String token,
    String locationId,
    double initialCash,
  );
  Future<void> cashIn(String token, String id, double amount);
  Future<void> cashOut(String token, String id, double amount);
  Future<CashRegisterSummary> summary(String token, String id);
  Future<CashRegisterSummary> close(
    String token,
    String id,
    Map<String, dynamic> payload,
  );
}
