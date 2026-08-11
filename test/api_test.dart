import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retailflow_pos/apis/api.dart';
import 'package:retailflow_pos/shared/models/entities.dart';

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
            "category":{"id":7,"name":"Grocery"},
            "unit":{"short_name":"pc"},
            "image_url":"http://localhost:8080/uploads/img/flour.jpg",
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
    expect(products.single.categoryId, '7');
    expect(products.single.imageUrl, endsWith('/flour.jpg'));
  });

  test('categories loads product taxonomies from the backend', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        expect(request.url.queryParameters['type'], 'product');
        return http.Response(
          '{"data":[{"id":7,"name":"Grocery","category_type":"product"}]}',
          200,
        );
      }),
    );

    final categories = await api.categories('token-123');

    expect(categories, hasLength(1));
    expect(categories.single.id, '7');
    expect(categories.single.name, 'Grocery');
  });

  test('stock report follows backend pagination', () async {
    var requests = 0;
    final api = Api(
      client: MockClient((request) async {
        requests++;
        final page = request.url.queryParameters['page'];
        return http.Response(
          '{"data":[{"product_id":$page,"variation_id":$page,"product":"Item $page","sku":"SKU-$page","unit":"pc","stock":"2","alert_quantity":"1","unit_price":"5","location_name":"Main"}],"meta":{"last_page":2}}',
          200,
        );
      }),
    );

    final stock = await api.stockReport('token-123');

    expect(requests, 2);
    expect(stock.map((item) => item.name), ['Item 1', 'Item 2']);
  });

  test('create sale unwraps HTTP 200 item-level backend errors', () async {
    final api = Api(
      client: MockClient(
        (_) async => http.Response(
          '[{"headers":{},"original":{"error":{"message":"Stock allocation failed"}},"exception":null}]',
          200,
        ),
      ),
    );
    const product = Product(
      id: '1',
      variationId: '2',
      name: 'Rice',
      sku: 'SKU-1',
      barcode: 'SKU-1',
      categoryId: '3',
      purchasePrice: 4000,
      sellingPrice: 4900,
      stock: 2,
      minimumStock: 1,
    );

    expect(
      () => api.createSale(
        accessToken: 'token-123',
        locationId: '1',
        customer: const Customer(id: '1', name: 'Walk-in'),
        lines: const [CartLine(product: product)],
        paymentMethod: 'cash',
        total: 4900,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Stock allocation failed',
        ),
      ),
    );
  });
}
