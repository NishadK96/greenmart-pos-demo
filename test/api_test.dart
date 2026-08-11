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

  test('products maps EazyERP price, stock, category, and image', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.url.queryParameters['per_page'], '-1');
        return http.Response('''
          {"data":[{
            "id":1,"name":"Whole Wheat Flour","sku":"SKU-1001",
            "category":{"name":"Grocery"},
            "unit":{"short_name":"pc"},
            "alert_quantity":"6.0000","is_inactive":0,
            "product_variations":[{"variations":[{
              "dpp_inc_tax":"36.7500","sell_price_inc_tax":"51.2500",
              "variation_location_details":[{"qty_available":"19.0000"}]
            }]}]
          }]}
        ''', 200);
      }),
    );

    final products = await api.products('token-123');

    expect(products, hasLength(1));
    expect(products.single.name, 'Whole Wheat Flour');
    expect(products.single.sellingPrice, 5125);
    expect(products.single.stock, 19);
    expect(products.single.categoryId, 'grocery');
    expect(products.single.imageAsset, endsWith('/wheat_flour.jpg'));
  });
}
