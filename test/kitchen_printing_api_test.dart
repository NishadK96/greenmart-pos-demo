import 'dart:convert';

import 'package:eazy_pos/apis/api.dart';
import 'package:eazy_pos/features/kitchen/domain/kitchen_entities.dart';
import 'package:eazy_pos/shared/models/entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('restaurant tables are filtered by location and mapped', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/table');
        expect(request.url.queryParameters, {'location_id': '2'});
        return http.Response(
          '{"data":[{"id":5,"name":"Table 1","description":null}]}',
          200,
        );
      }),
    );
    final tables = await api.restaurantTables('token', '2');
    expect(tables.single.id, '5');
    expect(tables.single.name, 'Table 1');
    expect(tables.single.description, isEmpty);
  });

  test(
    'restaurant staff and service types map order context options',
    () async {
      final api = Api(
        client: MockClient((request) async {
          if (request.url.path == '/connector/api/user') {
            expect(request.url.queryParameters, {'service_staff': '1'});
            return http.Response(
              '{"data":[{"id":7,"first_name":"Amina","last_name":"Ali"}]}',
              200,
            );
          }
          expect(request.url.path, '/connector/api/types-of-service');
          return http.Response('{"data":[{"id":4,"name":"Dine in"}]}', 200);
        }),
      );

      final staff = await api.restaurantServiceStaff('token');
      final types = await api.restaurantServiceTypes('token');

      expect(staff.single.id, '7');
      expect(staff.single.name, 'Amina Ali');
      expect(types.single.id, '4');
      expect(types.single.name, 'Dine in');
    },
  );

  for (final scenario in [
    (admin: true, permissions: <String>[], allowed: true),
    (admin: false, permissions: ['business_settings.access'], allowed: true),
    (admin: false, permissions: <String>[], allowed: false),
  ]) {
    test(
      'kitchen settings access: admin=${scenario.admin}, permissions=${scenario.permissions}',
      () async {
        final api = Api(
          client: MockClient((request) async {
            expect(request.url.path, '/connector/api/auth/context');
            return http.Response(
              jsonEncode({
                'data': {
                  'is_admin': scenario.admin,
                  'permissions': scenario.permissions,
                },
              }),
              200,
            );
          }),
        );
        final access = await api.connectorAccess('token');
        expect(access.allows('business_settings.access'), scenario.allowed);
      },
    );
  }

  test('kitchen sale is final, unpaid, and accepts 0.transaction_id', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/connector/api/sell');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final sale = (body['sells'] as List).single as Map<String, dynamic>;
        expect(sale['status'], 'draft');
        expect(sale['is_kitchen_order'], 1);
        expect(sale['is_suspend'], 1);
        expect(sale['table_id'], 8);
        expect(sale['service_staff_id'], 7);
        expect(sale['types_of_service_id'], 4);
        expect(sale['client_transaction_id'], isNotEmpty);
        expect(sale.containsKey('payments'), isFalse);
        expect(sale.containsKey('cash_register_id'), isFalse);
        expect(sale['sale_note'], 'Dine in · Table 1');
        final line = (sale['products'] as List).single as Map<String, dynamic>;
        expect(line['note'], 'Less sugar');
        return http.Response(
          jsonEncode({
            'data': {
              '0': {'transaction_id': 145},
            },
          }),
          200,
        );
      }),
    );
    const product = Product(
      id: '2',
      name: 'Tea',
      sku: 'TEA',
      barcode: '123',
      categoryId: '4',
      purchasePrice: 500,
      sellingPrice: 1000,
      stock: 10,
      minimumStock: 0,
      variationId: '3',
    );
    final result = await api.createSale(
      accessToken: 'token',
      locationId: '3',
      customer: const Customer(id: '5', name: 'Walk-in Customer'),
      lines: const [CartLine(product: product, itemNote: 'Less sugar')],
      total: 1000,
      grossDiscount: 0,
      clientTransactionId: '4d2f6b17-4e4b-4f2d-9a1d-0aa1d7a5a001',
      isKitchenOrder: true,
      saleNote: 'Dine in · Table 1',
      status: 'draft',
      tableId: '8',
      serviceStaffId: '7',
      serviceTypeId: '4',
      isSuspended: true,
    );
    expect(result['transaction_id'], 145);
  });

  test('paid kitchen sale includes register and selected payment', () async {
    final api = Api(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final sale = (body['sells'] as List).single as Map<String, dynamic>;
        expect(sale['is_kitchen_order'], 1);
        expect(sale['cash_register_id'], 12);
        expect((sale['payments'] as List).single, {
          'amount': 10.0,
          'method': 'card',
        });
        return http.Response('[{"transaction_id":146}]', 200);
      }),
    );
    const product = Product(
      id: '2',
      name: 'Tea',
      sku: 'TEA',
      barcode: '123',
      categoryId: '4',
      purchasePrice: 500,
      sellingPrice: 1000,
      stock: 10,
      minimumStock: 0,
      variationId: '3',
    );

    final result = await api.createSale(
      accessToken: 'token',
      locationId: '3',
      cashRegisterId: '12',
      customer: const Customer(id: '5', name: 'Walk-in Customer'),
      lines: const [CartLine(product: product)],
      paymentMethod: 'card',
      total: 1000,
      grossDiscount: 0,
      clientTransactionId: '20d8317e-e2ad-48ba-a79a-e39b1621a223',
      isKitchenOrder: true,
    );
    expect(result['transaction_id'], 146);
  });

  test('kitchen order update sends context, item note and payment', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/connector/api/sell/145');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['status'], 'final');
        expect(body['is_kitchen_order'], 1);
        expect(body['is_suspend'], 0);
        expect(body['table_id'], 8);
        expect(body['service_staff_id'], 7);
        expect(body['types_of_service_id'], 4);
        expect(body['sale_note'], 'Dine in · Pax 2');
        expect(body['discount_amount'], 1.5);
        expect((body['payments'] as List).single, {
          'amount': 8.5,
          'method': 'cash',
        });
        final line = (body['products'] as List).single as Map<String, dynamic>;
        expect(line['sell_line_id'], 19);
        expect(line['note'], 'No sugar');
        return http.Response('{"data":{"id":145}}', 200);
      }),
    );
    const product = Product(
      id: '2',
      name: 'Tea',
      sku: 'TEA',
      barcode: '123',
      categoryId: '4',
      purchasePrice: 500,
      sellingPrice: 1000,
      stock: 10,
      minimumStock: 0,
      variationId: '3',
    );

    await api.updateKitchenOrder(
      accessToken: 'token',
      transactionId: '145',
      locationId: '3',
      customer: const Customer(id: '5', name: 'Walk-in Customer'),
      lines: const [
        CartLine(product: product, sellLineId: '19', itemNote: 'No sugar'),
      ],
      status: 'final',
      tableId: '8',
      serviceStaffId: '7',
      serviceTypeId: '4',
      saleNote: 'Dine in · Pax 2',
      grossDiscount: 150,
      paymentMethod: 'cash',
    );
  });

  test('Connector permissions are read from auth context', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.url.path, '/connector/api/auth/context');
        return http.Response(
          jsonEncode({
            'data': {
              'is_admin': true,
              'permissions': ['business_settings.access', 'sell.view'],
            },
          }),
          200,
        );
      }),
    );

    expect(await api.connectorPermissions('token'), {
      'business_settings.access',
      'sell.view',
    });
  });

  test(
    'restaurant settings and printer options map the Connector contract',
    () async {
      final api = Api(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/restaurant-settings')) {
            return http.Response(
              jsonEncode({
                'data': {
                  'location_id': 3,
                  'receipt': {
                    'print_receipt_on_invoice': 1,
                    'receipt_printer_type': 'printer',
                    'printer_id': 5,
                  },
                  'kitchen': {
                    'selected_template': 'food_preparation',
                    'templates': [
                      {'key': 'thermal', 'name': 'Thermal 80mm'},
                      {
                        'key': 'food_preparation',
                        'name': 'Food preparation ticket',
                      },
                    ],
                  },
                  'invoice': {'invoice_layout_id': 4, 'invoice_scheme_id': 7},
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'data': {
                'location_id': 3,
                'printers': [
                  {'id': 5, 'name': 'Hot kitchen', 'location_id': 3},
                ],
                'categories': [
                  {
                    'id': 4,
                    'name': 'Food',
                    'sub_categories': [
                      {'id': 9, 'name': 'Grill'},
                    ],
                  },
                ],
                'templates': [
                  {'key': 'thermal', 'name': 'Thermal 80mm'},
                ],
              },
            }),
            200,
          );
        }),
      );

      final settings = await api.restaurantSettings(
        accessToken: 'token',
        locationId: '3',
      );
      final options = await api.kitchenPrinterOptions(
        accessToken: 'token',
        locationId: '3',
      );

      expect(settings.selectedTemplate, 'food_preparation');
      expect(settings.printReceiptOnInvoice, isTrue);
      expect(settings.receiptPrinterId, '5');
      expect(options.printers.single.name, 'Hot kitchen');
      expect(options.categories.single.subCategories.single.name, 'Grill');
    },
  );

  test('route save sends the complete routing contract', () async {
    final api = Api(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/connector/api/business-location/3/kitchen-printer-routes',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body, {
          'category_id': 4,
          'sub_category_id': 9,
          'printer_id': 5,
          'template_key': 'food_preparation',
          'priority': 10,
          'is_active': true,
        });
        return http.Response(
          jsonEncode({
            'data': {
              'id': 21,
              'category': {'id': 4, 'name': 'Food'},
              'sub_category': {'id': 9, 'name': 'Grill'},
              'printer': {'id': 5, 'name': 'Hot kitchen'},
              'template': {
                'key': 'food_preparation',
                'name': 'Food preparation ticket',
              },
              'priority': 10,
              'is_active': true,
            },
          }),
          201,
        );
      }),
    );

    final route = await api.saveKitchenPrinterRoute(
      accessToken: 'token',
      locationId: '3',
      values: const {
        'category_id': 4,
        'sub_category_id': 9,
        'printer_id': 5,
        'template_key': 'food_preparation',
        'priority': 10,
        'is_active': true,
      },
    );

    expect(route.id, '21');
    expect(route.subCategory?.name, 'Grill');
  });

  test(
    'durable kitchen jobs preserve items, modifiers and printer status',
    () async {
      final api = Api(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/connector/api/transactions/145/kitchen-print-jobs',
          );
          return http.Response(
            jsonEncode({
              'data': {
                'jobs': [
                  {
                    'id': 101,
                    'status': 'pending',
                    'transaction_id': 145,
                    'location_id': 3,
                    'template': 'thermal',
                    'attempts': 0,
                    'printer': {'id': 5, 'name': 'Hot kitchen'},
                    'items': [
                      {
                        'product_name': 'Burger',
                        'quantity': 2,
                        'note': 'No onions',
                        'modifiers': [
                          {'product_name': 'Extra cheese', 'quantity': 1},
                        ],
                      },
                    ],
                  },
                ],
                'unassigned_items': [],
              },
            }),
            200,
          );
        }),
      );

      final result = await api.generateKitchenPrintJobs(
        accessToken: 'token',
        transactionId: '145',
        locationId: '3',
      );

      expect(result.jobs.single.printer.id, '5');
      expect(result.jobs.single.items.single.note, 'No onions');
      expect(
        result.jobs.single.items.single.modifiers.single.productName,
        'Extra cheese',
      );
    },
  );

  test('kitchen domain accepts compact job status acknowledgements', () {
    final job = KitchenPrintJob.fromJson({
      'id': 101,
      'status': 'printed',
      'attempts': 1,
      'printed_at': '2026-09-14T10:01:00.000000Z',
    });

    expect(job.id, '101');
    expect(job.status, 'printed');
    expect(job.attempts, 1);
  });
}
