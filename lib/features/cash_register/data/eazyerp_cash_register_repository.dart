import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../domain/cash_register_entities.dart';
import '../domain/cash_register_repository.dart';

final cashRegisterRepositoryProvider = Provider<CashRegisterRepository>(
  (ref) => EazyErpCashRegisterRepository(ref.watch(apiProvider)),
);

class EazyErpCashRegisterRepository implements CashRegisterRepository {
  const EazyErpCashRegisterRepository(this._api);
  final Api _api;

  @override
  Future<CashRegister?> current(String token) =>
      _api.currentCashRegister(token);
  @override
  Future<CashRegister> open(
    String token,
    String locationId,
    double initialCash,
  ) => _api.openCashRegister(token, locationId, initialCash);
  @override
  Future<void> cashIn(String token, String id, double amount) =>
      _api.cashRegisterCashIn(token, id, amount);
  @override
  Future<void> cashOut(String token, String id, double amount) =>
      _api.cashRegisterCashOut(token, id, amount);
  @override
  Future<CashRegisterSummary> summary(String token, String id) =>
      _api.cashRegisterSummary(token, id);
  @override
  Future<CashRegisterSummary> close(
    String token,
    String id,
    Map<String, dynamic> payload,
  ) => _api.closeCashRegister(token, id, payload);
}
