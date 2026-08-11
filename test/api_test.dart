import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retailflow_pos/apis/api.dart';

void main() {
  test('login sends the OAuth password form and returns its token', () async {
    final api = Api(
      loginUrl: 'https://example.test/oauth/token',
      clientId: '9',
      clientSecret: 'configured-secret',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Accept'], 'application/json');
        expect(
          request.headers['Content-Type'],
          startsWith('application/x-www-form-urlencoded'),
        );
        expect(request.bodyFields, {
          'grant_type': 'password',
          'client_id': '9',
          'client_secret': 'configured-secret',
          'username': 'cashier',
          'password': 'password',
        });
        return http.Response('{"access_token":"token-123"}', 200);
      }),
    );

    final result = await api.login('cashier', 'password');

    expect(result.isSuccess, isTrue);
    expect(result.accessToken, 'token-123');
  });

  test('invalid_grant becomes an invalid credentials result', () async {
    final api = Api(
      loginUrl: 'https://example.test/oauth/token',
      clientId: '9',
      clientSecret: 'configured-secret',
      client: MockClient(
        (_) async => http.Response(
          '{"error":"invalid_grant","error_description":"Bad login"}',
          400,
        ),
      ),
    );

    final result = await api.login('wrong', 'wrong');

    expect(result.isSuccess, isFalse);
    expect(result.failure, LoginFailure.invalidCredentials);
  });
}
