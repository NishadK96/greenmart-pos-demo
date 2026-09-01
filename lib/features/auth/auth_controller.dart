import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apis/api.dart';
import '../../core/network/api_provider.dart';
import 'device_session_storage.dart';
import 'offline_credential_storage.dart';
import '../offline_pos/data/offline_pos_storage.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, String?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<String?> {
  final DeviceSessionStorage _sessions = DeviceSessionStorage();
  final OfflineCredentialStorage _offlineCredentials =
      OfflineCredentialStorage();
  String? _webCsrfToken;
  Future<void>? _webBootstrapInFlight;
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
        session = await _webLogin(username, password);
        _activeSessionId = session.sessionId;
      } else {
        session = await ref
            .read(apiProvider)
            .sessionLogin(username, password, await _sessions.deviceHeaders());
        await _sessions.saveSession(session.sessionId, session.refreshToken!);
      }
      if (remember) {
        await _offlineCredentials.save(username, password);
      } else {
        await _offlineCredentials.clear();
      }
      state = AsyncData(session.accessToken);
      return LoginResult.success(session.accessToken);
    } on ApiException catch (error) {
      if (error.statusCode == null || error.statusCode! >= 500) {
        final offline = await _offlineLogin(username, password);
        if (offline != null) return offline;
      }
      state = const AsyncData(null);
      return LoginResult.failure(
        error.statusCode == 400 || error.statusCode == 401
            ? LoginFailure.invalidCredentials
            : LoginFailure.server,
        message: error.message,
      );
    } catch (_) {
      final offline = await _offlineLogin(username, password);
      if (offline != null) return offline;
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

  Future<String> refreshAccessToken() async {
    final SessionLoginResult result;
    if (kIsWeb) {
      await _bootstrapWeb();
      var sessionId = _activeSessionId;
      if (sessionId == null) {
        final accounts = await ref.read(apiProvider).webSavedSessions();
        final resumable = accounts.where((account) => !account.expired);
        if (resumable.isEmpty) {
          throw const ApiException('Your saved session has expired.');
        }
        sessionId = resumable.first.sessionId;
      }
      result = await ref
          .read(apiProvider)
          .activateWebSession(sessionId, _webCsrfToken!);
      _activeSessionId = result.sessionId;
    } else {
      final sessionId = await _sessions.activeSessionId();
      final refresh = sessionId == null
          ? null
          : await _sessions.refreshToken(sessionId);
      if (sessionId == null || refresh == null) {
        throw const ApiException('Your saved session has expired.');
      }
      result = await ref
          .read(apiProvider)
          .activateSession(sessionId, refresh, await _sessions.deviceHeaders());
      await _sessions.saveSession(result.sessionId, result.refreshToken!);
    }
    state = AsyncData(result.accessToken);
    return result.accessToken;
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
    await OfflinePosStorage().disableOfflineResume();
    await _offlineCredentials.clear();
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

  Future<LoginResult?> _offlineLogin(String username, String password) async {
    if (!await OfflinePosStorage().canResumeOffline()) return null;
    final result = await _offlineCredentials.verify(username, password);
    switch (result) {
      case OfflineCredentialResult.success:
        const token = 'offline-local-session';
        state = const AsyncData(token);
        return LoginResult.success(token);
      case OfflineCredentialResult.mismatch:
        state = const AsyncData(null);
        return const LoginResult.failure(LoginFailure.invalidCredentials);
      case OfflineCredentialResult.expired:
        state = const AsyncData(null);
        return const LoginResult.failure(
          LoginFailure.server,
          message:
              'Offline access has expired. Connect to the server to sign in again.',
        );
      case OfflineCredentialResult.unavailable:
        return null;
    }
  }

  Future<SessionLoginResult> _webLogin(String username, String password) async {
    await _bootstrapWeb();
    try {
      return await ref
          .read(apiProvider)
          .webSessionLogin(username, password, _webCsrfToken!);
    } on ApiException catch (error) {
      final csrfMismatch =
          error.statusCode == 419 ||
          error.message.toLowerCase().contains('csrf token mismatch');
      if (!csrfMismatch) rethrow;

      await _bootstrapWeb(force: true);
      return ref
          .read(apiProvider)
          .webSessionLogin(username, password, _webCsrfToken!);
    }
  }

  Future<void> _bootstrapWeb({bool force = false}) async {
    if (force) _webCsrfToken = null;
    if (_webCsrfToken != null) return;

    final pending = _webBootstrapInFlight;
    if (pending != null) return pending;

    final operation = _loadWebBootstrap();
    _webBootstrapInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_webBootstrapInFlight, operation)) {
        _webBootstrapInFlight = null;
      }
    }
  }

  Future<void> _loadWebBootstrap() async {
    final bootstrap = await ref.read(apiProvider).webAuthBootstrap();
    _webCsrfToken = bootstrap.csrfToken;
  }
}
