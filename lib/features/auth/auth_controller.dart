import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../apis/api.dart';

final apiProvider = Provider<Api>((ref) => Api());
final authControllerProvider = AsyncNotifierProvider<AuthController, String?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<String?> {
  static const _tokenKey = 'oauth_access_token';

  @override
  Future<String?> build() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<LoginResult> login(
    String username,
    String password, {
    required bool remember,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(apiProvider).login(username, password);
    if (result.isSuccess) {
      final preferences = await SharedPreferences.getInstance();
      if (remember) {
        await preferences.setString(_tokenKey, result.accessToken!);
      } else {
        await preferences.remove(_tokenKey);
      }
      state = AsyncData(result.accessToken);
    } else {
      state = const AsyncData(null);
    }
    return result;
  }

  Future<void> logout() async {
    await (await SharedPreferences.getInstance()).remove(_tokenKey);
    state = const AsyncData(null);
  }
}
