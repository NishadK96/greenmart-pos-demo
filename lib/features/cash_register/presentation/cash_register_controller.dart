import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_controller.dart';
import '../data/eazyerp_cash_register_repository.dart';
import '../domain/cash_register_entities.dart';
import '../../settings/application/pos_operating_mode_controller.dart';
import '../../../apis/api.dart';

final cashRegisterControllerProvider =
    AsyncNotifierProvider<CashRegisterController, CashRegister?>(
      CashRegisterController.new,
    );

class CashRegisterController extends AsyncNotifier<CashRegister?> {
  @override
  Future<CashRegister?> build() async {
    final token = await ref.watch(authControllerProvider.future);
    if (token == null || token.isEmpty) {
      throw StateError('Your session has expired.');
    }
    final access = await ref.watch(posRoleAccessProvider.future);
    return _currentForAccess(token, access);
  }

  Future<CashRegister?> _currentForAccess(
    String token,
    PosRoleAccess access,
  ) async {
    final register = await ref
        .read(cashRegisterRepositoryProvider)
        .current(token);
    if (register != null &&
        !access.access.allowsLocation(register.locationId)) {
      throw const ApiException(
        'The open register location is not allowed for this account.',
      );
    }
    return register;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final token = await _token();
      final access = await ref.read(posRoleAccessProvider.future);
      return _currentForAccess(token, access);
    });
  }

  Future<void> open(String locationId, double initialCash) async {
    final access = await ref.read(posRoleAccessProvider.future);
    if (!access.access.allowsLocation(locationId)) {
      throw StateError('This location is not assigned to your POS account.');
    }
    state = const AsyncLoading();
    final repository = ref.read(cashRegisterRepositoryProvider);
    final token = await _token();
    try {
      final register = await repository.open(token, locationId, initialCash);
      state = AsyncData(register);
    } catch (error, stackTrace) {
      // The current-register read and open request can race (or a previous
      // request may have succeeded while its response was interrupted). In
      // that case, recover the already-open register instead of leaving the
      // UI in an error state and asking the cashier to open it again.
      try {
        final current = await repository.current(token);
        if (current != null &&
            access.access.allowsLocation(current.locationId)) {
          state = AsyncData(current);
          return;
        }
      } catch (_) {
        // Preserve the original open error because it is the actionable one.
      }
      state = AsyncError(error, stackTrace);
      rethrow;
    }
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
