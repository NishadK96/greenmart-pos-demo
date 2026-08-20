import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_controller.dart';
import '../data/eazyerp_cash_register_repository.dart';
import '../domain/cash_register_entities.dart';

final cashRegisterControllerProvider =
    AsyncNotifierProvider<CashRegisterController, CashRegister?>(
      CashRegisterController.new,
    );

class CashRegisterController extends AsyncNotifier<CashRegister?> {
  @override
  Future<CashRegister?> build() async =>
      ref.read(cashRegisterRepositoryProvider).current(await _token());

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> open(String locationId, double initialCash) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async => ref
          .read(cashRegisterRepositoryProvider)
          .open(await _token(), locationId, initialCash),
    );
    if (state.hasError) throw state.error!;
  }

  Future<void> cashIn(double amount) => _movement(amount, true);
  Future<void> cashOut(double amount) => _movement(amount, false);

  Future<void> _movement(double amount, bool cashIn) async {
    final register = state.asData?.value;
    if (register == null) throw StateError('No open cash register.');
    final repository = ref.read(cashRegisterRepositoryProvider);
    final token = await _token();
    if (cashIn) {
      await repository.cashIn(token, register.id, amount);
    } else {
      await repository.cashOut(token, register.id, amount);
    }
    await refresh();
  }

  Future<CashRegisterSummary> summary() async {
    final register = state.asData?.value;
    if (register == null) throw StateError('No open cash register.');
    return ref
        .read(cashRegisterRepositoryProvider)
        .summary(await _token(), register.id);
  }

  Future<CashRegisterSummary> close(Map<String, dynamic> payload) async {
    final register = state.asData?.value;
    if (register == null) throw StateError('No open cash register.');
    final result = await ref
        .read(cashRegisterRepositoryProvider)
        .close(await _token(), register.id, payload);
    state = const AsyncData(null);
    return result;
  }

  Future<String> _token() async {
    final token = await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty)
      throw StateError('Your session has expired.');
    return token;
  }
}
