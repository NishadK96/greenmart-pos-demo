import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_end_points.dart';
import '../config.dart';

enum LoginFailure { invalidCredentials, configuration, network, server }

class LoginResult {
  const LoginResult.success(this.accessToken) : failure = null, message = null;

  const LoginResult.failure(this.failure, {this.message}) : accessToken = null;

  final String? accessToken;
  final LoginFailure? failure;
  final String? message;
  bool get isSuccess => accessToken != null;
}

class Api {
  Api({
    http.Client? client,
    String? loginUrl,
    String? clientId,
    String? clientSecret,
  }) : _client = client ?? http.Client(),
       _loginUrl = loginUrl ?? ApiEndPoints.loginUrl,
       _clientId = clientId ?? Config.clientId,
       _clientSecret = clientSecret ?? Config.clientSecret;
  final http.Client _client;
  final String _loginUrl, _clientId, _clientSecret;

  Future<LoginResult> login(String username, String password) async {
    if (_clientSecret.isEmpty) {
      return const LoginResult.failure(LoginFailure.configuration);
    }

    try {
      final response = await _client
          .post(
            Uri.parse(_loginUrl),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'password',
              'client_id': _clientId,
              'client_secret': _clientSecret,
              'username': username,
              'password': password,
            },
          )
          .timeout(const Duration(seconds: 20));

      final json = _decode(response.body);
      final token = json['access_token']?.toString();
      if (response.statusCode == 200 && token != null && token.isNotEmpty) {
        return LoginResult.success(token);
      }
      if (response.statusCode == 401 ||
          (response.statusCode == 400 && json['error'] == 'invalid_grant')) {
        return LoginResult.failure(
          LoginFailure.invalidCredentials,
          message: _message(json),
        );
      }
      return LoginResult.failure(LoginFailure.server, message: _message(json));
    } catch (_) {
      return const LoginResult.failure(LoginFailure.network);
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : const {};
    } catch (_) {
      return const {};
    }
  }

  String? _message(Map<String, dynamic> json) =>
      (json['message'] ?? json['error_description'] ?? json['error'])
          ?.toString();
}
