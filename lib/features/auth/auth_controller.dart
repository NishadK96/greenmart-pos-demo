import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apis/api.dart';
import '../../core/network/api_provider.dart';
import 'device_session_storage.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, String?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<String?> {
  final DeviceSessionStorage _sessions = DeviceSessionStorage();
  String? _webCsrfToken;
  String? _activeSessionId;

  @override
  Future<String?> build() async {
    if (kIsWeb) {
      try {
        await _bootstrapWeb();
        final accounts = await ref.read(apiProvider).webSavedSessions();
        final resumable = accounts.where((account) => !account.expired);
        if (resumable.isEmpty) return null;
        final session = await ref
            .read(apiProvider)
            .activateWebSession(resumable.first.sessionId, _webCsrfToken!);
        _activeSessionId = session.sessionId;
        return session.accessToken;
      } catch (_) {
        return null;
      }
    }
    final id = await _sessions.activeSessionId();
    if (id == null) return null;
    final refresh = await _sessions.refreshToken(id);
    if (refresh == null) return null;
    try {
      final result = await ref
          .read(apiProvider)
          .activateSession(id, refresh, await _sessions.deviceHeaders());
      await _sessions.saveSession(result.sessionId, result.refreshToken!);
      return result.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<LoginResult> login(
    String username,
    String password, {
    required bool remember,
  }) async {
    state = const AsyncLoading();
    try {
      final SessionLoginResult session;
      if (kIsWeb) {
        await _bootstrapWeb();
        session = await ref
            .read(apiProvider)
            .webSessionLogin(username, password, _webCsrfToken!);
        _activeSessionId = session.sessionId;
      } else {
        session = await ref
            .read(apiProvider)
            .sessionLogin(username, password, await _sessions.deviceHeaders());
        await _sessions.saveSession(session.sessionId, session.refreshToken!);
      }
      state = AsyncData(session.accessToken);
      return LoginResult.success(session.accessToken);
    } on ApiException catch (error) {
      state = const AsyncData(null);
      return LoginResult.failure(
        error.statusCode == 400 || error.statusCode == 401
            ? LoginFailure.invalidCredentials
            : LoginFailure.server,
        message: error.message,
      );
    } catch (_) {
      state = const AsyncData(null);
      return const LoginResult.failure(LoginFailure.network);
    }
  }

  Future<List<SavedAccountSession>> savedAccounts() async {
    final String? activeId;
    final List<SavedAccountSession> accounts;
    if (kIsWeb) {
      await _bootstrapWeb();
      activeId = _activeSessionId;
      accounts = await ref.read(apiProvider).webSavedSessions();
    } else {
      activeId = await _sessions.activeSessionId();
      accounts = await ref
          .read(apiProvider)
          .savedSessions(await _sessions.deviceHeaders());
    }
    return accounts
        .map(
          (account) => account.copyWith(active: account.sessionId == activeId),
        )
        .toList(growable: false);
  }

  Future<void> switchAccount(String sessionId) async {
    final SessionLoginResult result;
    if (kIsWeb) {
      await _bootstrapWeb();
      result = await ref
          .read(apiProvider)
          .activateWebSession(sessionId, _webCsrfToken!);
      _activeSessionId = result.sessionId;
    } else {
      final refresh = await _sessions.refreshToken(sessionId);
      if (refresh == null) {
        throw const ApiException('Please sign in to this account again.');
      }
      result = await ref
          .read(apiProvider)
          .activateSession(sessionId, refresh, await _sessions.deviceHeaders());
      await _sessions.saveSession(result.sessionId, result.refreshToken!);
    }
    state = AsyncData(result.accessToken);
  }

  Future<void> removeAccount(String sessionId) async {
    if (kIsWeb) {
      await _bootstrapWeb();
      await ref.read(apiProvider).removeWebSession(sessionId, _webCsrfToken!);
      if (_activeSessionId == sessionId) _activeSessionId = null;
    } else {
      await ref
          .read(apiProvider)
          .removeSession(sessionId, await _sessions.deviceHeaders());
      await _sessions.removeSession(sessionId);
    }
  }

  Future<void> logout() async {
    if (kIsWeb) {
      final token = state.asData?.value;
      if (token != null) {
        await _bootstrapWeb();
        await ref.read(apiProvider).logoutWebSession(token, _webCsrfToken!);
      }
      _activeSessionId = null;
    } else {
      await _sessions.clearActiveSession();
    }
    state = const AsyncData(null);
  }

  Future<void> _bootstrapWeb() async {
    if (_webCsrfToken != null) return;
    final bootstrap = await ref.read(apiProvider).webAuthBootstrap();
    _webCsrfToken = bootstrap.csrfToken;
  }
}
