import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../apis/api.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/auth_controller.dart';
import '../domain/voucher_entities.dart';

class VoucherQuery {
  const VoucherQuery({this.type, this.page = 1, this.party = ''});

  final VoucherType? type;
  final int page;
  final String party;

  @override
  bool operator ==(Object other) =>
      other is VoucherQuery &&
      other.type == type &&
      other.page == page &&
      other.party == party;

  @override
  int get hashCode => Object.hash(type, page, party);
}

Future<String> _onlineToken(Ref ref) async {
  final token = await ref.watch(authControllerProvider.future);
  if (token == null || token.isEmpty) {
    throw const ApiException('Sign in to access accounting vouchers.');
  }
  if (token == 'offline-local-session') {
    throw const ApiException(
      'Accounting vouchers require an online connection.',
    );
  }
  return token;
}

final voucherListProvider = FutureProvider.autoDispose
    .family<VoucherPage, VoucherQuery>((ref, query) async {
      final token = await _onlineToken(ref);
      return ref
          .read(apiProvider)
          .vouchers(
            token,
            type: query.type,
            page: query.page,
            party: query.party,
          );
    });

final voucherActionsProvider = AsyncNotifierProvider<VoucherActions, void>(
  VoucherActions.new,
);

class VoucherActions extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> _token() async {
    final token = await ref.read(authControllerProvider.future);
    if (token == null || token.isEmpty) {
      throw const ApiException('Sign in to access accounting vouchers.');
    }
    if (token == 'offline-local-session') {
      throw const ApiException(
        'Accounting vouchers require an online connection.',
      );
    }
    return token;
  }

  Future<VoucherOptions> options(VoucherType type, {int? voucherId}) async =>
      ref
          .read(apiProvider)
          .voucherOptions(await _token(), type, voucherId: voucherId);

  Future<List<VoucherParty>> parties(
    VoucherType type, {
    String query = '',
    int? voucherId,
  }) async => ref
      .read(apiProvider)
      .voucherParties(await _token(), type, query: query, voucherId: voucherId);

  Future<VoucherDues> dues({
    required VoucherType type,
    required int locationId,
    required int contactId,
    String? amount,
    int? voucherId,
  }) async => ref
      .read(apiProvider)
      .voucherDues(
        await _token(),
        type: type,
        locationId: locationId,
        contactId: contactId,
        amount: amount,
        voucherId: voucherId,
      );

  Future<Voucher> detail(int id) async =>
      ref.read(apiProvider).voucher(await _token(), id);

  Future<Voucher> save(VoucherDraft draft, {int? id}) async {
    state = const AsyncLoading();
    try {
      final saved = await ref
          .read(apiProvider)
          .saveVoucher(await _token(), draft, id: id);
      state = const AsyncData(null);
      ref.invalidate(voucherListProvider);
      return saved;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> remove(Voucher voucher) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(apiProvider)
          .deleteVoucher(await _token(), voucher.id, voucher.revision);
      state = const AsyncData(null);
      ref.invalidate(voucherListProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<VoucherConfiguration> configuration() async =>
      ref.read(apiProvider).voucherConfiguration(await _token());

  Future<VoucherConfiguration> updateConfiguration(
    List<Map<String, Object?>> accounts,
  ) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(apiProvider)
          .updateVoucherConfiguration(await _token(), accounts);
      state = const AsyncData(null);
      ref.invalidate(voucherListProvider);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
